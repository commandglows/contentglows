import { bundle } from "@remotion/bundler";
import {
  ensureBrowser,
  makeCancelSignal,
  renderMedia,
  selectComposition,
} from "@remotion/renderer";
import dotenv from "dotenv";
import express, { type Request, type Response } from "express";
import path from "node:path";

import {
  buildArtifactRelativePath,
  cleanupExpiredArtifacts,
  ensureRenderDirectories,
  resolveSafeArtifactPath,
  readRenderStorageConfig,
  storeRenderedArtifact,
  type RenderArtifactMetadata,
  type RenderMode,
} from "./render-storage";

dotenv.config();

const DEFAULT_PORT = 3210;
const DEFAULT_RETENTION_DAYS = 30;
const MAINTENANCE_INTERVAL_MS = 24 * 60 * 60 * 1000;
const MAX_TIMELINE_DURATION_SECONDS = 180;
const TERMINAL_STATUSES = new Set(["completed", "failed", "cancelled"]);
const ACTIVE_STATUSES = new Set(["queued", "in_progress"]);

type WorkerStatus = "queued" | "in_progress" | "completed" | "failed" | "cancelled";

interface CreateRenderRequest {
  jobId: string;
  renderMode: RenderMode;
  durationSeconds: number;
  templateId?: string;
  compositionId?: string;
  inputProps: Record<string, unknown>;
}

interface WorkerJob {
  workerJobId: string;
  status: WorkerStatus;
  progress: number;
  renderMode: RenderMode;
  durationSeconds: number;
  compositionId: string;
  templateId: string;
  inputProps: Record<string, unknown>;
  artifact?: RenderArtifactMetadata;
  createdAt: string;
  updatedAt: string;
  startedAt?: string;
  completedAt?: string;
  message?: string;
  cancelRender?: () => void;
  cancelledByRequest: boolean;
}

interface WorkerResponsePayload {
  workerJobId: string;
  status: WorkerStatus;
  progress: number;
  renderMode: RenderMode;
  durationSeconds: number;
  templateId: string;
  compositionId: string;
  artifact?: RenderArtifactMetadata;
  message?: string;
  createdAt: string;
  updatedAt: string;
  startedAt?: string;
  completedAt?: string;
}

function readRetentionDays(): number {
  const raw = Number.parseInt(
    process.env.RENDER_ARTIFACT_RETENTION_DAYS ?? `${DEFAULT_RETENTION_DAYS}`,
    10,
  );
  if (!Number.isFinite(raw) || raw <= 0) {
    return DEFAULT_RETENTION_DAYS;
  }
  return raw;
}

function readToken(): string {
  const token = process.env.REMOTION_WORKER_TOKEN?.trim();
  if (!token) {
    throw new Error("REMOTION_WORKER_TOKEN is required");
  }
  return token;
}

function toPublicJob(job: WorkerJob): WorkerResponsePayload {
  return {
    workerJobId: job.workerJobId,
    status: job.status,
    progress: job.progress,
    renderMode: job.renderMode,
    durationSeconds: job.durationSeconds,
    templateId: job.templateId,
    compositionId: job.compositionId,
    artifact: job.artifact,
    message: job.message,
    createdAt: job.createdAt,
    updatedAt: job.updatedAt,
    startedAt: job.startedAt,
    completedAt: job.completedAt,
  };
}

function sanitizeMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message.slice(0, 500);
  }
  return "Render failed";
}

function sanitizeRenderFailureMessage(error: unknown): string {
  if (error instanceof Error && error.message.includes("Cancelled")) {
    return "Cancelled";
  }
  return "Render failed";
}

function requireWorkerToken(token: string) {
  return (req: Request, res: Response, next: () => void): void => {
    if (req.path === "/health") {
      next();
      return;
    }
    const value = req.header("authorization");
    if (!value?.startsWith("Bearer ")) {
      res.status(401).json({ detail: "Missing worker token" });
      return;
    }
    const presented = value.slice("Bearer ".length).trim();
    if (presented !== token) {
      res.status(401).json({ detail: "Invalid worker token" });
      return;
    }
    next();
  };
}

function getStringRouteParam(req: Request, key: string): string | null {
  const value = req.params[key];
  return typeof value === "string" ? value : null;
}

function isCreateRenderRequest(payload: unknown): payload is CreateRenderRequest {
  if (!payload || typeof payload !== "object") {
    return false;
  }
  const body = payload as Record<string, unknown>;
  return (
    typeof body.jobId === "string" &&
    (body.renderMode === "preview" || body.renderMode === "final") &&
    typeof body.durationSeconds === "number" &&
    typeof body.inputProps === "object" &&
    body.inputProps !== null
  );
}

async function bootstrapRemotionServeUrl(): Promise<string> {
  const prebuiltServeUrl = process.env.REMOTION_SERVE_URL?.trim();
  if (prebuiltServeUrl) {
    return prebuiltServeUrl;
  }
  return bundle({
    entryPoint: path.resolve(process.cwd(), "remotion/index.ts"),
    onProgress(progress) {
      console.info(`[remotion-worker] bundling: ${progress}%`);
    },
  });
}

async function startServer(): Promise<void> {
  const port = Number.parseInt(process.env.PORT ?? `${DEFAULT_PORT}`, 10);
  const token = readToken();
  const retentionDays = readRetentionDays();
  const storageConfig = readRenderStorageConfig();
  const renderRootDir = storageConfig.renderRootDir;
  const serveUrl = await bootstrapRemotionServeUrl();
  await ensureBrowser();
  await ensureRenderDirectories(renderRootDir);
  await cleanupExpiredArtifacts(renderRootDir, retentionDays);

  setInterval(async () => {
    try {
      await cleanupExpiredArtifacts(renderRootDir, retentionDays);
    } catch (error) {
      console.error("[remotion-worker] cleanup failed:", error);
    }
  }, MAINTENANCE_INTERVAL_MS).unref();

  const jobs = new Map<string, WorkerJob>();
  const app = express();
  app.use(express.json({ limit: "1mb" }));
  app.use(requireWorkerToken(token));

  app.get("/health", (_req: Request, res: Response) => {
    res.json({
      status: "ok",
      storageProvider: storageConfig.provider,
      renderRootDir,
      retentionDays,
      serveUrl,
    });
  });

  async function executeRender(jobId: string): Promise<void> {
    const current = jobs.get(jobId);
    if (!current || TERMINAL_STATUSES.has(current.status)) {
      return;
    }
    if (current.cancelledByRequest) {
      const now = new Date().toISOString();
      jobs.set(jobId, {
        ...current,
        status: "cancelled",
        progress: current.progress,
        updatedAt: now,
        completedAt: now,
        message: "Cancelled",
      });
      return;
    }

    const { cancel, cancelSignal } = makeCancelSignal();
    const startedAt = new Date().toISOString();
    jobs.set(jobId, {
      ...current,
      status: "in_progress",
      progress: 1,
      startedAt,
      updatedAt: startedAt,
      cancelRender: cancel,
    });

    try {
      const renderingJob = jobs.get(jobId);
      if (!renderingJob) {
        return;
      }
      const relativePath = buildArtifactRelativePath(jobId, renderingJob.renderMode);
      const absoluteOutputPath = resolveSafeArtifactPath(renderRootDir, relativePath);
      const composition = await selectComposition({
        serveUrl,
        id: renderingJob.compositionId,
        inputProps: renderingJob.inputProps,
      });

      await renderMedia({
        serveUrl,
        codec: "h264",
        composition,
        inputProps: renderingJob.inputProps,
        cancelSignal,
        outputLocation: absoluteOutputPath,
        onProgress(progress) {
          const latest = jobs.get(jobId);
          if (!latest || latest.status !== "in_progress") {
            return;
          }
          jobs.set(jobId, {
            ...latest,
            progress: Math.max(1, Math.min(99, Math.round(progress.progress * 100))),
            updatedAt: new Date().toISOString(),
          });
        },
      });

      const completedAt = new Date();
      const metadata = await storeRenderedArtifact({
        storageConfig,
        jobId,
        absoluteOutputPath,
        renderMode: renderingJob.renderMode,
        completedAt,
        retentionDays,
      });

      jobs.set(jobId, {
        ...renderingJob,
        status: "completed",
        progress: 100,
        artifact: metadata,
        updatedAt: completedAt.toISOString(),
        completedAt: completedAt.toISOString(),
        message: "Completed",
        cancelRender: undefined,
      });
    } catch (error) {
      const latest = jobs.get(jobId);
      if (!latest) {
        return;
      }
      const now = new Date().toISOString();
      const cancelled = latest.cancelledByRequest;
      jobs.set(jobId, {
        ...latest,
        status: cancelled ? "cancelled" : "failed",
        progress: cancelled ? latest.progress : 0,
        updatedAt: now,
        completedAt: now,
        message: cancelled ? "Cancelled" : sanitizeRenderFailureMessage(error),
        cancelRender: undefined,
      });
    }
  }

  app.post("/renders", async (req: Request, res: Response) => {
    if (!isCreateRenderRequest(req.body)) {
      res.status(400).json({ detail: "Invalid render payload" });
      return;
    }

    const payload = req.body;
    const compositionId = payload.compositionId ?? "ReelFromContent";
    if (!Number.isInteger(payload.durationSeconds) || payload.durationSeconds <= 0) {
      res.status(400).json({ detail: "durationSeconds must be a positive integer" });
      return;
    }
    if (compositionId === "ReelFromContent" && payload.durationSeconds !== 60) {
      res.status(400).json({ detail: "durationSeconds must equal 60 for ReelFromContent" });
      return;
    }
    if (
      compositionId === "ContentGlowsTimelineVideo" &&
      payload.durationSeconds > MAX_TIMELINE_DURATION_SECONDS
    ) {
      res.status(400).json({ detail: "durationSeconds must be <= 180 for ContentGlowsTimelineVideo" });
      return;
    }

    if (jobs.has(payload.jobId)) {
      const existing = jobs.get(payload.jobId);
      if (existing && ACTIVE_STATUSES.has(existing.status)) {
        res.status(409).json({ detail: "Render job already active" });
        return;
      }
      if (existing) {
        res.status(409).json({ detail: "Render job id already exists" });
        return;
      }
    }

    try {
      buildArtifactRelativePath(payload.jobId, payload.renderMode);
    } catch (error) {
      res.status(400).json({ detail: sanitizeMessage(error) });
      return;
    }

    const now = new Date().toISOString();
    const job: WorkerJob = {
      workerJobId: payload.jobId,
      status: "queued",
      progress: 0,
      renderMode: payload.renderMode,
      durationSeconds: payload.durationSeconds,
      compositionId,
      templateId: payload.templateId ?? "content-summary-v1",
      inputProps: payload.inputProps,
      createdAt: now,
      updatedAt: now,
      cancelledByRequest: false,
    };
    jobs.set(payload.jobId, job);
    void executeRender(payload.jobId);
    res.status(202).json(toPublicJob(job));
  });

  app.get("/renders/:workerJobId", (req: Request, res: Response) => {
    const workerJobId = getStringRouteParam(req, "workerJobId");
    if (!workerJobId) {
      res.status(400).json({ detail: "Invalid worker job id" });
      return;
    }
    const job = jobs.get(workerJobId);
    if (!job) {
      res.status(404).json({ detail: "Render job not found" });
      return;
    }
    res.json(toPublicJob(job));
  });

  app.delete("/renders/:workerJobId", (req: Request, res: Response) => {
    const workerJobId = getStringRouteParam(req, "workerJobId");
    if (!workerJobId) {
      res.status(400).json({ detail: "Invalid worker job id" });
      return;
    }
    const job = jobs.get(workerJobId);
    if (!job) {
      res.status(404).json({ detail: "Render job not found" });
      return;
    }
    if (TERMINAL_STATUSES.has(job.status)) {
      res.status(400).json({ detail: "Render job is not cancellable" });
      return;
    }

    const now = new Date().toISOString();
    if (job.status === "queued") {
      jobs.set(workerJobId, {
        ...job,
        status: "cancelled",
        cancelledByRequest: true,
        updatedAt: now,
        completedAt: now,
        message: "Cancelled",
      });
      res.json(toPublicJob(jobs.get(workerJobId)!));
      return;
    }

    job.cancelRender?.();
    jobs.set(workerJobId, {
      ...job,
      cancelledByRequest: true,
      updatedAt: now,
      message: "Cancellation requested",
    });
    res.json(toPublicJob(jobs.get(workerJobId)!));
  });

  app.listen(port, () => {
    console.info(`[remotion-worker] listening on port ${port}`);
  });
}

startServer().catch((error) => {
  console.error("[remotion-worker] startup failed:", error);
  process.exit(1);
});
