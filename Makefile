PYTHON ?= python3
CC ?= cc
CLANG ?= clang
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror
BUILD := build
BOOTSTRAP_C := compiler/lunac.py
BOOTSTRAP_LLVM := compiler/lunac_llvm.py
RUNTIME := runtime/luna_runtime.c
RUNTIME_H := runtime/luna_runtime.h
LLVM_RUNTIME := runtime/luna_runtime.ll
SELF_MODULES := \
	compiler/src/00_state_types.lith \
	compiler/src/10_lexer.lith \
	compiler/src/20_symbols_ir.lith \
	compiler/src/30_operators.lith \
	compiler/src/30_core_values.lith \
	compiler/src/31_expressions.lith \
	compiler/src/40_memory_arrays.lith \
	compiler/src/50_match_print.lith \
	compiler/src/60_statements.lith \
	compiler/src/70_scanner.lith \
	compiler/src/75_global_constants.lith \
	compiler/src/80_emitter_main.lith
SELF_SRC := $(BUILD)/lithc.lith
SELF_LITHC := $(BUILD)/lithc

.PHONY: all compiler driver-check semantic-check reference-selfhost test selfhost llvm llvm-check llvm-selfhost clean

all: compiler

$(BUILD):
	mkdir -p $(BUILD)

$(SELF_SRC): $(SELF_MODULES) | $(BUILD)
	cat $(SELF_MODULES) > $@

$(BUILD)/lithc-stage1.ll: $(SELF_SRC) $(BOOTSTRAP_LLVM) | $(BUILD)
	$(PYTHON) $(BOOTSTRAP_LLVM) $< $@

$(BUILD)/lithc-stage1: $(BUILD)/lithc-stage1.ll $(LLVM_RUNTIME)
	$(CLANG) -Wno-override-module -O2 $< $(LLVM_RUNTIME) -o $@

$(BUILD)/lithc-stage2.ll: $(SELF_SRC) $(BUILD)/lithc-stage1
	$(BUILD)/lithc-stage1 $(SELF_SRC) $@

$(SELF_LITHC): $(BUILD)/lithc-stage2.ll $(LLVM_RUNTIME)
	$(CLANG) -Wno-override-module -O2 $< $(LLVM_RUNTIME) -o $@

compiler: $(SELF_LITHC)
	chmod +x bin/lith bin/lithc bin/luna bin/lunac 2>/dev/null || true
	@echo 'Self-hosted Lith compiler: $(SELF_LITHC)'

$(BUILD)/reference.c: examples/reference.lith $(BOOTSTRAP_C) $(RUNTIME_H) | $(BUILD)
	$(PYTHON) $(BOOTSTRAP_C) $< $@

$(BUILD)/reference: $(BUILD)/reference.c $(RUNTIME) $(RUNTIME_H)
	$(CC) $(CFLAGS) -Iruntime $< $(RUNTIME) -o $@

$(BUILD)/reference.ll: examples/reference.lith $(BOOTSTRAP_LLVM) | $(BUILD)
	$(PYTHON) $(BOOTSTRAP_LLVM) $< $@

$(BUILD)/reference-llvm: $(BUILD)/reference.ll $(LLVM_RUNTIME)
	$(CLANG) -Wno-override-module -O2 $< $(LLVM_RUNTIME) -o $@

llvm: $(BUILD)/reference-llvm
	$(BUILD)/reference-llvm

selfhost:
	PYTHON=$(PYTHON) CC=$(CC) CFLAGS='$(CFLAGS)' BUILD=$(BUILD)/selfhost sh tests/self_host.sh

llvm-check:
	PYTHON=$(PYTHON) CLANG=$(CLANG) BUILD=$(BUILD)/llvm LLVM_LUNAC=$(BOOTSTRAP_LLVM) C_LUNAC=$(BOOTSTRAP_C) LLVM_RUNTIME=$(LLVM_RUNTIME) sh tests/llvm_backend.sh

llvm-selfhost: $(SELF_SRC)
	PYTHON=$(PYTHON) CLANG=$(CLANG) BUILD=$(BUILD)/llvm-selfhost LLVM_LUNAC=$(BOOTSTRAP_LLVM) LLVM_RUNTIME=$(LLVM_RUNTIME) SELF_SRC=$(SELF_SRC) sh tests/llvm_self_host.sh

driver-check: compiler
	sh bin/lith tests/selfhost_memory.lith -o $(BUILD)/driver-memory
	$(BUILD)/driver-memory
	sh bin/lith tests/selfhost_structs.lith -o $(BUILD)/driver-structs
	$(BUILD)/driver-structs
	sh bin/lith tests/selfhost_arrays.lith -o $(BUILD)/driver-arrays
	$(BUILD)/driver-arrays
	sh bin/lith tests/selfhost_operators.lith -o $(BUILD)/driver-operators
	$(BUILD)/driver-operators
	@echo 'Native Lith driver + memory + struct + array + operator parity: passed'

semantic-check: compiler
	sh tests/semantic_errors.sh

reference-selfhost: compiler
	BUILD=$(BUILD) sh tests/reference_selfhost.sh

test: compiler $(BUILD)/reference $(BUILD)/reference-llvm
	$(BUILD)/reference
	$(BUILD)/reference-llvm
	$(PYTHON) -m py_compile $(BOOTSTRAP_C) $(BOOTSTRAP_LLVM)
	$(MAKE) driver-check
	$(MAKE) semantic-check
	$(MAKE) reference-selfhost
	$(MAKE) selfhost
	$(MAKE) llvm-check
	$(MAKE) llvm-selfhost

clean:
	rm -rf $(BUILD) compiler/__pycache__ compiler/bootstrap/__pycache__
