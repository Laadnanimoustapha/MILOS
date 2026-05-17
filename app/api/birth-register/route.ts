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
      `INSERT INTO birth_registrations
        (father_fname, father_lname, father_dob, father_cin,
         mother_fname, mother_lname, mother_dob, mother_cin, mother_address,
         newborn_fname, gender, newborn_dob, newborn_birthplace)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        body.fatherFname || "",
        body.fatherLname || "",
        body.fatherDob || "",
        body.fatherCin || "",
        body.motherFname || "",
        body.motherLname || "",
        body.motherDob || "",
        body.motherCin || "",
        body.motherAddress || "",
        body.newbornFname || "",
        body.gender || "",
        body.newbornDob || "",
        body.newbornBirthplace || "",
      ]
    );

    const insertId = (result as { insertId: number }).insertId;

    // 2. Call Python FastAPI to generate PDF
    let pdfUrl = "";
    console.log(`[PDF] Calling HF backend at: ${PYTHON_API_URL}/generate-birth-pdf`);
    if (PYTHON_API_URL) {
      try {
        const pdfResponse = await fetch(`${PYTHON_API_URL}/generate-birth-pdf`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            father_fname: body.fatherFname || "",
            father_lname: body.fatherLname || "",
            father_dob: body.fatherDob || "",
            father_cin: body.fatherCin || "",
            mother_fname: body.motherFname || "",
            mother_lname: body.motherLname || "",
            mother_dob: body.motherDob || "",
            mother_cin: body.motherCin || "",
            mother_address: body.motherAddress || "",
            newborn_fname: body.newbornFname || "",
            gender: body.gender || "",
            newborn_dob: body.newbornDob || "",
            newborn_birthplace: body.newbornBirthplace || "",
          }),
        });

        console.log(`[PDF] HF response status: ${pdfResponse.status}`);

        if (pdfResponse.ok) {
          const pdfData = await pdfResponse.json();
          pdfUrl = pdfData.pdf_url || "";
          console.log(`[PDF] Got PDF URL: ${pdfUrl}`);

          // 3. Update DB record with PDF URL
          if (pdfUrl) {
            await db.execute(
              "UPDATE birth_registrations SET pdf_url = ? WHERE id = ?",
              [pdfUrl, insertId]
            );
          }
        } else {
          const errText = await pdfResponse.text();
          console.error(`[PDF] HF backend error ${pdfResponse.status}: ${errText}`);
        }
      } catch (pdfErr) {
        console.error("[PDF] Failed to reach HF backend:", pdfErr);
      }
    } else {
      console.warn("[PDF] PYTHON_API_URL is not set — skipping PDF generation");
    }

    return NextResponse.json({
      success: true,
      id: insertId,
      pdf_url: pdfUrl,
    });
  } catch (error: unknown) {
    const message =
      error instanceof Error ? error.message : "Unknown server error";
    console.error("Birth registration error:", message);
    return NextResponse.json(
      { success: false, error: message },
      { status: 500 }
    );
  }
}
