import { ResponsiveLayout } from "./ResponsiveLayout";
import { usePlatform } from "../../hooks/usePlatform";

export function PlatformAwareLayout() {
  const { isMobile } = usePlatform();

  return <ResponsiveLayout isMobile={isMobile} />;
}
