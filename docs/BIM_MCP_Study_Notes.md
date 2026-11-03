# BIM & CAD MCP 研討與實務技術筆記

本文件記錄了在 **AutoCAD MCP**、**Revit MCP** 以及第三方外掛（如 BIMANIA、pyRevit、Dynamo）整合自動化應用過程中的關鍵架構探討、實務除錯經驗與解決方案。

---

## 目錄
1. [AutoCAD MCP 通訊協議與圖元定位技巧](#1-autocad-mcp-通訊協議與圖元定位技巧)
2. [Revit 自動化技術選型分析（BIMANIA vs pyRevit vs Dynamo vs MCP）](#2-revit-自動化技術選型分析)
3. [實務除錯案例：Revit 柱尺寸標註「視圖中沒有柱子」深度解析](#3-實務除錯案例revit-柱尺寸標註視圖中沒有柱子深度解析)
4. [專案工具庫索引](#4-專案工具庫索引)

---

## 1. AutoCAD MCP 通訊協議與圖元定位技巧

### 1.1 FastMCP Stdio 通訊穩定性修復
* **問題現象**：在命令列直接執行 `print()` 訊息至標準輸出（`sys.stdout`）時，會混入 MCP 標準 JSON-RPC 協議流中，導致 Claude / Gemini 等 MCP Client 解析封包失敗或斷線。
* **解決方式**：
  * 所有日誌訊息改由 `sys.stderr` 輸出：
    ```python
    print("AutoCAD MCP Server starting...", file=sys.stderr)
    ```
  * 加入 UTF-8 編碼強制重構，避免 Windows 環境下的中文編碼例外：
    ```python
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")
    ```

### 1.2 提升 AI 讀取 CAD 物件精確度：圖元 Handle 機制
* **痛點**：AI 透過自然語言或全圖掃描難以精確辨識使用者當前在 AutoCAD 視圖中「選取或關注」的特定圖元；若採用圖層隔離，AI 仍可能讀取到底層隱藏圖元。
* **解決之道**：利用 AutoCAD 原生的 **圖元處理碼（Handle）**。
* **工具配備**（收錄於 `autocad_hand_tool/`）：
  * `GetHand.lsp`：選取圖面物件後，依類型（TEXT、LWPOLYLINE、INSERT 等）快速輸出所有選取物件的 Handle 清單。
  * `SelHand.lsp`：輸入 Handle 即可精準定位與亮顯 CAD 圖元。
  * **人機協同工作流**：
    1. 使用者在 CAD 框選圖元並執行 `GETHAND`。
    2. 將 Handle 清單複製提供給 AI。
    3. AI 透過 Handle 直接鎖定目標進行精準解析（例如鋼構桿件尺寸表比對），零誤判且效能最高。

---

## 2. Revit 自動化技術選型分析

在 Revit 生態系中，常見以下四種擴充與自動化工具：

| 工具類型 | 技術本質 | 優勢 | 限制 / 缺點 | 最適合場景 |
| :--- | :--- | :--- | :--- | :--- |
| **BIMANIA (C# Add-in)** | 編譯型原生插件 (.NET DLL / WPF) | 介面美觀、執行效能極高、封裝完整、一鍵執行複雜算量或出圖流程。 | 封閉黑盒子、依賴原廠更新修復 Bug、難以靈活自訂規則。 | 重複性極高的標準作業流程、全事務所統一發布的制式工具列。 |
| **pyRevit** | 基於 IronPython / CPython 的腳本引擎 | 開箱即用、熱重載（修改程式碼不必重啟 Revit）、可自訂 Ribbon 按鈕。 | 對高運算量任務效能稍遜於原生 C#、維護需具備 Python 基礎。 | 事務所內部敏捷開發、自訂批次處理按鈕、快速試錯原型。 |
| **Dynamo** | 官方視覺化節點編程 (Visual Programming) | 門檻低、直觀視覺化、幾何計算與參數批次更新方便、內建於 Revit。 | 節點規模龐大時難以維護、執行速度較慢、難以做成複雜封閉 UI。 | 複雜參數化曲面造型、特定批次參數重填、輕量級自動化。 |
| **Revit MCP + AI** | 外部代理架構（基於 WebSocket / API） | 自然語言驅動、跨軟體協同（CAD 轉 Revit、比對圖說）、具備推理解析與靈活適應力。 | 需本機常駐通訊 Server、仰賴大模型 API 或本機推論環境。 | 跨軟體協同比對、自動化審查、AI 輔助建模與智慧除錯。 |

### 建議協同策略
1. **日常高頻單點功能**：以 C# Add-in 或 pyRevit 打造一鍵按鈕。
2. **跨軟體比對與智慧決策**：以 **Revit MCP + AutoCAD MCP** 為中樞，由 AI 自動判讀 CAD 圖紙尺寸並在 Revit 中比對或輔助建立構件。

---

## 3. 實務除錯案例：Revit 柱尺寸標註「視圖中沒有柱子」深度解析

### 3.1 問題現象
在 Revit 中開啟專案平面視圖（如 `1FL`，高程 500mm），圖面上清楚可見網格交點處有完整的結構柱符號（如 C1 柱）。但點擊 BIMANIA 工具列的「柱尺寸標註」時，彈出警告：
> **「LayRevit Addin Client - Column Dimension: 當前樓層視圖中沒有柱子」**

### 3.2 原因深入分析
透過 Revit MCP 檢索模型與反組譯 BIMANIA 的 `ColumnDimCommand` 與內部過濾邏輯：

1. **專案柱子存在性**：
   * 專案內確實存在 44 根結構柱（`OST_StructuralColumns`）。
2. **柱子的建模基準**：
   * 40 根方柱：**基準樓層（Base Level）= `FT`**（-1000mm），**頂部樓層 = `RFL`**（13400mm）或 `2FL`。
   * 4 根圓柱：**基準樓層（Base Level）= `GL`**（0mm），**頂部樓層 = `2FL`**（5000mm）。
   * 柱子採用業界標準的**「通柱／多樓層連續柱」**建模方式，由基礎底面一路貫穿至頂部。
3. **插件代碼缺陷**：
   BIMANIA 的過濾函式寫死了比對邏輯：
   ```csharp
   // 擷取自反組譯邏輯
   Parameter parameter = item.get_Parameter(BuiltInParameter.FAMILY_BASE_LEVEL_PARAM);
   if (parameter != null && parameter.AsElementId() == currentViewLevel.Id)
   {
       list.Add(item);
   }
   ```
   * 插件硬性規定「柱子的 Base Level 必須剛好等於當前視圖的樓層（`1FL`）」。
   * 因為這 44 根連續柱的 Base Level 全都是 `FT` 或 `GL`，即使它們在 `1FL` 清楚可見並被割面切到，仍被全部過濾掉，導致外掛誤判「沒有柱子」。

### 3.3 改善建議
* **回報原廠改進**：過濾視圖內可標註構件時，應以 **「視圖割面（Cut Plane）與圖元外框相交（BoundingBox Intersects）」** 或 `FilteredElementCollector(doc, view.Id)` 取代單純比對 `FAMILY_BASE_LEVEL_PARAM`。
* **MCP 替代方案**：直接使用 Revit MCP 的幾何擷取與尺寸標註工具（`create_dimension`），不受樓層參數硬編碼限制。

---

## 4. 專案工具庫索引
* **AutoCAD MCP 伺服端**：`MCP-Server/server.py`
* **AutoCAD 原生 Add-in**：`AutoCAD-MCP-Addin/`
* **CAD 圖元 Handle 工具庫**：`autocad_hand_tool/`
  * `GetHand.lsp`：批次提取 CAD 物件 Handle。
  * `SelHand.lsp`：依 Handle 快速反向選取圖元。
  * `CAD圖元說明.txt`：AI 與 CAD 圖元互動方法說明。

---

## 5. AutoCAD MCP 連線除錯與雙階段結構桿件比對實戰

### 5.1 AutoCAD MCP Socket 8965 埠衝突問題排除
- **現象**：AutoCAD 指令列出現 [MCP] Server start failed: 一次只能用一個通訊端位址 (通訊協定/網路位址/連接埠)。
- **根本原因**：AutoCAD 重啟或重新載入時，舊的處理程序仍短暫占用 8965 埠（TIME_WAIT 狀態），造成 SocketServer.Start() 拋出 SocketException。
- **標準解法**：
  1. 確認無殘留之 cad.exe 占用 8965 埠（透過 PowerShell Get-NetTCPConnection -LocalPort 8965 檢查）。
  2. 於 AutoCAD 頂部 Ribbon 之 **「MCP Tools」** 頁籤點選綠色 **「Start Server」**（或於指令列輸入 STARTMCP），即可成功啟動並監聽 127.0.0.1:8965。

### 5.2 結構圖說雙階段比對與建置規範（一次圖說 vs 二次圖說）
- **階段定義**：
  - **建照圖說** ＝ **一次圖說** ➔ 對應 Revit 專案階段 **「新營造」**。
  - **施工圖說** ＝ **二次圖說** ➔ 對應 Revit 專案階段 **「二次」**。
- **比對與建置規則**：
  1. **【共用】**：若一次（新營造）與二次（施工）皆存在且斷面尺寸一致，標註為 共用 (新營造建置)。在 Revit 中於「新營造」階段建立族群型式，二次階段直接延用。
  2. **【新建置】**：若二次圖說中出現新桿件（一次圖說無），標註為 新建置 (二次階段)。
  3. **【重新編號新建置】**：若同編號但在二次圖說尺寸改變，保留原編號於一次，二次圖說之構件重新編號為 編號-二次(原編號) 或 B2-1(B2)。

### 5.3 技能收錄
- 已收錄技能：skills/structure-member-size-summary/
- 支援透過 AutoCAD MCP 底圖讀取直接提取各樓層平面圖之梁柱版桿件尺寸表，並產出標準化 Excel 比對矩陣總表。
