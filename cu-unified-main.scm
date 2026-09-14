;;; cu-unified-main.scm -- static-executable entry point for cu-unified.scm.
;;;
;;; csc -static -o cu-unified-server cu-unified-main.scm
(include "cu-unified.scm")
(import (awful main) cu-unified)
(module main = ((awful main) cu-unified))
