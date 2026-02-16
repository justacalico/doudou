import { useBackgroundPlayback } from "../../hooks/useBackgroundPlayback";
import { useMediaSession } from "../../hooks/useMediaSession";

export function BackgroundPlayer() {
  useBackgroundPlayback();
  useMediaSession();
  return null;
}
