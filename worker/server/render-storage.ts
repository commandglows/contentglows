import { createReadStream, promises as fs } from "node:fs";
import path from "node:path";
import { pipeline } from "node:stream/promises";
import { Storage, type File } from "@google-cloud/storage";

export type RenderMode = "preview" | "final";
export type RenderStorageProvider = "local" | "gcs";

export interface RetentionMetadata {
  retentionExpiresAt: string;
  deletionWarningAt: string;
}

export interface RenderArtifactMetadata extends RetentionMetadata {
  provider: RenderStorageProvider;
  artifactPath: string;
  byteSize: number;
  mimeType: "video/mp4";
  renderMode: RenderMode;
  fileName: string;
  bucket?: string;
  objectName?: string;
}

export interface RenderStorageConfig {
  provider: RenderStorageProvider;
  renderRootDir: string;
  gcsBucket?: string;
  gcsPrefix: string;
}

const SAFE_JOB_ID = /^[a-zA-Z0-9_-]{1,128}$/;
const ALLOWED_EXTENSION = ".mp4";
const DELETION_WARNING_HOURS = 72;

const folderByMode: Record<RenderMode, string> = {
  preview: "previews",
  final: "finals",
};

export function toSafeJobId(jobId: string): string {
  if (!SAFE_JOB_ID.test(jobId)) {
    throw new Error("Invalid job id");
  }
  return jobId;
}

function toModeFolder(renderMode: RenderMode): string {
  return folderByMode[renderMode];
}

export function resolveRenderRootDir(): string {
  const configured = process.env.CONTENTGLOWS_RENDER_DIR?.trim();
  if (configured) {
    return path.resolve(configured);
  }
  return path.resolve(process.cwd(), "renders");
}

function normalizeStorageProvider(value: string | undefined): RenderStorageProvider {
  const normalized = value?.trim().toLowerCase();
  if (!normalized || normalized === "local") {
    return "local";
  }
  if (normalized === "gcs") {
    return "gcs";
  }
  throw new Error("CONTENTGLOWS_RENDER_STORAGE must be local or gcs");
}

export function normalizeGcsPrefix(prefix: string | undefined): string {
  const cleaned = (prefix ?? "renders").trim().replace(/^\/+|\/+$/g, "");
  if (!cleaned) {
    return "renders";
  }
  if (cleaned.includes("..") || cleaned.includes("\\") || cleaned.startsWith("/")) {
    throw new Error("Unsafe GCS render prefix");
  }
  return cleaned;
}

export function readRenderStorageConfig(): RenderStorageConfig {
  const provider = normalizeStorageProvider(process.env.CONTENTGLOWS_RENDER_STORAGE);
  const renderRootDir = resolveRenderRootDir();
  if (provider === "local") {
    return {
      provider,
      renderRootDir,
      gcsPrefix: normalizeGcsPrefix(process.env.GCS_RENDER_PREFIX),
    };
  }

  const gcsBucket = process.env.GCS_RENDER_BUCKET?.trim();
  if (!gcsBucket) {
    throw new Error("GCS_RENDER_BUCKET is required when CONTENTGLOWS_RENDER_STORAGE=gcs");
  }

  return {
    provider,
    renderRootDir,
    gcsBucket,
    gcsPrefix: normalizeGcsPrefix(process.env.GCS_RENDER_PREFIX),
  };
}

export async function ensureRenderDirectories(rootDir: string): Promise<void> {
  await fs.mkdir(path.join(rootDir, "previews"), { recursive: true });
  await fs.mkdir(path.join(rootDir, "finals"), { recursive: true });
}

export function buildArtifactRelativePath(jobId: string, renderMode: RenderMode): string {
  const safeJobId = toSafeJobId(jobId);
  return `${toModeFolder(renderMode)}/${safeJobId}${ALLOWED_EXTENSION}`;
}

export function buildGcsObjectName(
  jobId: string,
  renderMode: RenderMode,
  prefix = normalizeGcsPrefix(process.env.GCS_RENDER_PREFIX),
): string {
  const safeJobId = toSafeJobId(jobId);
  return `${normalizeGcsPrefix(prefix)}/${toModeFolder(renderMode)}/${safeJobId}${ALLOWED_EXTENSION}`;
}

export function resolveSafeArtifactPath(rootDir: string, relativePath: string): string {
  const normalized = relativePath.replace(/\\/g, "/");
  if (normalized.startsWith("/") || normalized.includes("..")) {
    throw new Error("Unsafe artifact path");
  }

  const root = path.resolve(rootDir);
  const resolved = path.resolve(root, normalized);
  if (resolved !== root && !resolved.startsWith(`${root}${path.sep}`)) {
    throw new Error("Artifact path escapes render root");
  }
  if (path.extname(resolved).toLowerCase() !== ALLOWED_EXTENSION) {
    throw new Error("Unsupported artifact extension");
  }

  return resolved;
}

export function computeRetentionMetadata(
  completedAt: Date,
  retentionDays: number,
): RetentionMetadata {
  const retentionExpiresAt = new Date(completedAt.getTime() + retentionDays * 24 * 3600 * 1000);
  const deletionWarningAt = new Date(
    retentionExpiresAt.getTime() - DELETION_WARNING_HOURS * 3600 * 1000,
  );
  return {
    retentionExpiresAt: retentionExpiresAt.toISOString(),
    deletionWarningAt: deletionWarningAt.toISOString(),
  };
}

export async function buildArtifactMetadata(
  rootDir: string,
  absolutePath: string,
  renderMode: RenderMode,
  completedAt: Date,
  retentionDays: number,
): Promise<RenderArtifactMetadata> {
  const stat = await fs.stat(absolutePath);
  if (!stat.isFile() || stat.size <= 0) {
    throw new Error("Rendered artifact missing or empty");
  }

  const root = path.resolve(rootDir);
  const resolved = path.resolve(absolutePath);
  if (resolved !== root && !resolved.startsWith(`${root}${path.sep}`)) {
    throw new Error("Artifact path escapes render root");
  }

  const relativePath = path.relative(root, resolved).split(path.sep).join("/");
  if (relativePath.startsWith("..") || path.isAbsolute(relativePath)) {
    throw new Error("Invalid artifact relative path");
  }

  const timing = computeRetentionMetadata(completedAt, retentionDays);
  return {
    provider: "local",
    artifactPath: relativePath,
    byteSize: stat.size,
    mimeType: "video/mp4",
    renderMode,
    fileName: path.basename(resolved),
    ...timing,
  };
}

async function ensureMp4File(absolutePath: string): Promise<{ byteSize: number; fileName: string }> {
  const stat = await fs.stat(absolutePath);
  if (!stat.isFile() || stat.size <= 0) {
    throw new Error("Rendered artifact missing or empty");
  }
  if (path.extname(absolutePath).toLowerCase() !== ALLOWED_EXTENSION) {
    throw new Error("Unsupported artifact extension");
  }
  return {
    byteSize: stat.size,
    fileName: path.basename(absolutePath),
  };
}

async function uploadToGcs(file: File, localPath: string): Promise<void> {
  await pipeline(createReadStream(localPath), file.createWriteStream({
    resumable: false,
    contentType: "video/mp4",
    metadata: {
      cacheControl: "private, max-age=0, no-store",
    },
  }));
}

export async function buildGcsArtifactMetadata(
  {
    bucketName,
    objectName,
    absolutePath,
    renderMode,
    completedAt,
    retentionDays,
    storage = new Storage(),
  }: {
  bucketName: string;
  objectName: string;
  absolutePath: string;
  renderMode: RenderMode;
  completedAt: Date;
  retentionDays: number;
  storage?: Storage;
  },
): Promise<RenderArtifactMetadata> {
  const fileInfo = await ensureMp4File(absolutePath);
  const file = storage.bucket(bucketName).file(objectName);
  await uploadToGcs(file, absolutePath);
  const timing = computeRetentionMetadata(completedAt, retentionDays);
  return {
    provider: "gcs",
    artifactPath: objectName,
    bucket: bucketName,
    objectName,
    byteSize: fileInfo.byteSize,
    mimeType: "video/mp4",
    renderMode,
    fileName: fileInfo.fileName,
    ...timing,
  };
}

export async function storeRenderedArtifact(
  {
    storageConfig,
    jobId,
    absoluteOutputPath,
    renderMode,
    completedAt,
    retentionDays,
  }: {
  storageConfig: RenderStorageConfig;
  jobId: string;
  absoluteOutputPath: string;
  renderMode: RenderMode;
  completedAt: Date;
  retentionDays: number;
  },
): Promise<RenderArtifactMetadata> {
  if (storageConfig.provider === "local") {
    return buildArtifactMetadata(
      storageConfig.renderRootDir,
      absoluteOutputPath,
      renderMode,
      completedAt,
      retentionDays,
    );
  }

  if (!storageConfig.gcsBucket) {
    throw new Error("GCS render bucket is not configured");
  }
  return buildGcsArtifactMetadata({
    bucketName: storageConfig.gcsBucket,
    objectName: buildGcsObjectName(jobId, renderMode, storageConfig.gcsPrefix),
    absolutePath: absoluteOutputPath,
    renderMode,
    completedAt,
    retentionDays,
  });
}

function isExpiredArtifact(stats: { mtime: Date }, now: Date, retentionDays: number): boolean {
  const expiresAt = new Date(stats.mtime.getTime() + retentionDays * 24 * 3600 * 1000);
  return expiresAt.getTime() <= now.getTime();
}

export async function cleanupExpiredArtifacts(
  rootDir: string,
  retentionDays: number,
  now: Date = new Date(),
): Promise<{ deleted: number }> {
  await ensureRenderDirectories(rootDir);

  let deleted = 0;
  for (const folder of ["previews", "finals"]) {
    const folderPath = path.join(rootDir, folder);
    const entries = await fs.readdir(folderPath, { withFileTypes: true });
    for (const entry of entries) {
      if (!entry.isFile()) {
        continue;
      }
      if (path.extname(entry.name).toLowerCase() !== ALLOWED_EXTENSION) {
        continue;
      }
      const absolutePath = path.join(folderPath, entry.name);
      const stats = await fs.stat(absolutePath);
      if (isExpiredArtifact(stats, now, retentionDays)) {
        await fs.unlink(absolutePath);
        deleted += 1;
      }
    }
  }
  return { deleted };
}
