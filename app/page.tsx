import Link from "next/link";
import SiteHeader from "@/components/SiteHeader";

export default function HomePage() {
  return (
    <section className="app-shell" dir="rtl">
      <SiteHeader />
      <main className="main-content">
        <section className="search-page-title">
          <h2 className="search-page-title__heading">القائمة الرئيسية</h2>
          <p className="search-page-title__desc">
            اختر الإجراء المطلوب
          </p>
          <hr className="search-page-title__divider" />
        </section>

        <nav className="home-nav" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-md)' }}>
          {/* SEARCH CARDS */}
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
              <h3 className="home-nav__title">البحث في تصاريح الولادة</h3>
              <p className="home-nav__desc">البحث والإطلاع على السجلات</p>
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
              <h3 className="home-nav__title">البحث في تصاريح الوفاة</h3>
              <p className="home-nav__desc">البحث والإطلاع على السجلات</p>
            </article>
            <svg className="home-nav__chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width={20} height={20}>
              <path d="M15 18l-6-6 6-6" />
            </svg>
          </Link>

          {/* REGISTER CARDS */}
          <Link href="/birth-register" className="home-nav__card">
            <article className="home-nav__icon-wrap" style={{ color: 'var(--clr-accent-orange)' }}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" width={28} height={28}>
                <path d="M12 5v14" />
                <path d="M5 12h14" />
              </svg>
            </article>
            <article className="home-nav__text">
              <h3 className="home-nav__title">تسجيل تصريح بولادة</h3>
              <p className="home-nav__desc">إضافة تصريح ولادة جديد</p>
            </article>
            <svg className="home-nav__chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width={20} height={20}>
              <path d="M15 18l-6-6 6-6" />
            </svg>
          </Link>

          <Link href="/death-register" className="home-nav__card">
            <article className="home-nav__icon-wrap" style={{ color: 'var(--clr-accent-orange)' }}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" width={28} height={28}>
                <path d="M12 5v14" />
                <path d="M5 12h14" />
              </svg>
            </article>
            <article className="home-nav__text">
              <h3 className="home-nav__title">تسجيل تصريح بوفاة</h3>
              <p className="home-nav__desc">إضافة تصريح وفاة جديد</p>
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
