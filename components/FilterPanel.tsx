"use client";

import { useState, useCallback } from "react";
import type { SearchFilters } from "@/lib/types";
import { OFFICE_MAP } from "@/lib/types";

interface FilterPanelProps {
  filters: SearchFilters;
  onFilterChange: (filters: SearchFilters) => void;
}

export default function FilterPanel({ filters, onFilterChange }: FilterPanelProps) {
  const [isOpen, setIsOpen] = useState(false);

  const updateFilter = useCallback(
    (key: keyof SearchFilters, value: string) => {
      onFilterChange({ ...filters, [key]: value });
    },
    [filters, onFilterChange]
  );

  const clearFilter = useCallback(
    (key: keyof SearchFilters) => {
      onFilterChange({ ...filters, [key]: "" });
    },
    [filters, onFilterChange]
  );

  const activeFilters: { label: string; key: keyof SearchFilters }[] = [];

  if (filters.sex) {
    activeFilters.push({
      label: `الجنس: ${filters.sex === "male" ? "ذكر" : "أنثى"}`,
      key: "sex",
    });
  }
  if (filters.father) {
    activeFilters.push({ label: `الأب: ${filters.father}`, key: "father" });
  }
  if (filters.mother) {
    activeFilters.push({ label: `الأم: ${filters.mother}`, key: "mother" });
  }
  if (filters.office) {
    activeFilters.push({
      label: `المكتب: ${OFFICE_MAP[filters.office] ?? filters.office}`,
      key: "office",
    });
  }

  return (
    <aside className={`filter-panel${isOpen ? " filter-panel--open" : ""}`}>
      <article
        className="filter-panel__header"
        role="button"
        tabIndex={0}
        onClick={() => setIsOpen((prev) => !prev)}
        onKeyDown={(e) => {
          if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            setIsOpen((prev) => !prev);
          }
        }}
      >
        <span className="filter-panel__title">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3" />
          </svg>
          تصفية متقدمة
        </span>
        <svg className="filter-panel__toggle-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M6 9l6 6 6-6" />
        </svg>
      </article>

      <article className="filter-panel__body">
        <article className="filter-panel__body-inner">
          <article className="filter-panel__controls">

            <article className="filter-panel__group">
              <label className="form-label" htmlFor="filter-sex">الجنس</label>
              <select
                className="form-select"
                id="filter-sex"
                value={filters.sex}
                onChange={(e) => updateFilter("sex", e.target.value)}
              >
                <option value="">الكل</option>
                <option value="male">ذكر</option>
                <option value="female">أنثى</option>
              </select>
            </article>

            <article className="filter-panel__group">
              <label className="form-label" htmlFor="filter-father">اسم الأب</label>
              <input
                type="text"
                className="form-input"
                id="filter-father"
                placeholder="اسم الأب..."
                value={filters.father}
                onChange={(e) => updateFilter("father", e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && onFilterChange(filters)}
              />
            </article>

            <article className="filter-panel__group">
              <label className="form-label" htmlFor="filter-mother">اسم الأم</label>
              <input
                type="text"
                className="form-input"
                id="filter-mother"
                placeholder="اسم الأم..."
                value={filters.mother}
                onChange={(e) => updateFilter("mother", e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && onFilterChange(filters)}
              />
            </article>

            <article className="filter-panel__group">
              <label className="form-label" htmlFor="filter-office">مكتب الحالة المدنية</label>
              <select
                className="form-select"
                id="filter-office"
                value={filters.office}
                onChange={(e) => updateFilter("office", e.target.value)}
              >
                <option value="">الكل</option>
                {Object.entries(OFFICE_MAP).map(([value, label]) => (
                  <option key={value} value={value}>{label}</option>
                ))}
              </select>
            </article>

          </article>

          {activeFilters.length > 0 && (
            <article className="active-filters">
              {activeFilters.map((tag) => (
                <span className="filter-tag" key={tag.key}>
                  {tag.label}
                  <button
                    className="filter-tag__remove"
                    type="button"
                    aria-label="إزالة"
                    onClick={() => clearFilter(tag.key)}
                  >
                    &times;
                  </button>
                </span>
              ))}
            </article>
          )}

        </article>
      </article>
    </aside>
  );
}
