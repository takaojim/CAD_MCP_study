(defun c:SELHAND (/ input handles h e ss ok missing)

  ;; 將常見分隔符統一轉成空格
  (defun NormalizeDelimiters (s / chars)
    (setq chars '("," "." ";" "|" "\t"))
    (foreach ch chars
      (while (vl-string-search ch s)
        (setq s (vl-string-subst " " ch s))
      )
    )
    s
  )

  ;; 依空白切割字串
  (defun SplitBySpace (s / pos result token)
    (setq result '())
    (setq s (vl-string-trim " " s))

    (while (> (strlen s) 0)
      (if (setq pos (vl-string-search " " s))
        (progn
          (setq token (substr s 1 pos))
          (setq s (vl-string-trim " " (substr s (+ pos 2))))
          (if (/= token "")
            (setq result (cons token result))
          )
        )
        (progn
          (setq result (cons s result))
          (setq s "")
        )
      )
    )

    (reverse result)
  )

  ;; 使用者輸入
  (setq input
    (getstring T
      "\n輸入 Handle 清單（可用空格、逗號、句點分隔）: "
    )
  )

  (if (/= input "")
    (progn

      (setq input   (NormalizeDelimiters input))
      (setq handles (SplitBySpace input))
      (setq ss      (ssadd))
      (setq ok      0)
      (setq missing 0)

      ;; Handle -> Entity
      (foreach h handles

        (setq h (vl-string-trim " " h))
        (setq e (handent h))

        (if e
          (progn
            (ssadd e ss)
            (setq ok (1+ ok))
          )
          (progn
            (setq missing (1+ missing))
            (princ
              (strcat "\n找不到 Handle: " h)
            )
          )
        )
      )

      ;; 選取找到的物件
      (if (> (sslength ss) 0)
        (progn
          (sssetfirst nil ss)

          (princ
            (strcat
              "\nSELHAND 完成：已選取 "
              (itoa ok)
              " 個物件。"
            )
          )
        )
        (princ "\n沒有找到任何有效的 Handle。")
      )

      (if (> missing 0)
        (princ
          (strcat
            "\n找不到："
            (itoa missing)
            " 個 Handle。"
          )
        )
      )
    )
  )

  (princ)
)