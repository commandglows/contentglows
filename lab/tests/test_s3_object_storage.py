from __future__ import annotations

from base64 import b64encode
from datetime import datetime, timezone
import hashlib
import io

import pytest

from api.services.object_storage import ObjectStorageError, UploadMode
from api.services.s3_object_storage import S3ObjectStorageProvider


def _sha256(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


class _StreamingBody:
    def __init__(self, payload: bytes) -> None:
        self._payload = payload

    def iter_chunks(self, chunk_size: int = 8192):
        for offset in range(0, len(self._payload), chunk_size):
            yield self._payload[offset : offset + chunk_size]

    def read(self, amount: int | None = None) -> bytes:
        if amount is None:
            return self._payload
        return self._payload[:amount]


class RecordingS3Client:
    def __init__(self) -> None:
        self.calls: list[tuple[str, dict]] = []
        self.objects: dict[str, tuple[bytes, str, str]] = {}
        self.multipart: dict[str, dict[int, bytes]] = {}
        self.multipart_keys: dict[str, str] = {}
        self._version = 0

    def _next_version(self) -> str:
        self._version += 1
        return f"version-{self._version}"

    def put_object(self, **kwargs):
        self.calls.append(("put_object", kwargs))
        payload = kwargs["Body"].read()
        version = self._next_version()
        self.objects[kwargs["Key"]] = (payload, version, kwargs["ContentType"])
        return {"VersionId": version, "ETag": '"etag"'}

    def create_multipart_upload(self, **kwargs):
        self.calls.append(("create_multipart_upload", kwargs))
        upload_id = f"upload-{len(self.multipart) + 1}"
        self.multipart[upload_id] = {}
        self.multipart_keys[upload_id] = kwargs["Key"]
        return {"UploadId": upload_id}

    def generate_presigned_url(self, operation, Params, ExpiresIn, HttpMethod=None):
        self.calls.append(
            (
                "generate_presigned_url",
                {
                    "operation": operation,
                    "Params": Params,
                    "ExpiresIn": ExpiresIn,
                    "HttpMethod": HttpMethod,
                },
            )
        )
        return "https://signed.example/private?signature=top-secret"

    def upload_part(self, **kwargs):
        self.calls.append(("upload_part", kwargs))
        payload = kwargs["Body"].read()
        self.multipart[kwargs["UploadId"]][kwargs["PartNumber"]] = payload
        return {
            "ETag": f'"part-{kwargs["PartNumber"]}"',
            "ChecksumSHA256": kwargs["ChecksumSHA256"],
        }

    def complete_multipart_upload(self, **kwargs):
        self.calls.append(("complete_multipart_upload", kwargs))
        upload_id = kwargs["UploadId"]
        payload = b"".join(
            self.multipart[upload_id][part_number]
            for part_number in sorted(self.multipart[upload_id])
        )
        version = self._next_version()
        key = self.multipart_keys[upload_id]
        self.objects[key] = (payload, version, "application/octet-stream")
        return {"VersionId": version, "ETag": '"complete"'}

    def abort_multipart_upload(self, **kwargs):
        self.calls.append(("abort_multipart_upload", kwargs))
        self.multipart.pop(kwargs["UploadId"], None)
        return {}

    def head_object(self, **kwargs):
        self.calls.append(("head_object", kwargs))
        payload, version, content_type = self.objects[kwargs["Key"]]
        return {
            "ContentLength": len(payload),
            "ContentType": content_type,
            "VersionId": version,
            "ETag": '"etag"',
            "ChecksumSHA256": b64encode(hashlib.sha256(payload).digest()).decode("ascii"),
        }

    def get_object(self, **kwargs):
        self.calls.append(("get_object", kwargs))
        payload = self.objects[kwargs["Key"]][0]
        byte_range = kwargs.get("Range")
        if byte_range:
            start_raw, end_raw = byte_range.removeprefix("bytes=").split("-", 1)
            payload = payload[int(start_raw) : int(end_raw) + 1]
        return {"Body": _StreamingBody(payload)}

    def copy_object(self, **kwargs):
        self.calls.append(("copy_object", kwargs))
        source_key = kwargs["CopySource"]["Key"]
        payload, _, content_type = self.objects[source_key]
        version = self._next_version()
        self.objects[kwargs["Key"]] = (payload, version, content_type)
        return {"VersionId": version, "CopyObjectResult": {"ETag": '"copied"'}}

    def delete_object(self, **kwargs):
        self.calls.append(("delete_object", kwargs))
        self.objects.pop(kwargs["Key"], None)
        return {"VersionId": kwargs.get("VersionId")}


def _provider(client: RecordingS3Client) -> S3ObjectStorageProvider:
    ids = iter(("object-a", "object-b", "object-c", "object-d"))
    return S3ObjectStorageProvider(
        client=client,
        bucket="canonical-private-bucket",
        key_prefix="contentglows",
        id_factory=lambda: next(ids),
        clock=lambda: datetime(2026, 7, 13, tzinfo=timezone.utc),
        min_part_bytes=1,
        max_part_bytes=16,
        max_proxy_bytes=32,
        max_range_bytes=16,
    )


def test_s3_proxy_upload_is_injectable_versioned_and_checksummed() -> None:
    client = RecordingS3Client()
    storage = _provider(client)
    payload = b"image-bytes"
    session = storage.create_upload_session(
        namespace="quarantine",
        content_type="image/png",
        expected_size=len(payload),
        checksum_sha256=_sha256(payload),
        mode=UploadMode.PROXY,
    )

    locator = storage.upload_proxy(session=session, source=io.BytesIO(payload))
    stat = storage.stat(locator)

    assert locator.version == "version-1"
    assert stat.checksum_sha256 == _sha256(payload)
    put = next(call for call in client.calls if call[0] == "put_object")[1]
    assert put["Bucket"] == "canonical-private-bucket"
    assert put["Key"].startswith("contentglows/quarantine/")
    assert put["ChecksumSHA256"] == b64encode(hashlib.sha256(payload).digest()).decode("ascii")
    assert "ACL" not in put
    assert "canonical-private-bucket" not in repr(storage)
    assert put["Key"] not in repr(locator)


def test_s3_multipart_presign_proxy_complete_and_abort() -> None:
    client = RecordingS3Client()
    storage = _provider(client)
    payload = b"abcdef"
    session = storage.create_upload_session(
        namespace="quarantine",
        content_type="video/mp4",
        expected_size=len(payload),
        checksum_sha256=_sha256(payload),
        mode=UploadMode.MULTIPART,
    )

    signed = storage.presign_upload_part(
        session=session,
        part_number=1,
        checksum_sha256=_sha256(b"abc"),
        size_bytes=3,
        expires_in=60,
    )
    assert signed.url.startswith("https://signed.example/")
    assert "top-secret" not in repr(signed)
    signed_call = next(call for call in client.calls if call[0] == "generate_presigned_url")[1]
    assert signed_call["operation"] == "upload_part"
    assert signed_call["ExpiresIn"] == 60
    assert signed_call["Params"]["ChecksumSHA256"] == b64encode(
        hashlib.sha256(b"abc").digest()
    ).decode("ascii")
    assert signed_call["Params"]["ContentLength"] == 3

    first = storage.upload_part(session=session, part_number=1, source=b"abc")
    second = storage.upload_part(session=session, part_number=2, source=b"def")
    locator = storage.complete_upload(session=session, parts=(first, second))
    assert storage.read_range(locator, start=1, end=3) == b"bcd"

    second_session = storage.create_upload_session(
        namespace="quarantine",
        content_type="video/mp4",
        expected_size=3,
        checksum_sha256=_sha256(b"xyz"),
        mode=UploadMode.MULTIPART,
    )
    storage.abort_upload(second_session)
    assert any(name == "abort_multipart_upload" for name, _ in client.calls)


def test_s3_multipart_session_restores_in_new_adapter_instance() -> None:
    client = RecordingS3Client()
    first_instance = _provider(client)
    payload = b"restart-safe"
    session = first_instance.create_upload_session(
        namespace="quarantine",
        content_type="video/mp4",
        expected_size=len(payload),
        checksum_sha256=_sha256(payload),
        mode=UploadMode.MULTIPART,
    )
    private_state = first_instance.export_session_state(session)

    assert private_state["object_key"].startswith("contentglows/quarantine/")
    assert private_state["upload_id"].startswith("upload-")
    assert session.session_id.removeprefix("session-") not in private_state["object_key"]
    assert private_state["object_key"] not in repr(private_state)
    assert private_state["upload_id"] not in repr(private_state)

    restarted = _provider(client)
    restarted.restore_session(session, private_state)
    signed = restarted.presign_upload_part(
        session=session,
        part_number=1,
        checksum_sha256=_sha256(b"restart-"),
        size_bytes=8,
        expires_in=60,
    )
    assert signed.method == "PUT"
    first = restarted.upload_part(session=session, part_number=1, source=b"restart-")
    second = restarted.upload_part(session=session, part_number=2, source=b"safe")
    locator = restarted.complete_upload(session=session, parts=(first, second))

    assert restarted.read_range(locator, start=0, end=len(payload) - 1) == payload


def test_s3_restore_rejects_tampered_private_state_without_disclosure() -> None:
    client = RecordingS3Client()
    first_instance = _provider(client)
    session = first_instance.create_upload_session(
        namespace="quarantine",
        content_type="video/mp4",
        expected_size=3,
        checksum_sha256=_sha256(b"abc"),
        mode=UploadMode.MULTIPART,
    )
    private_state = dict(first_instance.export_session_state(session))
    private_state["object_key"] = "another-prefix/private/object"

    restarted = _provider(client)
    with pytest.raises(ObjectStorageError) as exc_info:
        restarted.restore_session(session, private_state)

    assert exc_info.value.code == "invalid_private_session_state"
    assert "another-prefix" not in str(exc_info.value)


def test_s3_promote_copies_then_optionally_deletes_exact_version() -> None:
    client = RecordingS3Client()
    storage = _provider(client)
    payload = b"audio"
    session = storage.create_upload_session(
        namespace="quarantine",
        content_type="audio/mpeg",
        expected_size=len(payload),
        checksum_sha256=_sha256(payload),
        mode=UploadMode.PROXY,
    )
    source = storage.upload_proxy(session=session, source=payload)

    promoted = storage.promote(source, target_namespace="assets", delete_source=True)

    assert promoted.namespace == "assets"
    copy = next(call for call in client.calls if call[0] == "copy_object")[1]
    delete = next(call for call in client.calls if call[0] == "delete_object")[1]
    assert copy["CopySource"]["VersionId"] == source.version
    assert delete["VersionId"] == source.version
    assert storage.read_range(promoted, start=0, end=4) == payload


def test_s3_checksum_failure_is_compensated_and_error_is_redacted() -> None:
    client = RecordingS3Client()
    storage = _provider(client)
    expected_payload = b"expected-private-payload"
    session = storage.create_upload_session(
        namespace="quarantine",
        content_type="image/png",
        expected_size=len(expected_payload),
        checksum_sha256=_sha256(expected_payload),
        mode=UploadMode.PROXY,
    )

    with pytest.raises(ObjectStorageError) as exc_info:
        storage.upload_proxy(session=session, source=b"x" * len(expected_payload))

    assert exc_info.value.code == "checksum_mismatch"
    assert "canonical-private-bucket" not in str(exc_info.value)
    assert "contentglows/" not in str(exc_info.value)
    assert "expected-private-payload" not in str(exc_info.value)


def test_s3_multipart_uses_streamed_full_sha256_when_head_is_composite() -> None:
    class CompositeChecksumClient(RecordingS3Client):
        def head_object(self, **kwargs):
            response = super().head_object(**kwargs)
            response["ChecksumSHA256"] = (
                b64encode(hashlib.sha256(b"part-checksum").digest()).decode("ascii") + "-2"
            )
            response["ChecksumType"] = "COMPOSITE"
            return response

    client = CompositeChecksumClient()
    storage = _provider(client)
    payload = b"abcdef"
    session = storage.create_upload_session(
        namespace="quarantine",
        content_type="video/mp4",
        expected_size=len(payload),
        checksum_sha256=_sha256(payload),
        mode=UploadMode.MULTIPART,
    )
    first = storage.upload_part(session=session, part_number=1, source=b"abc")
    second = storage.upload_part(session=session, part_number=2, source=b"def")

    locator = storage.complete_upload(session=session, parts=(first, second))

    assert storage.stat(locator).checksum_sha256 == _sha256(payload)
    assert any(name == "get_object" and "Range" not in params for name, params in client.calls)
