import type { Metadata } from "next";
import DeathSearchClient from "./DeathSearchClient";

export const metadata: Metadata = {
  title: "بحث و إطلاع للوفيات - نظام الحالة المدنية",
  description: "البحث في سجلات الوفيات حسب الاسم أو الجنس أو اسم الأب أو الأم",
};

export default function DeathSearchPage() {
  return <DeathSearchClient />;
}
