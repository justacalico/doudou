import { Outlet } from "react-router-dom";
import { MiniPlayer } from "../player/MiniPlayer";
import { DesktopSidebar } from "./DesktopSidebar";
import { MobileNavbar } from "./MobileNavbar";

interface ResponsiveLayoutProps {
  isMobile: boolean;
}

export function ResponsiveLayout({ isMobile }: ResponsiveLayoutProps) {
  if (isMobile) {
    return (
      <div className="mobile-shell">
        <main className="content-shell">
          <Outlet />
        </main>
        <MiniPlayer compact />
        <MobileNavbar />
      </div>
    );
  }

  return (
    <div className="app-shell">
      <div className="desktop-shell">
        <DesktopSidebar />
        <main className="content-shell">
          <Outlet />
        </main>
      </div>
      <MiniPlayer />
    </div>
  );
}
