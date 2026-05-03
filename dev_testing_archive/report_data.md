Below is a **clean, structured Markdown version**, arranged into logical tables.
You can copy–paste this directly into Markdown editors, GitHub, Notion, Obsidian, etc.

---

##  Cut List & Nesting Report

**Professional Manufacturing Analysis**
**Generated:** 2026-01-17, 5:35:57 PM

---

##  Project Summary

| Project Metric      | Value    |
| ------------------- | -------- |
| Total Parts         | 6        |
| Unique Components   | 6        |
| Material Sheets     | 4        |
| Kerf Width          | 12 mm    |
| Material Efficiency | 26.0%    |
| Total Waste Area    | 8.81 m³  |
| Total Cost          | SAR 0.00 |

---

##  Materials Used

| Material Type  | Sheets Required | Unit Cost | Total Cost |
| -------------- | --------------- | --------- | ---------- |
| Black Shaker   | 1               | SAR 0.00  | SAR 0.00   |
| Cherry Wood    | 1               | SAR 0.00  | SAR 0.00   |
| Maple Wood     | 1               | SAR 0.00  | SAR 0.00   |
| White Melamine | 1               | SAR 0.00  | SAR 0.00   |

---

##  Unique Part Types

| Part Name          | Width (mm) | Height (mm) | Thickness (mm) | Material       | Grain | Qty | Area (m²) |
| ------------------ | ---------- | ----------- | -------------- | -------------- | ----- | --- | --------- |
| Black_Panel_21x42  | 533.4      | 1066.8      | 19.1           | Black Shaker   | Any   | 1   | 0.6       |
| Black_Panel_24x42  | 609.6      | 1066.8      | 19.1           | Black Shaker   | Any   | 1   | 0.7       |
| Cherry_Panel_21x36 | 533.4      | 914.4       | 19.1           | Cherry Wood    | Any   | 1   | 0.5       |
| Cherry_Panel_24x36 | 609.6      | 914.4       | 19.1           | Cherry Wood    | Any   | 1   | 0.6       |
| Maple_Panel_24x30  | 609.6      | 762.0       | 19.1           | Maple Wood     | Any   | 1   | 0.5       |
| White_Panel_24x24  | 609.6      | 609.6       | 19.1           | White Melamine | Any   | 1   | 0.4       |

---

##  Sheet Inventory Summary

| Material       | Dimensions (mm) | Count | Total Area (m²) | Price / Sheet | Total Cost |
| -------------- | --------------- | ----- | --------------- | ------------- | ---------- |
| Black Shaker   | 2440 × 1220     | 1     | 3.0             | SAR 0.00      | SAR 0.00   |
| Cherry Wood    | 2440 × 1220     | 1     | 3.0             | SAR 0.00      | SAR 0.00   |
| Maple Wood     | 2440 × 1220     | 1     | 3.0             | SAR 0.00      | SAR 0.00   |
| White Melamine | 2440 × 1220     | 1     | 3.0             | SAR 0.00      | SAR 0.00   |

---

##  Cutting Diagrams (Efficiency Summary)

| Sheet | Material       | Efficiency | Waste |
| ----: | -------------- | ---------- | ----- |
|     1 | Cherry Wood    | 35.1%      | 64.9% |
|     2 | Black Shaker   | 41.0%      | 59.0% |
|     3 | Maple Wood     | 15.6%      | 84.4% |
|     4 | White Melamine | 12.5%      | 87.5% |

---

##  Cut Sequences — Sheet 1 (Cherry Wood)

**Stock Size:** 2440 × 1220 mm

| Step | Operation | Description                 | Measurement |
| ---- | --------- | --------------------------- | ----------- |
| 1    | Setup     | Prepare stock material      | 2440×1220   |
| 2    | Cut       | Cherry_Panel_24x36 – Length | 610 mm      |
| 3    | Cut       | Cherry_Panel_24x36 – Width  | 914 mm      |
| 4    | Edge Band | Apply edge banding          | None        |
| 5    | Cut       | Cherry_Panel_21x36 – Length | 533 mm      |
| 6    | Cut       | Cherry_Panel_21x36 – Width  | 914 mm      |
| 7    | Edge Band | Apply edge banding          | None        |

---

##  Cut Sequences — Sheet 2 (Black Shaker)

**Stock Size:** 2440 × 1220 mm

| Step | Operation | Description                | Measurement |
| ---- | --------- | -------------------------- | ----------- |
| 1    | Setup     | Prepare stock material     | 2440×1220   |
| 2    | Cut       | Black_Panel_24x42 – Length | 610 mm      |
| 3    | Cut       | Black_Panel_24x42 – Width  | 1067 mm     |
| 4    | Edge Band | Apply edge banding         | None        |
| 5    | Cut       | Black_Panel_21x42 – Length | 533 mm      |
| 6    | Cut       | Black_Panel_21x42 – Width  | 1067 mm     |
| 7    | Edge Band | Apply edge banding         | None        |

---

##  Cut Sequences — Sheet 3 (Maple Wood)

| Step | Operation | Description                | Measurement |
| ---- | --------- | -------------------------- | ----------- |
| 1    | Setup     | Prepare stock material     | 2440×1220   |
| 2    | Cut       | Maple_Panel_24x30 – Length | 610 mm      |
| 3    | Cut       | Maple_Panel_24x30 – Width  | 762 mm      |
| 4    | Edge Band | Apply edge banding         | None        |

---

##  Cut Sequences — Sheet 4 (White Melamine)

| Step | Operation | Description                | Measurement |
| ---- | --------- | -------------------------- | ----------- |
| 1    | Setup     | Prepare stock material     | 2440×1220   |
| 2    | Cut       | White_Panel_24x24 – Length | 610 mm      |
| 3    | Cut       | White_Panel_24x24 – Width  | 610 mm      |
| 4    | Edge Band | Apply edge banding         | None        |

---

##  Usable Offcuts

| Sheet # | Material       | Estimated Size (mm) | Area (m²) |
| ------: | -------------- | ------------------- | --------- |
|       1 | Cherry Wood    | 1952 × 990          | 1.932     |
|       2 | Black Shaker   | 1952 × 900          | 1.757     |
|       3 | Maple Wood     | 1952 × 1287         | 2.912     |
|       4 | White Melamine | 1952 × 1335         | 2.605     |

---

##  Cut List & Part Details

| Part ID | Name               | Dimensions (mm) | Material       | Sheet # | Grain | Edge Banding |
| ------: | ------------------ | --------------- | -------------- | ------- | ----- | ------------ |
|      P1 | Cherry_Panel_24x36 | 609.6 × 914.4   | Cherry Wood    | —       | Any   | None         |
|      P2 | Cherry_Panel_21x36 | 533.4 × 914.4   | Cherry Wood    | —       | Any   | None         |
|      P3 | Black_Panel_24x42  | 609.6 × 1066.8  | Black Shaker   | —       | Any   | None         |
|      P4 | Black_Panel_21x42  | 533.4 × 1066.8  | Black Shaker   | —       | Any   | None         |
|      P5 | Maple_Panel_24x30  | 609.6 × 762.0   | Maple Wood     | —       | Any   | None         |
|      P6 | White_Panel_24x24  | 609.6 × 609.6   | White Melamine | —       | Any   | None         |

---

**AutoNestCut Professional**
*Developed by Int. Arch. M. Shkeir*

---

If you want:

* the same output as **CSV / Excel**
* or auto-generated **Markdown from OCR directly**
* or a script that cleans OCR → tables automatically

Say the word and I’ll wire it properly.
