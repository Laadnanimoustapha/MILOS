"use client";

import { useState, useCallback, useEffect } from "react";
import Link from "next/link";
import SiteHeader from "@/components/SiteHeader";
import SearchBar from "@/components/SearchBar";
import FilterPanel from "@/components/FilterPanel";
import ResultsTable from "@/components/ResultsTable";
import type { SearchFilters } from "@/lib/types";

const HEADERS = [
  "رقم",
  "اسم المتوفى(ة)",
  "الاسم العائلي",
  "الجنس",
  "تاريخ الوفاة",
  "اسم الأب",
  "اسم الأم",
];

const DEFAULT_FILTERS: SearchFilters = {
  query: "",
  year: "",
  sex: "",
  father: "",
  mother: "",
  office: "",
};

export default function DeathSearchClient() {
  const [filters, setFilters] = useState<SearchFilters>(DEFAULT_FILTERS);
  const [rows, setRows] = useState<Record<string, unknown>[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const fetchData = useCallback(async (f: SearchFilters) => {
    setLoading(true);
    setError("");
    try {
      const params = new URLSearchParams();
      if (f.query)  params.set("query",  f.query);
      if (f.year)   params.set("year",   f.year);
      if (f.sex)    params.set("sex",    f.sex);
      if (f.father) params.set("father", f.father);
      if (f.mother) params.set("mother", f.mother);

      const res = await fetch(`/api/death-search?${params.toString()}`);
      const json = await res.json();
      if (json.success) {
        setRows(json.data);
      } else {
        setError(json.error || "حدث خطأ أثناء البحث");
      }
    } catch {
      setError("تعذر الاتصال بالخادم");
    } finally {
      setLoading(false);
    }
  }, []);

  // Load all records on mount
  useEffect(() => { fetchData(DEFAULT_FILTERS); }, [fetchData]);

  const handleSearch = useCallback(() => { fetchData(filters); }, [filters, fetchData]);

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
          <h2 className="search-page-title__heading">بحث و إطلاع للوفيات</h2>
          <p className="search-page-title__desc">
            البحث في سجلات الوفيات حسب الاسم أو الجنس أو اسم الأب أو الأم
          </p>
          <hr className="search-page-title__divider" />
        </section>

        <SearchBar
          nameLabel="اسم المتوفى(ة)"
          yearLabel="سنة الوفاة"
          query={filters.query}
          year={filters.year}
          onQueryChange={(v) => setFilters((f) => ({ ...f, query: v }))}
          onYearChange={(v) => setFilters((f) => ({ ...f, year: v }))}
          onSearch={handleSearch}
        />

        <FilterPanel filters={filters} onFilterChange={setFilters} />

        {loading && <p style={{ textAlign: "center", padding: "1rem" }}>جارٍ البحث...</p>}
        {error   && <p style={{ textAlign: "center", color: "var(--color-error, red)", padding: "1rem" }}>{error}</p>}

        {!loading && !error && <ResultsTable headers={HEADERS} rows={rows} dateKey="dod" />}
      </main>
    </section>
  );
}
