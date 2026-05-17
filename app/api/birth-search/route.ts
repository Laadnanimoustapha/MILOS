import { NextResponse } from "next/server";
import { getPool, initSchema } from "@/lib/db";

export async function GET(request: Request) {
  try {
    await initSchema();
    const db = getPool();

    const { searchParams } = new URL(request.url);
    const query = searchParams.get("query")?.trim() || "";
    const year  = searchParams.get("year")?.trim()  || "";
    const sex   = searchParams.get("sex")?.trim()   || "";
    const father = searchParams.get("father")?.trim() || "";
    const mother = searchParams.get("mother")?.trim() || "";

    const conditions: string[] = [];
    const params: string[] = [];

    if (query) {
      conditions.push("(newborn_fname LIKE ? OR father_lname LIKE ?)");
      params.push(`%${query}%`, `%${query}%`);
    }
    if (year) {
      conditions.push("newborn_dob LIKE ?");
      params.push(`${year}%`);
    }
    if (sex) {
      conditions.push("gender = ?");
      params.push(sex);
    }
    if (father) {
      conditions.push("father_fname LIKE ?");
      params.push(`%${father}%`);
    }
    if (mother) {
      conditions.push("mother_fname LIKE ?");
      params.push(`%${mother}%`);
    }

    const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
    const [rows] = await db.execute(
      `SELECT id, newborn_fname AS fname, father_lname AS lname, gender AS sex,
              newborn_dob AS dob, father_fname AS father, mother_fname AS mother,
              pdf_url
       FROM birth_registrations ${where}
       ORDER BY created_at DESC
       LIMIT 200`,
      params
    );

    return NextResponse.json({ success: true, data: rows });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error("Birth search error:", message);
    return NextResponse.json({ success: false, error: message }, { status: 500 });
  }
}
