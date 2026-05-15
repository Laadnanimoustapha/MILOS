"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import Image from "next/image";

export default function SiteHeader() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    function handleScroll() {
      setScrolled(window.scrollY > 10);
    }
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <header className={`site-header${scrolled ? " is-scrolled" : ""}`}>
      <nav className="header__brand">
        <Image
          src="/logo.png"
          alt="شعار النظام"
          className="header__logo"
          width={48}
          height={48}
          aria-hidden="true"
        />
        <article className="header__title-block">
          <h1 className="header__title">نظام تدبير سجلات الحالة المدنية</h1>
          <p className="header__subtitle">المملكة المغربية - وزارة الداخلية</p>
        </article>
      </nav>
      <nav className="header__actions" aria-label="إجراءات النظام">
        <Link href="/" className="header__action-btn" title="القائمة الرئيسية" aria-label="القائمة الرئيسية">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width={22} height={22} aria-hidden="true">
            <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
            <polyline points="9 22 9 12 15 12 15 22" />
          </svg>
        </Link>
      </nav>
    </header>
  );
}
