;;; regexp-expand-test.el --- Tests for regexp-expand.el. -*- lexical-binding: t; -*-

;; Copyright (C) 2020  Daniel Martín

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

(require 'regexp-expand)
(require 'ert)

;; Helpers
(defun check-regexp-explanation (regexp)
  "Check if calling `regexp-expand' on REGEXP adds a correct overlay to the buffer."
  (with-temp-buffer
    (insert (prin1-to-string regexp))
    (goto-char (point-min))
    (regexp-expand)
    (should (equal (overlay-get regexp-expand-overlay 'regexp-expand-original-regexp)
                   (prin1-to-string regexp)))
    (should (equal (buffer-substring-no-properties (overlay-start regexp-expand-overlay)
                                                   (overlay-end regexp-expand-overlay))
                   (string-trim-right
                    (xr-pp-rx-to-str
                     (xr regexp)))))))

;; Regexp texts
(ert-deftest regexp-expand-no-regexp ()
  (check-regexp-explanation "Hello"))

(ert-deftest regexp-expand-regexp ()
  (check-regexp-explanation "\\([0-9]\\{5\\}\\): \\([0-9]\\{10\\}\\) \\([0-9]\\{5\\}\\) \\(.\\)"))

(ert-deftest regexp-expand-regexp-with-control-characters ()
  (check-regexp-explanation "^\\([^: \n\t]+\\): line \\([0-9]+\\):"))

(ert-deftest regexp-expand-regexp-multiline ()
  (check-regexp-explanation "\\(?:^cucumber\\(?: -p [^[:space:]]+\\)?\\|#\\)\
\\(?: \\)\\([^(].*\\):\\([1-9][0-9]*\\)"))

(ert-deftest regexp-expand-regexp-string-quote ()
  (check-regexp-explanation "\\s\""))

(ert-deftest regexp-expand-not-string ()
  (should-error
   (with-temp-buffer
     (insert "Not a string constant")
     (goto-char (point-min))
     (regexp-expand))))

;; Minor mode behavior tests
(ert-deftest regexp-expand-enter-mode ()
  (with-temp-buffer
    (insert (prin1-to-string "Hello"))
    (goto-char (point-min))
    (regexp-expand)
    (should (bound-and-true-p regexp-expand-mode))))

(ert-deftest regexp-expand-enter-mode-inserts-rx-notation-in-buffer ()
  (with-temp-buffer
    (insert (prin1-to-string
             "\\([0-9]\\{5\\}\\): \\([0-9]\\{10\\}\\) \\([0-9]\\{5\\}\\) \\(.\\)"))
    (goto-char (point-min))
    (regexp-expand)
    (should (equal (buffer-substring-no-properties (point-min) (point-max))
                   "(seq (group
      (= 5
         (any \"0-9\")))
     \": \"
     (group
      (= 10
         (any \"0-9\")))
     \" \"
     (group
      (= 5
         (any \"0-9\")))
     \" \"
     (group nonl))"))))

(ert-deftest regexp-expand-buffer-should-not-be-writable ()
  (should-error
   (with-temp-buffer
     (insert (prin1-to-string "Hello"))
     (goto-char (point-min))
     (regexp-expand)
     (insert "Buffer should not be modifiable"))))

(ert-deftest regexp-expand-exit-mode ()
  (with-temp-buffer
    (insert (prin1-to-string "Hello"))
    (goto-char (point-min))
    (regexp-expand)
    (call-interactively (key-binding (kbd "q")))
    (should-not (bound-and-true-p regexp-expand-mode))))

(ert-deftest regexp-expand-exit-mode-restores-original-regexp ()
  (with-temp-buffer
    (insert (prin1-to-string "Hello"))
    (goto-char (point-min))
    (regexp-expand)
    (call-interactively (key-binding (kbd "q")))
    (should (equal (buffer-substring-no-properties (point-min) (point-max))
                   "\"Hello\""))))

(ert-deftest regexp-expand-exit-mode-buffer-is-not-modified ()
  (with-temp-buffer
    (with-silent-modifications
      (insert (prin1-to-string "Hello")))
    (goto-char (point-min))
    (regexp-expand)
    (call-interactively (key-binding (kbd "q")))
    (should-not (buffer-modified-p))))

(ert-deftest regexp-expand-exit-mode-buffer-was-modified-before ()
  (with-temp-buffer
    (insert (prin1-to-string "Hello"))
    (goto-char (point-min))
    (regexp-expand)
    (call-interactively (key-binding (kbd "q")))
    (should (buffer-modified-p))))

(ert-deftest regexp-expand-exit-mode-persists-undo ()
  (with-current-buffer (get-buffer-create "Undo Test")
    (insert (prin1-to-string "Hello"))
    (setq before-buffer-undo-list buffer-undo-list)
    (goto-char (point-min))
    (regexp-expand)
    (call-interactively (key-binding (kbd "q")))
    (should (and
             buffer-undo-list
             (> (length buffer-undo-list) 0)
             (equal before-buffer-undo-list buffer-undo-list)))))
