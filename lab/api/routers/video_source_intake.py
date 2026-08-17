"""Authenticated API for collecting sources before video generation."""

from __future__ import annotations

from fastapi import APIRouter, Depends, File, HTTPException, Response, UploadFile, status

from api.dependencies.auth import CurrentUser, require_current_user
from api.dependencies.ownership import require_owned_content_record, require_owned_project_id
from api.models.video_source_intake import (
    AddLinkRequest,
    AddTextRequest,
    CompleteUploadSessionRequest,
    CreateUploadSessionRequest,
    GenerateVideoRequest,
    GenerationHandoffResponse,
    GenerateVideoResultResponse,
    MarkSourcesReadyRequest,
    MutationRequest,
    OpenVideoSourceFolderRequest,
    SignUploadPartRequest,
    UploadPartInstruction,
    UploadSessionResponse,
    VideoSourceFolderResponse,
)
from api.services.video_source_intake_service import video_source_intake_service
from api.services.object_storage import ObjectStorageError
from api.services.video_source_media_service import (
    PROXY_MAX_BYTES,
    VideoSourceMediaError,
    get_video_source_media_service,
)
from api.services.video_source_intake_store import (
    IntakeConflictError,
    IntakeNotFoundError,
)
from status.service import get_status_service


router = APIRouter(
    prefix="/api/projects/{project_id}/contents/{content_id}/video-sources",
    tags=["Video Source Intake"],
)


async def _require_context(
    *, project_id: str, content_id: str, current_user: CurrentUser
) -> None:
    await require_owned_project_id(project_id, current_user)
    record = await require_owned_content_record(content_id, current_user, get_status_service())
    if record.project_id != project_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Content not found")


def _raise_domain_error(exc: Exception) -> None:
    if isinstance(exc, IntakeNotFoundError):
        raise HTTPException(status_code=404, detail={"code": "not_found", "message": "Source folder not found"}) from exc
    if isinstance(exc, IntakeConflictError):
        raise HTTPException(
            status_code=409,
            detail={"code": exc.code, "message": str(exc), "sourceIds": exc.source_ids},
        ) from exc
    raise exc


def _raise_media_error(exc: Exception) -> None:
    if isinstance(exc, (IntakeNotFoundError, IntakeConflictError)):
        _raise_domain_error(exc)
    if isinstance(exc, VideoSourceMediaError):
        raise HTTPException(
            status_code=422,
            detail={"code": exc.code, "message": str(exc), "retryable": exc.retryable},
        ) from exc
    if isinstance(exc, ObjectStorageError):
        raise HTTPException(
            status_code=409 if not exc.retryable else 503,
            detail={"code": exc.code, "message": str(exc), "retryable": exc.retryable},
        ) from exc
    if isinstance(exc, RuntimeError):
        raise HTTPException(
            status_code=503,
            detail={"code": "storage_unavailable", "message": "Binary uploads are temporarily unavailable."},
        ) from exc
    _raise_domain_error(exc)


@router.post("/folder", response_model=VideoSourceFolderResponse)
async def open_video_source_folder(
    project_id: str,
    content_id: str,
    request: OpenVideoSourceFolderRequest,
    response: Response,
    current_user: CurrentUser = Depends(require_current_user),
) -> VideoSourceFolderResponse:
    if request.project_id != project_id or request.content_id != content_id:
        raise HTTPException(status_code=409, detail="Request context does not match the route")
    await _require_context(project_id=project_id, content_id=content_id, current_user=current_user)
    response.status_code = status.HTTP_200_OK
    return await video_source_intake_service.open_folder(
        user_id=current_user.user_id, project_id=project_id, content_id=content_id
    )


@router.get("/folder/{folder_id}", response_model=VideoSourceFolderResponse)
async def get_video_source_folder(
    project_id: str,
    content_id: str,
    folder_id: str,
    current_user: CurrentUser = Depends(require_current_user),
) -> VideoSourceFolderResponse:
    await _require_context(project_id=project_id, content_id=content_id, current_user=current_user)
    folder = await video_source_intake_service.get_folder(
        folder_id=folder_id, user_id=current_user.user_id
    )
    if folder is None or folder.project_id != project_id or folder.content_id != content_id:
        raise HTTPException(status_code=404, detail="Source folder not found")
    return folder


@router.post("/folder/{folder_id}/text", response_model=VideoSourceFolderResponse)
async def add_text_source(
    project_id: str,
    content_id: str,
    folder_id: str,
    request: AddTextRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> VideoSourceFolderResponse:
    await _require_context(project_id=project_id, content_id=content_id, current_user=current_user)
    try:
        return await video_source_intake_service.add_text(
            folder_id=folder_id,
            user_id=current_user.user_id,
            text=request.text,
            idempotency_key=request.idempotency_key,
            expected_revision=request.expected_revision,
        )
    except (IntakeNotFoundError, IntakeConflictError) as exc:
        _raise_domain_error(exc)


@router.post("/folder/{folder_id}/link", response_model=VideoSourceFolderResponse)
async def add_link_source(
    project_id: str,
    content_id: str,
    folder_id: str,
    request: AddLinkRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> VideoSourceFolderResponse:
    await _require_context(project_id=project_id, content_id=content_id, current_user=current_user)
    try:
        return await video_source_intake_service.add_link(
            folder_id=folder_id,
            user_id=current_user.user_id,
            url=str(request.url),
            idempotency_key=request.idempotency_key,
            expected_revision=request.expected_revision,
        )
    except (IntakeNotFoundError, IntakeConflictError) as exc:
        _raise_domain_error(exc)


@router.post("/folder/{folder_id}/uploads", response_model=UploadSessionResponse, status_code=201)
async def create_binary_upload_session(
    project_id: str,
    content_id: str,
    folder_id: str,
    request: CreateUploadSessionRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> UploadSessionResponse:
    await _require_context(project_id=project_id, content_id=content_id, current_user=current_user)
    try:
        service = get_video_source_media_service()
        return await service.create_upload_session(
            folder_id=folder_id,
            user_id=current_user.user_id,
            source_type=request.source_type,
            file_name=request.file_name,
            mime_type=request.mime_type,
            byte_size=request.byte_size,
            checksum_sha256=request.checksum_sha256,
            expected_revision=request.expected_revision,
            idempotency_key=request.idempotency_key,
            replace_source_id=request.replace_source_id,
        )
    except (IntakeNotFoundError, IntakeConflictError, VideoSourceMediaError, ObjectStorageError, RuntimeError) as exc:
        _raise_media_error(exc)


@router.post("/folder/{folder_id}/uploads/{session_id}/content", response_model=VideoSourceFolderResponse)
async def upload_small_binary_source(
    project_id: str,
    content_id: str,
    folder_id: str,
    session_id: str,
    file: UploadFile = File(...),
    current_user: CurrentUser = Depends(require_current_user),
) -> VideoSourceFolderResponse:
    await _require_context(project_id=project_id, content_id=content_id, current_user=current_user)
    payload = bytearray()
    while chunk := await file.read(1024 * 1024):
        payload.extend(chunk)
        if len(payload) > PROXY_MAX_BYTES:
            raise HTTPException(
                status_code=413,
                detail={"code": "proxy_upload_too_large", "message": "Use the multipart upload instructions."},
            )
    try:
        return await get_video_source_media_service().upload_proxy(
            folder_id=folder_id,
            session_id=session_id,
            user_id=current_user.user_id,
            payload=bytes(payload),
        )
    except (IntakeNotFoundError, IntakeConflictError, VideoSourceMediaError, ObjectStorageError, RuntimeError) as exc:
        _raise_media_error(exc)


@router.delete(
    "/folder/{folder_id}/uploads/{session_id}",
    response_model=VideoSourceFolderResponse,
)
async def abort_binary_upload(
    project_id: str,
    content_id: str,
    folder_id: str,
    session_id: str,
    current_user: CurrentUser = Depends(require_current_user),
) -> VideoSourceFolderResponse:
    await _require_context(project_id=project_id, content_id=content_id, current_user=current_user)
    try:
        return await get_video_source_media_service().abort_upload(
            folder_id=folder_id,
            session_id=session_id,
            user_id=current_user.user_id,
        )
    except (IntakeNotFoundError, IntakeConflictError, VideoSourceMediaError, ObjectStorageError, RuntimeError) as exc:
        _raise_media_error(exc)


@router.post(
    "/folder/{folder_id}/uploads/{session_id}/parts/{part_number}/sign",
    response_model=UploadPartInstruction,
)
async def sign_binary_upload_part(
    project_id: str,
    content_id: str,
    folder_id: str,
    session_id: str,
    part_number: int,
    request: SignUploadPartRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> UploadPartInstruction:
    await _require_context(project_id=project_id, content_id=content_id, current_user=current_user)
    if request.part_number != part_number:
        raise HTTPException(
            status_code=409,
            detail={"code": "upload_part_mismatch", "message": "The part does not match the route."},
        )
    try:
        return await get_video_source_media_service().sign_upload_part(
            folder_id=folder_id,
            session_id=session_id,
            user_id=current_user.user_id,
            part_number=part_number,
            checksum_sha256=request.checksum_sha256,
            size_bytes=request.size_bytes,
        )
    except (IntakeNotFoundError, IntakeConflictError, VideoSourceMediaError, ObjectStorageError, RuntimeError) as exc:
        _raise_media_error(exc)


@router.post("/folder/{folder_id}/uploads/{session_id}/complete", response_model=VideoSourceFolderResponse)
async def complete_binary_multipart_upload(
    project_id: str,
    content_id: str,
    folder_id: str,
    session_id: str,
    request: CompleteUploadSessionRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> VideoSourceFolderResponse:
    await _require_context(project_id=project_id, content_id=content_id, current_user=current_user)
    try:
        return await get_video_source_media_service().complete_multipart(
            folder_id=folder_id,
            session_id=session_id,
            user_id=current_user.user_id,
            parts=request.parts,
        )
    except (IntakeNotFoundError, IntakeConflictError, VideoSourceMediaError, ObjectStorageError, RuntimeError) as exc:
        _raise_media_error(exc)


@router.delete("/folder/{folder_id}/sources/{source_id}", response_model=VideoSourceFolderResponse)
async def remove_source(
    project_id: str,
    content_id: str,
    folder_id: str,
    source_id: str,
    request: MutationRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> VideoSourceFolderResponse:
    await _require_context(project_id=project_id, content_id=content_id, current_user=current_user)
    try:
        return await video_source_intake_service.remove_source(
            folder_id=folder_id,
            source_id=source_id,
            user_id=current_user.user_id,
            expected_revision=request.revision,
        )
    except (IntakeNotFoundError, IntakeConflictError) as exc:
        _raise_domain_error(exc)


@router.post("/folder/{folder_id}/sources/{source_id}/retry", response_model=VideoSourceFolderResponse)
async def retry_source(
    project_id: str,
    content_id: str,
    folder_id: str,
    source_id: str,
    request: MutationRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> VideoSourceFolderResponse:
    await _require_context(project_id=project_id, content_id=content_id, current_user=current_user)
    try:
        return await video_source_intake_service.retry_source(
            folder_id=folder_id,
            source_id=source_id,
            user_id=current_user.user_id,
            expected_revision=request.revision,
        )
    except (IntakeNotFoundError, IntakeConflictError) as exc:
        _raise_domain_error(exc)


@router.post("/folder/{folder_id}/ready", response_model=VideoSourceFolderResponse)
async def mark_sources_ready(
    project_id: str,
    content_id: str,
    folder_id: str,
    request: MarkSourcesReadyRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> VideoSourceFolderResponse:
    await _require_context(project_id=project_id, content_id=content_id, current_user=current_user)
    try:
        return await video_source_intake_service.mark_ready(
            folder_id=folder_id,
            user_id=current_user.user_id,
            expected_revision=request.revision,
        )
    except (IntakeNotFoundError, IntakeConflictError) as exc:
        _raise_domain_error(exc)


@router.post("/folder/{folder_id}/generate", response_model=GenerateVideoResultResponse)
async def generate_video_from_sources(
    project_id: str,
    content_id: str,
    folder_id: str,
    request: GenerateVideoRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> GenerateVideoResultResponse:
    await _require_context(project_id=project_id, content_id=content_id, current_user=current_user)
    try:
        handoff = await video_source_intake_service.generate(
            folder_id=folder_id,
            user_id=current_user.user_id,
            expected_revision=request.revision,
            idempotency_key=request.idempotency_key,
        )
        folder = await video_source_intake_service.get_folder(
            folder_id=folder_id, user_id=current_user.user_id
        )
        if folder is None:
            raise HTTPException(status_code=404, detail="Source folder not found")
        return GenerateVideoResultResponse(
            folder=folder,
            canonical_request_id=handoff.generation_request_id,
        )
    except (IntakeNotFoundError, IntakeConflictError) as exc:
        _raise_domain_error(exc)
