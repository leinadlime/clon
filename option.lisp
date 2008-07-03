;;; option.lisp --- Option management for Clon

;; Copyright (C) 2008 Didier Verna

;; Author:        Didier Verna <didier@lrde.epita.fr>
;; Maintainer:    Didier Verna <didier@lrde.epita.fr>
;; Created:       Wed Jul  2 14:26:44 2008
;; Last Revision: Wed Jul  2 14:26:44 2008

;; This file is part of Clon.

;; Clon is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.

;; Clon is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.


;;; Commentary:

;; Contents management by FCM version 0.1.


;;; Code:

(in-package :clon)


;; ============================================================================
;; The Option class
;; ============================================================================

;; #### FIXME: make abstract
(defclass option ()
  ((short-name :documentation "The option's short name."
	       :type (or null string)
	       :reader short-name
	       :initarg :short-name)
   (long-name :documentation "The option's long name."
	      :type (or null string)
	      :reader long-name
	      :initarg :long-name)
   (description :documentation "The option's description."
		:type (or null string)
		:reader description
		:initarg :description)
   ;; #### FIXME: this slot is unsatisfactory because it is used only for
   ;; option setup. Should be in &allow-other-keys
   (builtin :documentation "Whether this option is internal to Clon."
	    :reader builtin
	    :initform nil))
  (:default-initargs
    :short-name nil
    :long-name nil
    :description nil)
  (:documentation "The OPTION class.
This class is the base class for all options."))

;; #### FIXME: we should probably do this on the keywords, in a :before
;; method.
(defmethod initialize-instance :after ((option option) &rest initargs)
  "Check consistency of OPTION."
  (declare (ignore initargs))
  (with-slots (short-name long-name) option
    (unless (or short-name long-name)
      (error "Option ~A: no name given." option))
    ;; #### FIXME: is this really necessary ? What about the day I would like
    ;; to add new syntax like -= etc ?
    ;; Empty long names are forbidden because of the special syntax -- (for
    ;; terminating options). However, it *is* possible to have *one* option
    ;; with an empty (that's different from NIL) short name. This option will
    ;; just appear as `-'. Note that this special option can't appear in a
    ;; minus or plus pack (of course :-), and can't have a sticky argument
    ;; either (that would look like a non-empty short name). Actually, its
    ;; usage can be one of:
    ;; - a flag, enabling `-',
    ;; - a boolean, enabling `-' or `+',
    ;; - a string, enabling `- foo'.
    ;; - a user option, behaving the same way.
    (when (and long-name (zerop (length long-name)))
      (error "Option ~A: empty long name." option))
    (when (and short-name long-name (string= short-name long-name))
      (error "Option ~A: short and long names identical." option))
    ;; Short names can't begin with a dash because that would conflict with
    ;; the long name syntax.
    (when (and short-name
	       (not (zerop (length short-name)))
	       (string= short-name "-" :end1 1))
      (error "Option ~A: short name begins with a dash." option))
    ;; Clon uses only long names, not short ones. But it's preferable to
    ;; reserve the prefix in both cases.
    (unless (builtin option)
      (dolist (name (list short-name long-name))
	(when (and name (or (and (= (length name) 4)
				 (string= name "clon"))
			    (and (> (length name) 4)
				 (string= name "clon-" :end1 5))))
	  (error "Option ~A: name ~S reserved by Clon." option name))))))


;; ============================================================================
;; The Flag class
;; ============================================================================

;; A flag can appear in the following forms:

;; -f, --flag                           both names
;; -f                                   short name
;; --flag                               long name

;; #### FIXME: make final
(defclass flag (option)
  ()
  (:documentation "The FLAG class.
This class implements options that don't take any argument."))

(defun make-flag (&rest keys &key short-name long-name description)
  "Make a new flag.
- SHORT-NAME is the option's short name without the dash.
  It defaults to nil.
- LONG-NAME is the option's long name, without the double-dash.
  It defaults to nil.
- DESCRIPTION is the option's description appearing in help strings.
  It defaults to nil."
  (declare (ignore short-name long-name description))
  (apply #'make-instance 'flag keys))


;; ============================================================================
;; The Valued Option class
;; ============================================================================

;; #### FIXME: make abstract
(defclass valued-option (option)
  ((argument-required :documentation "Whether the option's argument is required."
		      :reader argument-required-p
		      :initarg :argument-required)
   (argument-name :documentation "The option's argument display name."
		  :type string
		  :reader argument-name
		  :initarg :argument-name)
   (default-value :documentation "The option's default value."
		 :type (or null string)
		 :reader default-value
		 :initarg :default-value)
   (env-var :documentation "The option's associated environment variable."
	    :type (or null string)
	    :reader env-var
	    :initarg :env-var))
  (:default-initargs
    :argument-required t
    :argument-name "ARG"
    :default-value nil
    :env-var nil)
  (:documentation "The VALUED-OPTION class.
This class implements is the base class for options accepting arguments."))

;; #### FIXME: we should probably do this on the keywords, in a :before
;; method.
(defmethod initialize-instance :after ((option valued-option) &rest initargs)
  "Check consistency OPTION's value part."
  (declare (ignore initargs))
  (when (and (argument-name option) (zerop (length (argument-name option))))
    (error "option ~A: empty argument name." option))
  ;; #### FIXME: I can't remember why we don't accept empty default values...
  (when (and (default-value option) (zerop (length (default-value option))))
    (error "option ~A: empty default value." option)))


;; ============================================================================
;; The String Option class
;; ============================================================================

;; A string option can appear in the following formats:
;;
;;   -o, --option=STR                   both names, required argument
;;   -o, --option[=STR]                 both names, optional argument
;;   -o, --option                       both names, null argument name
;;   -o STR                             short name, required argument
;;   -o [STR]                           short name, optional argument
;;   -o                                 short name, null argument name
;;   --option=STR                       long name,  required argument
;;   --option[=STR]                     long name,  optional argument
;;   --option                           long name,  null argument name

;; #### FIXME: make final
(defclass stropt (valued-option)
  ()
  (:default-initargs :argument-name "STR")
  (:documentation "The STROPT class.
This class implements options the values of which are strings."))

(defun make-stropt (&rest keys
		    &key short-name long-name description
			 argument-required argument-name
			 default-value env-var)
  "Make a new STROPT."
  (declare (ignore short-name long-name description
		   argument-required argument-name
		   default-value env-var))
  (apply 'make-instance 'stropt keys))


;; ============================================================================
;; The Switch class
;; ============================================================================

;; A switch can appear in the following forms:
;;
;;  -(+)b, --boolean=yes(no)            both names, argument name given
;;  -(+)b, --boolean[=yes(no)]          both names, argument name given
;;  -(+)b, --boolean                    both names, null argument name
;;  -(+)b                               short name, regardless of argument
;;  --boolean[=yes(no)]                 long name,  argument name given,
;;  --boolean                           long name,  null argument name

(defclass switch (option argument)
  (argument)
  (:default-initargs
    :argument-required t
    :argument-name "ARG"
    :default-value nil
    :env-var nil)
  (:documentation "The SWITCH class.
This class implements boolean options."))

;(defun make-switch (&rest keys &keys)


;;; option.lisp ends here
