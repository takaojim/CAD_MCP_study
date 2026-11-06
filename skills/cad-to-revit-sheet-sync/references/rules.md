# Rules and Validation Checklist

## 1. Multi-source Cross Validation Checklist
- [ ] **CAD Table Text**: Extract raw `SheetNumber` and `SheetName` from DWG / PDF table cells.
- [ ] **Directory File Consistency**: Verify that corresponding DWG or PDF files exist in the project folder.
- [ ] **Typo / Duplicate Correction**:
  - If a table entry duplicates an earlier entry's `SheetNumber` but represents higher floors, check the physical file name and floor sequence logic.
  - Automatically correct the number (e.g. `S1-P02` for roof -> `S1-P03`) and log the change to user.
- [ ] **Revit Existing Sheets**: Read all existing sheets in Revit before creating new ones; skip any sheets that already exist to avoid Revit API duplicate number errors.

## 2. Revit Sheet Standards
- **TitleBlock Selection**:
  - Query existing titleblocks using `revit:query_elements(category="圖框")` or `revit:get_titleblocks()`.
  - Prefer the active project office titleblock (e.g. `陳敬傑建築師事務所A1`, Element ID `648261`).
- **Sheet List Schedule**:
  - After creating sheets, call `revit:read_schedule` to confirm they automatically appear in the project's `圖紙清單` schedule.
