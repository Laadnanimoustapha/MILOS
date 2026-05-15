import Link from "next/link";
import SiteHeader from "@/components/SiteHeader";

export default function HomePage() {
  return (
    <section className="app-shell">
      <SiteHeader />
      <main className="main-content">
        <section className="search-page-title">
          <h2 className="search-page-title__heading">البحث في السجلات</h2>
          <p className="search-page-title__desc">
            اختر نوع السجل للبحث والإطلاع
          </p>
          <hr className="search-page-title__divider" />
        </section>

        <nav className="home-nav">
          <Link href="/birth-search" className="home-nav__card">
            <article className="home-nav__icon-wrap">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" width={28} height={28}>
                <circle cx="12" cy="8" r="3.5" />
                <path d="M6.5 20v-1.5a5.5 5.5 0 0 1 11 0V20" />
                <path d="M15.5 8a2.5 2.5 0 0 1 2.5 2.5" />
                <path d="M18 14.5a4 4 0 0 1 2 3.5v2" />
              </svg>
            </article>
            <article className="home-nav__text">
              <h3 className="home-nav__title">تصفح تصاريح الولادة</h3>
              <p className="home-nav__desc">البحث في سجلات الولادة</p>
            </article>
            <svg className="home-nav__chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width={20} height={20}>
              <path d="M15 18l-6-6 6-6" />
            </svg>
          </Link>

          <Link href="/death-search" className="home-nav__card">
            <article className="home-nav__icon-wrap">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" width={28} height={28}>
                <path d="M8 21V9a4 4 0 0 1 8 0v12" />
                <path d="M5.5 21h13" />
                <path d="M8 17h8" />
              </svg>
            </article>
            <article className="home-nav__text">
              <h3 className="home-nav__title">بحث و إطلاع للوفيات</h3>
              <p className="home-nav__desc">البحث في سجلات الوفيات</p>
            </article>
            <svg className="home-nav__chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width={20} height={20}>
              <path d="M15 18l-6-6 6-6" />
            </svg>
          </Link>
        </nav>
      </main>
    </section>
  );
}
