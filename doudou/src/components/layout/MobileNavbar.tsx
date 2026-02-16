import { Download, Home, Library, Search, Settings } from "lucide-react";
import { NavLink } from "react-router-dom";

const navItems = [
  { to: "/", label: "Home", icon: Home },
  { to: "/albums", label: "Library", icon: Library },
  { to: "/search", label: "Search", icon: Search },
  { to: "/downloads", label: "Downloads", icon: Download },
  { to: "/settings", label: "Settings", icon: Settings },
];

export function MobileNavbar() {
  return (
    <nav className="mobile-nav">
      {navItems.map((item) => {
        const Icon = item.icon;
        return (
          <NavLink key={item.to} to={item.to} className="nav-link">
            <span style={{ display: "inline-flex", alignItems: "center", gap: 6 }}>
              <Icon size={16} />
              {item.label}
            </span>
          </NavLink>
        );
      })}
    </nav>
  );
}
