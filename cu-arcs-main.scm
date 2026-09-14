;;; cu-arcs-main.scm -- static-executable entry point for cu-arcs.scm.
;;;
;;; csc -static -o cu-arcs-server cu-arcs-main.scm
(include "cu-arcs.scm")
(import (awful main) cu-arcs)
(module main = ((awful main) cu-arcs))
