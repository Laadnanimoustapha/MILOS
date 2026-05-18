"use client";

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import SiteHeader from '@/components/SiteHeader';

export default function DeathRegisterPage() {
  const [currentStep, setCurrentStep] = useState(0);
  const totalSteps = 7;
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitResult, setSubmitResult] = useState<{ success: boolean; pdf_url?: string; error?: string } | null>(null);

  // Proactively wake up the sleeping HuggingFace Space backend in the background on mount
  useEffect(() => {
    fetch("https://dfifa-stage-backend.hf.space/", { mode: "no-cors" })
      .then(() => console.log("[HF Wakeup] Pinged HuggingFace Space successfully to wake it up."))
      .catch((err) => console.warn("[HF Wakeup] Sleep wake-up ping error:", err));
  }, []);

  const [formData, setFormData] = useState({
    dtype: 'direct',
    declDate: '',
    certNumber: '',
    deceasedFname: '',
    deceasedLname: '',
    dgender: '',
    deathDate: '',
    deathPlace: '',
    fatherFname: '',
    fatherLname: '',
    motherFname: '',
    motherLname: '',
    causeDeath: '',
    declarantName: '',
    declarantCin: '',
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

  const handleSubmit = async () => {
    setIsSubmitting(true);
    setSubmitResult(null);
    try {
      const response = await fetch('/api/death-register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData),
      });
      const data = await response.json();
      setSubmitResult(data);
    } catch {
      setSubmitResult({ success: false, error: 'فشل الاتصال بالخادم' });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleNext = () => {
    if (currentStep < totalSteps - 1) {
      setCurrentStep((prev) => prev + 1);
      window.scrollTo({ top: 0, behavior: 'smooth' });
    } else {
      handleSubmit();
    }
  };

  const handlePrev = () => {
    if (currentStep > 0) {
      setCurrentStep((prev) => prev - 1);
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
  };

  const steps = [
    "بيانات شهادة الوفاة",
    "بيانات المتوفى",
    "بيانات الأب",
    "بيانات الأم",
    "معلومات عامة",
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

        {/* STEP 0: Death Certificate Data */}
        <section className="form-step" hidden={currentStep !== 0}>
          <fieldset className="form-panel">
            <legend className="form-panel__legend">بيانات شهادة الوفاة</legend>
            <article className="alert-box alert-box--danger">
              تنبيه: يرجى التأكد من إدخال رقم شهادة الوفاة بالصيغة الصحيحة وفقا للنظام المعتمد.
            </article>

            <article className="form-row">
              <label className="form-label">نوع التصريح</label>
              <article style={{ display: 'flex', gap: '24px' }}>
                <label className="form-check">
                  <input type="radio" name="dtype" value="direct" checked={formData.dtype === 'direct'} onChange={handleInputChange} />
                  <span className="form-check__label">مباشر</span>
                </label>
                <label className="form-check">
                  <input type="radio" name="dtype" value="court" checked={formData.dtype === 'court'} onChange={handleInputChange} />
                  <span className="form-check__label">حكم من المحكمة</span>
                </label>
              </article>
            </article>

            <article className="form-row">
              <label className="form-label" htmlFor="declDate">تاريخ التصريح</label>
              <input type="date" className="form-input" name="declDate" id="declDate" style={{ maxWidth: '300px' }} value={formData.declDate} onChange={handleInputChange} required />
            </article>

            <article className="form-row">
              <label className="form-label" htmlFor="certNumber">رقم شهادة الوفاة</label>
              <input type="text" className="form-input form-input--with-keyboard" name="certNumber" id="certNumber" style={{ maxWidth: '300px' }} value={formData.certNumber} onChange={handleInputChange} required />
            </article>
          </fieldset>
        </section>

        {/* STEP 1: Deceased Data */}
        <section className="form-step" hidden={currentStep !== 1}>
          <fieldset className="form-panel">
            <legend className="form-panel__legend">بيانات المتوفى</legend>
            <article className="unknown-toggle">
              <label className="form-check">
                <input type="checkbox" id="unknown-deceased" />
                <span className="form-check__label">مجهول الهوية</span>
              </label>
            </article>

            <article className="form-row">
              <label className="form-label" htmlFor="deceasedFname">الاسم الشخصي</label>
              <input type="text" className="form-input form-input--with-keyboard" name="deceasedFname" id="deceasedFname" style={{ maxWidth: '300px' }} value={formData.deceasedFname} onChange={handleInputChange} required />
              <span className="form-label--fr">Prenom</span>
            </article>

            <article className="form-row">
              <label className="form-label" htmlFor="deceasedLname">الاسم العائلي</label>
              <input type="text" className="form-input form-input--with-keyboard" name="deceasedLname" id="deceasedLname" style={{ maxWidth: '300px' }} value={formData.deceasedLname} onChange={handleInputChange} required />
              <span className="form-label--fr">Nom</span>
            </article>

            <article className="form-row">
              <label className="form-label">الجنس</label>
              <article style={{ display: 'flex', gap: '24px' }}>
                <label className="form-check">
                  <input type="radio" name="dgender" value="ذكر" checked={formData.dgender === 'ذكر'} onChange={handleInputChange} />
                  <span className="form-check__label">ذكر</span>
                </label>
                <label className="form-check">
                  <input type="radio" name="dgender" value="أنثى" checked={formData.dgender === 'أنثى'} onChange={handleInputChange} />
                  <span className="form-check__label">أنثى</span>
                </label>
              </article>
            </article>

            <article className="form-row">
              <label className="form-label" htmlFor="deathDate">تاريخ الوفاة</label>
              <input type="date" className="form-input" name="deathDate" id="deathDate" style={{ maxWidth: '300px' }} value={formData.deathDate} onChange={handleInputChange} required />
            </article>

            <article className="form-row">
              <label className="form-label" htmlFor="deathPlace">مكان الوفاة</label>
              <input type="text" className="form-input form-input--with-keyboard" name="deathPlace" id="deathPlace" style={{ maxWidth: '400px' }} value={formData.deathPlace} onChange={handleInputChange} required />
              <span className="form-label--fr">Lieu de deces</span>
            </article>
          </fieldset>
        </section>

        {/* STEP 2: Father Data */}
        <section className="form-step" hidden={currentStep !== 2}>
          <fieldset className="form-panel">
            <legend className="form-panel__legend">بيانات الأب</legend>
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
          </fieldset>
        </section>

        {/* STEP 3: Mother Data */}
        <section className="form-step" hidden={currentStep !== 3}>
          <fieldset className="form-panel">
            <legend className="form-panel__legend">بيانات الأم</legend>
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
          </fieldset>
        </section>

        {/* STEP 4: General Info */}
        <section className="form-step" hidden={currentStep !== 4}>
          <fieldset className="form-panel">
            <legend className="form-panel__legend">معلومات عامة</legend>
            <article className="form-row">
              <label className="form-label" htmlFor="causeDeath">سبب الوفاة</label>
              <select className="form-select" name="causeDeath" id="causeDeath" style={{ maxWidth: '300px' }} value={formData.causeDeath} onChange={handleInputChange} required>
                <option value="">-- اختر --</option>
                <option value="سكتة قلبية">سكتة قلبية</option>
                <option value="أسباب طبيعية">أسباب طبيعية</option>
                <option value="حادث سير">حادث سير</option>
                <option value="غير محدد">غير محدد</option>
              </select>
            </article>
            <article className="form-row">
              <label className="form-label" htmlFor="declarantName">اسم المصرح</label>
              <input type="text" className="form-input form-input--with-keyboard" name="declarantName" id="declarantName" style={{ maxWidth: '400px' }} value={formData.declarantName} onChange={handleInputChange} required />
            </article>
            <article className="form-row">
              <label className="form-label" htmlFor="declarantCin">رقم بطاقة التعريف</label>
              <input type="text" className="form-input" name="declarantCin" id="declarantCin" style={{ maxWidth: '250px' }} value={formData.declarantCin} onChange={handleInputChange} required />
            </article>
          </fieldset>
        </section>

        {/* STEP 5: Documents */}
        <section className="form-step" hidden={currentStep !== 5}>
          <fieldset className="form-panel">
            <legend className="form-panel__legend">نسخ الوثائق المدعمة</legend>
            <article className="upload-controls">
              <article className="upload-controls__field">
                <label className="form-label">نوع الوثيقة</label>
                <select className="form-select" id="upload-doc-type" style={{ minWidth: '220px' }}>
                  <option value="">-- اختر --</option>
                  <option value="شهادة الوفاة">شهادة الوفاة</option>
                  <option value="بطاقة التعريف">بطاقة التعريف</option>
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

        {/* STEP 6: Summary */}
        <section className="form-step" hidden={currentStep !== 6}>
          <section className="review-accordion review-accordion--open">
            <button className="review-accordion__header">
              <span className="review-accordion__icon">-</span>
              <span className="review-accordion__title">بيانات شهادة الوفاة</span>
            </button>
            <article className="review-accordion__body" style={{ display: 'block' }}>
              <article className="review-row">
                <span className="review-row__label-fr">Date de declaration</span>
                <span className="review-row__value">{formData.declDate || '---'}</span>
                <span className="review-row__label-ar">تاريخ التصريح</span>
              </article>
              <article className="review-row">
                <span className="review-row__label-fr">Type</span>
                <span className="review-row__value">{formData.dtype === 'direct' ? 'مباشر' : 'حكم من المحكمة'}</span>
                <span className="review-row__label-ar">نوع التصريح</span>
              </article>
              <article className="review-row">
                <span className="review-row__label-fr">N de certificat</span>
                <span className="review-row__value">{formData.certNumber || '---'}</span>
                <span className="review-row__label-ar">رقم شهادة الوفاة</span>
              </article>
            </article>
          </section>

          <section className="review-accordion review-accordion--open">
            <button className="review-accordion__header">
              <span className="review-accordion__icon">-</span>
              <span className="review-accordion__title">بيانات المتوفى</span>
            </button>
            <article className="review-accordion__body" style={{ display: 'block' }}>
              <article className="review-row">
                <span className="review-row__label-fr">Prenom</span>
                <span className="review-row__value">{formData.deceasedFname || '---'}</span>
                <span className="review-row__label-ar">الاسم الشخصي</span>
              </article>
              <article className="review-row">
                <span className="review-row__label-fr">Nom</span>
                <span className="review-row__value">{formData.deceasedLname || '---'}</span>
                <span className="review-row__label-ar">الاسم العائلي</span>
              </article>
              <article className="review-row">
                <span className="review-row__label-fr">Sexe</span>
                <span className="review-row__value">{formData.dgender || '---'}</span>
                <span className="review-row__label-ar">الجنس</span>
              </article>
              <article className="review-row">
                <span className="review-row__label-fr">Date de deces</span>
                <span className="review-row__value">{formData.deathDate || '---'}</span>
                <span className="review-row__label-ar">تاريخ الوفاة</span>
              </article>
            </article>
          </section>
        </section>

        {/* SUBMISSION RESULT */}
        {submitResult && (
          <section className="form-panel" style={{ marginTop: '16px' }}>
            {submitResult.success ? (
              <article className="alert-box alert-box--success" style={{ background: 'var(--color-surface)', border: '1px solid #2d6a4f', padding: '20px', borderRadius: '8px' }}>
                <p style={{ fontWeight: 700, fontSize: '1.1rem', marginBottom: '8px' }}>تم حفظ التصريح بنجاح</p>
                {submitResult.pdf_url && (
                  <a href={submitResult.pdf_url} target="_blank" rel="noopener noreferrer" className="btn btn--primary" style={{ display: 'inline-block', marginTop: '8px' }}>
                    تحميل الوثيقة PDF
                  </a>
                )}
              </article>
            ) : (
              <article className="alert-box alert-box--danger" style={{ padding: '16px', borderRadius: '8px' }}>
                <p>{submitResult.error || 'حدث خطأ غير متوقع'}</p>
              </article>
            )}
          </section>
        )}

        {/* FORM NAVIGATION */}
        <nav className="form-nav">
          <button className="btn btn--outline" onClick={handlePrev} disabled={currentStep === 0 || isSubmitting}>السابق</button>
          <button className="btn btn--primary" onClick={handleNext} disabled={isSubmitting}>
            {isSubmitting ? 'جاري الإرسال...' : (currentStep === totalSteps - 1 ? 'تأكيد وإرسال' : 'التالي')}
          </button>
        </nav>
      </main>
    </div>
  );
}
