;;; regexp-expand.el --- Show the ELisp regular expression at point in `rx' form. -*- lexical-binding: t; -*-

;; Copyright (C) 2020  Daniel Martín

;; Author: Daniel Martín <mardani29@yahoo.es>
;; URL: https://github.com/danielmartin/regexp-expand
;; Keywords: lisp, regexps, debugging
;; Version: 0.1
;; Package-Requires: ((emacs "25.1") (xr "1.18"))

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

;;; Commentary:

;; This package shows an overlay with the regexp at point in `rx'
;; notation, by using the `xr' package
;; (https://elpa.gnu.org/packages/xr.html).  Regexps in `rx' notation
;; are much more readable than in their original string form,
;; specially if they contain a lot of backslashes.

;;; Code:

(require 'xr)

(defgroup regexp-expand nil
  "Explain the Emacs List regular expression at point."
  :group 'lisp
  :link '(url-link :tag "web page" "https://github.com/danielmartin/regexp-expand"))

(defface regexp-expand-highlight-face
  '((((min-colors 16581375) (background light)) :background "#eee8d5")
    (((min-colors 16581375) (background dark)) :background "#222222"))
  "Face for regular expression explanation highlight."
  :group 'regexp-expand)

(defvar regexp-expand-overlay nil
  "`regexp-expand' overlay in the current buffer.")
(make-variable-buffer-local 'regexp-expand-overlay)

(defvar regexp-expand-explain-function
  #'regexp-expand-explain
  "Function to explain the regular expression at point.")

(defun regexp-expand--point-inside-string-p ()
  "Return if point is inside a string."
  (nth 3 (syntax-ppss)))

(defun regexp-expand--move-point-backward-outside-of-string ()
  "Move point backward to place it one position before the first character in a string."
  (goto-char (nth 8 (syntax-ppss))))

(defun regexp-expand--move-point-forward-outside-of-string ()
  "Move point forward to place it one position after the last character in a string."
  (regexp-expand--move-point-backward-outside-of-string)
  (forward-sexp))

(defun regexp-expand--looking-back-on-line (regexp)
  "Return non-nil if there is a match for REGEXP in the text before point in the current line."
  (looking-back regexp (line-beginning-position)))

(defun regexp-expand--bounds-of-string-at-point ()
  "Return the start and end locations for the string at point.
If the point is not inside a string, return nil."
  (save-excursion
    (if (regexp-expand--point-inside-string-p)
        (regexp-expand--move-point-backward-outside-of-string)
      (when (regexp-expand--looking-back-on-line "\\s\"")
        (backward-char)
        (regexp-expand--move-point-backward-outside-of-string)))
    (when (looking-at "\\s\"")
      (let (beg end)
        (setq beg (copy-marker (point)))
        (forward-char)
        (regexp-expand--move-point-forward-outside-of-string)
        (setq end (point))
        (cons beg end)))))

(defun regexp-expand--collapse-overlay (overlay)
  "Collapse a regular expression explanation represented by OVERLAY and restore the original text."
  (with-current-buffer (overlay-buffer overlay)
    (let* ((start (overlay-start overlay))
           (end (overlay-end overlay))
           (text (overlay-get overlay 'regexp-expand-original-regexp))
           (regexp-end
            (copy-marker
             (if (equal (char-before end) ?\n) (1- end) end))))
      (goto-char start)
      (save-excursion
        (insert text)
        (delete-region (point) regexp-end)))
    (let ((highlight-overlay (overlay-get overlay 'regexp-expand-highlight-overlay)))
      (when highlight-overlay (delete-overlay highlight-overlay)))
    (delete-overlay overlay)))

(defun regexp-expand-collapse ()
  "Collapse the current regexp explanation and disable `regexp-expand-mode'."
  (interactive)
  (let ((inhibit-read-only t))
    (with-silent-modifications
      (regexp-expand--collapse-overlay regexp-expand-overlay)))
  (setq regexp-expand-overlay nil)
  (regexp-expand-mode 0))

(defun regexp-expand-command-hook ()
  "Disable `regexp-expand-mode' if the buffer is writable."
  (if (not buffer-read-only)
      (regexp-expand-mode 0)))

(defun regexp-expand-explain (regexp)
  "Run `xr' to convert REGEXP to an `rx' form."
  (insert (string-trim-right (xr-pp-rx-to-str (xr regexp)))))

(defun regexp-expand-explain-rx-syntax ()
  "Show a help buffer that documents the Lisp syntax of `rx' forms."
  (interactive)
  (describe-function #'rx))

(defvar regexp-expand-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map "e" #'regexp-expand-explain-rx-syntax)
    (define-key map "q" #'regexp-expand-collapse)
    map)
  "Keymap for `regexp-expand-mode'.")

;;;###autoload
(define-minor-mode regexp-expand-mode
  "Minor mode for inline explanation of regular expressions in Emacs Lisp source buffers."
  nil " Regexp-Expand"
  :keymap regexp-expand-keymap
  :group regexp-expand
  (if regexp-expand-mode
      ;; Enter the minor mode.
      (progn
        ;; Persist undo information as we need to restore it when the
        ;; user exits the mode.
        (setq regexp-expand-saved-undo-list buffer-undo-list
              buffer-undo-list t)
        ;; We also need to persist the read-only status of the current
        ;; buffer and set it to read-only.
        (setq regexp-expand-saved-read-only buffer-read-only
              buffer-read-only t)
        (add-hook 'post-command-hook #'regexp-expand-command-hook nil t)
        (message
         (substitute-command-keys
          "\\<regexp-expand-keymap>Press \\[regexp-expand-explain-rx-syntax] for more information about `rx' syntax, or \\[regexp-expand-collapse] to show the regular expression as a string again.")))
    ;; Exit the minor mode.
    (when regexp-expand-overlay (regexp-expand-collapse))
    (setq buffer-undo-list regexp-expand-saved-undo-list
          buffer-read-only regexp-expand-saved-read-only
          regexp-expand-saved-undo-list nil)
    (remove-hook 'post-command-hook #'regexp-expand-command-hook t)))

(defun regexp-expand--pretty-print-explanation ()
  "Pretty prints the ELisp expression at point."
  (save-excursion
    (backward-sexp)
    (indent-pp-sexp)))

;;;###autoload
(defun regexp-expand ()
  "Explain the Emacs Lisp regular expression following point."
  (interactive)
  (pcase-let ((`(,start . ,end) (regexp-expand--bounds-of-string-at-point)))
    (unless (or start end)
      (error "Point is not in a string"))
    (setq end (copy-marker end))
    (goto-char start)
    (let ((regexp (save-excursion (read (current-buffer))))
          ;; We need to keep the original regexp around to put it back
          ;; in the buffer when the mode is disabled.
          (original-regexp (buffer-substring-no-properties start end)))
      (unless regexp-expand-mode (regexp-expand-mode t))
      (with-silent-modifications
        (atomic-change-group
          (let ((inhibit-read-only t))
            (save-excursion
              (funcall regexp-expand-explain-function regexp)
              (regexp-expand--pretty-print-explanation)
              (delete-region (point) end)
              ;; Create a new overlay.
              (let* ((overlay
                      (make-overlay start
                                    (if (looking-at "\n")
                                        (progn
                                          (1+ (point)))
                                      (point))))
                     (highlight-overlay (copy-overlay overlay)))
                (overlay-put highlight-overlay 'face 'regexp-expand-highlight-face)
                (overlay-put highlight-overlay 'priority -1)
                (overlay-put overlay 'regexp-expand-highlight-overlay highlight-overlay)
                (overlay-put overlay 'priority 1)
                (overlay-put overlay 'regexp-expand-original-regexp original-regexp)
                (setq regexp-expand-overlay overlay)))))))))

(provide 'regexp-expand)

;;; regexp-expand.el ends here
