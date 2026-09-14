;;; cu-systems-main.scm -- static-executable entry point for cu-systems.scm.
;;;
;;; csc -static -o cu-systems-server cu-systems-main.scm
(include "cu-systems.scm")
(import (awful main) cu-systems)
(module main = ((awful main) cu-systems))
