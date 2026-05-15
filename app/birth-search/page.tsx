import type { Metadata } from "next";
import BirthSearchClient from "./BirthSearchClient";

export const metadata: Metadata = {
  title: "تصفح تصاريح الولادة - نظام الحالة المدنية",
  description: "البحث في سجلات الولادة حسب الاسم أو الجنس أو اسم الأب أو الأم",
};

export default function BirthSearchPage() {
  return <BirthSearchClient />;
}
