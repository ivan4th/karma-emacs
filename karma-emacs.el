;; -*- lexical-binding: t -*-
;; TBD: faces in *karma-emacs*
;; TBD: stack handling
;; TBD: clear log before run
(require 'json)
(require 'simple-httpd)

(defvar karma-emacs-active-p t)
(defvar karma-emacs-running-p nil)
(defvar karma-emacs-run-total 0)
(defvar karma-emacs-run-success 0)
(defvar karma-emacs-run-failed 0)
(defvar karma-emacs-run-skipped 0)

(defgroup karma-emacs nil "karma-emacs options"
  :group 'applications)

(defface karma-emacs-error
  '((t (:foreground "red" :weight bold)))
  "karma-emacs error face"
  :group 'karma-emacs)

(defface karma-emacs-success
  '((t (:foreground "forestgreen" :weight bold)))
  "karma-emacs success face"
  :group 'karma-emacs)

(defface karma-emacs-skip
  '((t (:foreground "darkgoldenrod" :weight bold)))
  "karma-emacs face to be used when some tests are skipped"
  :group 'karma-emacs)

(defface karma-testfail
  '((t (:foreground "red")))
  "karma-emacs test failure face"
  :group 'karma-emacs)

(defface karma-log
  '((t (:foreground "yellowgreen")))
  "karma-emacs log face"
  :group 'karma-emacs)

(defun karma-emacs-make-preview-string ()
  "Karma preview")

(defun karma-emacs-buffer ()
  (get-buffer-create "*karma-emacs*"))

(defun karma-emacs-mode-line-string ()
  (if (not karma-emacs-active-p)
      ""
    (let ((s (format "(%d%s/%d%s%s)"
                     (+ karma-emacs-run-success karma-emacs-run-failed)
                     (if karma-emacs-running-p "…" "")
                     karma-emacs-run-total
                     (if (plusp karma-emacs-run-failed)
                         (format " %sF" karma-emacs-run-failed)
                       "")
                     (if (plusp karma-emacs-run-skipped)
                         (format " %sS" karma-emacs-run-skipped)
                       "")))
          (map (make-sparse-keymap)))
      (define-key map (vector 'mode-line 'mouse-2)
        `(lambda (e)
           (interactive "e")
           (message "Karma click")))
      (add-text-properties 0 (length s)
                           `(local-map ,map
                                       face ,(cond ((plusp karma-emacs-run-failed)
                                                    'karma-emacs-error)
                                                   ((plusp karma-emacs-run-skipped)
                                                    'karma-emacs-skip)
                                                   (t
                                                    'karma-emacs-success))
                                       mouse-face mode-line-highlight
                                       help-echo ,(concat
                                                   (karma-emacs-make-preview-string)
                                                   "\nmouse-2: visit web gmail"))
                           s)
      s)))

;; (setq httpd-root "/var/www")
(setf httpd-port 8008
      httpd-serve-files nil)
(httpd-start)
;; (httpd-stop)

(defun karma-emacs-clear-logs ()
  (with-current-buffer (karma-emacs-buffer)
    (erase-buffer)))

(defun karma-emacs-show-logs (logs)
  (with-current-buffer (karma-emacs-buffer)
    (cl-loop for log-item across logs
             do (let ((browser (aref log-item 0))
                      (type (aref log-item 1))
                      (message (aref log-item 2)))
                  (goto-char (point-max))
                  (let ((text (format "%s: %s\n" type message)))
                    (cond ((string= type "TESTFAIL")
                           (add-text-properties
                            0 (or (cl-position 10 text) (length text))
                            '(face karma-testfail) text))
                          ((string= type "LOG")
                           (add-text-properties
                            0 (length text) '(face karma-log) text)))
                    (insert text))))))

(defservlet karma/post text/plain (path query req)
  ;; (message "content: %S" content)
  (let* ((data (json-read-from-string (cadr (assoc "Content" req))))
         (logs (cdr (assoc 'logs data)))
         (status (cdr (assoc 'status data)))
         (was-running-p karma-emacs-running-p))
    ;; (message "data: %S" data)
    (when status
      (setf karma-emacs-running-p (eq (cdr (assoc 'running status)) t)
            karma-emacs-run-total (cdr (assoc 'total status))
            karma-emacs-run-success (cdr (assoc 'success status))
            karma-emacs-run-failed (cdr (assoc 'failed status))
            karma-emacs-run-skipped (cdr (assoc 'skipped status))))
    ;; FIXME: this doesn't work properly for some reason
    (when (and karma-emacs-running-p (not was-running-p))
      ;; (message "------------------- clear ---------------------")
      (karma-emacs-clear-logs))
    (when logs
      (karma-emacs-show-logs logs))
    (force-mode-line-update)
    (insert (json-encode
             (list (cons 'req data))
             ;; '((ok . t))
             ))))

;; (json-encode '((a . "3")))

;; TBD: global mode
(defun karma-emacs-start ()
  (interactive)
  (add-to-list 'global-mode-string
               '(:eval (karma-emacs-mode-line-string)) t))

(defun karma-emacs-stop ()
  (interactive)
  (setq global-mode-string
	(remove '(:eval (karma-emacs-mode-line-string))
		global-mode-string)))

(provide 'karma-emacs)
