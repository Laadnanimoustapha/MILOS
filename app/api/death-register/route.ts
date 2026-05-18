import { NextResponse } from "next/server";
import { getPool, initSchema } from "@/lib/db";

const PYTHON_API_URL = (process.env.PYTHON_API_URL || "").replace(/\/$/, "");
const HF_READ_TKEN   = process.env.HF_READ_TKEN || "";

/**
 * Wake a sleeping HuggingFace Space by polling GET / with Auth header
 * Returns true once the Space responds with 2xx, false on timeout.
 */
async function wakeSpace(baseUrl: string, token: string, timeoutMs = 12000): Promise<boolean> {
  const deadline = Date.now() + timeoutMs;
  const headers: Record<string, string> = {};
  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }

  while (Date.now() < deadline) {
    try {
      const res = await fetch(`${baseUrl}/`, { method: "GET", headers });
      if (res.ok) return true;
    } catch {
      // still sleeping
    }
    await new Promise((r) => setTimeout(r, 2000));
  }
  return false;
}

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

    // 2. Call Python FastAPI to generate PDF (non-blocking — registration always succeeds)
    let pdfUrl = "";
    if (PYTHON_API_URL) {
      try {
        console.log(`[PDF] Waking HF Space at ${PYTHON_API_URL} ...`);
        const awake = await wakeSpace(PYTHON_API_URL, HF_READ_TKEN);
        if (!awake) {
          console.warn("[PDF] HF Space did not wake in time — skipping PDF.");
        } else {
          const headers: Record<string, string> = {
            "Content-Type": "application/json",
          };
          if (HF_READ_TKEN) {
            headers["Authorization"] = `Bearer ${HF_READ_TKEN}`;
          }

          const pdfResponse = await fetch(`${PYTHON_API_URL}/generate-death-pdf`, {
            method: "POST",
            headers,
            body: JSON.stringify({
              dtype:          body.dtype || "direct",
              decl_date:      body.declDate || "",
              cert_number:    body.certNumber || "",
              deceased_fname: body.deceasedFname || "",
              deceased_lname: body.deceasedLname || "",
              dgender:        body.dgender || "",
              death_date:     body.deathDate || "",
              death_place:    body.deathPlace || "",
              father_fname:   body.fatherFname || "",
              father_lname:   body.fatherLname || "",
              mother_fname:   body.motherFname || "",
              mother_lname:   body.motherLname || "",
              cause_death:    body.causeDeath || "",
              declarant_name: body.declarantName || "",
              declarant_cin:  body.declarantCin || "",
              supabase_url:   process.env.SUPABASE_URL || "",
              supabase_key:   process.env.SUPABASE_API_KEY || "",
            }),
          });

          if (pdfResponse.ok) {
            const pdfData = await pdfResponse.json();
            pdfUrl = pdfData.pdf_url || "";
            console.log(`[PDF] Got PDF URL: ${pdfUrl}`);
            if (pdfUrl) {
              await db.execute(
                "UPDATE death_registrations SET pdf_url = ? WHERE id = ?",
                [pdfUrl, insertId]
              );
            }
          } else {
            const errText = await pdfResponse.text();
            console.error(`[PDF] HF error ${pdfResponse.status}: ${errText.slice(0, 200)}`);
          }
        }
      } catch (pdfErr) {
        console.error("[PDF] Failed to reach HF backend:", pdfErr);
      }
    } else {
      console.warn("[PDF] PYTHON_API_URL not set — skipping PDF generation.");
    }

    return NextResponse.json({ success: true, id: insertId, pdf_url: pdfUrl });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Unknown server error";
    console.error("Death registration error:", message);
    return NextResponse.json({ success: false, error: message }, { status: 500 });
  }
}
