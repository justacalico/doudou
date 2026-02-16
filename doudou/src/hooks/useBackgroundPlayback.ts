import { useEffect } from "react";
import { invoke } from "@tauri-apps/api/core";

export function useBackgroundPlayback() {
  useEffect(() => {
    void invoke("enable_background_playback").catch(() => {
      // Background playback support is implemented progressively in Rust.
    });
  }, []);
}
