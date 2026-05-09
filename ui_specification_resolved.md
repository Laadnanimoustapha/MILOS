# UI Specification Document: Civil Status System

## Executive Summary
This document provides a pixel-perfect, technical UI specification for recreating the Moroccan National Civil Status Register Management System's primary navigation interface. 

As requested, **this specification strictly filters the interface** to include ONLY the modules related to **Birth (الولادة)** and **Death (الوفيات)**, including their respective browsing and search lists. All other modules (Registers, Family Booklet, Marriage, etc.) have been intentionally omitted.

---

## 1. Layout Structure
* **Page Hierarchy:**
  * **App Shell:** Consists of a fixed top Header, a right-aligned functional Sidebar (settings), and a scrollable Main Content Area.
  * **Main Content Area:** A vertically stacked list of full-width accordion elements, centered horizontally.
* **Grids & Spacing System:**
  * **Global Direction:** Natively RTL (Right-to-Left).
  * **Container Max-Width:** Approximately `1000px - 1200px` for the central menu block.
  * **Vertical Rhythm:**
    * Gap between main accordion categories: `16px` (`1rem`).
    * Header Height: `~80px`.
* **Alignment:**
  * Text inside accordions and sub-menus is strictly right-aligned (RTL compliant).
  * Category icons are positioned on the far right of the accordion header, housed in their own distinct square container.
* **Responsiveness Behavior:**
  * Fluid container with `padding-inline` on large screens to keep the menu centered.
  * Accordions span 100% of the constrained container width.

---

## 2. Design System
* **Colors (Hex References):**
  * `Primary Green`: `#33C94A` or `#36A945` (Main Accordion background - adjust for WCAG contrast).
  * `Primary Green Dark`: `#2A9137` (Icon container background on the right side of the banner).
  * `Background Light Grey`: `#F5F7F6` (App body background).
  * `Sub-menu Grey Background`: `#EEEEEE` or `#F2F2F2`.
  * `Sub-menu Hover Background`: `#E6E6E6`.
  * `Header Dark Grey`: `#787878` or `#8C8C8C`.
  * `Text Primary (Dark)`: `#333333` (Used for sub-menus and top header text).
  * `Text White`: `#FFFFFF` (Used for main accordion titles and icons).
* **Shadows & Borders:**
  * **Accordions:** Flat, institutional design. Extremely subtle drop shadow: `box-shadow: 0 1px 3px rgba(0,0,0,0.1)`.
  * **Borders:** Sharp corners (`border-radius: 0px`). Sub-menu items are separated by `1px solid #FFFFFF` to create a distinct striped, readable effect.
* **Typography:**
  * **Font Family:** Arabic system sans-serif (e.g., Cairo, Tajawal, or system defaults like Segoe UI).
  * **Main Accordion Titles:** `~22px`, Font Weight: `700` (Bold), Color: White.
  * **Sub-menu Items:** `~16px`, Font Weight: `500` (Medium), Color: Dark Grey.

---

## 3. Components

### Accordion Headers (Categories)
Solid green rectangular blocks acting as dropdown triggers.
* **Layout:** Flexbox, `flex-direction: row` (RTL).
* **Sections:**
  * **Right block (Icon Box):** Fixed width (`~64px`), slightly darker green background, contains a horizontally and vertically centered white SVG icon.
  * **Left block (Text Box):** Flex-grow, primary green background, contains right-aligned white text with `~20px` right padding.
* **Icons (Flat, Line or Solid SVG, White):**
  * **Baby Icon:** Used for "Birth Declarations".
  * **Tombstone Icon:** Used for "Death Declarations".
  * **Document Icon:** Used for "Marginal Data".

### Sub-menus
Expandable vertical lists beneath the Accordion Headers.
* **List Item Layout:** Block elements, full width of the parent accordion.
* **Padding:** `padding: 12px 64px 12px 20px`. The right padding (`64px`) aligns the sub-menu text perfectly with the header text, bypassing the icon box above it.
* **Hover State:** Background darkens slightly. Entire row becomes clickable.

---

## 4. Required Navigation Lists (Filtered)

These are the **ONLY** lists that should be generated in the final code.

### A. Birth Modules (الولادة)

**1. تدبير تصاريح الولادة (Managing birth declarations)**
* **Icon:** Baby
* **Sub-items:**
  1. تسجيل التصريح بالولادة (Registering birth declaration)
  2. تصفح تصاريح الولادة (Browsing birth declarations)
  3. المراقبة و المصادقة على التصاريح (Monitoring and validating declarations)
  4. تصفح لائحة الإشعارات (Browsing list of notifications)

**2. تدبير البيانات الهامشية للولادة (Managing marginal birth data)**
* **Icon:** Document
* **Sub-items:** Standard accordion behavior (empty/dynamic).

### B. Death Modules (الوفيات)

**3. تدبير تصاريح الوفيات (Managing death declarations)**
* **Icon:** Tombstone
* **Sub-items:**
  1. تسجيل التصريح بالوفاة (Registering death declaration)
  2. بحث و إطلاع للوفيات (Search and browsing for deaths)
  3. المراقبة و المصادقة على التصاريح (Monitoring and validating declarations)
  4. مقابلة معلومات التصريح (Matching declaration information)
  5. تصفح لائحة الإشعارات (Browsing list of notifications)

**4. تدبير البيانات الهامشية للوفاة (Managing marginal death data)**
* **Icon:** Document
* **Sub-items:** Standard accordion behavior (empty/dynamic).

---

## 5. Animations & Transitions
* **Hover Effects:**
  * **Main Accordion:** A native tooltip (`title="Afficher le sous-menu"`) appears on hover. The cursor changes to `pointer`.
  * **Sub-menu Items:** Immediate background color change to the darker grey (`#E6E6E6`). No sluggish transitions; interaction should feel instantaneous and institutional.
* **Transitions:**
  * **Accordion Expansion:** Smooth vertical slide down. Use CSS `grid-template-rows: 0fr` to `1fr` transition or a controlled `max-height` transition. Duration: `200ms-300ms`, Easing: `ease-in-out`.
* **Active States:**
  * Currently viewed sub-item should visually indicate active status (e.g., darker background or a bold font weight).

---

## 6. Exact Visual Observations (Estimates)
* **Accordion Header Height:** `~64px`
* **Sub-menu Item Height:** `~48px`
* **Icon Box Dimensions:** `64px` width, `64px` height.
* **Gap between Accordions:** `16px` margin-bottom.
* **Separator:** A visible separation exists between the icon box and the text box. This can be achieved by assigning a slightly darker background color to the icon container.

---

## 7. Interaction Behavior
* **Accordion Logic:** Clicking a green category header expands its respective sub-menu list.
* **Navigation:** Clicking a sub-menu row triggers an immediate route change. The clickable area (`<a>` or `<button>`) must span the **entire row**, not just the text.
* **Native Tooltips:** Replicate the "Afficher le sous-menu" functionality using the standard HTML `title` attribute on the accordion header containers.

---

## 8. Form Interfaces (Data Entry & Consultation)

The application utilizes complex, multi-step form views for data entry (e.g., `DeclarationNaissaince.aspx`) and read-only views for consultation (`DeclarationNaissance_Consultation.aspx`).

### 8.1. Page Layout (Forms)
* **Stepper / Progress Bar:** 
  * A horizontal, chevron-styled progress indicator spans the top of the form area.
  * **Multi-line Wrapping:** If the number of steps exceeds the container width (e.g., the Death module has 7 steps, while Birth has 6), the chevron stepper gracefully wraps to a second row while maintaining the RTL directional flow.
  * **States:**
    * `Inactive/Completed`: Light grey background (`#F5F5F5`), dark grey text.
    * `Active/Current`: Solid Orange/Brown (`#D58536`), white text.
    * `Next Step`: White background with a green border and green text.
  * **Steps (Birth Example):** معلومات عامة -> معلومات عن الأم -> معلومات عن الأب -> معلومات عن المولود(ة) -> نسخ الوثائق المدعمة -> خلاصة وتأكيد.
  * **Steps (Death Example):** بيانات شهادة الوفاة -> بيانات المتوفى -> بيانات الأب -> بيانات الأم -> معلومات عامة -> نسخ الوثائق المدعمة -> خلاصة وتأكيد.
* **Form Panels (Fieldsets):**
  * Forms are divided into logical groups (e.g., "معلومات عن التصريح" - Information about the declaration, "معلومات حول المصرح" - Information about the declarant, "معلومات عن المولود" - Information about the newborn).
  * **Styling:** Enclosed in a subtle, light green or grey border (`1px solid #DEDEDE`), with the section title positioned on the top right border (behaving like an HTML `<legend>`). Title color matches the primary green.

### 8.2. Form Components
* **Text Inputs:** Standard rectangular inputs with a light border (`border-radius: 2px`). Many text inputs include a small **keyboard icon (`⌨️`)** positioned inside the left edge of the input field, which toggles an onscreen virtual keyboard for Arabic/Latin characters.
* **Dropdowns (Selects):** Standard dropdowns with chevron icons.
* **Radio Buttons & Checkboxes:** Native inputs accompanied by right-aligned labels (e.g., "مباشر", "حكم من المحكمة").
* **Dual-Language Labeling:** In specific sections (like Newborn and Father details), inputs are flanked by bilingual labels to assist bilingual operators. 
  * **Arabic label:** On the right side of the input (Primary).
  * **French label:** On the far left of the container (Secondary) (e.g., `Prénom`, `Nom`, `Fille de`, `Adresse de naissance`).
* **Date Selectors:** Dates are not single inputs. They are split into three distinct dropdowns: `Day` (اليوم), `Month` (الشهر), and `Year` (السنة). 
  * Dual calendars are supported side-by-side: Gregorian (تاريخ الولادة) and Hijri (الموافق ل).
  * Includes a specific checkbox for missing days: "لا يتوفر على اليوم" (Does not have day).
* **"Unknown Entity" Checkbox:**
  * Positioned at the very top right of major fieldsets (e.g., "بيانات الأب" - Father details, "بيانات المتوفى" - Deceased details).
  * Labeled specifically to the context (e.g., "مجهول الأب" - Unknown father, "مجهول الهوية" - Unknown identity).
  * This is a structural toggle, likely used to disable or bypass the mandatory fields for that specific individual.
* **Archive Search Block (`البحث في بيانات الأرشيف`):** 
  * A recurring sub-section within parent panels (e.g., Father details, Spouse details) used to query legacy paper records.
  * Contains fields for Civil Status Office, Registration Year, and Certificate Number, accompanied by an orange `+ إضافة` (Add) action button.
* **Instructional Alert Box:**
  * A prominent warning box placed above complex data entry fields (e.g., historical certificate numbers).
  * **Styling:** Red tinted background with a solid red border and dark red text. Used strictly for critical input formatting instructions (like entering strings right-to-left).
* **Action Buttons:**
  * Example: "إضافة مولود توأم" (Add twin newborn) is styled as a secondary orange button with white text.
  * Navigation buttons like "السابق" (Previous) and "التالي" (Next) exist for moving through the stepper.

### 8.3. Grid & Spacing (Forms)
* The form heavily utilizes a multi-column CSS Grid or Flexbox layout, naturally flowing RTL.
* Spacing between form groups (vertical): `~24px`.
* Spacing between individual grid rows: `~16px`.
* The alignment relies heavily on fixed-width label columns to keep the central inputs vertically aligned across different rows, while pushing French labels to a fixed left column.

### 8.4. Document Gallery (Uploads Step)
* The "نسخ الوثائق المدعمة" (Supporting Documents) step provides both an upload interface and a gallery of uploaded scans.
* **Upload Controls:**
  * A distinct green button block "تحميل صورة الوثيقة" (Upload document image) accompanied by a standard file picker (`Choisir un fichier`) and a prominent scanner icon.
  * A dropdown to select the `نوع الوثيقة` (Document type) being uploaded.
* **Thumbnail Containers:**
  * Square or slightly rectangular aspect ratio.
  * Thick, prominent green border (`~3px solid #36A945`) surrounding the document image.
  * Image is centered within the container.
* **Document Actions:**
  * Centered or right-aligned text positioned directly beneath each thumbnail describes the document type.
  * A full-width, light red `حذف` (Delete) button is positioned directly under the text label for removing the specific scan.

### 8.5. Summary & Confirmation (Final Step)
* The final step "خلاصة وتأكيد" alters the layout to present a read-only review of all entered data.
* **Review Accordions:**
  * Previous form fieldsets are transformed into stacked, collapsible accordions.
  * The accordion header features a distinct icon: a circular green outline containing a `+` symbol (or `-` when expanded), indicating expandability.
  * Header text is colored in the primary green.
* **Data Presentation (Read-Only):**
  * Data is displayed in clean, borderless rows or very light grid cells.
  * Dual-language labels persist, ensuring bilingual operators can review the exact output (e.g., `Date de déclaration` / `19-01-2023` / `تاريخ التصريح بالولادة`).
  * Values are displayed as static text, with inputs completely removed.
