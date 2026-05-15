export type Sex = "male" | "female";

export interface BirthRecord {
  id: string;
  fname: string;
  lname: string;
  sex: Sex;
  dob: string;
  father: string;
  mother: string;
  office: string;
}

export interface DeathRecord {
  id: string;
  fname: string;
  lname: string;
  sex: Sex;
  dod: string;
  father: string;
  mother: string;
  office: string;
}

export type CivilRecord = BirthRecord | DeathRecord;

export interface SearchFilters {
  query: string;
  year: string;
  sex: string;
  father: string;
  mother: string;
  office: string;
}

export const OFFICE_MAP: Record<string, string> = {
  rabat: "الرباط",
  casablanca: "الدار البيضاء",
  fes: "فاس",
  marrakech: "مراكش",
  tangier: "طنجة",
};
