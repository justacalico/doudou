import { useEffect, useState } from "react";
import { useServerStore } from "../stores/serverStore";
import { useSettingsStore } from "../stores/settingsStore";
import type { ProviderType } from "../types";

export function SettingsPage() {
  const session = useServerStore((state) => state.activeSession);
  const connect = useServerStore((state) => state.connect);
  const disconnect = useServerStore((state) => state.disconnect);
  const { settings, loadSettings, saveSettings } = useSettingsStore();

  const [provider, setProvider] = useState<ProviderType>("subsonic");
  const [url, setUrl] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void loadSettings();
  }, [loadSettings]);

  return (
    <section className="page-card">
      <h2 style={{ marginTop: 0 }}>Settings</h2>
      <h3>Server Connection</h3>
      <div style={{ display: "grid", gap: 8, maxWidth: 520 }}>
        <select value={provider} onChange={(event) => setProvider(event.currentTarget.value as ProviderType)}>
          <option value="subsonic">Subsonic</option>
          <option value="jellyfin">Jellyfin</option>
          <option value="plex">Plex</option>
          <option value="local">Local</option>
        </select>
        <input value={url} onChange={(event) => setUrl(event.currentTarget.value)} placeholder="Server URL" />
        <input value={username} onChange={(event) => setUsername(event.currentTarget.value)} placeholder="Username" />
        <input
          type="password"
          value={password}
          onChange={(event) => setPassword(event.currentTarget.value)}
          placeholder="Password / Token"
        />
        <div style={{ display: "flex", gap: 8 }}>
          <button
            type="button"
            onClick={() => {
              setError(null);
              void connect(provider, url, username, password).catch((err: unknown) =>
                setError(err instanceof Error ? err.message : "Connection failed"),
              );
            }}
          >
            Connect
          </button>
          <button type="button" disabled={!session} onClick={() => void disconnect()}>
            Disconnect
          </button>
        </div>
      </div>
      <p>Active session: {session ? `${session.provider} (${session.id})` : "none"}</p>
      {error ? <p style={{ color: "#ff9f9f" }}>{error}</p> : null}
      <h3>Playback Preferences</h3>
      <div style={{ display: "grid", gap: 8, maxWidth: 520 }}>
        <select
          value={settings.theme}
          onChange={(event) => void saveSettings({ ...settings, theme: event.currentTarget.value as typeof settings.theme })}
        >
          <option value="dark">Dark</option>
          <option value="light">Light</option>
          <option value="system">System</option>
        </select>
        <label>
          Accent color
          <input
            type="color"
            value={settings.accentColor}
            onChange={(event) => void saveSettings({ ...settings, accentColor: event.currentTarget.value })}
          />
        </label>
        <label>
          Crossfade seconds
          <input
            type="number"
            min={0}
            max={12}
            value={settings.crossfadeSeconds}
            onChange={(event) =>
              void saveSettings({
                ...settings,
                crossfadeSeconds: Number(event.currentTarget.value) || 0,
              })
            }
          />
        </label>
      </div>
    </section>
  );
}
