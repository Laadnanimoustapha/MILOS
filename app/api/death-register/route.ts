import { NextResponse } from "next/server";
import { getPool, initSchema } from "@/lib/db";

const PYTHON_API_URL = process.env.PYTHON_API_URL || "";

export async function POST(request: Request) {
  try {
    const body = await request.json();

    // Ensure tables exist
    await initSchema();

    // 1. Save to Aiven MySQL
    const db = getPool();
    const [result] = await db.execute(
      `INSERT INTO death_registrations
        (dtype, decl_date, cert_number,
         deceased_fname, deceased_lname, dgender, death_date, death_place,
         father_fname, father_lname, mother_fname, mother_lname,
         cause_death, declarant_name, declarant_cin)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        body.dtype || "direct",
        body.declDate || "",
        body.certNumber || "",
        body.deceasedFname || "",
        body.deceasedLname || "",
        body.dgender || "",
        body.deathDate || "",
        body.deathPlace || "",
        body.fatherFname || "",
        body.fatherLname || "",
        body.motherFname || "",
        body.motherLname || "",
        body.causeDeath || "",
        body.declarantName || "",
        body.declarantCin || "",
      ]
    );

    const insertId = (result as { insertId: number }).insertId;

    // 2. Call Python FastAPI to generate PDF
    let pdfUrl = "";
    if (PYTHON_API_URL) {
      const pdfResponse = await fetch(`${PYTHON_API_URL}/generate-death-pdf`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          dtype: body.dtype || "direct",
          decl_date: body.declDate || "",
          cert_number: body.certNumber || "",
          deceased_fname: body.deceasedFname || "",
          deceased_lname: body.deceasedLname || "",
          dgender: body.dgender || "",
          death_date: body.deathDate || "",
          death_place: body.deathPlace || "",
          father_fname: body.fatherFname || "",
          father_lname: body.fatherLname || "",
          mother_fname: body.motherFname || "",
          mother_lname: body.motherLname || "",
          cause_death: body.causeDeath || "",
          declarant_name: body.declarantName || "",
          declarant_cin: body.declarantCin || "",
        }),
      });

      if (pdfResponse.ok) {
        const pdfData = await pdfResponse.json();
        pdfUrl = pdfData.pdf_url || "";

        // 3. Update DB record with PDF URL
        if (pdfUrl) {
          await db.execute(
            "UPDATE death_registrations SET pdf_url = ? WHERE id = ?",
            [pdfUrl, insertId]
          );
        }
      }
    }

    return NextResponse.json({
      success: true,
      id: insertId,
      pdf_url: pdfUrl,
    });
  } catch (error: unknown) {
    const message =
      error instanceof Error ? error.message : "Unknown server error";
    console.error("Death registration error:", message);
    return NextResponse.json(
      { success: false, error: message },
      { status: 500 }
    );
  }
}
