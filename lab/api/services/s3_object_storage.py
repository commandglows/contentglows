"""Amazon S3 implementation of the provider-neutral object-storage port."""

from __future__ import annotations

from base64 import b64decode, b64encode
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import re
from tempfile import SpooledTemporaryFile
from typing import Any, Callable, Mapping, Sequence
from uuid import uuid4

from api.services.object_storage import (
    ObjectStat,
    ObjectStorageCapabilities,
    ObjectStorageError,
    PresignedOperation,
    PrivateSessionState,
    StorageLocator,
    UploadedPart,
    UploadMode,
    UploadSession,
    UploadSource,
)
from api.services import object_storage as _contract


_SERVER_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$")


@dataclass
class _S3SessionState:
    public: UploadSession
    key: str
    upload_id: str | None = None
    parts: dict[int, UploadedPart] = field(default_factory=dict)
    completed: StorageLocator | None = None
    aborted: bool = False


class S3ObjectStorageProvider:
    """Version-aware private S3 adapter with injectable client and clock.

    Passing ``client`` is the recommended construction path in tests and in
    dependency-injected runtimes. If omitted, boto3 resolves credentials only
    from the server runtime's standard credential chain.
    """

    provider_name = "s3"
    capabilities = ObjectStorageCapabilities()

    def __init__(
        self,
        *,
        bucket: str,
        client: Any | None = None,
        region_name: str | None = None,
        endpoint_url: str | None = None,
        key_prefix: str = "contentglows",
        server_side_encryption: str = "AES256",
        kms_key_id: str | None = None,
        max_proxy_bytes: int = 10 * 1024 * 1024,
        max_object_bytes: int = 250 * 1024 * 1024,
        min_part_bytes: int = 5 * 1024 * 1024,
        max_part_bytes: int = 64 * 1024 * 1024,
        max_parts: int = 10_000,
        max_range_bytes: int = 8 * 1024 * 1024,
        spool_memory_bytes: int = 1024 * 1024,
        clock: Callable[[], datetime] | None = None,
        id_factory: Callable[[], str] | None = None,
        session_id_factory: Callable[[], str] | None = None,
    ) -> None:
        _validate_secret_config(bucket=bucket, kms_key_id=kms_key_id)
        _contract._validate_positive_limits(
            max_proxy_bytes=max_proxy_bytes,
            max_object_bytes=max_object_bytes,
            min_part_bytes=min_part_bytes,
            max_part_bytes=max_part_bytes,
            max_parts=max_parts,
            max_range_bytes=max_range_bytes,
            spool_memory_bytes=spool_memory_bytes,
        )
        if min_part_bytes > max_part_bytes:
            raise ValueError("Minimum multipart size cannot exceed maximum multipart size")
        self._bucket = bucket
        self._key_prefix = _validate_key_prefix(key_prefix)
        self._server_side_encryption = server_side_encryption
        self._kms_key_id = kms_key_id
        self.max_proxy_bytes = max_proxy_bytes
        self.max_object_bytes = max_object_bytes
        self.min_part_bytes = min_part_bytes
        self.max_part_bytes = max_part_bytes
        self.max_parts = max_parts
        self.max_range_bytes = max_range_bytes
        self.spool_memory_bytes = spool_memory_bytes
        self._clock = clock or _utc_now
        self._id_factory = id_factory or (lambda: uuid4().hex)
        self._session_id_factory = session_id_factory or (lambda: uuid4().hex)
        self._sessions: dict[str, _S3SessionState] = {}
        if client is None:
            import boto3

            client = boto3.client(
                "s3",
                region_name=region_name,
                endpoint_url=endpoint_url,
            )
        self._client = client

    def __repr__(self) -> str:
        return "S3ObjectStorageProvider(provider='s3', bucket=<redacted>, key_prefix=<redacted>)"

    def presign_private_read(self, *, locator: StorageLocator, expires_in: int = 120) -> str:
        """Return a short-lived read URL for an already-authorized private object."""
        if locator.provider != self.provider_name or expires_in < 30 or expires_in > 300:
            raise ObjectStorageError(
                code="invalid_read_request",
                message="Private media delivery request is invalid.",
            )
        try:
            return str(
                self._client.generate_presigned_url(
                    "get_object",
                    Params={
                        "Bucket": self._bucket,
                        "Key": locator.object_key,
                        "VersionId": locator.version,
                    },
                    ExpiresIn=expires_in,
                    HttpMethod="GET",
                )
            )
        except Exception as exc:
            raise ObjectStorageError(
                code="preview_delivery_unavailable",
                message="Private media preview is temporarily unavailable.",
                retryable=True,
            ) from exc

    def create_upload_session(
        self,
        *,
        namespace: str,
        content_type: str,
        expected_size: int,
        checksum_sha256: str,
        mode: UploadMode | None = None,
        expires_in: int = 900,
    ) -> UploadSession:
        selected_mode = _contract._validate_upload_request(
            namespace=namespace,
            content_type=content_type,
            expected_size=expected_size,
            checksum_sha256=checksum_sha256,
            mode=mode,
            expires_in=expires_in,
            max_proxy_bytes=self.max_proxy_bytes,
            max_object_bytes=self.max_object_bytes,
        )
        server_id = self._new_identifier(self._id_factory)
        session_id = f"session-{self._new_identifier(self._session_id_factory)}"
        key = f"{self._key_prefix}/{namespace}/{server_id}"
        upload_id: str | None = None
        if selected_mode is UploadMode.MULTIPART:
            try:
                response = self._client.create_multipart_upload(
                    Bucket=self._bucket,
                    Key=key,
                    ContentType=content_type,
                    ChecksumAlgorithm="SHA256",
                    **self._encryption_args(),
                )
                upload_id = str(response.get("UploadId") or "")
            except Exception:
                raise ObjectStorageError(
                    code="multipart_initialization_failed",
                    message="Multipart upload could not be initialized",
                    retryable=True,
                ) from None
            if not upload_id or _contract._has_control(upload_id):
                raise ObjectStorageError(
                    code="invalid_provider_response",
                    message="Storage provider returned an invalid upload receipt",
                    retryable=True,
                )
        session = UploadSession(
            session_id=session_id,
            provider=self.provider_name,
            mode=selected_mode,
            namespace=namespace,
            content_type=content_type,
            expected_size=expected_size,
            checksum_sha256=checksum_sha256,
            expires_at=self._clock() + timedelta(seconds=expires_in),
        )
        self._sessions[session_id] = _S3SessionState(
            public=session,
            key=key,
            upload_id=upload_id,
        )
        return session

    def upload_proxy(self, *, session: UploadSession, source: UploadSource) -> StorageLocator:
        state = self._require_session(session, expected_mode=UploadMode.PROXY)
        if state.completed is not None:
            return state.completed
        stream, size_bytes, checksum_hex, checksum_b64 = self._spool_source(
            source,
            limit=session.expected_size,
        )
        try:
            self._verify_upload_values(
                size_bytes=size_bytes,
                checksum_sha256=checksum_hex,
                session=session,
            )
            try:
                response = self._client.put_object(
                    Bucket=self._bucket,
                    Key=state.key,
                    Body=stream,
                    ContentLength=size_bytes,
                    ContentType=session.content_type,
                    ChecksumSHA256=checksum_b64,
                    **self._encryption_args(),
                )
            except Exception:
                raise ObjectStorageError(
                    code="proxy_upload_failed",
                    message="Object upload failed",
                    retryable=True,
                ) from None
            version = str(response.get("VersionId") or "")
            if not version:
                self._safe_delete_key(state.key, version=None)
                raise ObjectStorageError(
                    code="versioning_required",
                    message="Object storage did not return a durable version",
                )
            locator = StorageLocator(
                provider=self.provider_name,
                namespace=session.namespace,
                object_key=state.key,
                version=version,
                checksum_sha256=session.checksum_sha256,
            )
            try:
                self._verify_remote(locator, expected_size=session.expected_size)
            except ObjectStorageError:
                self._safe_delete_key(state.key, version=version)
                raise
            state.completed = locator
            return locator
        finally:
            stream.close()

    def presign_upload_part(
        self,
        *,
        session: UploadSession,
        part_number: int,
        checksum_sha256: str | None = None,
        size_bytes: int | None = None,
        expires_in: int = 300,
    ) -> PresignedOperation:
        state = self._require_session(session, expected_mode=UploadMode.MULTIPART)
        _contract._validate_part_number(part_number, self.max_parts)
        bound_part = _contract._validate_presigned_part(
            checksum_sha256=checksum_sha256,
            size_bytes=size_bytes,
            max_part_bytes=self.max_part_bytes,
        )
        _contract._validate_presign_ttl(expires_in, session=session, now=self._clock())
        checksum_b64 = _hex_to_b64(bound_part[0]) if bound_part is not None else None
        params: dict[str, Any] = {
            "Bucket": self._bucket,
            "Key": state.key,
            "UploadId": state.upload_id,
            "PartNumber": part_number,
        }
        if bound_part is not None:
            params["ChecksumSHA256"] = checksum_b64
            params["ContentLength"] = bound_part[1]
        try:
            url = self._client.generate_presigned_url(
                "upload_part",
                Params=params,
                ExpiresIn=expires_in,
                HttpMethod="PUT",
            )
        except Exception:
            raise ObjectStorageError(
                code="presign_failed",
                message="Signed upload operation could not be created",
                retryable=True,
            ) from None
        return PresignedOperation(
            method="PUT",
            url=str(url),
            expires_at=self._clock() + timedelta(seconds=expires_in),
            headers=(
                {"x-amz-checksum-sha256": checksum_b64}
                if checksum_b64 is not None
                else {}
            ),
        )

    def upload_part(
        self,
        *,
        session: UploadSession,
        part_number: int,
        source: UploadSource,
    ) -> UploadedPart:
        state = self._require_session(session, expected_mode=UploadMode.MULTIPART)
        _contract._validate_part_number(part_number, self.max_parts)
        stream, size_bytes, checksum_hex, checksum_b64 = self._spool_source(
            source,
            limit=self.max_part_bytes,
        )
        try:
            if size_bytes == 0:
                raise ObjectStorageError(code="empty_upload_part", message="Upload part is empty")
            try:
                response = self._client.upload_part(
                    Bucket=self._bucket,
                    Key=state.key,
                    UploadId=state.upload_id,
                    PartNumber=part_number,
                    Body=stream,
                    ContentLength=size_bytes,
                    ChecksumSHA256=checksum_b64,
                )
            except Exception:
                raise ObjectStorageError(
                    code="upload_part_failed",
                    message="Multipart upload part failed",
                    retryable=True,
                ) from None
            etag = str(response.get("ETag") or "")
            if not etag:
                raise ObjectStorageError(
                    code="invalid_provider_response",
                    message="Storage provider returned an invalid part receipt",
                    retryable=True,
                )
            receipt = UploadedPart(
                part_number=part_number,
                etag=etag,
                checksum_sha256=checksum_hex,
                size_bytes=size_bytes,
            )
            previous = state.parts.get(part_number)
            if previous is not None and previous != receipt:
                raise ObjectStorageError(
                    code="upload_part_conflict",
                    message="Upload part conflicts with its previous receipt",
                )
            state.parts[part_number] = receipt
            return receipt
        finally:
            stream.close()

    def complete_upload(
        self,
        *,
        session: UploadSession,
        parts: Sequence[UploadedPart],
    ) -> StorageLocator:
        state = self._require_session(session, expected_mode=UploadMode.MULTIPART)
        if state.completed is not None:
            return state.completed
        ordered = self._validate_completion_parts(session=session, state=state, parts=parts)
        request_parts = [
            {
                "PartNumber": part.part_number,
                "ETag": part.etag,
                "ChecksumSHA256": _hex_to_b64(part.checksum_sha256),
            }
            for part in ordered
        ]
        try:
            response = self._client.complete_multipart_upload(
                Bucket=self._bucket,
                Key=state.key,
                UploadId=state.upload_id,
                MultipartUpload={"Parts": request_parts},
            )
            version = str(response.get("VersionId") or "")
        except Exception:
            recovered = self._recover_completed_upload(session=session, state=state)
            if recovered is not None:
                state.completed = recovered
                return recovered
            raise ObjectStorageError(
                code="multipart_completion_failed",
                message="Multipart upload could not be completed",
                retryable=True,
            ) from None
        if not version:
            self._safe_delete_key(state.key, version=None)
            raise ObjectStorageError(
                code="versioning_required",
                message="Object storage did not return a durable version",
            )
        locator = StorageLocator(
            provider=self.provider_name,
            namespace=session.namespace,
            object_key=state.key,
            version=version,
            checksum_sha256=session.checksum_sha256,
        )
        try:
            self._verify_remote(locator, expected_size=session.expected_size)
        except ObjectStorageError:
            self._safe_delete_key(state.key, version=version)
            raise
        state.completed = locator
        return locator

    def abort_upload(self, session: UploadSession) -> None:
        state = self._sessions.get(session.session_id)
        if state is None:
            return
        if state.public != session:
            raise ObjectStorageError(code="invalid_upload_session", message="Upload session is invalid")
        if state.aborted or state.completed is not None:
            return
        if state.upload_id:
            try:
                self._client.abort_multipart_upload(
                    Bucket=self._bucket,
                    Key=state.key,
                    UploadId=state.upload_id,
                )
            except Exception:
                raise ObjectStorageError(
                    code="multipart_abort_failed",
                    message="Multipart upload cleanup failed",
                    retryable=True,
                ) from None
        state.parts.clear()
        state.aborted = True

    def export_session_state(self, session: UploadSession) -> PrivateSessionState:
        state = self._require_session(session, expected_mode=session.mode)
        if state.completed is not None:
            raise ObjectStorageError(
                code="upload_already_completed",
                message="Upload session is already complete",
            )
        return PrivateSessionState(
            {
                "state_version": "1",
                "provider": self.provider_name,
                "object_key": state.key,
                "upload_id": state.upload_id or "",
                "session_fingerprint": _contract._session_fingerprint(session),
            }
        )

    def restore_session(self, session: UploadSession, state: Mapping[str, str]) -> None:
        values = _contract._validate_private_state_shape(state)
        key_prefix = f"{self._key_prefix}/{session.namespace}/"
        server_id = values["object_key"][len(key_prefix) :] if values["object_key"].startswith(key_prefix) else ""
        upload_id_valid = (
            bool(values["upload_id"])
            if session.mode is UploadMode.MULTIPART
            else values["upload_id"] == ""
        )
        valid = (
            session.provider == self.provider_name
            and values["provider"] == self.provider_name
            and bool(_SERVER_ID_RE.fullmatch(server_id))
            and upload_id_valid
            and hmac.compare_digest(
                values["session_fingerprint"],
                _contract._session_fingerprint(session),
            )
            and self._clock() < session.expires_at
        )
        if not valid:
            raise ObjectStorageError(
                code="invalid_private_session_state",
                message="Private upload session state is invalid",
            )
        existing = self._sessions.get(session.session_id)
        if existing is not None:
            if (
                existing.public == session
                and existing.key == values["object_key"]
                and (existing.upload_id or "") == values["upload_id"]
            ):
                return
            raise ObjectStorageError(
                code="invalid_private_session_state",
                message="Private upload session state is invalid",
            )
        self._sessions[session.session_id] = _S3SessionState(
            public=session,
            key=values["object_key"],
            upload_id=values["upload_id"] or None,
        )

    def stat(self, locator: StorageLocator) -> ObjectStat:
        self._require_provider(locator)
        response = self._head(locator.object_key, version=locator.version)
        version = str(response.get("VersionId") or locator.version)
        if version != locator.version:
            raise ObjectStorageError(code="version_mismatch", message="Stored object version is unavailable")
        size_bytes = int(response.get("ContentLength", -1))
        if size_bytes < 0:
            raise ObjectStorageError(
                code="invalid_provider_response",
                message="Storage provider returned invalid object metadata",
                retryable=True,
            )
        checksum = _checksum_from_head(response)
        if checksum is None:
            checksum = self._stream_remote_checksum(
                key=locator.object_key,
                version=locator.version,
                max_bytes=min(self.max_object_bytes, size_bytes),
            )
        if checksum != locator.checksum_sha256:
            raise ObjectStorageError(code="checksum_mismatch", message="Stored object checksum is invalid")
        content_type = str(response.get("ContentType") or "application/octet-stream").split(";", 1)[0]
        try:
            _contract._validate_content_type(content_type)
        except ValueError:
            content_type = "application/octet-stream"
        return ObjectStat(
            locator=locator,
            size_bytes=size_bytes,
            content_type=content_type,
            checksum_sha256=checksum,
            etag=str(response.get("ETag") or "") or None,
        )

    def promote(
        self,
        locator: StorageLocator,
        *,
        target_namespace: str,
        delete_source: bool = False,
    ) -> StorageLocator:
        self._require_provider(locator)
        try:
            _contract._validate_namespace(target_namespace)
        except ValueError:
            raise ObjectStorageError(code="invalid_namespace", message="Storage namespace is invalid") from None
        server_id = self._new_identifier(self._id_factory)
        target_key = f"{self._key_prefix}/{target_namespace}/{server_id}"
        try:
            response = self._client.copy_object(
                Bucket=self._bucket,
                Key=target_key,
                CopySource={
                    "Bucket": self._bucket,
                    "Key": locator.object_key,
                    "VersionId": locator.version,
                },
                MetadataDirective="COPY",
                ChecksumAlgorithm="SHA256",
                **self._encryption_args(),
            )
        except Exception:
            raise ObjectStorageError(
                code="promotion_failed",
                message="Stored object could not be promoted",
                retryable=True,
            ) from None
        version = str(response.get("VersionId") or "")
        if not version:
            head = self._head(target_key, version=None)
            version = str(head.get("VersionId") or "")
        if not version:
            self._safe_delete_key(target_key, version=None)
            raise ObjectStorageError(
                code="versioning_required",
                message="Promoted object has no durable version",
            )
        promoted = StorageLocator(
            provider=self.provider_name,
            namespace=target_namespace,
            object_key=target_key,
            version=version,
            checksum_sha256=locator.checksum_sha256,
        )
        try:
            source_stat = self.stat(locator)
            self._verify_remote(promoted, expected_size=source_stat.size_bytes)
        except ObjectStorageError:
            self._safe_delete_key(target_key, version=version)
            raise
        if delete_source:
            self.delete_version(locator)
        return promoted

    def delete_version(self, locator: StorageLocator) -> None:
        self._require_provider(locator)
        try:
            self._client.delete_object(
                Bucket=self._bucket,
                Key=locator.object_key,
                VersionId=locator.version,
            )
        except Exception:
            raise ObjectStorageError(
                code="delete_failed",
                message="Stored object cleanup failed",
                retryable=True,
            ) from None

    def read_range(self, locator: StorageLocator, *, start: int, end: int) -> bytes:
        self._require_provider(locator)
        _contract._validate_range(start=start, end=end, max_range_bytes=self.max_range_bytes)
        try:
            response = self._client.get_object(
                Bucket=self._bucket,
                Key=locator.object_key,
                VersionId=locator.version,
                Range=f"bytes={start}-{end}",
            )
            body = response["Body"]
            payload = body.read(self.max_range_bytes + 1)
            close = getattr(body, "close", None)
            if callable(close):
                close()
        except Exception:
            raise ObjectStorageError(
                code="range_read_failed",
                message="Stored object range is unavailable",
                retryable=True,
            ) from None
        if not isinstance(payload, bytes) or len(payload) > self.max_range_bytes:
            raise ObjectStorageError(
                code="invalid_provider_response",
                message="Storage provider returned an invalid object range",
                retryable=True,
            )
        return payload

    @staticmethod
    def _new_identifier(factory: Callable[[], str]) -> str:
        try:
            value = str(factory())
        except Exception:
            raise ObjectStorageError(
                code="invalid_server_identifier",
                message="Server could not allocate a storage identifier",
            ) from None
        if not _SERVER_ID_RE.fullmatch(value):
            raise ObjectStorageError(
                code="invalid_server_identifier",
                message="Server could not allocate a storage identifier",
            )
        return value

    def _require_session(
        self,
        session: UploadSession,
        *,
        expected_mode: UploadMode,
    ) -> _S3SessionState:
        state = self._sessions.get(session.session_id)
        if state is None or state.public != session or session.provider != self.provider_name:
            raise ObjectStorageError(code="invalid_upload_session", message="Upload session is invalid")
        if state.aborted:
            raise ObjectStorageError(code="upload_aborted", message="Upload session is no longer active")
        if self._clock() >= session.expires_at:
            raise ObjectStorageError(code="upload_session_expired", message="Upload session has expired")
        if session.mode is not expected_mode:
            raise ObjectStorageError(code="invalid_upload_mode", message="Upload mode is invalid")
        return state

    def _require_provider(self, locator: StorageLocator) -> None:
        if locator.provider != self.provider_name:
            raise ObjectStorageError(code="unsupported_provider", message="Storage provider is unsupported")

    def _spool_source(
        self,
        source: UploadSource,
        *,
        limit: int,
    ) -> tuple[SpooledTemporaryFile[bytes], int, str, str]:
        stream = SpooledTemporaryFile(max_size=self.spool_memory_bytes, mode="w+b")
        digest = hashlib.sha256()
        total = 0
        try:
            reader = _source_reader(source)
            while True:
                chunk = reader(min(1024 * 1024, limit + 1 - total))
                if not chunk:
                    break
                if not isinstance(chunk, bytes):
                    raise ObjectStorageError(code="invalid_upload_source", message="Upload source is invalid")
                total += len(chunk)
                if total > limit:
                    raise ObjectStorageError(
                        code="upload_too_large",
                        message="Upload exceeds its declared size",
                    )
                digest.update(chunk)
                stream.write(chunk)
            stream.seek(0)
            digest_bytes = digest.digest()
            return stream, total, digest.hexdigest(), b64encode(digest_bytes).decode("ascii")
        except ObjectStorageError:
            stream.close()
            raise
        except Exception:
            stream.close()
            raise ObjectStorageError(
                code="invalid_upload_source",
                message="Upload source is invalid",
            ) from None

    def _verify_upload_values(
        self,
        *,
        size_bytes: int,
        checksum_sha256: str,
        session: UploadSession,
    ) -> None:
        if size_bytes != session.expected_size:
            raise ObjectStorageError(code="size_mismatch", message="Upload size does not match its session")
        if checksum_sha256 != session.checksum_sha256:
            raise ObjectStorageError(
                code="checksum_mismatch",
                message="Upload checksum does not match its session",
            )

    def _validate_completion_parts(
        self,
        *,
        session: UploadSession,
        state: _S3SessionState,
        parts: Sequence[UploadedPart],
    ) -> tuple[UploadedPart, ...]:
        ordered = tuple(sorted(parts, key=lambda part: part.part_number))
        if not ordered or len(ordered) > self.max_parts:
            raise ObjectStorageError(code="invalid_multipart_receipts", message="Multipart receipts are invalid")
        if tuple(part.part_number for part in ordered) != tuple(range(1, len(ordered) + 1)):
            raise ObjectStorageError(code="invalid_multipart_receipts", message="Multipart receipts are invalid")
        for index, part in enumerate(ordered):
            recorded = state.parts.get(part.part_number)
            if recorded is not None and recorded != part:
                raise ObjectStorageError(code="invalid_multipart_receipts", message="Multipart receipts are invalid")
            if part.size_bytes > self.max_part_bytes:
                raise ObjectStorageError(code="upload_part_too_large", message="Multipart part exceeds its size limit")
            if index < len(ordered) - 1 and part.size_bytes < self.min_part_bytes:
                raise ObjectStorageError(code="upload_part_too_small", message="Multipart part is below its size limit")
        if sum(part.size_bytes for part in ordered) != session.expected_size:
            raise ObjectStorageError(code="size_mismatch", message="Multipart size does not match its session")
        return ordered

    def _verify_remote(self, locator: StorageLocator, *, expected_size: int) -> ObjectStat:
        stat = self.stat(locator)
        if stat.size_bytes != expected_size:
            raise ObjectStorageError(code="size_mismatch", message="Stored object size is invalid")
        return stat

    def _recover_completed_upload(
        self,
        *,
        session: UploadSession,
        state: _S3SessionState,
    ) -> StorageLocator | None:
        try:
            head = self._head(state.key, version=None)
            version = str(head.get("VersionId") or "")
            if not version:
                return None
            locator = StorageLocator(
                provider=self.provider_name,
                namespace=session.namespace,
                object_key=state.key,
                version=version,
                checksum_sha256=session.checksum_sha256,
            )
            self._verify_remote(locator, expected_size=session.expected_size)
            return locator
        except (ObjectStorageError, ValueError):
            return None

    def _head(self, key: str, *, version: str | None) -> Mapping[str, Any]:
        params: dict[str, Any] = {
            "Bucket": self._bucket,
            "Key": key,
            "ChecksumMode": "ENABLED",
        }
        if version:
            params["VersionId"] = version
        try:
            return self._client.head_object(**params)
        except Exception:
            raise ObjectStorageError(
                code="object_not_found",
                message="Stored object is unavailable",
                retryable=True,
            ) from None

    def _stream_remote_checksum(self, *, key: str, version: str, max_bytes: int) -> str:
        try:
            response = self._client.get_object(
                Bucket=self._bucket,
                Key=key,
                VersionId=version,
            )
            body = response["Body"]
            digest = hashlib.sha256()
            total = 0
            iterator = getattr(body, "iter_chunks", None)
            chunks = iterator(chunk_size=1024 * 1024) if callable(iterator) else iter(lambda: body.read(1024 * 1024), b"")
            for chunk in chunks:
                if not chunk:
                    continue
                total += len(chunk)
                if total > max_bytes:
                    raise ObjectStorageError(
                        code="object_too_large",
                        message="Stored object exceeds its verified size",
                    )
                digest.update(chunk)
            close = getattr(body, "close", None)
            if callable(close):
                close()
            return digest.hexdigest()
        except ObjectStorageError:
            raise
        except Exception:
            raise ObjectStorageError(
                code="checksum_unavailable",
                message="Stored object checksum is unavailable",
                retryable=True,
            ) from None

    def _safe_delete_key(self, key: str, *, version: str | None) -> None:
        params: dict[str, Any] = {"Bucket": self._bucket, "Key": key}
        if version:
            params["VersionId"] = version
        try:
            self._client.delete_object(**params)
        except Exception:
            # The caller still receives the original safe failure. Reconciliation
            # owns follow-up when best-effort compensation cannot complete.
            return

    def _encryption_args(self) -> dict[str, str]:
        args = {"ServerSideEncryption": self._server_side_encryption}
        if self._kms_key_id:
            args["SSEKMSKeyId"] = self._kms_key_id
        return args


def _source_reader(source: UploadSource) -> Callable[[int], bytes]:
    if isinstance(source, (bytes, bytearray, memoryview)):
        buffer = memoryview(bytes(source))
        offset = 0

        def read(amount: int) -> bytes:
            nonlocal offset
            chunk = bytes(buffer[offset : offset + amount])
            offset += len(chunk)
            return chunk

        return read
    read = getattr(source, "read", None)
    if not callable(read):
        raise ObjectStorageError(code="invalid_upload_source", message="Upload source is invalid")
    return read


def _checksum_from_head(response: Mapping[str, Any]) -> str | None:
    raw = response.get("ChecksumSHA256")
    if not raw:
        return None
    # SHA-256 multipart checksums are composite in S3 (typically suffixed
    # ``-N``) and are not the SHA-256 of the full byte stream persisted in the
    # provider-neutral locator. Stream once, bounded by ContentLength, to
    # verify the canonical full-object digest instead.
    if str(response.get("ChecksumType") or "").upper() == "COMPOSITE" or "-" in str(raw):
        return None
    try:
        decoded = b64decode(str(raw), validate=True)
    except Exception:
        raise ObjectStorageError(
            code="invalid_provider_response",
            message="Storage provider returned an invalid checksum",
            retryable=True,
        ) from None
    if len(decoded) != hashlib.sha256().digest_size:
        raise ObjectStorageError(
            code="invalid_provider_response",
            message="Storage provider returned an invalid checksum",
            retryable=True,
        )
    return decoded.hex()


def _hex_to_b64(checksum_sha256: str) -> str:
    return b64encode(bytes.fromhex(checksum_sha256)).decode("ascii")


def _validate_secret_config(*, bucket: str, kms_key_id: str | None) -> None:
    if not bucket or len(bucket) > 255 or _contract._has_control(bucket):
        raise ValueError("S3 bucket configuration is invalid")
    if kms_key_id is not None and (not kms_key_id or _contract._has_control(kms_key_id)):
        raise ValueError("S3 KMS configuration is invalid")


def _validate_key_prefix(value: str) -> str:
    normalized = value.strip("/")
    try:
        _contract._validate_object_key(f"{normalized}/sentinel")
    except ValueError:
        raise ValueError("S3 key prefix configuration is invalid") from None
    return normalized


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


__all__ = ["S3ObjectStorageProvider"]
