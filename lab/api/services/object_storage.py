"""Provider-neutral object-storage contracts and a deterministic test adapter.

The domain persists :class:`StorageLocator`, never a durable URL. Provider
credentials, buckets, physical object identifiers, multipart upload IDs and
signed operations remain adapter concerns.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from enum import Enum
import hashlib
import hmac
import re
from types import MappingProxyType
from typing import BinaryIO, Callable, Iterator, Mapping, Protocol, Sequence, runtime_checkable


_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_PROVIDER_RE = re.compile(r"^[a-z][a-z0-9-]{0,31}$")
_NAMESPACE_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")
_CONTENT_TYPE_RE = re.compile(r"^[a-z0-9][a-z0-9.+-]*/[a-z0-9][a-z0-9.+-]*$")


class ObjectStorageError(RuntimeError):
    """A stable, shareable storage error that never embeds provider details."""

    def __init__(self, *, code: str, message: str, retryable: bool = False) -> None:
        super().__init__(message)
        self.code = code
        self.retryable = retryable

    def __repr__(self) -> str:
        return f"ObjectStorageError(code={self.code!r}, retryable={self.retryable!r})"


class UploadMode(str, Enum):
    PROXY = "proxy"
    MULTIPART = "multipart"


@dataclass(frozen=True, repr=False)
class StorageLocator:
    """Durable provider-neutral object identity, intentionally without a URL."""

    provider: str
    namespace: str
    object_key: str
    version: str
    checksum_sha256: str

    def __post_init__(self) -> None:
        _validate_provider(self.provider)
        _validate_namespace(self.namespace)
        _validate_object_key(self.object_key)
        _validate_version(self.version)
        _validate_checksum(self.checksum_sha256)

    def __repr__(self) -> str:
        return (
            "StorageLocator("
            f"provider={self.provider!r}, namespace={self.namespace!r}, "
            "object_key=<redacted>, version=<redacted>, checksum_sha256=<redacted>)"
        )


@dataclass(frozen=True, repr=False)
class UploadSession:
    """Opaque server-created upload capability.

    The physical object key and provider upload ID are deliberately absent.
    Adapters must bind this immutable public record to private server state and
    reject any modified copy.
    """

    session_id: str
    provider: str
    mode: UploadMode
    namespace: str
    content_type: str
    expected_size: int
    checksum_sha256: str
    expires_at: datetime

    def __post_init__(self) -> None:
        if not self.session_id or len(self.session_id) > 256 or _has_control(self.session_id):
            raise ValueError("Upload session id is invalid")
        _validate_provider(self.provider)
        _validate_namespace(self.namespace)
        _validate_content_type(self.content_type)
        if self.expected_size <= 0:
            raise ValueError("Expected upload size must be positive")
        _validate_checksum(self.checksum_sha256)
        if self.expires_at.tzinfo is None:
            raise ValueError("Upload session expiry must be timezone-aware")

    def __repr__(self) -> str:
        return (
            "UploadSession("
            "session_id=<redacted>, "
            f"provider={self.provider!r}, mode={self.mode.value!r}, "
            f"namespace={self.namespace!r}, content_type={self.content_type!r}, "
            f"expected_size={self.expected_size!r}, checksum_sha256=<redacted>, "
            f"expires_at={self.expires_at.isoformat()!r})"
        )


@dataclass(frozen=True, repr=False)
class UploadedPart:
    part_number: int
    etag: str
    checksum_sha256: str
    size_bytes: int

    def __post_init__(self) -> None:
        if self.part_number <= 0 or self.part_number > 10_000:
            raise ValueError("Multipart part number is invalid")
        if not self.etag or len(self.etag) > 512 or _has_control(self.etag):
            raise ValueError("Multipart part receipt is invalid")
        _validate_checksum(self.checksum_sha256)
        if self.size_bytes <= 0:
            raise ValueError("Multipart part size must be positive")

    def __repr__(self) -> str:
        return (
            "UploadedPart("
            f"part_number={self.part_number}, etag=<redacted>, "
            f"checksum_sha256=<redacted>, size_bytes={self.size_bytes})"
        )


@dataclass(frozen=True, repr=False)
class PresignedOperation:
    """Ephemeral operation returned to a trusted transport layer."""

    method: str
    url: str = field(repr=False)
    expires_at: datetime
    headers: Mapping[str, str] = field(default_factory=dict, repr=False)

    def __post_init__(self) -> None:
        if self.method not in {"GET", "PUT"}:
            raise ValueError("Presigned operation method is invalid")
        if not self.url.startswith("https://"):
            raise ValueError("Presigned operation must use HTTPS")
        if self.expires_at.tzinfo is None:
            raise ValueError("Presigned operation expiry must be timezone-aware")

    def __repr__(self) -> str:
        return (
            "PresignedOperation("
            f"method={self.method!r}, url=<redacted>, "
            f"expires_at={self.expires_at.isoformat()!r}, headers=<redacted>)"
        )


@dataclass(frozen=True, repr=False)
class ObjectStat:
    locator: StorageLocator
    size_bytes: int
    content_type: str
    checksum_sha256: str
    etag: str | None = field(default=None, repr=False)

    def __post_init__(self) -> None:
        if self.size_bytes < 0:
            raise ValueError("Object size cannot be negative")
        _validate_content_type(self.content_type)
        _validate_checksum(self.checksum_sha256)

    def __repr__(self) -> str:
        return (
            "ObjectStat("
            f"locator={self.locator!r}, size_bytes={self.size_bytes}, "
            f"content_type={self.content_type!r}, checksum_sha256=<redacted>, "
            "etag=<redacted>)"
        )


@dataclass(frozen=True)
class ObjectStorageCapabilities:
    proxy_upload: bool = True
    multipart_upload: bool = True
    versioned_objects: bool = True
    ranged_reads: bool = True
    server_side_copy: bool = True


UploadSource = bytes | bytearray | memoryview | BinaryIO


class PrivateSessionState(Mapping[str, str]):
    """Serializable backend-only session state with an always-redacted repr.

    ``dict(state)`` is intentionally available to the trusted persistence
    layer. This object itself must never cross an API response boundary.
    """

    def __init__(self, values: Mapping[str, str]) -> None:
        copied = dict(values)
        if not copied or any(not isinstance(key, str) or not isinstance(value, str) for key, value in copied.items()):
            raise ValueError("Private session state is invalid")
        self._values = MappingProxyType(copied)

    def __getitem__(self, key: str) -> str:
        return self._values[key]

    def __iter__(self) -> Iterator[str]:
        return iter(self._values)

    def __len__(self) -> int:
        return len(self._values)

    def __repr__(self) -> str:
        return "PrivateSessionState(<redacted>)"


@runtime_checkable
class ObjectStorageProvider(Protocol):
    provider_name: str
    capabilities: ObjectStorageCapabilities

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
        ...

    def upload_proxy(self, *, session: UploadSession, source: UploadSource) -> StorageLocator:
        ...

    def presign_upload_part(
        self,
        *,
        session: UploadSession,
        part_number: int,
        checksum_sha256: str | None = None,
        size_bytes: int | None = None,
        expires_in: int = 300,
    ) -> PresignedOperation:
        ...

    def upload_part(
        self,
        *,
        session: UploadSession,
        part_number: int,
        source: UploadSource,
    ) -> UploadedPart:
        ...

    def complete_upload(
        self,
        *,
        session: UploadSession,
        parts: Sequence[UploadedPart],
    ) -> StorageLocator:
        ...

    def abort_upload(self, session: UploadSession) -> None:
        ...

    def export_session_state(self, session: UploadSession) -> PrivateSessionState:
        """Export minimal provider state for trusted backend persistence only."""
        ...

    def restore_session(
        self,
        session: UploadSession,
        state: Mapping[str, str],
    ) -> None:
        """Restore a server-owned upload session after a process restart."""
        ...

    def restore_session_for_cleanup(
        self,
        session: UploadSession,
        state: Mapping[str, str],
    ) -> None:
        """Restore verified private state only so an expired upload can be aborted."""
        ...

    def stat(self, locator: StorageLocator) -> ObjectStat:
        ...

    def promote(
        self,
        locator: StorageLocator,
        *,
        target_namespace: str,
        delete_source: bool = False,
    ) -> StorageLocator:
        ...

    def delete_version(self, locator: StorageLocator) -> None:
        ...

    def read_range(self, locator: StorageLocator, *, start: int, end: int) -> bytes:
        ...


@dataclass
class _FakeSessionState:
    public: UploadSession
    object_key: str
    parts: dict[int, tuple[UploadedPart, bytes]] = field(default_factory=dict)
    completed: StorageLocator | None = None
    aborted: bool = False


@dataclass(frozen=True)
class _FakeObject:
    payload: bytes
    content_type: str
    checksum_sha256: str


class FakeObjectStorageProvider:
    """Deterministic in-memory implementation used by shared contract tests."""

    provider_name = "fake"
    capabilities = ObjectStorageCapabilities()

    def __init__(
        self,
        *,
        max_proxy_bytes: int = 10 * 1024 * 1024,
        max_object_bytes: int = 250 * 1024 * 1024,
        min_part_bytes: int = 5 * 1024 * 1024,
        max_part_bytes: int = 64 * 1024 * 1024,
        max_parts: int = 10_000,
        max_range_bytes: int = 8 * 1024 * 1024,
        clock: Callable[[], datetime] | None = None,
    ) -> None:
        _validate_positive_limits(
            max_proxy_bytes=max_proxy_bytes,
            max_object_bytes=max_object_bytes,
            min_part_bytes=min_part_bytes,
            max_part_bytes=max_part_bytes,
            max_parts=max_parts,
            max_range_bytes=max_range_bytes,
        )
        if min_part_bytes > max_part_bytes:
            raise ValueError("Minimum multipart size cannot exceed maximum multipart size")
        self.max_proxy_bytes = max_proxy_bytes
        self.max_object_bytes = max_object_bytes
        self.min_part_bytes = min_part_bytes
        self.max_part_bytes = max_part_bytes
        self.max_parts = max_parts
        self.max_range_bytes = max_range_bytes
        self._clock = clock or _utc_now
        self._session_counter = 0
        self._object_counter = 0
        self._version_counter = 0
        self._delivery_counter = 0
        self._sessions: dict[str, _FakeSessionState] = {}
        self._objects: dict[tuple[str, str], _FakeObject] = {}

    def __repr__(self) -> str:
        return "FakeObjectStorageProvider(provider='fake')"

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
        selected_mode = _validate_upload_request(
            namespace=namespace,
            content_type=content_type,
            expected_size=expected_size,
            checksum_sha256=checksum_sha256,
            mode=mode,
            expires_in=expires_in,
            max_proxy_bytes=self.max_proxy_bytes,
            max_object_bytes=self.max_object_bytes,
        )
        self._session_counter += 1
        self._object_counter += 1
        session_id = f"session-{self._session_counter:04d}"
        object_key = f"fake/{namespace}/object-{self._object_counter:04d}"
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
        self._sessions[session_id] = _FakeSessionState(public=session, object_key=object_key)
        return session

    def upload_proxy(self, *, session: UploadSession, source: UploadSource) -> StorageLocator:
        state = self._require_session(session, expected_mode=UploadMode.PROXY)
        if state.completed is not None:
            return state.completed
        payload = _read_bounded(source, limit=session.expected_size)
        _verify_payload(payload, expected_size=session.expected_size, checksum=session.checksum_sha256)
        locator = self._store(
            namespace=session.namespace,
            object_key=state.object_key,
            payload=payload,
            content_type=session.content_type,
        )
        state.completed = locator
        return locator

    def presign_upload_part(
        self,
        *,
        session: UploadSession,
        part_number: int,
        checksum_sha256: str | None = None,
        size_bytes: int | None = None,
        expires_in: int = 300,
    ) -> PresignedOperation:
        self._require_session(session, expected_mode=UploadMode.MULTIPART)
        _validate_part_number(part_number, self.max_parts)
        bound_part = _validate_presigned_part(
            checksum_sha256=checksum_sha256,
            size_bytes=size_bytes,
            max_part_bytes=self.max_part_bytes,
        )
        _validate_presign_ttl(expires_in, session=session, now=self._clock())
        self._delivery_counter += 1
        return PresignedOperation(
            method="PUT",
            url=(
                "https://upload.invalid/"
                f"operation-{self._delivery_counter:04d}?token=test-token-{self._delivery_counter:04d}"
            ),
            expires_at=self._clock() + timedelta(seconds=expires_in),
            headers=(
                {"x-amz-checksum-sha256": bound_part[0]}
                if bound_part is not None
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
        _validate_part_number(part_number, self.max_parts)
        payload = _read_bounded(source, limit=self.max_part_bytes)
        if not payload:
            raise ObjectStorageError(code="empty_upload_part", message="Upload part is empty")
        receipt = UploadedPart(
            part_number=part_number,
            etag=f"fake-etag-{part_number}-{hashlib.sha256(payload).hexdigest()[:16]}",
            checksum_sha256=hashlib.sha256(payload).hexdigest(),
            size_bytes=len(payload),
        )
        previous = state.parts.get(part_number)
        if previous is not None:
            if previous[0] != receipt:
                raise ObjectStorageError(
                    code="upload_part_conflict",
                    message="Upload part conflicts with its previous receipt",
                )
            return previous[0]
        state.parts[part_number] = (receipt, payload)
        return receipt

    def complete_upload(
        self,
        *,
        session: UploadSession,
        parts: Sequence[UploadedPart],
    ) -> StorageLocator:
        state = self._require_session(session, expected_mode=UploadMode.MULTIPART)
        if state.completed is not None:
            return state.completed
        validated = _validate_completion_parts(
            parts=parts,
            recorded=state.parts,
            expected_size=session.expected_size,
            min_part_bytes=self.min_part_bytes,
            max_part_bytes=self.max_part_bytes,
            max_parts=self.max_parts,
        )
        payload = b"".join(state.parts[part.part_number][1] for part in validated)
        _verify_payload(payload, expected_size=session.expected_size, checksum=session.checksum_sha256)
        locator = self._store(
            namespace=session.namespace,
            object_key=state.object_key,
            payload=payload,
            content_type=session.content_type,
        )
        state.completed = locator
        return locator

    def abort_upload(self, session: UploadSession) -> None:
        state = self._sessions.get(session.session_id)
        if state is None:
            return
        if state.public != session:
            raise ObjectStorageError(
                code="invalid_upload_session",
                message="Upload session is invalid",
            )
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
                "object_key": state.object_key,
                "upload_id": "",
                "session_fingerprint": _session_fingerprint(session),
            }
        )

    def restore_session(self, session: UploadSession, state: Mapping[str, str]) -> None:
        self._restore_session(session=session, state=state, require_active=True)

    def restore_session_for_cleanup(
        self, session: UploadSession, state: Mapping[str, str]
    ) -> None:
        self._restore_session(session=session, state=state, require_active=False)

    def _restore_session(
        self, *, session: UploadSession, state: Mapping[str, str], require_active: bool
    ) -> None:
        values = _validate_private_state_shape(state)
        expected_prefix = f"fake/{session.namespace}/object-"
        valid = (
            session.provider == self.provider_name
            and values["provider"] == self.provider_name
            and values["upload_id"] == ""
            and values["object_key"].startswith(expected_prefix)
            and values["object_key"][len(expected_prefix) :].isdigit()
            and hmac.compare_digest(
                values["session_fingerprint"],
                _session_fingerprint(session),
            )
            and (not require_active or self._clock() < session.expires_at)
        )
        if not valid:
            raise ObjectStorageError(
                code="invalid_private_session_state",
                message="Private upload session state is invalid",
            )
        existing = self._sessions.get(session.session_id)
        if existing is not None:
            if existing.public == session and existing.object_key == values["object_key"]:
                return
            raise ObjectStorageError(
                code="invalid_private_session_state",
                message="Private upload session state is invalid",
            )
        self._sessions[session.session_id] = _FakeSessionState(
            public=session,
            object_key=values["object_key"],
        )
        suffix = int(values["object_key"][len(expected_prefix) :])
        self._object_counter = max(self._object_counter, suffix)

    def stat(self, locator: StorageLocator) -> ObjectStat:
        obj = self._require_object(locator)
        return ObjectStat(
            locator=locator,
            size_bytes=len(obj.payload),
            content_type=obj.content_type,
            checksum_sha256=obj.checksum_sha256,
            etag=f"fake-etag-{locator.version}",
        )

    def promote(
        self,
        locator: StorageLocator,
        *,
        target_namespace: str,
        delete_source: bool = False,
    ) -> StorageLocator:
        _validate_namespace(target_namespace)
        source = self._require_object(locator)
        self._object_counter += 1
        promoted = self._store(
            namespace=target_namespace,
            object_key=f"fake/{target_namespace}/object-{self._object_counter:04d}",
            payload=source.payload,
            content_type=source.content_type,
        )
        if delete_source:
            self.delete_version(locator)
        return promoted

    def delete_version(self, locator: StorageLocator) -> None:
        self._require_provider(locator)
        self._objects.pop((locator.object_key, locator.version), None)

    def read_range(self, locator: StorageLocator, *, start: int, end: int) -> bytes:
        _validate_range(start=start, end=end, max_range_bytes=self.max_range_bytes)
        obj = self._require_object(locator)
        if start >= len(obj.payload):
            raise ObjectStorageError(code="range_not_satisfiable", message="Object range is invalid")
        return obj.payload[start : min(end + 1, len(obj.payload))]

    def _require_session(
        self,
        session: UploadSession,
        *,
        expected_mode: UploadMode,
    ) -> _FakeSessionState:
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

    def _store(
        self,
        *,
        namespace: str,
        object_key: str,
        payload: bytes,
        content_type: str,
    ) -> StorageLocator:
        self._version_counter += 1
        version = f"v{self._version_counter:04d}"
        checksum = hashlib.sha256(payload).hexdigest()
        locator = StorageLocator(
            provider=self.provider_name,
            namespace=namespace,
            object_key=object_key,
            version=version,
            checksum_sha256=checksum,
        )
        self._objects[(object_key, version)] = _FakeObject(
            payload=payload,
            content_type=content_type,
            checksum_sha256=checksum,
        )
        return locator

    def _require_provider(self, locator: StorageLocator) -> None:
        if locator.provider != self.provider_name:
            raise ObjectStorageError(code="unsupported_provider", message="Storage provider is unsupported")

    def _require_object(self, locator: StorageLocator) -> _FakeObject:
        self._require_provider(locator)
        obj = self._objects.get((locator.object_key, locator.version))
        if obj is None or obj.checksum_sha256 != locator.checksum_sha256:
            raise ObjectStorageError(code="object_not_found", message="Stored object is unavailable")
        return obj


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _has_control(value: str) -> bool:
    return any(ord(character) < 32 or ord(character) == 127 for character in value)


def _validate_provider(value: str) -> None:
    if not _PROVIDER_RE.fullmatch(value):
        raise ValueError("Storage provider identifier is invalid")


def _validate_namespace(value: str) -> None:
    if not _NAMESPACE_RE.fullmatch(value):
        raise ValueError("Storage namespace is invalid")


def _validate_object_key(value: str) -> None:
    if (
        not value
        or len(value.encode("utf-8")) > 1024
        or value.startswith("/")
        or "://" in value
        or _has_control(value)
        or any(segment in {"", ".", ".."} for segment in value.split("/"))
    ):
        raise ValueError("Storage object key is invalid")


def _validate_version(value: str) -> None:
    if not value or len(value) > 512 or _has_control(value):
        raise ValueError("Storage object version is invalid")


def _validate_checksum(value: str) -> None:
    if not _SHA256_RE.fullmatch(value):
        raise ValueError("SHA-256 checksum is invalid")


def _validate_content_type(value: str) -> None:
    if len(value) > 127 or not _CONTENT_TYPE_RE.fullmatch(value):
        raise ValueError("Content type is invalid")


def _validate_positive_limits(**limits: int) -> None:
    if any(value <= 0 for value in limits.values()):
        raise ValueError("Storage limits must be positive")


def _validate_upload_request(
    *,
    namespace: str,
    content_type: str,
    expected_size: int,
    checksum_sha256: str,
    mode: UploadMode | None,
    expires_in: int,
    max_proxy_bytes: int,
    max_object_bytes: int,
) -> UploadMode:
    try:
        _validate_namespace(namespace)
        _validate_content_type(content_type)
        _validate_checksum(checksum_sha256)
    except ValueError as exc:
        raise ObjectStorageError(code="invalid_upload_request", message=str(exc)) from None
    if expected_size <= 0:
        raise ObjectStorageError(code="invalid_upload_size", message="Upload size must be positive")
    if expected_size > max_object_bytes:
        raise ObjectStorageError(code="object_too_large", message="Upload exceeds the object size limit")
    if expires_in < 30 or expires_in > 3600:
        raise ObjectStorageError(code="invalid_upload_expiry", message="Upload expiry is outside allowed bounds")
    selected_mode = mode or (
        UploadMode.PROXY if expected_size <= max_proxy_bytes else UploadMode.MULTIPART
    )
    if selected_mode is UploadMode.PROXY and expected_size > max_proxy_bytes:
        raise ObjectStorageError(
            code="proxy_upload_too_large",
            message="Upload exceeds the proxy size limit",
        )
    return selected_mode


def _read_bounded(source: UploadSource, *, limit: int, chunk_size: int = 1024 * 1024) -> bytes:
    if isinstance(source, (bytes, bytearray, memoryview)):
        payload = bytes(source)
        if len(payload) > limit:
            raise ObjectStorageError(code="upload_too_large", message="Upload exceeds its declared size")
        return payload
    if not hasattr(source, "read"):
        raise ObjectStorageError(code="invalid_upload_source", message="Upload source is invalid")
    chunks: list[bytes] = []
    total = 0
    while True:
        chunk = source.read(min(chunk_size, limit + 1 - total))
        if not chunk:
            break
        if not isinstance(chunk, bytes):
            raise ObjectStorageError(code="invalid_upload_source", message="Upload source is invalid")
        total += len(chunk)
        if total > limit:
            raise ObjectStorageError(code="upload_too_large", message="Upload exceeds its declared size")
        chunks.append(chunk)
    return b"".join(chunks)


def _verify_payload(payload: bytes, *, expected_size: int, checksum: str) -> None:
    if len(payload) != expected_size:
        raise ObjectStorageError(code="size_mismatch", message="Upload size does not match its session")
    if hashlib.sha256(payload).hexdigest() != checksum:
        raise ObjectStorageError(
            code="checksum_mismatch",
            message="Upload checksum does not match its session",
        )


def _validate_part_number(part_number: int, max_parts: int) -> None:
    if part_number <= 0 or part_number > max_parts:
        raise ObjectStorageError(code="invalid_part_number", message="Multipart part number is invalid")


def _validate_presign_ttl(expires_in: int, *, session: UploadSession, now: datetime) -> None:
    remaining = int((session.expires_at - now).total_seconds())
    if expires_in < 30 or expires_in > 900 or expires_in > remaining:
        raise ObjectStorageError(code="invalid_presign_ttl", message="Signed operation expiry is invalid")


def _validate_presigned_part(
    *,
    checksum_sha256: str | None,
    size_bytes: int | None,
    max_part_bytes: int,
) -> tuple[str, int] | None:
    if checksum_sha256 is None and size_bytes is None:
        return None
    if checksum_sha256 is None or size_bytes is None:
        raise ObjectStorageError(
            code="incomplete_part_binding",
            message="Multipart part binding is incomplete",
        )
    try:
        _validate_checksum(checksum_sha256)
    except ValueError:
        raise ObjectStorageError(
            code="invalid_part_checksum",
            message="Multipart part checksum is invalid",
        ) from None
    if size_bytes <= 0 or size_bytes > max_part_bytes:
        raise ObjectStorageError(
            code="invalid_part_size",
            message="Multipart part size is invalid",
        )
    return checksum_sha256, size_bytes


def _validate_completion_parts(
    *,
    parts: Sequence[UploadedPart],
    recorded: Mapping[int, tuple[UploadedPart, bytes]],
    expected_size: int,
    min_part_bytes: int,
    max_part_bytes: int,
    max_parts: int,
) -> tuple[UploadedPart, ...]:
    ordered = tuple(sorted(parts, key=lambda part: part.part_number))
    if not ordered or len(ordered) > max_parts:
        raise ObjectStorageError(code="invalid_multipart_receipts", message="Multipart receipts are invalid")
    if tuple(part.part_number for part in ordered) != tuple(range(1, len(ordered) + 1)):
        raise ObjectStorageError(code="invalid_multipart_receipts", message="Multipart receipts are invalid")
    for index, part in enumerate(ordered):
        recorded_part = recorded.get(part.part_number)
        if recorded_part is None or recorded_part[0] != part:
            raise ObjectStorageError(code="invalid_multipart_receipts", message="Multipart receipts are invalid")
        if part.size_bytes > max_part_bytes:
            raise ObjectStorageError(code="upload_part_too_large", message="Multipart part exceeds its size limit")
        if index < len(ordered) - 1 and part.size_bytes < min_part_bytes:
            raise ObjectStorageError(code="upload_part_too_small", message="Multipart part is below its size limit")
    if sum(part.size_bytes for part in ordered) != expected_size:
        raise ObjectStorageError(code="size_mismatch", message="Multipart size does not match its session")
    return ordered


def _validate_range(*, start: int, end: int, max_range_bytes: int) -> None:
    if start < 0 or end < start:
        raise ObjectStorageError(code="invalid_range", message="Object range is invalid")
    if end - start + 1 > max_range_bytes:
        raise ObjectStorageError(code="range_too_large", message="Object range exceeds the read limit")


def _session_fingerprint(session: UploadSession) -> str:
    canonical = "\n".join(
        (
            session.session_id,
            session.provider,
            session.mode.value,
            session.namespace,
            session.content_type,
            str(session.expected_size),
            session.checksum_sha256,
            session.expires_at.astimezone(timezone.utc).isoformat(),
        )
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def _validate_private_state_shape(state: Mapping[str, str]) -> dict[str, str]:
    expected_keys = {
        "state_version",
        "provider",
        "object_key",
        "upload_id",
        "session_fingerprint",
    }
    try:
        values = dict(state)
    except Exception:
        raise ObjectStorageError(
            code="invalid_private_session_state",
            message="Private upload session state is invalid",
        ) from None
    if (
        set(values) != expected_keys
        or values.get("state_version") != "1"
        or any(not isinstance(value, str) for value in values.values())
        or any(len(value) > 2048 or _has_control(value) for value in values.values())
        or not _SHA256_RE.fullmatch(values.get("session_fingerprint", ""))
    ):
        raise ObjectStorageError(
            code="invalid_private_session_state",
            message="Private upload session state is invalid",
        )
    return values


__all__ = [
    "FakeObjectStorageProvider",
    "ObjectStat",
    "ObjectStorageCapabilities",
    "ObjectStorageError",
    "ObjectStorageProvider",
    "PresignedOperation",
    "PrivateSessionState",
    "StorageLocator",
    "UploadedPart",
    "UploadMode",
    "UploadSession",
    "UploadSource",
]
