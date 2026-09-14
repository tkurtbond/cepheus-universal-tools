# GNUmakefile -- build static executables for the awful web apps using
# the awful-main egg.
#
#   make                 build all static executables (into build/)
#   make run-arcs        build (if needed) and run the cu-arcs server
#   make run-worlds      build (if needed) and run the cu-worlds server
#   make run-systems     build (if needed) and run the cu-systems server
#   make test            run every test below
#   make test-unit       run the alien-tables/worlds-tables/system-tables unit tests
#   make test-e2e        run all three end-to-end smoke tests
#   make clean           remove build/

CSC = csc
CSC_FLAGS = -static -O3
CSI = csi

BUILD_DIR = build

APPS = cu-arcs cu-worlds cu-systems

EXECUTABLES = $(APPS:%=$(BUILD_DIR)/%-server)

.PHONY: all clean run-arcs run-worlds run-systems test test-unit test-e2e \
	test-alien-tables test-worlds-tables test-system-tables \
	test-e2e-arcs test-e2e-worlds test-e2e-systems

all: $(EXECUTABLES)

$(BUILD_DIR)/cu-arcs-server: cu-arcs-main.scm cu-arcs.scm alien-tables.scm worlds-tables.scm roll-tables.scm | $(BUILD_DIR)
	$(CSC) $(CSC_FLAGS) -o $@ $<

$(BUILD_DIR)/cu-worlds-server: cu-worlds-main.scm cu-worlds.scm worlds-tables.scm roll-tables.scm | $(BUILD_DIR)
	$(CSC) $(CSC_FLAGS) -o $@ $<

$(BUILD_DIR)/cu-systems-server: cu-systems-main.scm cu-systems.scm system-tables.scm worlds-tables.scm roll-tables.scm | $(BUILD_DIR)
	$(CSC) $(CSC_FLAGS) -o $@ $<

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)/static

run-arcs: $(BUILD_DIR)/cu-arcs-server
	$(BUILD_DIR)/cu-arcs-server --port=8101

run-worlds: $(BUILD_DIR)/cu-worlds-server
	$(BUILD_DIR)/cu-worlds-server --port=8102

run-systems: $(BUILD_DIR)/cu-systems-server
	$(BUILD_DIR)/cu-systems-server --port=8103

test: test-unit test-e2e

test-unit: test-alien-tables test-worlds-tables test-system-tables

test-alien-tables: test-alien-tables.scm alien-tables.scm roll-tables.scm
	$(CSI) -s test-alien-tables.scm

test-worlds-tables: test-worlds-tables.scm worlds-tables.scm roll-tables.scm
	$(CSI) -s test-worlds-tables.scm

test-system-tables: test-system-tables.scm system-tables.scm worlds-tables.scm roll-tables.scm
	$(CSI) -s test-system-tables.scm

test-e2e: test-e2e-arcs test-e2e-worlds test-e2e-systems

test-e2e-arcs: test-e2e.sh cu-arcs.scm
	./test-e2e.sh

test-e2e-worlds: test-worlds-e2e.sh cu-worlds.scm
	./test-worlds-e2e.sh

test-e2e-systems: test-systems-e2e.sh cu-systems.scm
	./test-systems-e2e.sh

clean:
	rm -rf $(BUILD_DIR)
