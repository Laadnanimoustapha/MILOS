import { NextResponse } from "next/server";
import { getPool, initSchema } from "@/lib/db";
import { generateDeathPDFBuffer } from "@/lib/pdfGenerator";
import { createClient } from "@supabase/supabase-js";

export async function POST(request: Request) {
  try {
    const body = await request.json();

    // Ensure tables exist
    await initSchema();

    // 1. Save to Aiven MySQL
    const db = getPool();
    const [result] = await db.execute(
      `INSERT INTO death_registrations
        (deceased_fname, deceased_lname, dgender, death_date, death_place, cause_death,
         father_fname, father_lname, mother_fname, mother_lname,
         declarant_name, declarant_cin, dtype, decl_date)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        body.deceasedFname || "",
        body.deceasedLname || "",
        body.dgender || "",
        body.deathDate || "",
        body.deathPlace || "",
        body.causeDeath || "",
        body.fatherFname || "",
        body.fatherLname || "",
        body.motherFname || "",
        body.motherLname || "",
        body.declarantName || "",
        body.declarantCin || "",
        body.dtype || "",
        body.declDate || "",
      ]
    );

    const insertId = (result as { insertId: number }).insertId;

    // 2. Local PDF Generation & Supabase Upload
    let pdfUrl = "";
    try {
      console.log(`[PDF] Generating local death PDF...`);
      const pdfData = {
        deceased_fname:     body.deceasedFname || "",
        deceased_lname:     body.deceasedLname || "",
        dgender:            body.dgender || "",
        death_date:         body.deathDate || "",
        death_place:        body.deathPlace || "",
        cause_death:        body.causeDeath || "",
        father_fname:       body.fatherFname || "",
        father_lname:       body.fatherLname || "",
        mother_fname:       body.motherFname || "",
        mother_lname:       body.motherLname || "",
        declarant_name:     body.declarantName || "",
        declarant_cin:      body.declarantCin || "",
        dtype:              body.dtype || "",
        decl_date:          body.declDate || "",
      };

      const pdfBuffer = await generateDeathPDFBuffer(pdfData);
      
      const supabaseUrl = process.env.SUPABASE_URL || "";
      const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_API_KEY || "";
      
      if (supabaseUrl && supabaseKey) {
        const supabase = createClient(supabaseUrl, supabaseKey);
        
        // Generate random filename
        const randStr = Math.random().toString(36).substring(2, 10);
        const dateStr = new Date().toISOString().split("T")[0].replace(/-/g, "");
        const filename = `death_${randStr}_${dateStr}.pdf`;
        const filePath = `pdf/${filename}`;
        
        const { error } = await supabase.storage
          .from("DP")
          .upload(filePath, pdfBuffer, {
            contentType: "application/pdf",
          });

        if (error) {
          console.error("[PDF] Supabase upload error:", error);
        } else {
          const { data: publicUrlData } = supabase.storage
            .from("DP")
            .getPublicUrl(filePath);
          
          pdfUrl = publicUrlData.publicUrl;
          console.log(`[PDF] Got PDF URL: ${pdfUrl}`);
          
          if (pdfUrl) {
            await db.execute(
              "UPDATE death_registrations SET pdf_url = ? WHERE id = ?",
              [pdfUrl, insertId]
            );
          }
        }
      } else {
         console.warn("[PDF] Supabase credentials missing, skipping upload.");
      }
    } catch (pdfErr) {
      console.error("[PDF] Failed to generate/upload local PDF:", pdfErr);
    }

    return NextResponse.json({ success: true, id: insertId, pdf_url: pdfUrl });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Unknown server error";
    console.error("Death registration error:", message);
    return NextResponse.json({ success: false, error: message }, { status: 500 });
  }
}
