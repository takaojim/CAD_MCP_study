---
name: structure-member-size-summary
description: Convert structural drawing CAD files (via AutoCAD MCP), PDFs, images, or tables into a normalized cross-floor Excel workbook, with support for comparing two-phase structural drawings (建照/新營造 vs 施工/二次). Use when the user asks for 結構桿件尺寸總表, 桿件尺寸, 各樓層結構桿件尺寸, 桿件尺寸表, 梁柱版尺寸整理, 結構圖PDF轉Excel, 結構圖桿件比對, 執行結構桿件比對, 比對結構圖桿件尺寸, or wants member sizes compared across floors and phases.
---

# Structure Member Size Summary

## Purpose

Use this skill to turn structural member size schedules from CAD drawings (via AutoCAD MCP), PDFs, images, or extracted tables into a normalized Excel workbook for checking column, beam, small beam, slab, and foundation dimensions across floors and project phases.

Use the openpyxl runtime for the final .xlsx output.

## Workflow

1. Read the source file or CAD drawing.
   - For CAD drawings: Read directly via AutoCAD MCP (port 8965) or inspection of floor plan schedules.
   - For PDF/images: Extract text or render high-resolution images.
   - Preserve the original floor label shown on each page, such as 1F, 1MF, 2F, 3F, 4F, RF, PRF.
2. Extract source rows per floor with these fields:
   - floor
   - original category
   - original member number
   - original RC / SS section size
3. Normalize into a cross-floor matrix:
   - Columns: 結構名稱, 構件編號, 材料/斷面規格, 階段歸屬 / 比對結果, floors from low to high, 備註.
   - Floor columns should sort as B/F levels if present, then 1F, 1MF (if present), 2F, ... , roof floors such as RF, PRF.
   - Use - when the member does not exist on that floor.
4. Split merged member numbers before building the matrix:
   - FB*、FG* -> FB* and FG*
   - FB2、FG2 -> FB2 and FG2
   - B1、G1 -> B1 and G1
5. Compare dimensions floor by floor and phase by phase:
   - If the same member number has different sizes across floors or phases, create additional traceable rows (e.g. B2-二次(B2) or B2-1(B2)).
6. Build an Excel workbook and verify it before finalizing.

## Normalization Rules

Rows must be grouped and sorted in this order:

1. 柱
2. 大梁
3. 小梁
4. 版
5. 基礎大梁
6. 基礎小梁
7. 基礎版

Within 大梁, list B series before G series. Within 小梁, list  series before g series.

Split combined labels into independent rows:
- B1、G1 -> B1 and G1
- 1、g1 -> 1 and g1
- FB*、FG* -> FB* and FG*
- FB2、FG2 -> FB2 and FG2

## CAD MCP & Phase Comparison Rules (一次新營造 vs 二次)

When reading directly via AutoCAD MCP or comparing two drawing sets (建照 vs 施工):

1. **Phase Mapping**:
   - 建照圖說: 一次圖說 (對應專案階段: 新營造 / Phase 1)。
   - 施工圖說: 二次圖說 (對應專案階段: 二次 / Phase 2)。
2. **Comparison Logic**:
   - **共用 (Shared)**: 若一次與二次皆存在且斷面尺寸一致，標註為 共用 (新營造建置)，在 Revit 中於新營造階段建置，二次階段延用。
   - **新建置 (New)**: 若二次圖說中出現新桿件（一次圖說無），標註為 新建置 (二次階段)。
   - **變更斷面重新編號 (Re-numbered)**: 若同編號但在二次圖說尺寸改變，保留原編號於一次，二次圖說之構件重新編號為 編號-二次(原編號) 或 B2-1(B2) 並標註尺寸變更。

## Excel Output

Create a workbook with these sheets:

- 總表: normalized cross-floor matrix with frozen headers and phase tagging.
- 逐頁來源: compact extracted source rows for audit and traceability.
- 檢查: pass/fail checklist for floor ordering, splitting, size changes, and phase verification.
