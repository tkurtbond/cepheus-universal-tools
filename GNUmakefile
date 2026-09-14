# GNUmakefile -- build static executables for the awful web apps using
# the awful-main egg.
#
#   make            build all static executables (into build/)
#   make run-arcs   build (if needed) and run the cu-arcs server
#   make run-worlds build (if needed) and run the cu-worlds server
#   make clean      remove build/

CSC = csc
CSC_FLAGS = -static -O3

BUILD_DIR = build

APPS = cu-arcs cu-worlds

EXECUTABLES = $(APPS:%=$(BUILD_DIR)/%-server)

.PHONY: all clean run-arcs run-worlds

all: $(EXECUTABLES)

$(BUILD_DIR)/cu-arcs-server: cu-arcs-main.scm cu-arcs.scm alien-tables.scm worlds-tables.scm roll-tables.scm | $(BUILD_DIR)
	$(CSC) $(CSC_FLAGS) -o $@ $<

$(BUILD_DIR)/cu-worlds-server: cu-worlds-main.scm cu-worlds.scm worlds-tables.scm roll-tables.scm | $(BUILD_DIR)
	$(CSC) $(CSC_FLAGS) -o $@ $<

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)/static

run-arcs: $(BUILD_DIR)/cu-arcs-server
	$(BUILD_DIR)/cu-arcs-server --port=2020

run-worlds: $(BUILD_DIR)/cu-worlds-server
	$(BUILD_DIR)/cu-worlds-server --port=2021

clean:
	rm -rf $(BUILD_DIR)
