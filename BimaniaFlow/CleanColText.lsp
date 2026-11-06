;;; ==========================================================================
;;; CleanColText.lsp - 自動清除柱編號兩側的引號與符號
;;; 將 ""C11""、''C11''、˚C11˚、"C1" 自動清理為純淨的 C11、C1
;;; ==========================================================================

(defun c:CLEANCOL (/ ss i ent obj txt oldTxt cleaned count)
  (vl-load-com)
  (princ "\n正在搜尋圖面上的柱編號文字 (TEXT / MTEXT)...")
  
  ;; 抓取包含引號或特殊符號的文字物件
  (setq ss (ssget "X" '((0 . "TEXT,MTEXT"))))
  (setq count 0)
  
  (if ss
    (progn
      (repeat (setq i (sslength ss))
        (setq ent (ssname ss (setq i (1- i))))
        (setq obj (vlax-ename->vla-object ent))
        (setq txt (vlax-get-property obj 'TextString))
        (setq oldTxt txt)
        
        ;; 去除常見的各類引號與特殊符號
        (foreach sym '("\"" "'" "“" "”" "‘" "’" "˚" "°" "%%d" "%%D" "，" " ")
          (while (vl-string-search sym txt)
            (setq txt (vl-string-subst "" sym txt))
          )
        )
        
        ;; 如果文字有被修改，更新回 AutoCAD 物件
        (if (/= txt oldTxt)
          (progn
            (vlax-put-property obj 'TextString txt)
            (setq count (1+ count))
          )
        )
      )
      (vla-regen (vla-get-ActiveDocument (vlax-get-acad-object)) acActiveViewport)
      (princ (strcat "\n>>> 完成！共清理了 " (itoa count) " 個文字標籤。"))
    )
    (princ "\n未在圖面上找到任何文字物件。")
  )
  (princ)
)

(princ "\n[提示] 柱編號清理工具已載入！請在指令列輸入 CLEANCOL 並按 Enter 執行。")
(princ)

