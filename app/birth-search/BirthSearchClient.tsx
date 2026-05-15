"use client";

import { useState, useMemo, useCallback } from "react";
import Link from "next/link";
import SiteHeader from "@/components/SiteHeader";
import SearchBar from "@/components/SearchBar";
import FilterPanel from "@/components/FilterPanel";
import ResultsTable from "@/components/ResultsTable";
import { BIRTH_DATA } from "@/lib/data";
import { OFFICE_MAP } from "@/lib/types";
import type { SearchFilters } from "@/lib/types";

const HEADERS = [
  "رقم الرسم",
  "الاسم الشخصي",
  "الاسم العائلي",
  "الجنس",
  "تاريخ الولادة",
  "اسم الأب",
  "اسم الأم",
  "المكتب",
];

const DEFAULT_FILTERS: SearchFilters = {
  query: "",
  year: "",
  sex: "",
  father: "",
  mother: "",
  office: "",
};

export default function BirthSearchClient() {
  const [filters, setFilters] = useState<SearchFilters>(DEFAULT_FILTERS);

  const handleSearch = useCallback(() => {
    // Triggers re-render via state -- filtering is derived
  }, []);

  const filteredRows = useMemo(() => {
    return BIRTH_DATA.filter((item) => {
      const q = filters.query.trim().toLowerCase();
      const matchesQuery =
        !q || item.fname.toLowerCase().includes(q) || item.lname.toLowerCase().includes(q);
      const matchesYear = !filters.year || item.dob.startsWith(filters.year);
      const matchesSex = !filters.sex || item.sex === filters.sex;
      const matchesFather =
        !filters.father || item.father.toLowerCase().includes(filters.father.toLowerCase());
      const matchesMother =
        !filters.mother || item.mother.toLowerCase().includes(filters.mother.toLowerCase());
      const matchesOffice =
        !filters.office || item.office === OFFICE_MAP[filters.office];
      return matchesQuery && matchesYear && matchesSex && matchesFather && matchesMother && matchesOffice;
    });
  }, [filters]);

  const rows = useMemo(
    () =>
      filteredRows.map((r) => ({
        id: r.id,
        fname: r.fname,
        lname: r.lname,
        sex: r.sex,
        dob: r.dob,
        father: r.father,
        mother: r.mother,
        office: r.office,
      })),
    [filteredRows]
  );

  return (
    <section className="app-shell">
      <SiteHeader />
      <main className="main-content">
        <Link href="/" className="back-link">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" width={16} height={16}>
            <path d="M9 18l6-6-6-6" />
          </svg>
          العودة إلى القائمة الرئيسية
        </Link>

        <section className="search-page-title">
          <h2 className="search-page-title__heading">تصفح تصاريح الولادة</h2>
          <p className="search-page-title__desc">
            البحث في سجلات الولادة حسب الاسم أو الجنس أو اسم الأب أو الأم
          </p>
          <hr className="search-page-title__divider" />
        </section>

        <SearchBar
          nameLabel="الاسم الكامل"
          yearLabel="سنة الولادة"
          query={filters.query}
          year={filters.year}
          onQueryChange={(v) => setFilters((f) => ({ ...f, query: v }))}
          onYearChange={(v) => setFilters((f) => ({ ...f, year: v }))}
          onSearch={handleSearch}
        />

        <FilterPanel filters={filters} onFilterChange={setFilters} />

        <ResultsTable headers={HEADERS} rows={rows} dateKey="dob" />
      </main>
    </section>
  );
}
