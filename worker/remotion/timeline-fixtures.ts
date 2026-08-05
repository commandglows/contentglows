import type { ContentGlowsTimelineProps } from "./ContentGlowsTimelineVideo";

export const verticalTimelineFixture: ContentGlowsTimelineProps = {
  composition_id: "ContentGlowsTimelineVideo",
  timeline_id: "timeline-vertical-001",
  version_id: "version-vertical-001",
  format: {
    preset: "vertical_9_16",
    width: 1080,
    height: 1920,
    fps: 30,
    duration_in_frames: 300,
  },
  tracks: [
    { id: "visual-main", type: "visual", order: 0, muted: false },
    { id: "overlay", type: "overlay", order: 1, muted: false },
    { id: "audio-main", type: "audio", order: 2, muted: false },
  ],
  clips: [
    {
      id: "bg",
      track_id: "visual-main",
      type: "background",
      start_frame: 0,
      duration_in_frames: 300,
      trim_start_frame: 0,
      style: { background_color: "#0f172a" },
    },
    {
      id: "hero-image",
      track_id: "visual-main",
      type: "image",
      start_frame: 0,
      duration_in_frames: 150,
      asset_ref: "asset-image-1",
      trim_start_frame: 0,
      style: { fit: "cover" },
    },
    {
      id: "hero-video",
      track_id: "visual-main",
      type: "video",
      start_frame: 150,
      duration_in_frames: 150,
      asset_ref: "asset-video-1",
      trim_start_frame: 15,
      style: { fit: "cover" },
    },
    {
      id: "title-1",
      track_id: "overlay",
      type: "text",
      start_frame: 20,
      duration_in_frames: 120,
      trim_start_frame: 0,
      text: "Unified ContentGlows timeline",
      style: {
        font_size: 68,
        text_align: "center",
        color: "#f8fafc",
        background_color: "rgba(0, 0, 0, 0.35)",
      },
    },
    {
      id: "title-2",
      track_id: "overlay",
      type: "text",
      start_frame: 170,
      duration_in_frames: 100,
      trim_start_frame: 0,
      text: "Video + audio + music MVP",
      style: {
        font_size: 60,
        text_align: "center",
        color: "#e2e8f0",
        background_color: "rgba(15, 23, 42, 0.45)",
      },
    },
    {
      id: "voice",
      track_id: "audio-main",
      type: "audio",
      start_frame: 0,
      duration_in_frames: 180,
      asset_ref: "asset-audio-1",
      trim_start_frame: 10,
      volume: 1,
      style: {},
    },
    {
      id: "music-bed",
      track_id: "audio-main",
      type: "music",
      start_frame: 0,
      duration_in_frames: 300,
      asset_ref: "asset-music-1",
      trim_start_frame: 0,
      volume: 0.45,
      style: {},
    },
  ],
  assets: {
    "asset-image-1": {
      render_url:
        "https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=1080&q=80",
    },
    "asset-video-1": {
      render_url: "https://samplelib.com/lib/preview/mp4/sample-5s.mp4",
    },
    "asset-audio-1": {
      render_url: "https://samplelib.com/lib/preview/mp3/sample-3s.mp3",
    },
    "asset-music-1": {
      render_url: "https://samplelib.com/lib/preview/mp3/sample-12s.mp3",
    },
  },
};

export const landscapeTimelineFixture: ContentGlowsTimelineProps = {
  ...verticalTimelineFixture,
  timeline_id: "timeline-landscape-001",
  version_id: "version-landscape-001",
  format: {
    preset: "landscape_16_9",
    width: 1920,
    height: 1080,
    fps: 30,
    duration_in_frames: 300,
  },
  clips: verticalTimelineFixture.clips.map((clip) =>
    clip.type === "text"
      ? {
          ...clip,
          style: {
            ...clip.style,
            font_size: 54,
          },
        }
      : clip,
  ),
};
