import { useEffect } from "react";
import { getPlatform } from "../lib/tauri-commands";
import { useSettingsStore } from "../stores/settingsStore";

export function usePlatform() {
  const platform = useSettingsStore((state) => state.platform);
  const setPlatform = useSettingsStore((state) => state.setPlatform);

  useEffect(() => {
    let isMounted = true;
    void getPlatform()
      .then((value) => {
        if (isMounted) {
          setPlatform(value);
        }
      })
      .catch(() => {
        if (isMounted) {
          setPlatform("linux");
        }
      });
    return () => {
      isMounted = false;
    };
  }, [setPlatform]);

  const isMobile = platform === "android" || platform === "ios";
  const isDesktop = !isMobile;

  return {
    platform,
    isMobile,
    isDesktop,
  };
}
