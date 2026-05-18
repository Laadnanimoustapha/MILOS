"""
DILONA -- FastAPI PDF Generation Microservice
Generates formal Moroccan civil status PDFs (birth + death certificates)
and uploads them to Supabase Storage.
"""

import os
import io
import uuid
from datetime import datetime

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional

from fpdf import FPDF
from supabase import create_client

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "")
SUPABASE_BUCKET = os.getenv("SUPABASE_BUCKET", "DP")

app = FastAPI(title="DILONA PDF Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------
class BirthPDFRequest(BaseModel):
    father_fname: str = ""
    father_lname: str = ""
    father_dob: str = ""
    father_cin: str = ""
    mother_fname: str = ""
    mother_lname: str = ""
    mother_dob: str = ""
    mother_cin: str = ""
    mother_address: str = ""
    newborn_fname: str = ""
    gender: str = ""
    newborn_dob: str = ""
    newborn_birthplace: str = ""
    supabase_url: Optional[str] = None
    supabase_key: Optional[str] = None


class DeathPDFRequest(BaseModel):
    dtype: str = "direct"
    decl_date: str = ""
    cert_number: str = ""
    deceased_fname: str = ""
    deceased_lname: str = ""
    dgender: str = ""
    death_date: str = ""
    death_place: str = ""
    father_fname: str = ""
    father_lname: str = ""
    mother_fname: str = ""
    mother_lname: str = ""
    cause_death: str = ""
    declarant_name: str = ""
    declarant_cin: str = ""
    supabase_url: Optional[str] = None
    supabase_key: Optional[str] = None


class PDFResponse(BaseModel):
    pdf_url: str
    filename: str


# ---------------------------------------------------------------------------
# Arabic-aware PDF helper
# ---------------------------------------------------------------------------
class ArabicPDF(FPDF):
    """Custom FPDF subclass with Arabic font and RTL helpers."""

    def __init__(self):
        super().__init__()
        self.set_text_shaping(True)
        font_dir = os.path.join(os.path.dirname(__file__), "fonts")
        self.add_font("Arabic", "", os.path.join(font_dir, "Amiri-Regular.ttf"))
        self.add_font("Arabic", "B", os.path.join(font_dir, "Amiri-Bold.ttf"))

    def rtl_cell(self, w, h, txt, border=0, ln=0, align="R", fill=False):
        """Write a right-to-left cell."""
        self.set_font("Arabic", "", 12)
        self.cell(w, h, txt, border=border, ln=ln, align=align, fill=fill)

    def rtl_cell_bold(self, w, h, txt, border=0, ln=0, align="R", fill=False):
        """Write a bold right-to-left cell."""
        self.set_font("Arabic", "B", 14)
        self.cell(w, h, txt, border=border, ln=ln, align=align, fill=fill)

    def header_block(self, title_ar: str, title_fr: str):
        """Draw the official Moroccan document header."""
        self.set_font("Arabic", "B", 16)
        self.cell(0, 10, "\u0627\u0644\u0645\u0645\u0644\u0643\u0629 \u0627\u0644\u0645\u063a\u0631\u0628\u064a\u0629", ln=True, align="C")

        self.set_font("Arabic", "", 11)
        self.cell(0, 7, "Royaume du Maroc", ln=True, align="C")

        self.set_font("Arabic", "", 10)
        self.cell(0, 6, "\u0648\u0632\u0627\u0631\u0629 \u0627\u0644\u062f\u0627\u062e\u0644\u064a\u0629", ln=True, align="C")
        self.cell(0, 6, "\u0645\u0635\u0644\u062d\u0629 \u0627\u0644\u062d\u0627\u0644\u0629 \u0627\u0644\u0645\u062f\u0646\u064a\u0629", ln=True, align="C")
        self.cell(0, 5, "Service de l'Etat Civil", ln=True, align="C")

        self.ln(4)
        self.set_draw_color(180, 150, 80)
        self.set_line_width(0.8)
        self.line(20, self.get_y(), 190, self.get_y())
        self.ln(6)

        self.set_font("Arabic", "B", 18)
        self.cell(0, 12, title_ar, ln=True, align="C")
        self.set_font("Arabic", "", 12)
        self.cell(0, 8, title_fr, ln=True, align="C")
        self.ln(4)
        self.line(20, self.get_y(), 190, self.get_y())
        self.ln(8)

    def section_title(self, title: str):
        """Draw a section divider with a title."""
        self.set_fill_color(245, 240, 230)
        self.set_font("Arabic", "B", 13)
        self.cell(0, 9, title, ln=True, align="R", fill=True)
        self.ln(3)

    def field_row(self, label_ar: str, value: str, label_fr: str = ""):
        """Draw a single labelled field row."""
        col_w = 90
        self.set_font("Arabic", "B", 11)
        self.cell(col_w, 8, label_ar, align="R")
        self.set_font("Arabic", "", 11)
        self.cell(col_w, 8, value if value else "---", align="R")
        self.ln(8)
        if label_fr:
            self.set_font("Arabic", "", 9)
            self.set_text_color(120, 120, 120)
            self.cell(col_w, 5, label_fr, align="R")
            self.set_text_color(0, 0, 0)
            self.ln(5)

    def stamp_area(self):
        """Draw the official stamp and signature area at the bottom."""
        self.ln(12)
        self.set_draw_color(180, 150, 80)
        self.line(20, self.get_y(), 190, self.get_y())
        self.ln(8)

        y = self.get_y()
        self.set_font("Arabic", "", 10)
        self.set_xy(120, y)
        self.cell(70, 7, "\u062e\u0627\u062a\u0645 \u0648\u062a\u0648\u0642\u064a\u0639 \u0636\u0627\u0628\u0637 \u0627\u0644\u062d\u0627\u0644\u0629 \u0627\u0644\u0645\u062f\u0646\u064a\u0629", align="C")
        self.set_xy(120, y + 7)
        self.cell(70, 6, "Cachet et signature de l'OEC", align="C")

        self.set_xy(20, y)
        self.cell(70, 7, f"\u062d\u0631\u0631 \u0628\u062a\u0627\u0631\u064a\u062e: {datetime.now().strftime('%Y-%m-%d')}", align="C")

        self.set_xy(120, y + 20)
        self.set_draw_color(200, 200, 200)
        self.rect(130, y + 16, 50, 25)


# ---------------------------------------------------------------------------
# Supabase upload helper
# ---------------------------------------------------------------------------
def upload_to_supabase(pdf_bytes: bytes, filename: str, url: str = "", key: str = "") -> str:
    """Upload PDF bytes to Supabase Storage and return the public URL."""
    active_url = url or SUPABASE_URL
    active_key = key or SUPABASE_KEY

    if not active_url or not active_key:
        raise HTTPException(
            status_code=500,
            detail="Supabase credentials not configured.",
        )

    supabase = create_client(active_url, active_key)
    file_path = f"pdf/{filename}"

    supabase.storage.from_(SUPABASE_BUCKET).upload(
        file_path,
        pdf_bytes,
        file_options={"content-type": "application/pdf"},
    )

    public_url = supabase.storage.from_(SUPABASE_BUCKET).get_public_url(file_path)
    return public_url


# ---------------------------------------------------------------------------
# PDF generation functions
# ---------------------------------------------------------------------------
def generate_birth_pdf(data: BirthPDFRequest) -> bytes:
    """Generate a formal Moroccan birth certificate PDF."""
    pdf = ArabicPDF()
    pdf.add_page()
    pdf.set_auto_page_break(auto=True, margin=20)

    pdf.header_block(
        "\u0631\u0633\u0645 \u0627\u0644\u0648\u0644\u0627\u062f\u0629",
        "Acte de Naissance",
    )

    # Father section
    pdf.section_title("\u0645\u0639\u0644\u0648\u0645\u0627\u062a \u0639\u0646 \u0627\u0644\u0623\u0628 / Informations sur le pere")
    pdf.field_row("\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0634\u062e\u0635\u064a", data.father_fname, "Prenom")
    pdf.field_row("\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0639\u0627\u0626\u0644\u064a", data.father_lname, "Nom")
    pdf.field_row("\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0627\u0632\u062f\u064a\u0627\u062f", data.father_dob, "Date de naissance")
    pdf.field_row("\u0631\u0642\u0645 \u0628\u0637\u0627\u0642\u0629 \u0627\u0644\u062a\u0639\u0631\u064a\u0641", data.father_cin, "CIN")

    pdf.ln(4)

    # Mother section
    pdf.section_title("\u0645\u0639\u0644\u0648\u0645\u0627\u062a \u0639\u0646 \u0627\u0644\u0623\u0645 / Informations sur la mere")
    pdf.field_row("\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0634\u062e\u0635\u064a", data.mother_fname, "Prenom")
    pdf.field_row("\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0639\u0627\u0626\u0644\u064a", data.mother_lname, "Nom")
    pdf.field_row("\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0627\u0632\u062f\u064a\u0627\u062f", data.mother_dob, "Date de naissance")
    pdf.field_row("\u0631\u0642\u0645 \u0628\u0637\u0627\u0642\u0629 \u0627\u0644\u062a\u0639\u0631\u064a\u0641", data.mother_cin, "CIN")
    pdf.field_row("\u0639\u0646\u0648\u0627\u0646 \u0627\u0644\u0625\u0642\u0627\u0645\u0629", data.mother_address, "Adresse")

    pdf.ln(4)

    # Newborn section
    pdf.section_title("\u0645\u0639\u0644\u0648\u0645\u0627\u062a \u0639\u0646 \u0627\u0644\u0645\u0648\u0644\u0648\u062f(\u0629) / Informations sur le nouveau-ne")
    pdf.field_row("\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0634\u062e\u0635\u064a", data.newborn_fname, "Prenom")
    pdf.field_row("\u0627\u0644\u062c\u0646\u0633", data.gender, "Sexe")
    pdf.field_row("\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0648\u0644\u0627\u062f\u0629", data.newborn_dob, "Date de naissance")
    pdf.field_row("\u0645\u0643\u0627\u0646 \u0627\u0644\u0648\u0644\u0627\u062f\u0629", data.newborn_birthplace, "Lieu de naissance")

    # Stamp area
    pdf.stamp_area()

    return pdf.output()


def generate_death_pdf(data: DeathPDFRequest) -> bytes:
    """Generate a formal Moroccan death certificate PDF."""
    pdf = ArabicPDF()
    pdf.add_page()
    pdf.set_auto_page_break(auto=True, margin=20)

    pdf.header_block(
        "\u0631\u0633\u0645 \u0627\u0644\u0648\u0641\u0627\u0629",
        "Acte de Deces",
    )

    # Certificate info
    pdf.section_title("\u0628\u064a\u0627\u0646\u0627\u062a \u0634\u0647\u0627\u062f\u0629 \u0627\u0644\u0648\u0641\u0627\u0629 / Donnees du certificat")
    pdf.field_row("\u0646\u0648\u0639 \u0627\u0644\u062a\u0635\u0631\u064a\u062d", "\u0645\u0628\u0627\u0634\u0631" if data.dtype == "direct" else "\u062d\u0643\u0645 \u0645\u0646 \u0627\u0644\u0645\u062d\u0643\u0645\u0629", "Type")
    pdf.field_row("\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u062a\u0635\u0631\u064a\u062d", data.decl_date, "Date de declaration")
    pdf.field_row("\u0631\u0642\u0645 \u0634\u0647\u0627\u062f\u0629 \u0627\u0644\u0648\u0641\u0627\u0629", data.cert_number, "N du certificat")

    pdf.ln(4)

    # Deceased info
    pdf.section_title("\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0645\u062a\u0648\u0641\u0649 / Informations sur le defunt")
    pdf.field_row("\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0634\u062e\u0635\u064a", data.deceased_fname, "Prenom")
    pdf.field_row("\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0639\u0627\u0626\u0644\u064a", data.deceased_lname, "Nom")
    pdf.field_row("\u0627\u0644\u062c\u0646\u0633", data.dgender, "Sexe")
    pdf.field_row("\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0648\u0641\u0627\u0629", data.death_date, "Date de deces")
    pdf.field_row("\u0645\u0643\u0627\u0646 \u0627\u0644\u0648\u0641\u0627\u0629", data.death_place, "Lieu de deces")

    pdf.ln(4)

    # Parents
    pdf.section_title("\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0648\u0627\u0644\u062f\u064a\u0646 / Parents")
    pdf.field_row("\u0627\u0633\u0645 \u0627\u0644\u0623\u0628", f"{data.father_fname} {data.father_lname}", "Nom du pere")
    pdf.field_row("\u0627\u0633\u0645 \u0627\u0644\u0623\u0645", f"{data.mother_fname} {data.mother_lname}", "Nom de la mere")

    pdf.ln(4)

    # General info
    pdf.section_title("\u0645\u0639\u0644\u0648\u0645\u0627\u062a \u0625\u0636\u0627\u0641\u064a\u0629 / Informations complementaires")
    pdf.field_row("\u0633\u0628\u0628 \u0627\u0644\u0648\u0641\u0627\u0629", data.cause_death, "Cause du deces")
    pdf.field_row("\u0627\u0633\u0645 \u0627\u0644\u0645\u0635\u0631\u062d", data.declarant_name, "Nom du declarant")
    pdf.field_row("\u0631\u0642\u0645 \u0628\u0637\u0627\u0642\u0629 \u0627\u0644\u062a\u0639\u0631\u064a\u0641", data.declarant_cin, "CIN du declarant")

    # Stamp area
    pdf.stamp_area()

    return pdf.output()


# ---------------------------------------------------------------------------
# API endpoints
# ---------------------------------------------------------------------------
@app.get("/")
def health_check():
    return {"status": "ok", "service": "DILONA PDF Generator"}


@app.post("/generate-birth-pdf", response_model=PDFResponse)
def create_birth_pdf(data: BirthPDFRequest):
    """Generate a birth certificate PDF and upload to Supabase."""
    try:
        pdf_bytes = generate_birth_pdf(data)
        filename = f"birth_{uuid.uuid4().hex[:8]}_{datetime.now().strftime('%Y%m%d')}.pdf"
        pdf_url = upload_to_supabase(pdf_bytes, filename, data.supabase_url or "", data.supabase_key or "")
        return PDFResponse(pdf_url=pdf_url, filename=filename)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/generate-death-pdf", response_model=PDFResponse)
def create_death_pdf(data: DeathPDFRequest):
    """Generate a death certificate PDF and upload to Supabase."""
    try:
        pdf_bytes = generate_death_pdf(data)
        filename = f"death_{uuid.uuid4().hex[:8]}_{datetime.now().strftime('%Y%m%d')}.pdf"
        pdf_url = upload_to_supabase(pdf_bytes, filename, data.supabase_url or "", data.supabase_key or "")
        return PDFResponse(pdf_url=pdf_url, filename=filename)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
