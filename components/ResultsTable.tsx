import type { Sex } from "@/lib/types";

interface ResultsTableProps {
  headers: string[];
  rows: Record<string, string>[];
  dateKey: string;
}

function GenderBadge({ sex }: { sex: Sex }) {
  const label = sex === "male" ? "ذكر" : "أنثى";
  const cls = sex === "male" ? "badge badge--male" : "badge badge--female";
  return <span className={cls}>{label}</span>;
}

function ViewButton() {
  return (
    <button className="table-action" type="button" title="عرض التفاصيل" aria-label="عرض التفاصيل">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
        <circle cx="12" cy="12" r="3" />
      </svg>
    </button>
  );
}

function DownloadButton({ url }: { url: string }) {
  if (!url) return null;
  return (
    <a href={url} target="_blank" rel="noopener noreferrer" className="table-action" title="تحميل الوثيقة" aria-label="تحميل الوثيقة" style={{ marginLeft: '8px' }}>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
        <polyline points="7 10 12 15 17 10" />
        <line x1="12" y1="15" x2="12" y2="3" />
      </svg>
    </a>
  );
}

export default function ResultsTable({ headers, rows, dateKey }: ResultsTableProps) {
  if (rows.length === 0) {
    return (
      <article className="empty-state">
        <svg className="empty-state__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
          <circle cx="11" cy="11" r="8" />
          <path d="M21 21l-4.35-4.35" />
          <path d="M8 11h6" />
        </svg>
        <p className="empty-state__title">لا توجد نتائج</p>
        <p className="empty-state__desc">حاول تعديل معايير البحث أو تغيير التصفية</p>
      </article>
    );
  }

  return (
    <>
      <article className="results-summary">
        <span>
          عدد النتائج:{" "}
          <strong className="results-summary__count">{rows.length}</strong>
        </span>
      </article>

      <article className="results-table-wrap">
        <table className="results-table">
          <thead>
            <tr>
              {headers.map((h) => (
                <th key={h}>{h}</th>
              ))}
              <th>إجراءات</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.id}>
                <td>{row.id}</td>
                <td>{row.fname}</td>
                <td>{row.lname}</td>
                <td>
                  <GenderBadge sex={row.sex as Sex} />
                </td>
                <td>{row[dateKey]}</td>
                <td>{row.father}</td>
                <td>{row.mother}</td>
                <td>{row.office}</td>
                <td style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <ViewButton />
                  <DownloadButton url={row.pdf_url} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </article>
    </>
  );
}
