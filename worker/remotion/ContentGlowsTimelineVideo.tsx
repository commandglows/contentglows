import type { CSSProperties, ReactElement } from "react";
import { AbsoluteFill, Audio, Img, OffthreadVideo, Sequence } from "remotion";
import { z } from "zod";

const FPS = 30;
const MAX_DURATION_IN_FRAMES = 5400;
const FALLBACK_DURATION_IN_FRAMES = 180;

const FORMAT_DIMENSIONS = {
  vertical_9_16: { width: 1080, height: 1920 },
  landscape_16_9: { width: 1920, height: 1080 },
} as const;

const formatSchema = z
  .object({
    preset: z.enum(["vertical_9_16", "landscape_16_9"]),
    width: z.number().int().positive(),
    height: z.number().int().positive(),
    fps: z.number().int().positive(),
    duration_in_frames: z.number().int().positive().max(MAX_DURATION_IN_FRAMES),
  })
  .superRefine((value, ctx) => {
    if (value.fps !== FPS) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["fps"],
        message: "Only 30fps is supported.",
      });
    }
    const expected = FORMAT_DIMENSIONS[value.preset];
    if (value.width !== expected.width || value.height !== expected.height) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["width"],
        message: "Dimensions do not match format preset.",
      });
    }
  });

const trackSchema = z
  .object({
    id: z.string().min(1),
    type: z.enum(["visual", "overlay", "audio"]),
    order: z.number().int(),
    muted: z.boolean().optional().default(false),
  })
  .passthrough();

const clipSchema = z
  .object({
    id: z.string().min(1),
    track_id: z.string().min(1),
    type: z.enum(["text", "image", "video", "audio", "music", "background", "render_output"]),
    start_frame: z.number().int().nonnegative(),
    duration_in_frames: z.number().int().positive(),
    asset_ref: z.string().optional(),
    trim_start_frame: z.number().int().nonnegative().optional().default(0),
    text: z.string().optional(),
    role: z.string().optional(),
    volume: z.number().nonnegative().max(2).optional(),
    style: z.record(z.string(), z.unknown()).optional().default({}),
  })
  .passthrough();

const assetSchema = z.record(z.string(), z.unknown());

export const contentGlowsTimelinePropsSchema = z
  .object({
    composition_id: z.literal("ContentGlowsTimelineVideo"),
    timeline_id: z.string().min(1),
    version_id: z.string().min(1),
    format: formatSchema,
    tracks: z.array(trackSchema).max(12),
    clips: z.array(clipSchema).max(100),
    assets: z.record(z.string(), assetSchema).default({}),
  })
  .superRefine((value, ctx) => {
    if (value.format.duration_in_frames > MAX_DURATION_IN_FRAMES) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["format", "duration_in_frames"],
        message: `duration_in_frames must be <= ${MAX_DURATION_IN_FRAMES}.`,
      });
    }
  });

export type ContentGlowsTimelineProps = z.infer<typeof contentGlowsTimelinePropsSchema>;

type TimelineTrack = ContentGlowsTimelineProps["tracks"][number];
type TimelineClip = ContentGlowsTimelineProps["clips"][number];
type AssetDescriptor = ContentGlowsTimelineProps["assets"][string];

function clampVolume(value: number | undefined): number {
  if (typeof value !== "number" || Number.isNaN(value)) {
    return 1;
  }
  return Math.max(0, Math.min(2, value));
}

function asString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value : null;
}

function asNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function getRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function resolveAssetSrc(asset: AssetDescriptor | undefined): string | null {
  if (!asset) {
    return null;
  }

  const directKeys = ["render_url", "playback_url", "signed_url", "url", "src"];
  for (const key of directKeys) {
    const direct = asString(asset[key]);
    if (direct) {
      return direct;
    }
  }

  const nestedKeys = ["artifact", "storage", "descriptor", "file"];
  for (const nestedKey of nestedKeys) {
    const nested = getRecord(asset[nestedKey]);
    if (!nested) {
      continue;
    }
    for (const key of directKeys) {
      const candidate = asString(nested[key]);
      if (candidate) {
        return candidate;
      }
    }
  }

  return null;
}

function sortTracks(tracks: TimelineTrack[]): TimelineTrack[] {
  return [...tracks].sort((a, b) => {
    if (a.order === b.order) {
      return a.id.localeCompare(b.id);
    }
    return a.order - b.order;
  });
}

function sortClips(clips: TimelineClip[]): TimelineClip[] {
  return [...clips].sort((a, b) => {
    if (a.start_frame === b.start_frame) {
      return a.id.localeCompare(b.id);
    }
    return a.start_frame - b.start_frame;
  });
}

function resolvePositionStyle(style: Record<string, unknown> | undefined): CSSProperties {
  if (!style) {
    return {
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      width: "100%",
      height: "100%",
    };
  }

  const x = asNumber(style.x) ?? 0;
  const y = asNumber(style.y) ?? 0;
  const width = asNumber(style.width);
  const height = asNumber(style.height);

  return {
    left: x,
    top: y,
    width: width ?? "100%",
    height: height ?? "100%",
  };
}

function renderPlaceholder(label: string): ReactElement {
  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        backgroundColor: "#121216",
      }}
    >
      <div
        style={{
          border: "1px solid #2f3640",
          borderRadius: 8,
          backgroundColor: "#191c22",
          color: "#c8d1dc",
          padding: "10px 14px",
          fontSize: 22,
          fontFamily: "Inter, Arial, sans-serif",
        }}
      >
        {label}
      </div>
    </AbsoluteFill>
  );
}

function renderAudioPlaceholder(label: string): ReactElement {
  return (
    <AbsoluteFill style={{ justifyContent: "flex-end", alignItems: "flex-start", padding: 24 }}>
      <div
        style={{
          border: "1px solid #2f3640",
          borderRadius: 8,
          backgroundColor: "rgba(13, 18, 28, 0.8)",
          color: "#c8d1dc",
          padding: "8px 10px",
          fontSize: 18,
          fontFamily: "Inter, Arial, sans-serif",
        }}
      >
        {label}
      </div>
    </AbsoluteFill>
  );
}

function renderTextClip(clip: TimelineClip): ReactElement {
  const style = getRecord(clip.style) ?? {};
  const fontSize = Math.max(16, asNumber(style.font_size) ?? 60);
  const lineHeight = Math.max(1, asNumber(style.line_height) ?? 1.15);
  const textAlign = asString(style.text_align) ?? "center";
  const color = asString(style.color) ?? "#f8fafc";
  const backgroundColor = asString(style.background_color) ?? "transparent";

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        pointerEvents: "none",
        padding: 80,
      }}
    >
      <div
        style={{
          margin: 0,
          maxWidth: "100%",
          fontFamily: "Inter, Arial, sans-serif",
          fontWeight: 600,
          fontSize,
          lineHeight,
          letterSpacing: 0,
          color,
          backgroundColor,
          textAlign: textAlign as CSSProperties["textAlign"],
          padding: "8px 12px",
          borderRadius: 6,
          whiteSpace: "pre-wrap",
        }}
      >
        {clip.text?.trim() || " "}
      </div>
    </AbsoluteFill>
  );
}

function renderBackgroundClip(clip: TimelineClip, assets: ContentGlowsTimelineProps["assets"]): ReactElement {
  const asset = clip.asset_ref ? assets[clip.asset_ref] : undefined;
  const src = resolveAssetSrc(asset);
  if (src) {
    return <Img src={src} style={{ width: "100%", height: "100%", objectFit: "cover" }} />;
  }
  const style = getRecord(clip.style) ?? {};
  const bg = asString(style.background_color) ?? asString(style.color) ?? "#0b0e14";
  return <AbsoluteFill style={{ backgroundColor: bg }} />;
}

function renderImageClip(clip: TimelineClip, assets: ContentGlowsTimelineProps["assets"]): ReactElement {
  const asset = clip.asset_ref ? assets[clip.asset_ref] : undefined;
  const src = resolveAssetSrc(asset);
  if (!src) {
    return renderPlaceholder(`Missing image asset: ${clip.asset_ref ?? "unknown"}`);
  }
  const position = resolvePositionStyle(getRecord(clip.style) ?? undefined);
  const fit = asString(getRecord(clip.style)?.fit) ?? "cover";

  return (
    <AbsoluteFill style={{ overflow: "hidden" }}>
      <Img
        src={src}
        style={{
          position: "absolute",
          objectFit: fit as CSSProperties["objectFit"],
          ...position,
        }}
      />
    </AbsoluteFill>
  );
}

function renderVideoClip(clip: TimelineClip, assets: ContentGlowsTimelineProps["assets"]): ReactElement {
  const asset = clip.asset_ref ? assets[clip.asset_ref] : undefined;
  const src = resolveAssetSrc(asset);
  if (!src) {
    return renderPlaceholder(`Missing video asset: ${clip.asset_ref ?? "unknown"}`);
  }
  const position = resolvePositionStyle(getRecord(clip.style) ?? undefined);
  const fit = asString(getRecord(clip.style)?.fit) ?? "cover";

  return (
    <AbsoluteFill style={{ overflow: "hidden" }}>
      <OffthreadVideo
        src={src}
        muted
        startFrom={clip.trim_start_frame}
        style={{
          position: "absolute",
          objectFit: fit as CSSProperties["objectFit"],
          ...position,
        }}
      />
    </AbsoluteFill>
  );
}

function renderVisualClip(clip: TimelineClip, assets: ContentGlowsTimelineProps["assets"]): ReactElement | null {
  switch (clip.type) {
    case "background":
      return renderBackgroundClip(clip, assets);
    case "text":
      return renderTextClip(clip);
    case "image":
      return renderImageClip(clip, assets);
    case "video":
      return renderVideoClip(clip, assets);
    default:
      return null;
  }
}

export const deriveTimelineMetadata = (inputProps: unknown) => {
  const parsed = contentGlowsTimelinePropsSchema.safeParse(inputProps);
  if (parsed.success) {
    return {
      width: parsed.data.format.width,
      height: parsed.data.format.height,
      fps: parsed.data.format.fps,
      durationInFrames: parsed.data.format.duration_in_frames,
    };
  }

  const fallback = FORMAT_DIMENSIONS.vertical_9_16;
  return {
    width: fallback.width,
    height: fallback.height,
    fps: FPS,
    durationInFrames: FALLBACK_DURATION_IN_FRAMES,
  };
};

export const ContentGlowsTimelineVideo = ({
  tracks,
  clips,
  assets,
}: ContentGlowsTimelineProps) => {
  const orderedTracks = sortTracks(tracks);
  const orderedClips = sortClips(clips);
  const clipsByTrack = new Map<string, TimelineClip[]>();
  for (const clip of orderedClips) {
    const onTrack = clipsByTrack.get(clip.track_id);
    if (onTrack) {
      onTrack.push(clip);
    } else {
      clipsByTrack.set(clip.track_id, [clip]);
    }
  }

  const visualElements: ReactElement[] = [];
  const audioElements: ReactElement[] = [];

  for (const track of orderedTracks) {
    if (track.muted) {
      continue;
    }
    const trackClips = clipsByTrack.get(track.id) ?? [];
    for (const clip of trackClips) {
      const sequenceProps = {
        from: clip.start_frame,
        durationInFrames: clip.duration_in_frames,
      };

      if (clip.type === "audio" || clip.type === "music") {
        const asset = clip.asset_ref ? assets[clip.asset_ref] : undefined;
        const src = resolveAssetSrc(asset);
        if (!src) {
          visualElements.push(
            <Sequence key={`audio-missing-${clip.id}`} {...sequenceProps}>
              {renderAudioPlaceholder(`Missing ${clip.type} asset: ${clip.asset_ref ?? "unknown"}`)}
            </Sequence>,
          );
          continue;
        }
        audioElements.push(
          <Sequence key={`audio-${clip.id}`} {...sequenceProps}>
            <Audio
              src={src}
              startFrom={clip.trim_start_frame}
              volume={() => clampVolume(clip.volume)}
            />
          </Sequence>,
        );
        continue;
      }

      const visual = renderVisualClip(clip, assets);
      if (!visual) {
        continue;
      }
      visualElements.push(
        <Sequence key={`visual-${track.order}-${clip.id}`} {...sequenceProps}>
          {visual}
        </Sequence>,
      );
    }
  }

  return (
    <AbsoluteFill style={{ backgroundColor: "#07090d" }}>
      {visualElements}
      {audioElements}
    </AbsoluteFill>
  );
};
