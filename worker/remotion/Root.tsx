import { Composition, type CalculateMetadataFunction } from "remotion";

import {
  ContentGlowsTimelineVideo,
  type ContentGlowsTimelineProps,
  contentGlowsTimelinePropsSchema,
  deriveTimelineMetadata,
} from "./ContentGlowsTimelineVideo";
import { ReelFromContent, reelFromContentSchema } from "./ReelFromContent";
import { verticalTimelineFixture } from "./timeline-fixtures";

const FPS = 30;
const DURATION_SECONDS = 60;

const calculateContentGlowsTimelineMetadata: CalculateMetadataFunction<ContentGlowsTimelineProps> = ({
  props,
}) => deriveTimelineMetadata(props);

export const RemotionRoot = () => {
  return (
    <>
      <Composition
        id="ReelFromContent"
        component={ReelFromContent}
        durationInFrames={FPS * DURATION_SECONDS}
        fps={FPS}
        width={1080}
        height={1920}
        schema={reelFromContentSchema}
        defaultProps={{
          title: "Weekly Content Summary",
          hook: "Turn one article into a short narrative reel.",
          key_points: [
            "Identify one clear user pain.",
            "Show a concrete before and after.",
            "Give one practical next action.",
          ],
          cta: "Follow for next week summary.",
        }}
      />
      <Composition
        id="ContentGlowsTimelineVideo"
        component={ContentGlowsTimelineVideo}
        durationInFrames={verticalTimelineFixture.format.duration_in_frames}
        fps={verticalTimelineFixture.format.fps}
        width={verticalTimelineFixture.format.width}
        height={verticalTimelineFixture.format.height}
        schema={contentGlowsTimelinePropsSchema}
        defaultProps={verticalTimelineFixture}
        calculateMetadata={calculateContentGlowsTimelineMetadata}
      />
    </>
  );
};
