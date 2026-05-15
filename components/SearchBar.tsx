"use client";

interface SearchBarProps {
  nameLabel: string;
  yearLabel: string;
  query: string;
  year: string;
  onQueryChange: (value: string) => void;
  onYearChange: (value: string) => void;
  onSearch: () => void;
}

export default function SearchBar({
  nameLabel,
  yearLabel,
  query,
  year,
  onQueryChange,
  onYearChange,
  onSearch,
}: SearchBarProps) {
  return (
    <fieldset className="search-bar">
      <legend className="form-panel__legend">البحث في السجلات</legend>
      <article className="search-bar__row">
        <article className="search-bar__field">
          <label className="form-label" htmlFor="search-name">
            {nameLabel}
          </label>
          <input
            type="text"
            className="form-input"
            id="search-name"
            placeholder="ابحث بالاسم الشخصي أو العائلي..."
            value={query}
            onChange={(e) => onQueryChange(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && onSearch()}
          />
        </article>

        <article className="search-bar__field search-bar__field--fixed">
          <label className="form-label" htmlFor="search-year">
            {yearLabel}
          </label>
          <select
            className="form-select"
            id="search-year"
            value={year}
            onChange={(e) => onYearChange(e.target.value)}
          >
            <option value="">الكل</option>
            <option value="2026">2026</option>
            <option value="2025">2025</option>
            <option value="2024">2024</option>
            <option value="2023">2023</option>
            <option value="2022">2022</option>
            <option value="2021">2021</option>
            <option value="2020">2020</option>
          </select>
        </article>

        <button
          type="button"
          className="btn btn--primary"
          onClick={onSearch}
          style={{ alignSelf: "flex-end" }}
        >
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            width={18}
            height={18}
            aria-hidden="true"
          >
            <circle cx="11" cy="11" r="8" />
            <path d="M21 21l-4.35-4.35" />
          </svg>
          بحث
        </button>
      </article>
    </fieldset>
  );
}
