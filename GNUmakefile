# GNUmakefile -- build static executables for the awful web apps using
# the awful-main egg.
#
#   make                 build all static executables (into build/)
#   make run-arcs        build (if needed) and run the cu-arcs server
#   make run-worlds      build (if needed) and run the cu-worlds server
#   make test            run every test below
#   make test-unit       run the alien-tables/worlds-tables unit tests
#   make test-e2e        run both end-to-end smoke tests
#   make clean           remove build/

CSC = csc
CSC_FLAGS = -static -O3
CSI = csi

BUILD_DIR = build

APPS = cu-arcs cu-worlds

EXECUTABLES = $(APPS:%=$(BUILD_DIR)/%-server)

.PHONY: all clean run-arcs run-worlds test test-unit test-e2e \
	test-alien-tables test-worlds-tables test-e2e-arcs test-e2e-worlds

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

test: test-unit test-e2e

test-unit: test-alien-tables test-worlds-tables

test-alien-tables: test-alien-tables.scm alien-tables.scm roll-tables.scm
	$(CSI) -s test-alien-tables.scm

test-worlds-tables: test-worlds-tables.scm worlds-tables.scm roll-tables.scm
	$(CSI) -s test-worlds-tables.scm

test-e2e: test-e2e-arcs test-e2e-worlds

test-e2e-arcs: test-e2e.sh cu-arcs.scm
	./test-e2e.sh

test-e2e-worlds: test-worlds-e2e.sh cu-worlds.scm
	./test-worlds-e2e.sh

clean:
	rm -rf $(BUILD_DIR)
