"use client";

import React, { useState } from 'react';
import Link from 'next/link';
import SiteHeader from '@/components/SiteHeader';

export default function HomePage() {
  const [expanded, setExpanded] = useState<'birth' | 'death' | null>(null);

  const toggleAccordion = (panel: 'birth' | 'death') => {
    setExpanded(prev => (prev === panel ? null : panel));
  };

  return (
    <section className="app-shell" dir="rtl">
      <SiteHeader />
      <main className="main-content">
        <section className="search-page-title">
          <h2 className="search-page-title__heading">القائمة الرئيسية</h2>
          <p className="search-page-title__desc">
            اختر الخدمة المطلوبة من الخيارات أسفله
          </p>
          <hr className="search-page-title__divider" />
        </section>

        <nav className="dashboard-grid" role="navigation" aria-label="الخدمات الرئيسية">
          
          {/* Card 1: Death Declarations (Right side conceptually, but it's flex so order depends on DOM) */}
          <section className="dashboard-card">
            <button 
              className="card__header" 
              type="button" 
              aria-expanded={expanded === 'death'} 
              aria-controls="panel-death" 
              id="card-death"
              onClick={() => toggleAccordion('death')}
            >
              <span className="card__icon-wrap" aria-hidden="true">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M8 21V9a4 4 0 0 1 8 0v12" />
                  <path d="M5.5 21h13" />
                  <path d="M8 17h8" />
                </svg>
              </span>
              <article className="card__title-group">
                <h3 className="card__title">تدبير تصاريح الوفيات</h3>
                <p className="card__desc">تسجيل ومراقبة ومصادقة تصاريح الوفيات</p>
              </article>
              <svg className="card__chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M15 18l-6-6 6-6" />
              </svg>
            </button>
            <article className="card__panel" id="panel-death" role="region" aria-labelledby="card-death" aria-hidden={expanded !== 'death'}>
              <div className="card__panel-inner">
                <ul>
                  <li><Link className="submenu__link" href="/death-register">تسجيل التصريح بالوفاة</Link></li>
                  <li><Link className="submenu__link" href="/death-search">بحث و إطلاع للوفيات</Link></li>
                </ul>
              </div>
            </article>
          </section>

          {/* Card 2: Birth Declarations */}
          <section className="dashboard-card">
            <button 
              className="card__header" 
              type="button" 
              aria-expanded={expanded === 'birth'} 
              aria-controls="panel-birth" 
              id="card-birth"
              onClick={() => toggleAccordion('birth')}
            >
              <span className="card__icon-wrap" aria-hidden="true">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="8" r="3.5" />
                  <path d="M6.5 20v-1.5a5.5 5.5 0 0 1 11 0V20" />
                  <path d="M15.5 8a2.5 2.5 0 0 1 2.5 2.5" />
                  <path d="M18 14.5a4 4 0 0 1 2 3.5v2" />
                </svg>
              </span>
              <article className="card__title-group">
                <h3 className="card__title">تدبير تصاريح الولادة</h3>
                <p className="card__desc">تسجيل ومراقبة ومصادقة تصاريح الولادة</p>
              </article>
              <svg className="card__chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M15 18l-6-6 6-6" />
              </svg>
            </button>
            <article className="card__panel" id="panel-birth" role="region" aria-labelledby="card-birth" aria-hidden={expanded !== 'birth'}>
              <div className="card__panel-inner">
                <ul>
                  <li><Link className="submenu__link" href="/birth-register">تسجيل التصريح بالولادة</Link></li>
                  <li><Link className="submenu__link" href="/birth-search">تصفح تصاريح الولادة</Link></li>
                </ul>
              </div>
            </article>
          </section>

        </nav>
      </main>
    </section>
  );
}
