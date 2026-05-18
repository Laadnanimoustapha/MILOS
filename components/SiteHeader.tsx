"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";

export default function SiteHeader() {
  const router = useRouter();
  const [userRole, setUserRole] = useState<string | null>(null);
  const [scrolled, setScrolled] = useState(false);

  // Authentication and role handling
  useEffect(() => {
    const isLoggedIn = sessionStorage.getItem("dilona_logged_in");
    if (!isLoggedIn) {
      router.replace("/login");
      return;
    }
    const role = sessionStorage.getItem("dilona_user_role");
    setUserRole(role);
  }, [router]);

  // Scroll effect for header styling
  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 10);
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  const handleLogout = () => {
    sessionStorage.removeItem("dilona_logged_in");
    sessionStorage.removeItem("dilona_user_role");
    router.replace("/login");
  };

  return (
    <header className={`site-header${scrolled ? " is-scrolled" : ""}`}>
      <nav className="header__brand">
        <Image src="/logo.png" alt="شعار النظام" className="header__logo" width={48} height={48} aria-hidden="true" />
        <article className="header__title-block">
          <h1 className="header__title">نظام تدبير سجلات الحالة المدنية</h1>
          <p className="header__subtitle">المملكة المغربية - وزارة الداخلية</p>
          {userRole && <p className="header__role">{userRole}</p>}
        </article>
      </nav>
      <nav className="header__actions" aria-label="إجراءات النظام">
        <button
          type="button"
          className="header__action-btn"
          title="تسجيل الخروج"
          aria-label="تسجيل الخروج"
          onClick={handleLogout}
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width={22} height={22} aria-hidden="true">
            <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
            <polyline points="16 17 21 12 16 7" />
            <line x1="21" y1="12" x2="9" y2="12" />
          </svg>
        </button>
      </nav>
    </header>
  );
}
