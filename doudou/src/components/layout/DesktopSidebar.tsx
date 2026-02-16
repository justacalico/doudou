import { Disc3, Download, FolderOpen, Home, Search, Settings, Users } from "lucide-react";
import { NavLink } from "react-router-dom";

const navItems = [
  { to: "/", label: "Home", icon: Home },
  { to: "/albums", label: "Albums", icon: Disc3 },
  { to: "/artists", label: "Artists", icon: Users },
  { to: "/playlists", label: "Playlists", icon: Disc3 },
  { to: "/downloads", label: "Downloads", icon: Download },
  { to: "/local-files", label: "Local Files", icon: FolderOpen },
  { to: "/search", label: "Search", icon: Search },
  { to: "/settings", label: "Settings", icon: Settings },
];

export function DesktopSidebar() {
  return (
    <aside className="sidebar">
      <h1>Doudou</h1>
      <div className="status-chip">Rust network boundary enabled</div>
      <nav className="nav-group" style={{ marginTop: 12 }}>
        {navItems.map((item) => {
          const Icon = item.icon;
          return (
            <NavLink key={item.to} className="nav-link" to={item.to}>
              <span style={{ display: "inline-flex", alignItems: "center", gap: 8 }}>
                <Icon size={16} />
                {item.label}
              </span>
            </NavLink>
          );
        })}
      </nav>
    </aside>
  );
}
