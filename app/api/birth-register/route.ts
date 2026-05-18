import { NextResponse } from "next/server";
import { getPool, initSchema } from "@/lib/db";
import { generateBirthPDFBuffer } from "@/lib/pdfGenerator";
import { createClient } from "@supabase/supabase-js";

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

    // 2. Local PDF Generation & Supabase Upload
    let pdfUrl = "";
    try {
      console.log(`[PDF] Generating local PDF...`);
      const pdfData = {
        father_fname:       body.fatherFname || "",
        father_lname:       body.fatherLname || "",
        father_dob:         body.fatherDob || "",
        father_cin:         body.fatherCin || "",
        mother_fname:       body.motherFname || "",
        mother_lname:       body.motherLname || "",
        mother_dob:         body.motherDob || "",
        mother_cin:         body.motherCin || "",
        mother_address:     body.motherAddress || "",
        newborn_fname:      body.newbornFname || "",
        gender:             body.gender || "",
        newborn_dob:        body.newbornDob || "",
        newborn_birthplace: body.newbornBirthplace || "",
      };

      const pdfBuffer = await generateBirthPDFBuffer(pdfData);
      
      const supabaseUrl = process.env.SUPABASE_URL || "";
      const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_API_KEY || "";
      
      if (supabaseUrl && supabaseKey) {
        const supabase = createClient(supabaseUrl, supabaseKey);
        
        // Generate random filename
        const randStr = Math.random().toString(36).substring(2, 10);
        const dateStr = new Date().toISOString().split("T")[0].replace(/-/g, "");
        const filename = `birth_${randStr}_${dateStr}.pdf`;
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
              "UPDATE birth_registrations SET pdf_url = ? WHERE id = ?",
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
    console.error("Birth registration error:", message);
    return NextResponse.json({ success: false, error: message }, { status: 500 });
  }
}
