;;; org-contactsx.el --- Contacts management system for Org Mode -*- lexical-binding: t; -*-

;; Copyright (C) 2022 Thomas Freeman, org-contactsx.el
;; Copyright (C) 2010-2014, 2021 Julien Danjou <julien@danjou.info>, org-contacts.el

;; Author: Thomas Freeman
;; Maintainer: Thomas Freeman
;; Keywords: contacts, org-mode, outlines, hypermedia, calendar
;; Version: 0.1
;; Package-Requires: ((emacs "27.1") (cl-lib "0.7") (org "9.3.4") (gnus "5.13"))
;; Homepage: https://github.com/tfree87/org-contacts-extended
;;
;; This file is not part of GNU Emacs.
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:

;; This file contains the code for managing your contacts into Org-mode.

;; To enter new contacts, you can use `org-capture' and a minimal template just like
;; this:

;;         ("c" "Contacts" entry (file "~/Org/contacts.org")
;;          "* %(org-contactsx-template-name)
;; :PROPERTIES:
;; :EMAIL: %(org-contactsx-template-email)
;; :END:")))
;;
;; You can also use a complex template, for example:
;;
;;         ("c" "Contacts" entry (file "~/Org/contacts.org")
;;          "* %(org-contactsx-template-name)
;; :PROPERTIES:
;; :EMAIL: %(org-contactsx-template-email)
;; :PHONE:
;; :ALIAS:
;; :IGNORE:
;; :ICON:
;; :NOTE:
;; :ADDRESS:
;; :BIRTHDAY:
;; :END:")))

;;;; Usage:

;;; How to search?
;;; - You can use [M-x org-contactsx] command to search.
;;;
;;; - You can use `org-sparse-tree' [C-c / p] to filter based on a
;;;   specific property. Or other matcher on `org-sparse-tree'.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'gnus-util)
(require 'gnus-art)
(require 'mail-utils)
(require 'org-agenda)
(require 'org-capture)
(require 'ol)

(defgroup org-contactsx nil
  "Options for Org Contacts Extended."
  :group 'org)

(defcustom org-contacts-files nil
  "List of Org files to use as contacts source.
When set to nil, all your Org files will be used."
  :type '(repeat file))

(defcustom org-contactsx-address-default-property "ADDRESS"
  "The default address name used for templates."
  :type 'string)

(defcustom org-contactsx-address-properties '("ADDRESS"
                                              "OTHER_ADDRESS"
                                              "HOME_ADDRESS"
                                              "WORK_ADDRESS")
  "A list of properties defining addresses for the contact."
  :type '(repeat string))

(defcustom org-contactsx-alias-default-property "ALIAS"
  "Name of the property for contact name alias."
  :type 'string)

(defcustom org-contactsx-alias-properties '("ALIAS"
                                            "AKA"
                                            "NICKNAME")
  "A list of properties defining aliases for the contact."
  :type '(repeat string))

(defcustom org-contactsx-anniv-format "Anniversary: %l (%Y)"
  "Format of the anniversary agenda entry.
The following replacements are available:

  %h - Heading name
  %l - Link to the heading
  %y - Number of year
  %Y - Number of year (ordinal)"
  :type 'string)

(defcustom org-contactsx-anniv-default-property "ANNIVERSARY"
  "The default anniversary name used for templates."
  :type 'string)

(defcustom org-contactsx-anniv-properties '("ANNIVERSARY"
                                           "WEDDING_ANNIVERSARY"
                                           "WORK_ANNIVERSARY")
  "A list of properties defining anniversary dates for the contact."
  :type '(repeat string))

(defcustom org-contactsx-birthday-format "Birthday: %l (%Y)"
  "Format of the birthday anniversary agenda entry.
The following replacements are available:

  %h - Heading name
  %l - Link to the heading
  %y - Number of year
  %Y - Number of year (ordinal)"
  :type 'string)

(defcustom org-contactsx-birthday-default-property "BIRTHDAY"
  "Name of the property for contact birthday date."
  :type 'string)

(defcustom org-contactsx-birthday-properties '("BIRTHDAY")
  "A list of properties defining companies for the contact."
  :type '(repeat string))

(defcustom org-contactsx-company-default-property "COMPANY"
  "The default company property name used for templates."
  :type 'string)

(defcustom org-contactsx-company-properties '("COMPANY"
                                              "EMPLOYER")
  "A list of properties defining companies for the contact."
  :type '(repeat string))

(defcustom org-contactsx-dept-default-property "DEPARTMENT"
  "The default department property name used for templates."
  :type 'string)

(defcustom org-contactsx-dept-properties '("DEPARTMENT"
                                           "BRANCH"
                                           "SUBDIVISION")
  "A list of properties defining dpartments for the contact."
  :type '(repeat string))

(defcustom org-contactsx-email-default-property "EMAIL"
  "The default email name used for templates."
  :type 'string)

(defcustom org-contactsx-email-properties '("EMAIL"
                                            "WORK_EMAIL"
                                            "PERSONAL_EMAIL"
                                            "OTHER_EMAIL")
  "A list of properties defining email addresses for the contact."
  :type '(repeat string))

(defcustom org-contactsx-irc-property "IRC"
  "The default property defining the contact's IRC nickname."
  :type 'string)

(defcustom org-contactsx-job-default-property "JOB_TITLE"
  "The default job title used for templates."
  :type 'string)

(defcustom org-contactsx-job-properties '("JOB_TITLE"
                                          "ROLE"
                                          "RESPONSIBILITY")
  "A list of properties defining job titles for the contact."
  :type '(repeat string))

(defcustom org-contactsx-chat-default-property "MESSENGER"
  "The default chat nickname used for templates."
  :type 'string)

(defcustom org-contactsx-chat-properties '("MESSENGER"
                                           "BONJOUR"
                                           "IRC"
                                           "JABBER"
                                           "SKYPE")
  "A list of properties defining chat nicknames for the contact."
  :type '(repeat string))

(defcustom org-contactsx-note-default-property "NOTE"
  "Name of the property for contact note."
  :type 'string)

(defcustom org-contactsx-tel-properties '("PHONE"
                                          "WORK_PHONE"
                                          "MOBILE_PHONE"
                                          "HOME_PHONE"
                                          "OTHER_PHONE")
  "A list of properties defining telephone addresses for the contact."
  :type '(repeat string))

(defcustom org-contactsx-default-tel-property "PHONE"
  "The default telephone number name used for templates."
  :type 'string)

(defcustom org-contactsx-tel-properties '("PHONE"
                                          "WORK_PHONE"
                                          "MOBILE_PHONE"
                                          "HOME_PHONE"
                                          "OTHER_PHONE")
  "A list of properties defining telephone addresses for the contact."
  :type '(repeat string))

(defcustom org-contactsx-ignore-property "IGNORE"
  "Name of the property, which values will be ignored when
completing or exporting to vcard."
  :type 'string)

(defcustom org-contactsx-last-read-mail-property "LAST_READ_MAIL"
  "Name of the property for contact last read email link storage."
  :type 'string)

(defcustom org-contactsx-icon-property "ICON"
  "Name of the property for contact icon."
  :type 'string)

(defcustom org-contactsx-icon-size 32
  "Size of the contacts icons."
  :type 'string)

(defcustom org-contactsx-icon-use-gravatar (fboundp 'gravatar-retrieve)
  "Whether use Gravatar to fetch contact icons."
  :type 'boolean)

(defcustom org-contactsx-completion-ignore-case t
  "Ignore case when completing contacts."
  :type 'boolean)

(defcustom org-contactsx-group-prefix "+"
  "Group prefix."
  :type 'string)

(defcustom org-contactsx-tags-props-prefix "#"
  "Tags and properties prefix."
  :type 'string)

(defcustom org-contactsx-matcher
  (mapconcat #'identity
             (mapcar (lambda (x) (concat x "<>\"\""))
                     (append org-contactsx-email-properties
                             org-contactsx-alias-properties
                             org-contactsx-tel-properties
                             org-contactsx-address-properties
                             org-contactsx-birthday-properties
                             ))
             "|")
  "Matching rule for finding heading that are contacts.
This can be a tag name, or a property check."
  :type 'string)

(defcustom org-contactsx-email-link-description-format "%s (%d)"
  "Format used to store links to email.
This overrides `org-email-link-description-format' if set."
  :type 'string)

(defcustom org-contactsx-vcard-file "contacts.vcf"
  "Default file for vcard export."
  :type 'file)

(defcustom org-contactsx-enable-completion t
  "Enable or not the completion in `message-mode' with `org-contactsx'."
  :type 'boolean)

(defcustom org-contactsx-complete-functions
  '(org-contactsx-complete-group org-contactsx-complete-tags-props org-contactsx-complete-name)
  "List of functions used to complete contacts in `message-mode'."
  :type 'hook)

;; Declare external functions and variables
(declare-function org-reverse-string "org")
(declare-function diary-ordinal-suffix "ext:diary-lib")
(declare-function wl-summary-message-number "ext:wl-summary")
(declare-function wl-address-header-extract-address "ext:wl-address")
(declare-function wl-address-header-extract-realname "ext:wl-address")
(declare-function erc-buffer-list "ext:erc")
(declare-function erc-get-channel-user-list "ext:erc")
(declare-function google-maps-static-show "ext:google-maps-static")
(declare-function elmo-message-field "ext:elmo-pipe")
(declare-function std11-narrow-to-header "ext:std11")
(declare-function std11-fetch-field "ext:std11")

(defvar org-contactsx-property-categories
  `(("Address" . ,(list org-contactsx-address-properties))
    ("Alias" . ,(list org-contactsx-alias-properties))
    ("Anniversary" . ,(list org-contactsx-anniv-properties))
    ("Birthday" . ,(list org-contactsx-birthday-properties))
    ("Company". ,(list org-contactsx-company-properties))
    ("Department" . ,(list org-contactsx-dept-properties))
    ("Email" . ,(list org-contactsx-email-properties))
    ("Job Title" . ,(list org-contactsx-job-properties))
    ("Messenger" . ,(list org-contactsx-chat-properties))
    ("Phone" . ,(list org-contactsx-tel-properties)))
  "An alist matching the type of information to the property keys.")

(defvar org-contactsx-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map "C" #'org-contactsx-copy)
    (define-key map "M" #'org-contactsx-view-send-email)
    (define-key map "i" #'org-contactsx-view-switch-to-irc-buffer)
    map)
  "The keymap used in `org-contactsx' result list.")

(defvar org-contactsx-db nil
  "Org Contacts database.")

(defvar org-contactsx-last-update nil
  "Last time the Org Contacts database has been updated.")

(defun org-contactsx-files ()
  "Return list of Org files to use for contact management."
  (if org-contacts-files
      org-contacts-files
    (message "[ERROR] Your custom variable `org-contacts-files' is nil. Revert to `org-agenda-files' now.")
    (org-agenda-files t 'ifmode)))

(defun org-contactsx-db-need-update-p ()
  "Determine whether `org-contactsx-db' needs to be refreshed."
  (or (null org-contactsx-last-update)
      (cl-find-if (lambda (file)
                    (or (time-less-p org-contactsx-last-update
                                     (elt (file-attributes file) 5))))
                  (org-contactsx-files))
      (org-contactsx-db-has-dead-markers-p org-contactsx-db)))

(defun org-contactsx-db-has-dead-markers-p (db)
  "Return t if at least one dead marker is found in DB.
A dead marker in this case is a marker pointing to dead or no
buffer."
  ;; Scan contacts list looking for dead markers, and return t at first found.
  (catch 'dead-marker-found
    (while db
      (unless (marker-buffer (nth 1 (car db)))
        (throw 'dead-marker-found t))
      (setq db (cdr db)))
    nil))

(defun org-contactsx-db ()
  "Return the latest Org Contacts Database."
  (let* ((org--matcher-tags-todo-only nil)
         (contacts-matcher (cdr (org-make-tags-matcher org-contactsx-matcher)))
         result)
    (when (org-contactsx-db-need-update-p)
      (let ((progress-reporter
             (make-progress-reporter "Updating Org Contacts Database..." 0 (length (org-contacts-files))))
            (i 0))
        (dolist (file (org-contactsx-files))
          (if (catch 'nextfile
                ;; if file doesn't exist and the user agrees to removing it
                ;; from org-agendas-list, 'nextfile is thrown.  Catch it here
                ;; and skip processing the file.
                ;;
                ;; TODO: suppose that the user has set an org-contacts-files
                ;; list that contains an element that doesn't exist in the
                ;; file system: in that case, the org-agenda-files list could
                ;; be updated (and saved to the customizations of the user) if
                ;; it contained the same file even though the org-agenda-files
                ;; list wasn't actually used.  I don't think it is normal that
                ;; org-contactsx updates org-agenda-files in this case, but
                ;; short of duplicating org-check-agenda-files and
                ;; org-remove-files, I don't know how to avoid it.
                ;;
                ;; A side effect of the TODO is that the faulty
                ;; org-contacts-files list never gets updated and thus the
                ;; user is always queried about the missing files when
                ;; org-contactsx-db-need-update-p returns true.
                (org-check-agenda-file file))
              (message "Skipped %s removed from org-agenda-files list."
                       (abbreviate-file-name file))
            (with-current-buffer (org-get-agenda-file-buffer file)
              (unless (eq major-mode 'org-mode)
                (error "File %s is not in `org-mode'" file))
              (setf result
                    (append result
                            (org-scan-tags 'org-contactsx-at-point
                                           contacts-matcher
                                           org--matcher-tags-todo-only)))))
          (progress-reporter-update progress-reporter (setq i (1+ i))))
        (setf org-contactsx-db result
              org-contactsx-last-update (current-time))
        (progress-reporter-done progress-reporter)))
    org-contactsx-db))

(defun org-contactsx-at-point (&optional pom)
  "Return the contacts at point-or-marker POM or current position
if nil."
  (setq pom (or pom (point)))
  (org-with-point-at pom
    (list (org-get-heading t) (set-marker (make-marker) pom) (org-entry-properties pom 'all))))

(defun org-contactsx-filter (&optional name-match tags-match prop-match)
  "Search for a contact matching any of NAME-MATCH, TAGS-MATCH, PROP-MATCH.
If all match values are nil, return all contacts.

The optional PROP-MATCH argument is a single (PROP . VALUE) cons
cell corresponding to the contact properties.
"
  (if (and (null name-match)
           (null prop-match)
           (null tags-match))
      (org-contactsx-db)
    (cl-loop for contact in (org-contactsx-db)
             if (or
                 (and name-match
                      (string-match-p name-match
                                      (cl-first contact)))
                 (and prop-match
                      (cl-find-if (lambda (prop)
                                    (and (string= (car prop-match) (car prop))
                                         (string-match-p (cdr prop-match) (cdr prop))))
                                  (caddr contact)))
                 (and tags-match
                      (cl-find-if (lambda (tag)
                                    (string-match-p tags-match tag))
                                  (org-split-string
                                   (or (cdr (assoc-string "ALLTAGS" (caddr contact))) "") ":"))))
             collect contact)))

(defun org-contactsx-try-completion-prefix (to-match collection &optional predicate)
  "Custom implementation of `try-completion'.
This version works only with list and alist and it looks at all
prefixes rather than just the beginning of the string."
  (cl-loop with regexp = (concat "\\b" (regexp-quote to-match))
           with ret = nil
           with ret-start = nil
           with ret-end = nil

           for el in collection
           for string = (if (listp el) (car el) el)

           for start = (when (or (null predicate) (funcall predicate string))
                         (string-match regexp string))

           if start
           do (let ((end (match-end 0))
                    (len (length string)))
                (if (= end len)
                    (cl-return t)
                  (cl-destructuring-bind (string start end)
                      (if (null ret)
                          (cl-values string start end)
                        (org-contactsx-common-substring
                         ret ret-start ret-end
                         string start end))
                    (setf ret string
                          ret-start start
                          ret-end end))))

           finally (cl-return
                    (replace-regexp-in-string "\\`[ \t\n]*" "" ret))))

(defun org-contactsx-compare-strings (s1 start1 end1 s2 start2 end2 &optional ignore-case)
  "Compare the contents of two strings, using `compare-strings'.

This function works like `compare-strings' excepted that it
returns a cons.
- The CAR is the number of characters that match at the beginning.
- The CDR is T is the two strings are the same and NIL otherwise."
  (let ((ret (compare-strings s1 start1 end1 s2 start2 end2 ignore-case)))
    (if (eq ret t)
        (cons (or end1 (length s1)) t)
      (cons (1- (abs ret)) nil))))

(defun org-contactsx-common-substring (s1 start1 end1 s2 start2 end2)
  "Extract the common substring between S1 and S2.

This function extracts the common substring between S1 and S2 and
adjust the part that remains common.

START1 and END1 delimit the part in S1 that we know is common
between the two strings. This applies to START2 and END2 for S2.

This function returns a list whose contains:
- The common substring found.
- The new value of the start of the known inner substring.
- The new value of the end of the known inner substring."
  ;; Given two strings:
  ;; s1: "foo bar baz"
  ;; s2: "fooo bar baz"
  ;; and the inner substring is "bar"
  ;; then: start1 = 4, end1 = 6, start2 = 5, end2 = 7
  ;;
  ;; To find the common substring we will compare two substrings:
  ;; " oof" and " ooof" to find the beginning of the common substring.
  ;; " baz" and " baz" to find the end of the common substring.
  (let* ((len1 (length s1))
         (start1 (or start1 0))
         (end1 (or end1 len1))

         (len2 (length s2))
         (start2 (or start2 0))
         (end2 (or end2 len2))

         (new-start (car (org-contactsx-compare-strings
                          (substring (org-reverse-string s1) (- len1 start1)) nil nil
                          (substring (org-reverse-string s2) (- len2 start2)) nil nil)))

         (new-end (+ end1 (car (org-contactsx-compare-strings
                                (substring s1 end1) nil nil
                                (substring s2 end2) nil nil)))))
    (list (substring s1 (- start1 new-start) new-end)
          new-start
          (+ new-start (- end1 start1)))))

(defun org-contactsx-all-completions-prefix (to-match collection &optional predicate)
  "Custom version of `all-completions'.
This version works only with list and alist and it looks at all
prefixes rather than just the beginning of the string."
  (cl-loop with regexp = (concat "\\b" (regexp-quote to-match))
           for el in collection
           for string = (if (listp el) (car el) el)
           for match? = (when (and (or (null predicate) (funcall predicate string)))
                          (string-match regexp string))
           if match?
           collect (progn
                     (let ((end (match-end 0)))
                       (org-no-properties string)
                       (when (< end (length string))
                         ;; Here we add a text property that will be used
                         ;; later to highlight the character right after
                         ;; the common part between each addresses.
                         ;; See `org-contactsx-display-sort-function'.
                         (put-text-property end (1+ end) 'org-contactsx-prefix 't string)))
                     string)))

(defun org-contactsx-make-collection-prefix (collection)
  "Make a collection function from COLLECTION which will match on prefixes."
  (let ((collection collection))
    (lambda (string predicate flag)
      (cond ((eq flag nil)
             (org-contactsx-try-completion-prefix string collection predicate))
            ((eq flag t)
             ;; `org-contactsx-all-completions-prefix' has already been
             ;; used to compute `all-completions'.
             collection)
            ((eq flag 'lambda)
             (org-contactsx-test-completion-prefix string collection predicate))
            ((and (listp flag) (eq (car flag) 'boundaries))
             (org-contactsx-boundaries-prefix string collection predicate (cdr flag)))
            ((eq flag 'metadata)
             (org-contactsx-metadata-prefix))
            (t nil          ; operation unsupported
               )))))

(defun org-contactsx-display-sort-function (completions)
  "Sort function for contacts display."
  (mapcar (lambda (string)
            (cl-loop with len = (1- (length string))
                     for i upfrom 0 to len
                     if (memq 'org-contactsx-prefix
                              (text-properties-at i string))
                     do (set-text-properties
                         i (1+ i)
                         (list 'font-lock-face
                               (if (char-equal (aref string i)
                                               (string-to-char " "))
                                   ;; Spaces can't be bold.
                                   'underline
                                 'bold)) string)
                     else
                     do (set-text-properties i (1+ i) nil string)
                     finally (cl-return string)))
          completions))

(defun org-contactsx-test-completion-prefix (string collection predicate)
  (cl-find-if (lambda (el)
                (and (or (null predicate) (funcall predicate el))
                     (string= string el)))
              collection))

(defun org-contactsx-boundaries-prefix (string collection predicate suffix)
  (cl-list* 'boundaries (completion-boundaries string collection predicate suffix)))

(defun org-contactsx-metadata-prefix (&rest _)
  '(metadata .
             ((cycle-sort-function . org-contactsx-display-sort-function)
              (display-sort-function . org-contactsx-display-sort-function))))

(defun org-contactsx-complete-group (string)
  "Complete text at START from a group.

A group FOO is composed of contacts with the tag FOO."
  (let* ((completion-ignore-case org-contactsx-completion-ignore-case)
         (group-completion-p (string-match-p
                              (concat "^" org-contactsx-group-prefix) string)))
    (when group-completion-p
      (let ((completion-list
             (all-completions
              string
              (mapcar (lambda (group)
                        (propertize (concat org-contactsx-group-prefix group)
                                    'org-contactsx-group group))
                      (org-uniquify
                       (cl-loop for contact in (org-contactsx-filter)
                                nconc (org-split-string
                                       (or (cdr (assoc-string "ALLTAGS" (caddr contact))) "") ":")))))))

        (if (= (length completion-list) 1)
            ;; We've found the correct group, returns the address
            (let ((tag (get-text-property 0 'org-contactsx-group
                                          (car completion-list))))
              (mapconcat #'identity
                         (cl-loop for contact in (org-contactsx-filter
                                                  nil
                                                  tag)
                                  ;; The contact name is always the car of the assoc-list
                                  ;; returned by `org-contactsx-filter'.
                                  for contact-name = (car contact)
                                  ;; Grab the first email of the contact
                                  for email = org-contactsx-email-default-property
                                  ;; If the user has an email address, append USER <EMAIL>.
                                  if email collect (org-contactsx-format-email contact-name email))
                         ", "))
          ;; We haven't found the correct group
          (completion-table-case-fold completion-list
                                      (not org-contactsx-completion-ignore-case)))))))

(defun org-contactsx-complete-tags-props (string)
  "Insert emails that match the tags expression.

For example: FOO-BAR will match entries tagged with FOO but not
with BAR.

See (org) Matching tags and properties for a complete
description."
  (let* ((completion-ignore-case org-contactsx-completion-ignore-case)
         (completion-p (string-match-p
                        (concat "^" org-contactsx-tags-props-prefix) string)))
    (when completion-p
      (let ((result
             (mapconcat
              #'identity
              (cl-loop for contact in (org-contactsx-db)
                       for contact-name = (car contact)
                       for email = (org-contactsx-strip-link
                                    (or (car (org-contactsx-split-property
                                              (or
                                               (cdr (assoc-string org-contactsx-default-email-property
                                                                  (cl-caddr contact)))
                                               "")))
                                        ""))
                       ;; for tags = (cdr (assoc "TAGS" (nth 2 contact)))
                       ;; for tags-list = (if tags
                       ;;      (split-string (substring (cdr (assoc "TAGS" (nth 2 contact))) 1 -1) ":")
                       ;;    '())
                       for marker = (nth 1 contact)
                       if (with-current-buffer (marker-buffer marker)
                            (save-excursion
                              (goto-char marker)
                              ;; FIXME: AFAIK, `org-make-tags-matcher' returns
                              ;; a cons whose cdr is a function, so why do we
                              ;; pass it to `eval' rather than to (say)
                              ;; `funcall'?
                              (eval (cdr (org-make-tags-matcher (cl-subseq string 1))))))
                       collect (org-contactsx-format-email contact-name email))
              ",")))
        (when (not (string= "" result))
          result)))))

(defun org-contactsx-remove-ignored-property-values (ignore-list list)
  "Remove all ignore-list's elements from list and you can use
   regular expressions in the ignore list."
  (cl-remove-if (lambda (el)
                  (cl-find-if (lambda (x)
                                (string-match-p x el))
                              ignore-list))
                list))

(defun org-contactsx-complete-name (string)
  "Complete text at START with a user name and email."
  (let* ((completion-ignore-case org-contactsx-completion-ignore-case)
         (completion-list
          (cl-loop for contact in (org-contactsx-filter)
                   ;; The contact name is always the car of the assoc-list
                   ;; returned by `org-contactsx-filter'.
                   for contact-name = (car contact)

                   ;; Build the list of the email addresses which has
                   ;; been expired
                   for ignore-list = (cdr (assoc-string
                                           org-contactsx-ignore-property
                                           (nth 2 contact)))
                   ;; Build the list of the user email addresses.
                   for email-list = (let ((emails '()))
                                      (dolist (property
                                               org-contactsx-email-properties)
                                        (let ((email
                                               (org-contactsx-get-alist-value
                                                (nth 2 contact)
                                                property)))
                                          (when email
                                            (add-to-list 'emails email))))
                                      emails)
                   ;; If the user has email addresses…
                   if email-list
                   ;; … append a list of USER <EMAIL>.
                   nconc (cl-loop for email in email-list
                                  collect (org-contactsx-format-email
                                           contact-name (org-contactsx-strip-link
                                                         email)))))
         (completion-list (org-contactsx-all-completions-prefix
                           string
                           (org-uniquify completion-list))))
    (when completion-list
      (org-contactsx-make-collection-prefix completion-list))))

(defun org-contactsx-message-complete-function ()
  "Function used in `completion-at-point-functions' in `message-mode'."
  (let ((mail-abbrev-mode-regexp
         "^\\(Resent-To\\|To\\|B?Cc\\|Reply-To\\|From\\|Mail-Followup-To\\|Mail-Copies-To\\|Disposition-Notification-To\\|Return-Receipt-To\\):"))
    (when (mail-abbrev-in-expansion-header-p)
      (let
          ((beg
            (save-excursion
              (re-search-backward "\\(\\`\\|[\n:,]\\)[ \t]*")
              (goto-char (match-end 0))
              (point)))
           (end (point)))
        (list beg
              end
              (completion-table-dynamic
               (lambda (string)
                 (run-hook-with-args-until-success
                  'org-contactsx-complete-functions string))))))))

(defun org-contactsx-org-complete--annotation-function (candidate)
  "Return org-contactsx tags of contact candidate."
  ;; TODO
  "Tags: "
  (ignore candidate))

(defun org-contactsx-org-complete--doc-function (candidate)
  "Return org-contactsx content of contact candidate."
  (let* ((candidate (substring-no-properties candidate 1 nil))
         (contact (seq-find
                   (lambda (contact) (string-equal (plist-get contact :name) candidate))
                   (org-contactsx--all-contacts)))
         (name (plist-get contact :name))
         (file (plist-get contact :file))
         (position (plist-get contact :position))
         (doc-buffer (get-buffer-create " *org-contact*"))
         (org-contact-buffer (get-buffer (find-file-noselect file)))
         ;; get org-contact headline and property drawer.
         (contents (with-current-buffer org-contact-buffer
                     (when (derived-mode-p 'org-mode)
                       (save-excursion
                         (goto-char position)
                         (cond ((ignore-errors (org-edit-src-code))
                                (delete-other-windows))
                               ((org-at-block-p)
                                (org-narrow-to-block))
                               (t (org-narrow-to-subtree)))
                         (let ((content (buffer-substring (point-min) (point-max))))
                           (when (buffer-narrowed-p) (widen))
                           content))))))
    (ignore name)
    (with-current-buffer doc-buffer
      (read-only-mode 1)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert contents)
        (org-mode)
        (org-show-all)
        (font-lock-ensure)))
    doc-buffer))

;;; display company-mode doc buffer bellow current window.
(add-to-list 'display-buffer-alist '("^ \\*org-contact\\*" . (display-buffer-below-selected)))

(defun org-contactsx-org-complete--location-function (candidate)
  "Return org-contactsx location of contact candidate."
  (let* ((candidate (substring-no-properties candidate 1 nil))
         (contact (seq-find
                   (lambda (contact) (string-equal (plist-get contact :name) candidate))
                   (org-contactsx--all-contacts)))
         (name (plist-get contact :name))
         (file (plist-get contact :file))
         (position (plist-get contact :position)))
    (ignore name)
    (with-current-buffer (find-file-noselect file)
      (goto-char position)
      (cons (current-buffer) position))))

;;;###autoload
(defun org-contactsx-org-complete-function ()
  "Function used in `completion-at-point-functions' in `org-mode' to complete @name.
Usage: (add-hook 'completion-at-point-functions 'org-contactsx-org-complete-function nil 'local)"
  (when-let* ((end (point))
              (begin (save-excursion (skip-chars-backward "[:alnum:]@") (point)))
              (symbol (buffer-substring-no-properties begin end))
              (org-contactsx-prefix-p (string-prefix-p "@" symbol)))
    (when org-contactsx-prefix-p
      (list begin
            end
            (completion-table-dynamic
             (lambda (_)
               (mapcar
                (lambda (contact) (concat "@" (plist-get contact :name)))
                (org-contactsx--all-contacts))))

            :predicate 'stringp
            :exclusive 'no
            ;; properties check out `completion-extra-properties'
            :annotation-function #'org-contactsx-org-complete--annotation-function
            ;; :exit-function ; TODO change completion candidate inserted contact name into org-contact link??

            :company-docsig #'identity                                    ; metadata
            :company-doc-buffer #'org-contactsx-org-complete--doc-function ; doc popup
            :company-location #'org-contactsx-org-complete--location-function))))

(defun org-contactsx-gnus-get-name-email ()
  "Get name and email address from Gnus message."
  (if (gnus-alive-p)
      (gnus-with-article-headers
        (mail-extract-address-components
         (or (mail-fetch-field "From") "")))))

(defun org-contactsx-gnus-article-from-get-marker ()
  "Return a marker for a contact based on From."
  (let* ((address (org-contactsx-gnus-get-name-email))
         (name (car address))
         (email (cadr address)))
    (cl-cadar (or (org-contactsx-filter
                   nil
                   nil
                   (cons org-contactsx-default-email-property (concat "\\b" (regexp-quote email) "\\b")))
                  (when name
                    (org-contactsx-filter
                     (concat "^" name "$")))))))

(defun org-contactsx-gnus-article-from-goto ()
  "Go to contact in the From address of current Gnus message."
  (interactive)
  (let ((marker (org-contactsx-gnus-article-from-get-marker)))
    (when marker
      (switch-to-buffer-other-window (marker-buffer marker))
      (goto-char marker)
      (when (eq major-mode 'org-mode)
        (if (fboundp 'org-fold-show-context)
            (org-fold-show-context 'agenda)
          (org-show-context 'agenda))))))

(with-no-warnings (defvar date)) ;; unprefixed, from calendar.el
(defun org-contactsx-anniversaries (&optional field format)
  "Compute FIELD anniversary for each contact, returning FORMAT.
Default FIELD value is \"BIRTHDAY\".

Format is a string matching the following format specification:

  %h - Heading name
  %l - Link to the heading
  %y - Number of year
  %Y - Number of year (ordinal)"
  (let ((calendar-date-style 'american))
    (unless format (setq format org-contactsx-birthday-format))
    (cl-loop for contact in (org-contactsx-filter)
             for anniv = (let ((anniv (cdr (assoc-string
                                            (or field org-contactsx-birthday-default-property)
                                            (nth 2 contact)))))
                           (when anniv
                             (calendar-gregorian-from-absolute
                              (org-time-string-to-absolute anniv))))
             ;; Use `diary-anniversary' to compute anniversary.
             ;; FIXME: should we require `diary-lib' somewhere to be sure
             ;; `diary-anniversary' is defined when we get here?
             if (and anniv (apply #'diary-anniversary anniv))
             collect (format-spec format
                                  `((?l . ,(org-with-point-at (cadr contact) (org-store-link nil)))
                                    (?h . ,(car contact))
                                    (?y . ,(- (calendar-extract-year date)
                                              (calendar-extract-year anniv)))
                                    (?Y . ,(let ((years (- (calendar-extract-year date)
                                                           (calendar-extract-year anniv))))
                                             (format "%d%s" years (diary-ordinal-suffix years)))))))))

(defun org-contactsx--completing-read-date ( prompt _collection
                                  &optional _predicate _require-match _initial-input
                                  _hist def _inherit-input-method)
  "Like `completing-read' but reads a date.
Only PROMPT and DEF are really used."
  (org-read-date nil nil nil prompt nil def))

(add-to-list 'org-property-set-functions-alist
             `(,org-contactsx-birthday-default-property . org-contactsx--completing-read-date))

(defun org-contactsx-template-name (&optional return-value)
  "Try to return the contact name for a template.
If not found return RETURN-VALUE or something that would ask the user."
  (or (car (org-contactsx-gnus-get-name-email))
      return-value
      "%^{Name}"))

(defun org-contactsx-template-email (&optional return-value)
  "Try to return the contact email for a template.
If not found return RETURN-VALUE or something that would ask the user."
  (or (cadr (org-contactsx-gnus-get-name-email))
      return-value
      (concat "%^{" org-contactsx-default-email-property "}p")))

(defun org-contactsx-gnus-store-last-mail ()
  "Store a link between mails and contacts.

This function should be called from `gnus-article-prepare-hook'."
  (let ((marker (org-contactsx-gnus-article-from-get-marker)))
    (when marker
      (with-current-buffer (marker-buffer marker)
        (save-excursion
          (goto-char marker)
          (let* ((org-link-email-description-format (or org-contactsx-email-link-description-format
                                                        org-link-email-description-format))
                 (link (gnus-with-article-buffer (org-store-link nil))))
            (org-set-property org-contactsx-last-read-mail-property link)))))))

(defun org-contactsx-icon-as-string ()
  "Return the contact icon as a string."
  (let ((image (org-contactsx-get-icon)))
    (concat
     (propertize "-" 'display
                 (append
                  (if image
                      image
                    `'(space :width (,org-contactsx-icon-size)))
                  '(:ascent center)))
     " ")))

;;;###autoload
(defun org-contactsx (name)
  "Create agenda view for contacts matching NAME."
  (interactive (list (read-string "Name: ")))
  (let ((org-agenda-files (org-contactsx-files))
        (org-agenda-skip-function
         (lambda () (org-agenda-skip-if nil `(notregexp ,name))))
        (org-agenda-prefix-format
         (propertize
          "%(org-contactsx-icon-as-string)% s%(org-contactsx-irc-number-of-unread-messages) "
          'keymap org-contactsx-keymap))
        (org-agenda-overriding-header
         (or org-agenda-overriding-header
             (concat "List of contacts matching `" name "':"))))
    (setq org-agenda-skip-regexp name)
    (org-tags-view nil org-contactsx-matcher)
    (with-current-buffer org-agenda-buffer-name
      (setq org-agenda-redo-command
            (list 'org-contactsx name)))))

(defun org-contactsx-completing-read (prompt
                                     &optional predicate
                                     initial-input hist def inherit-input-method)
  "Call `completing-read' with contacts name as collection."
  (org-completing-read
   prompt (org-contactsx-filter) predicate t initial-input hist def inherit-input-method))

(defun org-contactsx-format-name (name)
  "Trim any local formatting to get a bare NAME."
  ;; Remove radio targets characters
  (replace-regexp-in-string org-radio-target-regexp "\\1" name))

(defun org-contactsx-format-email (name email)
  "Format an EMAIL address corresponding to NAME."
  (unless email
    (error "`email' cannot be nul"))
  (if name
      (concat (org-contactsx-format-name name) " <" email ">")
    email))

(defun org-contactsx-gnus-check-mail-address ()
  "Check that contact has the current address recorded.
This function should be called from `gnus-article-prepare-hook'."
  (let ((marker (org-contactsx-gnus-article-from-get-marker)))
    (when marker
      (org-with-point-at marker
        (org-contactsx-check-mail-address (cadr (org-contactsx-gnus-get-name-email)))))))

(defun org-contactsx-gnus-insinuate ()
  "Add some hooks for Gnus user.
This adds `org-contactsx-gnus-check-mail-address' and
`org-contactsx-gnus-store-last-mail' to
`gnus-article-prepare-hook'.  It also adds a binding on `;' in
`gnus-summary-mode-map' to `org-contactsx-gnus-article-from-goto'"
  (require 'gnus)
  (require 'gnus-art)
  (define-key gnus-summary-mode-map ";" #'org-contactsx-gnus-article-from-goto)
  (add-hook 'gnus-article-prepare-hook #'org-contactsx-gnus-check-mail-address)
  (add-hook 'gnus-article-prepare-hook #'org-contactsx-gnus-store-last-mail))

(defun org-contactsx-setup-completion-at-point ()
  "Add `org-contactsx-message-complete-function' as a new function
to complete the thing at point."
  (add-to-list 'completion-at-point-functions
               'org-contactsx-message-complete-function))

(defun org-contactsx-unload-hook ()
  (remove-hook 'message-mode-hook #'org-contactsx-setup-completion-at-point))

(when (and org-contactsx-enable-completion
           (boundp 'completion-at-point-functions))
  (add-hook 'message-mode-hook #'org-contactsx-setup-completion-at-point))

(defun org-contactsx-wl-get-from-header-content ()
  "Retrieve the content of the `From' header of an email.
Works from wl-summary-mode and mime-view-mode - that is while viewing email.
Depends on Wanderlust been loaded."
  (with-current-buffer (org-capture-get :original-buffer)
    (cond
     ((eq major-mode 'wl-summary-mode) (when (and (boundp 'wl-summary-buffer-elmo-folder)
                                                  wl-summary-buffer-elmo-folder)
                                         (elmo-message-field
                                          wl-summary-buffer-elmo-folder
                                          (wl-summary-message-number)
                                          'from)))
     ((eq major-mode 'mime-view-mode) (std11-narrow-to-header)
      (prog1
          (std11-fetch-field "From")
        (widen))))))

(defun org-contactsx-wl-get-name-email ()
  "Get name and email address from Wanderlust email.
See `org-contactsx-wl-get-from-header-content' for limitations."
  (let ((from (org-contactsx-wl-get-from-header-content)))
    (when from
      (list (wl-address-header-extract-realname from)
            (wl-address-header-extract-address from)))))

(defun org-contactsx-template-wl-name (&optional return-value)
  "Try to return the contact name for a template from wl.
If not found, return RETURN-VALUE or something that would ask the
user."
  (or (car (org-contactsx-wl-get-name-email))
      return-value
      "%^{Name}"))

(defun org-contactsx-template-wl-email (&optional return-value)
  "Try to return the contact email for a template from Wanderlust.
If not found return RETURN-VALUE or something that would ask the user."
  (or (cadr (org-contactsx-wl-get-name-email))
      return-value
      (concat "%^{" org-contactsx-default-email-property "}p")))

(defun org-contactsx-view-send-email (&optional ask)
  "Send email to the contact at point.
If ASK is set, ask for the email address even if there's only one
address."
  (interactive "P")
  (let ((marker (org-get-at-bol 'org-hd-marker)))
    (org-with-point-at marker
      (let ((email-list (org-contactsx-get-alist org-contactsx-email-properties)))
        (let ((email (org-contactsx-get-alist-value email-list ask)))
          (compose-mail (org-contactsx-format-email (org-get-heading t) email)))))))

(defun org-contactsx-get-icon (&optional pom)
  "Get icon for contact at POM."
  (setq pom (or pom (point)))
  (catch 'icon
    ;; Use `org-contactsx-icon-property'
    (let* ((link-matcher-regexp
            "\\[\\[\\([^]]*\\)\\]\\(\\[\\(.*\\)\\]\\)?\\]")
           (contacts-dir (file-name-directory (car (org-contactsx-files))))
           (image-path
            (if-let ((avatar (org-entry-get pom org-contactsx-icon-property)))
                (cond
                 ;; [[file:dir/filename.png]]
                 ((string-match-p "\\[\\[.*\\]\\]" avatar)
                  ;; FIXME: What if avatar matches the above regexp but the
                  ;; one below?
                  (when (string-match link-matcher-regexp avatar)
                    ;; FIXME: 5 seems to be the length of `file:' but I can't
                    ;; see anything that guarantees that the submatch 1 starts
                    ;; with `file:'.
                    (expand-file-name (substring (match-string-no-properties 1 avatar) 5 nil)
                                      contacts-dir)))
                 ;; "" (empty string)
                 ((string-empty-p avatar) nil)
                 (t (expand-file-name avatar contacts-dir))))))
      (when image-path
        (throw 'icon
               (if (featurep 'imagemagick)
                   (create-image image-path 'imagemagick nil
                                 :height org-contactsx-icon-size)
                 (create-image image-path nil nil
                               :height org-contactsx-icon-size)))))
    
    ;; Next, try Gravatar
    (when org-contactsx-icon-use-gravatar
      (defvar gravatar-size)
      (let* ((gravatar-size org-contactsx-icon-size)
             (email-list (org-entry-get pom org-contactsx-email-default-property))
             (gravatar
              (when email-list
                (cl-loop for email in (org-contactsx-split-property email-list)
                         for gravatar = (gravatar-retrieve-synchronously (org-contactsx-strip-link email))
                         if (and gravatar
                                 (not (eq gravatar 'error)))
                         return gravatar))))
        (when gravatar (throw 'icon gravatar))))))

(defun org-contactsx-irc-buffer (&optional pom)
  "Get the IRC buffer associated with the entry at POM."
  (setq pom (or pom (point)))
  (let ((nick (org-entry-get pom org-contactsx-irc-property)))
    (when nick
      (let ((buffer (get-buffer nick)))
        (when buffer
          (with-current-buffer buffer
            (when (eq major-mode 'erc-mode)
              buffer)))))))

(defun org-contactsx-irc-number-of-unread-messages (&optional pom)
  "Return the number of unread messages for contact at POM."
  (when (boundp 'erc-modified-channels-alist)
    (let ((number (cadr (assoc (org-contactsx-irc-buffer pom) erc-modified-channels-alist))))
      (if number
          (format (concat "%3d unread message" (if (> number 1) "s" " ") " ") number)
        (make-string 21 ? )))))

(defun org-contactsx-view-switch-to-irc-buffer ()
  "Switch to the IRC buffer of the current contact if it has one."
  (interactive)
  (let ((marker (org-get-at-bol 'org-hd-marker)))
    (org-with-point-at marker
      (switch-to-buffer-other-window (org-contactsx-irc-buffer)))))

(defun org-contactsx-completing-read-nickname (prompt collection
                                                     &optional predicate require-match initial-input
                                                     hist def inherit-input-method)
  "Like `completing-read' but reads a nickname."
  (if (featurep 'erc)
      (org-completing-read prompt (append collection (org-contactsx-erc-nicknames-list)) predicate require-match
                           initial-input hist def inherit-input-method)
    (org-completing-read prompt collection predicate require-match
                         initial-input hist def inherit-input-method)))

(defun org-contactsx-erc-nicknames-list ()
  "Return all nicknames of all ERC buffers."
  (cl-loop for buffer in (erc-buffer-list)
           nconc (with-current-buffer buffer
                   (cl-loop for user-entry
                            in (mapcar #'car (erc-get-channel-user-list))
                            collect (elt user-entry 1)))))

                                        ;(add-to-list 'org-property-set-functions-alist
                                        ;             `(,org-contactsx-nickname-property . org-contactsx-completing-read-nickname))

(defun org-contactsx-vcard-escape (str)
  "Escape ; , and \n in STR for the VCard format."
  ;; Thanks to this library for the regexp:
  ;; https://www.emacswiki.org/cgi-bin/wiki/bbdb-vcard-export.el
  (when str
    (replace-regexp-in-string
     "\n" "\\\\n"
     (replace-regexp-in-string "\\(;\\|,\\|\\\\\\)" "\\\\\\1" str))))

(defun org-contactsx-vcard-encode-name (name)
  "Try to encode NAME as VCard's N property.
The N property expects

  FamilyName;GivenName;AdditionalNames;Prefix;Postfix.

org-contactsx does not specify how to encode the name.  So we try
to do our best."
  (concat (replace-regexp-in-string "\\(\\w+\\) \\(.*\\)" "\\2;\\1" name) ";;;"))

;; TODO Update this to allow for including multiple emails,addresses, and phone numbers
(defun org-contactsx-vcard-format (contact)
  "Formats CONTACT in VCard 3.0 format."
  (let* ((properties (nth 2 contact))
         (name (org-contactsx-vcard-escape (car contact)))
         (n (org-contactsx-vcard-encode-name name))
         (email (cdr (assoc-string org-contactsx-email-default-property properties)))
         (tel (cdr (assoc-string org-contactsx-tel-default-property properties)))
         (ignore-list (cdr (assoc-string org-contactsx-ignore-property properties)))
         (ignore-list (when ignore-list
                        (org-contactsx-split-property ignore-list)))
         (note (cdr (assoc-string org-contactsx-note-property properties)))
         (bday (org-contactsx-vcard-escape (cdr (assoc-string org-contactsx-birthday-default-property properties))))
         (addr (cdr (assoc-string org-contactsx-address-default-property properties)))
         (nick " ")
         (head (format "BEGIN:VCARD\nVERSION:3.0\nN:%s\nFN:%s\n" n name))
         emails-list result phones-list)
    (concat
     head
     (when email
       (progn
         (setq emails-list (org-contactsx-remove-ignored-property-values
                            ignore-list (org-contactsx-split-property email)))
         (setq result "")
         (while emails-list
           (setq result (concat result  "EMAIL:" (org-contactsx-strip-link (car emails-list)) "\n"))
           (setq emails-list (cdr emails-list)))
         result))
     (when addr
       (format "ADR:;;%s\n" (replace-regexp-in-string "\\, ?" ";" addr)))
     (when tel
       (progn
         (setq phones-list (org-contactsx-remove-ignored-property-values
                            ignore-list (org-contactsx-split-property tel)))
         (setq result "")
         (while phones-list
           (setq result (concat result  "TEL:" (org-contactsx-strip-link
                                                (org-link-unescape (car phones-list))) "\n"))
           (setq phones-list (cdr phones-list)))
         result))
     (when bday
       (let ((cal-bday (calendar-gregorian-from-absolute (org-time-string-to-absolute bday))))
         (format "BDAY:%04d-%02d-%02d\n"
                 (calendar-extract-year cal-bday)
                 (calendar-extract-month cal-bday)
                 (calendar-extract-day cal-bday))))
     (when nick (format "NICKNAME:%s\n" nick))
     (when note (format "NOTE:%s\n" note))
     "END:VCARD\n\n")))

(defun org-contactsx-export-as-vcard (&optional name file to-buffer)
  "Export org contacts to V-Card 3.0.

By default, all contacts are exported to `org-contactsx-vcard-file'.

When NAME is \\[universal-argument], prompts for a contact name.

When NAME is \\[universal-argument] \\[universal-argument],
prompts for a contact name and a file name where to export.

When NAME is \\[universal-argument] \\[universal-argument]
\\[universal-argument], prompts for a contact name and a buffer where to export.

If the function is not called interactively, all parameters are
passed to `org-contactsx-export-as-vcard-internal'."
  (interactive "P")
  (when (called-interactively-p 'any)
    (cl-psetf name
              (when name
                (read-string "Contact name: "
                             (nth 0 (org-contactsx-at-point))))
              file
              (when (equal name '(16))
                (read-file-name "File: " nil org-contactsx-vcard-file))
              to-buffer
              (when (equal name '(64))
                (read-buffer "Buffer: "))))
  (org-contactsx-export-as-vcard-internal name file to-buffer))

(defun org-contactsx-export-as-vcard-internal (&optional name file to-buffer)
  "Export all contacts matching NAME as VCard 3.0.
If TO-BUFFER is nil, the content is written to FILE or
`org-contactsx-vcard-file'.  If TO-BUFFER is non-nil, the buffer
is created and the VCard is written into that buffer."
  (let* ((filename (or file org-contactsx-vcard-file))
         (buffer (if to-buffer
                     (get-buffer-create to-buffer)
                   (find-file-noselect filename))))
    (message "Exporting...")
    (set-buffer buffer)
    (let ((inhibit-read-only t)) (erase-buffer))
    (fundamental-mode)
    (when (fboundp 'set-buffer-file-coding-system)
      (set-buffer-file-coding-system coding-system-for-write))
    (cl-loop for contact in (org-contactsx-filter name)
             do (insert (org-contactsx-vcard-format contact)))
    (if to-buffer
        (current-buffer)
      (progn (save-buffer) (kill-buffer)))))

(defun org-contactsx-show-map (&optional name)
  "Show contacts on a map.
Requires google-maps-el."
  (interactive)
  (unless (fboundp 'google-maps-static-show)
    (error "`org-contactsx-show-map' requires `google-maps-el'"))
  (google-maps-static-show
   :markers
   (cl-loop
    for contact in (org-contactsx-filter name)
    for addr = (cdr (assoc-string org-contactsx-default-address-property (nth 2 contact)))
    if addr
    collect (cons (list addr) (list :label (string-to-char (car contact)))))))

(defun org-contactsx-strip-link (link)
  "Remove brackets, description, link type and colon from an org
link string and return the pure link target."
  (let (startpos colonpos endpos)
    (setq startpos (string-match (regexp-opt '("[[tel:" "[[mailto:")) link))
    (if startpos
        (progn
          (setq colonpos (string-match ":" link))
          (setq endpos (string-match "\\]" link))
          (if endpos (substring link (1+ colonpos) endpos) link))
      (progn
        (setq startpos (string-match "mailto:" link))
        (setq colonpos (string-match ":" link))
        (if startpos (substring link (1+ colonpos)) link)))))

;; Add the link type supported by org-contactsx-strip-link
;; so everything is in order for its use in Org files
(if (fboundp 'org-link-set-parameters)
    (org-link-set-parameters "tel")
  (if (fboundp 'org-add-link-type)
      (org-add-link-type "tel")))

;;;###autoload
;;; Add an Org link type `org-contact:' for easy jump to or searching org-contactsx headline.
;;; link spec: [[org-contact:query][desc]]
(if (fboundp 'org-link-set-parameters)
    (org-link-set-parameters "org-contact"
                             :complete #'org-contactsx-link-complete
                             :store #'org-contactsx-link-store
                             :face 'org-contactsx-link-face)
  (if (fboundp 'org-add-link-type)
      (org-add-link-type "org-contact" 'org-contactsx-link-open)))

;;;###autoload
(defun org-contactsx-link-store ()
  "Store the contact in `org-contacts-files' with a link."
  (when (and (eq major-mode 'org-mode)
             (member (buffer-file-name)
                     (mapcar #'expand-file-name (org-contactsx-files))))
    (if (bound-and-true-p org-id-link-to-org-use-id)
        (org-id-store-link)
      (let ((headline-str (substring-no-properties (concat
                                                    buffer-file-name
                                                    "::*"
                                                    (org-get-heading t t t t)))))
        (org-link-store-props
         :type "org-contact"
         :link headline-str
         :description (org-get-heading t t t t))
        (let ((link (concat "file:" headline-str)))
          (org-link-add-props :link link :description headline-str)
          link)))))

(defun org-contactsx--all-contacts ()
  "Return a list of all contacts in `org-contacts-files'.
Each element has the form (NAME . (FILE . POSITION))."
  (car (mapcar
        (lambda (file)
          (unless (buffer-live-p (get-buffer (file-name-nondirectory file)))
            (find-file file))
          (with-current-buffer (get-buffer (file-name-nondirectory file))
            (org-map-entries
             (lambda ()
               (let ((name (substring-no-properties (org-get-heading t t t t)))
                     (file (buffer-file-name))
                     (position (point)))
                 `(:name ,name :file ,file :position ,position))))))
        (org-contactsx-files))))

;;;###autoload
(defun org-contactsx-link-complete (&optional _arg)
  "Create a org-contactsx link using completion."
  (let ((name (completing-read "org-contacts NAME: "
                               (mapcar
                                (lambda (plist) (plist-get plist :name))
                                (org-contactsx--all-contacts)))))
    (let ((file-name (catch 'file-name
                       (dolist (element (org-contactsx--all-contacts))
                         (when (string= (plist-get element :name) name)
                           (throw 'file-name (plist-get element :file)))))))
      (concat "file:" file-name "::*" name))))

(defun org-contactsx-link-face (path)
  "Different face color for different org-contactsx link query."
  (cond
   ((string-match "/.*/" path)
    '(:background "sky blue" :overline t :slant 'italic))
   (t '(:inherit org-link))))

;;; org-mode link "mailto:" email completion.
(if (fboundp 'org-link-set-parameters)
    (org-link-set-parameters "mailto" :complete #'org-contactsx-mailto-link-completion)
  (if (fboundp 'org-add-link-type)
      (org-add-link-type "mailto")))

(defun org-contactsx-mailto-link--get-all-emails ()
  "Retrieve all org-contactsx EMAIL property values."
  (mapcar
   (lambda (contact)
     (let* ((org-contactsx-buffer (find-file-noselect (car (org-contactsx-files))))
            (name (plist-get contact :name))
            (position (plist-get contact :position))
            (email (save-excursion
                     (with-current-buffer org-contactsx-buffer
                       (goto-char position)
                       (dolist (email-name org-contactsx-email-properties email)
                         (when (org-entry-get (point) email-name)
                           (setq email (append (org-entry-get
                                                (point)
                                                email-name)))))))))
       (ignore name)
       ;; (cons name email)
       email))
   (org-contactsx--all-contacts)))

(defun org-contactsx-get-alist (property-list)
  "Return an alist for org contact properties in PROPERTY-LIST.
The alist is a list of cons cells matching each property in PROPERTY-LIST with
the corresponding value of that property under the contact heading."
  (let (list)
    (dolist (element property-list list)
      (when (org-entry-get (point) element)
        (setq list (append list
                           (list (cons element
                                       (org-entry-get (point) element)))))))))

(defun org-contactsx-get-alist-value (alist &optional key ask)
  "Return the value of the ALIST using KEY and process the output."
  (if key
      (let ((value (cdr (assoc key alist))))
        (if value
            (org-contactsx-strip-link value)
          value))
    (if (and (= (length alist) 1) (not ask))
        (org-contactsx-strip-link (cdr (car alist)))
      (let ((selection (completing-read "Select which item: " alist)))
        (org-contactsx-strip-link (cdr (assoc selection alist)))))))

(defun org-contactsx-props-from-category (category)
  "Return the list of contact properties matching CATEGORY.
CATEGORY are those defined in `org-contactsx-property-categories' The function
will then return the matching list of properties (e.g. `Address' returns
the list `org-contactsx-address-properties')."
  (cadr (assoc category org-contactsx-property-categories)))

(defun org-contactsx-copy (&optional ask)
  "Copy a contact property value for the contact at point to the kill ring.
If ASK is set, ask for the email address even if there's only one
address."
  (interactive)
  (let ((marker (org-get-at-bol 'org-hd-marker)))
    (org-with-point-at marker
      (let ((category (completing-read "Select item to copy: "
                                       org-contactsx-property-categories)))
        (let ((alist (org-contactsx-get-alist
                      (org-contactsx-props-from-category category))))
          (unless alist
            (error (format "No %s properties are defined for this contact" category)))
          (let ((value (org-contactsx-get-alist-value alist
                                                      ask)))
            (message "Hello")
            (when (= (length value) 0)
              (error (format "No information found for %s." (caar alist))))
            (kill-new value)
            (message (format "Added to kill ring: %s" value))))))))

(defun org-contactsx-mailto-link-completion (&optional _arg)
  "Org mode link `mailto:' completion with org-contactsx emails."
  (let ((email (completing-read "org-contactsx EMAIL: "
                                (org-contactsx-mailto-link--get-all-emails
                                 nil
                                 nil))))
    (concat "[[mailto:" email "]]")))

(provide 'org-contactsx)


;;; org-contactsx.el ends here
