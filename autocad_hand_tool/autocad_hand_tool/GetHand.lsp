(vl-load-com)

;; ============================================================
;; 將字串清單組合成單一字串
;; 例如：("1503" "1504" "1508") → "1503、1504、1508"
;; ============================================================

(defun GH:Join (items delimiter / result)
  (if items
    (progn
      (setq result (car items))
      (foreach item (cdr items)
        (setq result (strcat result delimiter item))
      )
    )
    (setq result "")
  )
  result
)


;; ============================================================
;; 依物件類型分類 Handle
;; ============================================================

(defun GH:GroupByType (ss / result index entity data entityType handle item)
  (setq result '())
  (setq index 0)

  (while (< index (sslength ss))
    (setq entity (ssname ss index))
    (setq data (entget entity))
    (setq entityType (cdr (assoc 0 data)))
    (setq handle (cdr (assoc 5 data)))

    (if (and entityType handle)
      (progn
        (setq item (assoc entityType result))
        (if item
          (setq result
            (subst
              (append item (list handle))
              item
              result
            )
          )
          (setq result
            (append
              result
              (list (list entityType handle))
            )
          )
        )
      )
    )
    (setq index (1+ index))
  )
  result
)


;; ============================================================
;; 擷取選取物件的詳細文字與屬性內容
;; 包含：TEXT/MTEXT 文字、DIMENSION 標註、INSERT 圖塊名稱
;; ============================================================

(defun GH:ExtractDetails (ss / details index entity data entityType handle txt blk)
  (setq details '())
  (setq index 0)

  (while (< index (sslength ss))
    (setq entity (ssname ss index))
    (setq data (entget entity))
    (setq entityType (cdr (assoc 0 data)))
    (setq handle (cdr (assoc 5 data)))
    (setq txt nil)
    (setq blk nil)

    (cond
      ;; 單行文字或多行文字
      ((or (= entityType "TEXT") (= entityType "MTEXT"))
        (setq txt (cdr (assoc 1 data)))
        (if (and txt (/= txt ""))
          (setq details
            (append details
              (list (strcat "[" handle "] (" entityType ") " txt))
            )
          )
        )
      )
      ;; 尺寸標註
      ((= entityType "DIMENSION")
        (setq txt (cdr (assoc 1 data)))
        (if (and txt (/= txt ""))
          (setq details
            (append details
              (list (strcat "[" handle "] (DIMENSION) " txt))
            )
          )
        )
      )
      ;; 圖塊參照
      ((= entityType "INSERT")
        (setq blk (cdr (assoc 2 data)))
        (if blk
          (setq details
            (append details
              (list (strcat "[" handle "] (INSERT圖塊: " blk ")"))
            )
          )
        )
      )
    )
    (setq index (1+ index))
  )
  details
)


;; ============================================================
;; 將分類資料轉成文字清單
;; ============================================================

(defun GH:BuildLines (groups / lines group entityType handles)
  (setq lines '())
  (foreach group groups
    (setq entityType (car group))
    (setq handles (cdr group))
    (setq lines
      (append
        lines
        (list
          (strcat
            entityType
            "  "
            (GH:Join handles "、")
          )
        )
      )
    )
  )
  lines
)


;; ============================================================
;; 建立剪貼簿文字（包含 Handle 分類清單 與 詳細文字解析）
;; ============================================================

(defun GH:BuildClipboardText (lines details / text)
  (setq text (GH:Join lines "\r\n"))
  (if details
    (setq text
      (strcat
        text
        "\r\n\r\n--- 【文字與內容解析明細 (共 "
        (itoa (length details))
        " 項)】---\r\n"
        (GH:Join details "\r\n")
      )
    )
  )
  text
)


;; ============================================================
;; 複製文字到 Windows 剪貼簿
;; ============================================================

(defun GH:CopyToClipboard (text / result html window clipboard)
  (setq result
    (vl-catch-all-apply
      '(lambda ()
        (setq html (vlax-create-object "htmlfile"))
        (setq window (vlax-get-property html 'ParentWindow))
        (setq clipboard (vlax-get-property window 'ClipboardData))
        (vlax-invoke-method clipboard 'SetData "Text" text)
      )
    )
  )
  (if (and clipboard (= (type clipboard) 'VLA-OBJECT))
    (vlax-release-object clipboard)
  )
  (if (and window (= (type window) 'VLA-OBJECT))
    (vlax-release-object window)
  )
  (if (and html (= (type html) 'VLA-OBJECT))
    (vlax-release-object html)
  )
  (not (vl-catch-all-error-p result))
)


;; ============================================================
;; 建立暫存 DCL 檔案
;; ============================================================

(defun GH:CreateDCL (/ filePath fileObject)
  (setq filePath (vl-filename-mktemp "GETHAND" nil ".dcl"))
  (setq fileObject (open filePath "w"))
  (if fileObject
    (progn
      (write-line "gethand_dialog : dialog {" fileObject)
      (write-line "  label = \"物件性質與處理碼 (含文字解析)\";" fileObject)
      (write-line "  : column {" fileObject)
      (write-line "    : text {" fileObject)
      (write-line "      label = \"下列圖元 Handle 與文字內容已自動複製到剪貼簿：\";" fileObject)
      (write-line "    }" fileObject)
      (write-line "    : list_box {" fileObject)
      (write-line "      key = \"handle_list\";" fileObject)
      (write-line "      width = 76;" fileObject)
      (write-line "      height = 18;" fileObject)
      (write-line "      fixed_width_font = true;" fileObject)
      (write-line "      multiple_select = false;" fileObject)
      (write-line "    }" fileObject)
      (write-line "    : text {" fileObject)
      (write-line "      key = \"summary\";" fileObject)
      (write-line "      label = \"\";" fileObject)
      (write-line "    }" fileObject)
      (write-line "  }" fileObject)
      (write-line "  ok_only;" fileObject)
      (write-line "}" fileObject)
      (close fileObject)
      filePath
    )
    nil
  )
)


;; ============================================================
;; 顯示 DCL 對話窗
;; ============================================================

(defun GH:ShowDialog (lines details entityCount typeCount clipboardOK
                      / dclPath dclID displayList summaryText)
  (setq dclPath (GH:CreateDCL))
  (if dclPath
    (progn
      (setq dclID (load_dialog dclPath))
      (if (and (> dclID 0) (new_dialog "gethand_dialog" dclID))
        (progn
          (start_list "handle_list")
          (foreach line lines (add_list line))
          (if details
            (progn
              (add_list "----------------------------------------")
              (add_list (strcat "--- 【文字解析 (共 " (itoa (length details)) " 項)】---"))
              (foreach d details (add_list d))
            )
          )
          (end_list)

          (setq summaryText
            (strcat
              "共選取 " (itoa entityCount) " 個物件，"
              (itoa typeCount) " 種圖元類型"
              (if details (strcat "，解析出 " (itoa (length details)) " 項文字") "")
              "。"
              (if clipboardOK " 已完整複製到剪貼簿。" " 剪貼簿複製失敗。")
            )
          )
          (set_tile "summary" summaryText)
          (action_tile "accept" "(done_dialog 1)")
          (start_dialog)
        )
        (prompt "\n無法建立 GETHAND 對話窗。")
      )
      (if (> dclID 0) (unload_dialog dclID))
      (if (findfile dclPath) (vl-file-delete dclPath))
    )
    (prompt "\n無法建立暫存 DCL 檔案。")
  )
  (princ)
)


;; ============================================================
;; 主指令：GETHAND
;; ============================================================

(defun c:GETHAND (/ ss groups details lines clipboardText clipboardOK)
  (vl-load-com)

  ;; 優先讀取目前已預選的物件
  (setq ss (ssget "_I"))

  ;; 如果沒有預選物件，再讓使用者框選
  (if (null ss)
    (progn
      (prompt "\n請選取要取得物件性質與處理碼的物件，完成後按 Enter：")
      (setq ss (ssget))
    )
  )

  (if ss
    (progn
      (sssetfirst nil nil)

      ;; 依物件類型分類 Handle
      (setq groups (GH:GroupByType ss))

      ;; 擷取文字與圖塊屬性明細
      (setq details (GH:ExtractDetails ss))

      ;; 建立分類文字行
      (setq lines (GH:BuildLines groups))

      ;; 建立剪貼簿文字（Handle + 文字內容）
      (setq clipboardText (GH:BuildClipboardText lines details))

      ;; 寫入剪貼簿
      (setq clipboardOK (GH:CopyToClipboard clipboardText))

      (prompt "\n\n========== 物件性質與處理碼 ==========")
      (foreach line lines (prompt (strcat "\n" line)))
      (if details
        (progn
          (prompt "\n--- 文字內容解析 ---")
          (foreach d details (prompt (strcat "\n" d)))
        )
      )
      (prompt
        (strcat
          "\n========================================"
          "\n共選取 " (itoa (sslength ss)) " 個物件，"
          (itoa (length groups)) " 種物件類型。"
        )
      )

      (if clipboardOK
        (prompt "\n清單與文字內容已成功複製到 Windows 剪貼簿。")
        (prompt "\n警告：無法複製到 Windows 剪貼簿。")
      )

      ;; 彈出結果對話窗
      (GH:ShowDialog lines details (sslength ss) (length groups) clipboardOK)
    )
    (prompt "\n沒有選取任何物件。")
  )
  (princ)
)
