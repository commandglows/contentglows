import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, it } from "node:test";
import assert from "node:assert/strict";
import { Writable } from "node:stream";

import {
  buildGcsArtifactMetadata,
  buildGcsObjectName,
  buildArtifactRelativePath,
  cleanupExpiredArtifacts,
  computeRetentionMetadata,
  ensureRenderDirectories,
  readRenderStorageConfig,
  resolveSafeArtifactPath,
} from "./render-storage";

const tempPaths: string[] = [];

afterEach(async () => {
  while (tempPaths.length > 0) {
    const p = tempPaths.pop();
    if (p) {
      await fs.rm(p, { recursive: true, force: true });
    }
  }
});

describe("render storage", () => {
  it("builds safe preview and final paths", () => {
    assert.equal(buildArtifactRelativePath("job_1", "preview"), "previews/job_1.mp4");
    assert.equal(buildArtifactRelativePath("job-2", "final"), "finals/job-2.mp4");
  });

  it("rejects unsafe job ids", () => {
    assert.throws(() => buildArtifactRelativePath("../bad", "preview"), /Invalid job id/);
  });

  it("prevents path traversal", () => {
    const root = "/tmp/renders";
    assert.throws(
      () => resolveSafeArtifactPath(root, "../secrets.txt"),
      /Unsafe artifact path/,
    );
  });

  it("computes 30d retention and 72h warning", () => {
    const completedAt = new Date("2026-05-01T00:00:00.000Z");
    const timing = computeRetentionMetadata(completedAt, 30);
    assert.equal(timing.retentionExpiresAt, "2026-05-31T00:00:00.000Z");
    assert.equal(timing.deletionWarningAt, "2026-05-28T00:00:00.000Z");
  });

  it("builds safe GCS object names", () => {
    assert.equal(
      buildGcsObjectName("job_1", "preview", "contentglows/renders"),
      "contentglows/renders/previews/job_1.mp4",
    );
    assert.throws(() => buildGcsObjectName("../bad", "final", "renders"), /Invalid job id/);
    assert.throws(() => buildGcsObjectName("job_1", "final", "../renders"), /Unsafe GCS render prefix/);
  });

  it("fails closed when GCS storage mode has no bucket", () => {
    const previousMode = process.env.CONTENTGLOWS_RENDER_STORAGE;
    const previousBucket = process.env.GCS_RENDER_BUCKET;
    process.env.CONTENTGLOWS_RENDER_STORAGE = "gcs";
    delete process.env.GCS_RENDER_BUCKET;
    try {
      assert.throws(() => readRenderStorageConfig(), /GCS_RENDER_BUCKET is required/);
    } finally {
      if (previousMode === undefined) {
        delete process.env.CONTENTGLOWS_RENDER_STORAGE;
      } else {
        process.env.CONTENTGLOWS_RENDER_STORAGE = previousMode;
      }
      if (previousBucket === undefined) {
        delete process.env.GCS_RENDER_BUCKET;
      } else {
        process.env.GCS_RENDER_BUCKET = previousBucket;
      }
    }
  });

  it("uploads GCS artifacts and returns private metadata", async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), "cf-render-gcs-test-"));
    tempPaths.push(root);
    const videoPath = path.join(root, "job_1.mp4");
    await fs.writeFile(videoPath, "video");

    const uploads: Array<{ objectName: string; content: Buffer; contentType?: string }> = [];
    const fakeStorage = {
      bucket() {
        return {
          file(objectName: string) {
            return {
              createWriteStream(options: { contentType?: string }) {
                const chunks: Buffer[] = [];
                return new Writable({
                  write(chunk, _encoding, callback) {
                    chunks.push(Buffer.from(chunk));
                    callback();
                  },
                  final(callback) {
                    uploads.push({
                      objectName,
                      content: Buffer.concat(chunks),
                      contentType: options.contentType,
                    });
                    callback();
                  },
                });
              },
            };
          },
        };
      },
    };

    const metadata = await buildGcsArtifactMetadata({
      bucketName: "private-bucket",
      objectName: "renders/previews/job_1.mp4",
      absolutePath: videoPath,
      renderMode: "preview",
      completedAt: new Date("2026-05-01T00:00:00.000Z"),
      retentionDays: 30,
      // The fake implements the Storage methods used by this helper.
      storage: fakeStorage as never,
    });

    assert.equal(uploads.length, 1);
    assert.equal(uploads[0].objectName, "renders/previews/job_1.mp4");
    assert.equal(uploads[0].contentType, "video/mp4");
    assert.equal(metadata.provider, "gcs");
    assert.equal(metadata.bucket, "private-bucket");
    assert.equal(metadata.artifactPath, "renders/previews/job_1.mp4");
    assert.equal(metadata.objectName, "renders/previews/job_1.mp4");
  });

  it("cleans up expired mp4 artifacts", async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), "cf-render-test-"));
    tempPaths.push(root);
    await ensureRenderDirectories(root);

    const previewPath = path.join(root, "previews", "old.mp4");
    const finalPath = path.join(root, "finals", "new.mp4");
    await fs.writeFile(previewPath, "x");
    await fs.writeFile(finalPath, "x");

    const oldTime = new Date("2026-01-01T00:00:00.000Z");
    await fs.utimes(previewPath, oldTime, oldTime);
    const recentTime = new Date("2026-05-10T00:00:00.000Z");
    await fs.utimes(finalPath, recentTime, recentTime);

    const result = await cleanupExpiredArtifacts(root, 30, new Date("2026-05-14T00:00:00.000Z"));
    assert.equal(result.deleted, 1);

    await assert.rejects(async () => fs.stat(previewPath));
    await fs.stat(finalPath);
  });
});
