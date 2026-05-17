"use client";

import React, { useState } from 'react';
import Link from 'next/link';
import SiteHeader from '@/components/SiteHeader';

export default function BirthRegisterPage() {
  const [currentStep, setCurrentStep] = useState(0);
  const totalSteps = 5;

  const [formData, setFormData] = useState({
    declType: 'direct',
    declDate: '',
    declNumber: '',
    declarantName: '',
    declarantCin: '',
    declarantRelation: '',
    motherFname: '',
    motherLname: '',
    motherDob: '',
    motherCin: '',
    fatherFname: '',
    fatherLname: '',
    fatherDob: '',
    fatherCin: '',
    newbornFname: '',
    gender: '',
    newbornDob: '',
    newbornBirthplace: '',
  });

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value, type } = e.target;
    if (type === 'radio' || type === 'checkbox') {
      const checked = (e.target as HTMLInputElement).checked;
      if (checked) {
        setFormData((prev) => ({ ...prev, [name]: value }));
      }
    } else {
      setFormData((prev) => ({ ...prev, [name]: value }));
    }
  };

  const handleNext = () => {
    if (currentStep < totalSteps - 1) {
      setCurrentStep((prev) => prev + 1);
      window.scrollTo({ top: 0, behavior: 'smooth' });
    } else {
      alert("تم حفظ التصريح بنجاح!");
    }
  };

  const handlePrev = () => {
    if (currentStep > 0) {
      setCurrentStep((prev) => prev - 1);
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
  };

  const steps = [
    "معلومات عن الأب",
    "معلومات عن الأم",
    "معلومات عن المولود(ة)",
    "نسخ الوثائق المدعمة",
    "خلاصة وتأكيد"
  ];

  return (
    <div className="app-shell" dir="rtl">
      <SiteHeader />

      <main className="main-content">
        <Link href="/" className="back-link">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M9 18l6-6-6-6" />
          </svg>
          العودة إلى القائمة الرئيسية
        </Link>

        {/* STEPPER */}
        <nav className="stepper" aria-label="خطوات التسجيل">
          {steps.map((label, index) => {
            let stepClass = "stepper__step--inactive";
            if (index < currentStep) stepClass = "stepper__step--completed";
            else if (index === currentStep) stepClass = "stepper__step--active";
            else if (index === currentStep + 1) stepClass = "stepper__step--next";

            return (
              <article key={index} className={`stepper__step ${stepClass}`}>
                <span className="stepper__indicator">
                  <span className="stepper__number">{index + 1}</span>
                  <svg className="stepper__check" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M3 8.5l3.5 3.5 6.5-7" />
                  </svg>
                </span>
                <span className="stepper__label">{label}</span>
              </article>
            );
          })}
        </nav>

        {/* STEP 0: Father Info */}
        <section className="form-step" hidden={currentStep !== 0}>
          <fieldset className="form-panel">
            <legend className="form-panel__legend">معلومات عن الأب</legend>

            <article className="unknown-toggle">
              <label className="form-check">
                <input type="checkbox" id="unknown-father" />
                <span className="form-check__label">مجهول الأب</span>
              </label>
            </article>

            <article className="form-row">
              <label className="form-label" htmlFor="fatherFname">الاسم الشخصي</label>
              <input type="text" className="form-input form-input--with-keyboard" name="fatherFname" id="fatherFname" style={{ maxWidth: '300px' }} value={formData.fatherFname} onChange={handleInputChange} required />
              <span className="form-label--fr">Prenom</span>
            </article>

            <article className="form-row">
              <label className="form-label" htmlFor="fatherLname">الاسم العائلي</label>
              <input type="text" className="form-input form-input--with-keyboard" name="fatherLname" id="fatherLname" style={{ maxWidth: '300px' }} value={formData.fatherLname} onChange={handleInputChange} required />
              <span className="form-label--fr">Nom</span>
            </article>

            <article className="form-row">
              <label className="form-label" htmlFor="fatherDob">تاريخ الازدياد</label>
              <input type="date" className="form-input" name="fatherDob" id="fatherDob" style={{ maxWidth: '300px' }} value={formData.fatherDob} onChange={handleInputChange} required />
              <span className="form-label--fr">Date de naissance</span>
            </article>

            <article className="form-row">
              <label className="form-label" htmlFor="fatherCin">رقم بطاقة التعريف</label>
              <input type="text" className="form-input" name="fatherCin" id="fatherCin" style={{ maxWidth: '250px' }} value={formData.fatherCin} onChange={handleInputChange} />
              <span className="form-label--fr">CIN</span>
            </article>
          </fieldset>
        </section>

        {/* STEP 1: Mother Info */}
        <section className="form-step" hidden={currentStep !== 1}>
          <fieldset className="form-panel">
            <legend className="form-panel__legend">معلومات عن الأم</legend>

            <article className="form-row">
              <label className="form-label" htmlFor="motherFname">الاسم الشخصي</label>
              <input type="text" className="form-input form-input--with-keyboard" name="motherFname" id="motherFname" style={{ maxWidth: '300px' }} value={formData.motherFname} onChange={handleInputChange} required />
              <span className="form-label--fr">Prenom</span>
            </article>

            <article className="form-row">
              <label className="form-label" htmlFor="motherLname">الاسم العائلي</label>
              <input type="text" className="form-input form-input--with-keyboard" name="motherLname" id="motherLname" style={{ maxWidth: '300px' }} value={formData.motherLname} onChange={handleInputChange} required />
              <span className="form-label--fr">Nom</span>
            </article>

            <article className="form-row">
              <label className="form-label" htmlFor="motherDob">تاريخ الازدياد</label>
              <input type="date" className="form-input" name="motherDob" id="motherDob" style={{ maxWidth: '300px' }} value={formData.motherDob} onChange={handleInputChange} required />
              <span className="form-label--fr">Date de naissance</span>
            </article>

            <article className="form-row">
              <label className="form-label" htmlFor="motherCin">رقم بطاقة التعريف</label>
              <input type="text" className="form-input" name="motherCin" id="motherCin" style={{ maxWidth: '250px' }} value={formData.motherCin} onChange={handleInputChange} />
              <span className="form-label--fr">CIN</span>
            </article>

            <article className="form-row">
              <label className="form-label">عنوان الإقامة</label>
              <input type="text" className="form-input form-input--with-keyboard" style={{ maxWidth: '400px' }} />
              <span className="form-label--fr">Adresse</span>
            </article>
          </fieldset>
        </section>

        {/* STEP 2: Newborn Info */}
        <section className="form-step" hidden={currentStep !== 2}>
          <fieldset className="form-panel">
            <legend className="form-panel__legend">معلومات عن المولود(ة)</legend>

            <article className="form-row">
              <label className="form-label" htmlFor="newbornFname">الاسم الشخصي</label>
              <input type="text" className="form-input form-input--with-keyboard" name="newbornFname" id="newbornFname" style={{ maxWidth: '300px' }} value={formData.newbornFname} onChange={handleInputChange} required />
              <span className="form-label--fr">Prenom</span>
            </article>

            <article className="form-row">
              <label className="form-label">الجنس</label>
              <article style={{ display: 'flex', gap: '24px' }}>
                <label className="form-check">
                  <input type="radio" name="gender" value="ذكر" checked={formData.gender === 'ذكر'} onChange={handleInputChange} />
                  <span className="form-check__label">ذكر</span>
                </label>
                <label className="form-check">
                  <input type="radio" name="gender" value="أنثى" checked={formData.gender === 'أنثى'} onChange={handleInputChange} />
                  <span className="form-check__label">أنثى</span>
                </label>
              </article>
            </article>

            <article className="form-row">
              <label className="form-label" htmlFor="newbornDob">تاريخ الولادة</label>
              <input type="date" className="form-input" name="newbornDob" id="newbornDob" style={{ maxWidth: '300px' }} value={formData.newbornDob} onChange={handleInputChange} required />
            </article>

            <article className="form-row">
              <label className="form-label" htmlFor="newbornBirthplace">مكان الولادة</label>
              <input type="text" className="form-input form-input--with-keyboard" name="newbornBirthplace" id="newbornBirthplace" style={{ maxWidth: '400px' }} value={formData.newbornBirthplace} onChange={handleInputChange} required />
              <span className="form-label--fr">Lieu de naissance</span>
            </article>
          </fieldset>
        </section>

        {/* STEP 3: Documents */}
        <section className="form-step" hidden={currentStep !== 3}>
          <fieldset className="form-panel">
            <legend className="form-panel__legend">نسخ الوثائق المدعمة</legend>
            <article className="upload-controls">
              <article className="upload-controls__field">
                <label className="form-label">نوع الوثيقة</label>
                <select className="form-select" id="upload-doc-type" style={{ minWidth: '220px' }}>
                  <option value="">-- اختر نوع الوثيقة --</option>
                  <option value="شهادة طبية">شهادة طبية</option>
                  <option value="بطاقة التعريف">بطاقة التعريف</option>
                  <option value="عقد الزواج">عقد الزواج</option>
                </select>
              </article>
              <article className="upload-controls__field">
                <label className="form-label">تحميل صورة الوثيقة</label>
                <input type="file" className="form-input" id="upload-doc-file" accept="image/*" />
              </article>
              <button type="button" className="btn btn--primary" id="upload-doc-btn">تحميل صورة الوثيقة</button>
            </article>
            <article className="doc-gallery" id="doc-gallery-container"></article>
          </fieldset>
        </section>

        {/* STEP 4: Summary */}
        <section className="form-step" hidden={currentStep !== 4}>
          <section className="review-accordion review-accordion--open">
            <button className="review-accordion__header">
              <span className="review-accordion__icon">-</span>
              <span className="review-accordion__title">معلومات عن المولود(ة)</span>
            </button>
            <article className="review-accordion__body" style={{ display: 'block' }}>
              <article className="review-row">
                <span className="review-row__label-fr">Prenom</span>
                <span className="review-row__value">{formData.newbornFname || '---'}</span>
                <span className="review-row__label-ar">الاسم الشخصي</span>
              </article>
              <article className="review-row">
                <span className="review-row__label-fr">Sexe</span>
                <span className="review-row__value">{formData.gender || '---'}</span>
                <span className="review-row__label-ar">الجنس</span>
              </article>
            </article>
          </section>
        </section>

        {/* FORM NAVIGATION */}
        <nav className="form-nav">
          <button className="btn btn--outline" onClick={handlePrev} disabled={currentStep === 0}>السابق</button>
          <button className="btn btn--primary" onClick={handleNext}>{currentStep === totalSteps - 1 ? 'تأكيد وإرسال' : 'التالي'}</button>
        </nav>
      </main>
    </div>
  );
}
