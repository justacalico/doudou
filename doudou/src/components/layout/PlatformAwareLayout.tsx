import { ResponsiveLayout } from "./ResponsiveLayout";
import { usePlatform } from "../../hooks/usePlatform";
import { BackgroundPlayer } from "../player/BackgroundPlayer";

export function PlatformAwareLayout() {
  const { isMobile } = usePlatform();

  return (
    <>
      <BackgroundPlayer />
      <ResponsiveLayout isMobile={isMobile} />
    </>
  );
}
