;;; cu-worlds-main.scm -- static-executable entry point for cu-worlds.scm.
;;;
;;; csc -static -o cu-worlds-server cu-worlds-main.scm
(include "cu-worlds.scm")
(import (awful main) cu-worlds)
(module main = ((awful main) cu-worlds))
