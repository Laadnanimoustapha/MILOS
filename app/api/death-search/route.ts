import { NextResponse } from "next/server";
import { getPool, initSchema } from "@/lib/db";

export async function GET(request: Request) {
  try {
    await initSchema();
    const db = getPool();

    const { searchParams } = new URL(request.url);
    const query  = searchParams.get("query")?.trim()  || "";
    const year   = searchParams.get("year")?.trim()   || "";
    const sex    = searchParams.get("sex")?.trim()    || "";
    const father = searchParams.get("father")?.trim() || "";
    const mother = searchParams.get("mother")?.trim() || "";

    const conditions: string[] = [];
    const params: string[] = [];

    if (query) {
      conditions.push("(deceased_fname LIKE ? OR deceased_lname LIKE ?)");
      params.push(`%${query}%`, `%${query}%`);
    }
    if (year) {
      conditions.push("death_date LIKE ?");
      params.push(`${year}%`);
    }
    if (sex) {
      conditions.push("dgender = ?");
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
      `SELECT id, deceased_fname AS fname, deceased_lname AS lname, dgender AS sex,
              death_date AS dod, father_fname AS father, mother_fname AS mother,
              pdf_url
       FROM death_registrations ${where}
       ORDER BY created_at DESC
       LIMIT 200`,
      params
    );

    return NextResponse.json({ success: true, data: rows });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error("Death search error:", message);
    return NextResponse.json({ success: false, error: message }, { status: 500 });
  }
}
