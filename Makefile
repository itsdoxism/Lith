PYTHON ?= python3
CC ?= cc
CLANG ?= clang
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror
BUILD := build
LUNAC := compiler/lunac.py
LLVM_LUNAC := compiler/lunac_llvm.py
SELF_SRC := compiler/lunac.luna
SELF_LUNAC := $(BUILD)/lunac
RUNTIME := runtime/luna_runtime.c
RUNTIME_H := runtime/luna_runtime.h
LLVM_RUNTIME := runtime/luna_runtime.ll
BOOTSTRAP_GEN := compiler/bootstrap/build_reference_parity.py
BOOTSTRAP_CHECK_SRC := $(BUILD)/bootstrap-check.luna

.PHONY: all compiler bootstrap-source-check driver-check reference-selfhost test selfhost llvm llvm-check llvm-selfhost clean

all: compiler

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/lunac-stage1.ll: $(SELF_SRC) $(LLVM_LUNAC) | $(BUILD)
	$(PYTHON) $(LLVM_LUNAC) $(SELF_SRC) $@

$(BUILD)/lunac-stage1: $(BUILD)/lunac-stage1.ll $(LLVM_RUNTIME)
	$(CLANG) -Wno-override-module -O2 $< $(LLVM_RUNTIME) -o $@

$(BUILD)/lunac-stage2.ll: $(SELF_SRC) $(BUILD)/lunac-stage1
	$(BUILD)/lunac-stage1 $(SELF_SRC) $@

$(SELF_LUNAC): $(BUILD)/lunac-stage2.ll $(LLVM_RUNTIME)
	$(CLANG) -Wno-override-module -O2 $< $(LLVM_RUNTIME) -o $@

compiler: $(SELF_LUNAC)
	chmod +x bin/luna bin/lunac 2>/dev/null || true
	@echo 'Self-hosted Luna compiler: $(SELF_LUNAC)'

bootstrap-source-check: | $(BUILD)
	$(PYTHON) $(BOOTSTRAP_GEN) $(BOOTSTRAP_CHECK_SRC)
	cmp $(BOOTSTRAP_CHECK_SRC) $(SELF_SRC)
	@echo 'Historical bootstrap generator reproduces compiler/lunac.luna'

$(BUILD)/reference.c: examples/reference.luna $(LUNAC) $(RUNTIME_H) | $(BUILD)
	$(PYTHON) $(LUNAC) $< $@

$(BUILD)/reference: $(BUILD)/reference.c $(RUNTIME) $(RUNTIME_H)
	$(CC) $(CFLAGS) -Iruntime $< $(RUNTIME) -o $@

$(BUILD)/reference.ll: examples/reference.luna $(LLVM_LUNAC) | $(BUILD)
	$(PYTHON) $(LLVM_LUNAC) $< $@

$(BUILD)/reference-llvm: $(BUILD)/reference.ll $(LLVM_RUNTIME)
	$(CLANG) -Wno-override-module -O2 $< $(LLVM_RUNTIME) -o $@

llvm: $(BUILD)/reference-llvm
	$(BUILD)/reference-llvm

selfhost:
	PYTHON=$(PYTHON) CC=$(CC) CFLAGS='$(CFLAGS)' BUILD=$(BUILD)/selfhost sh tests/self_host.sh

llvm-check:
	PYTHON=$(PYTHON) CLANG=$(CLANG) BUILD=$(BUILD)/llvm LLVM_LUNAC=$(LLVM_LUNAC) C_LUNAC=$(LUNAC) LLVM_RUNTIME=$(LLVM_RUNTIME) sh tests/llvm_backend.sh

llvm-selfhost:
	PYTHON=$(PYTHON) CLANG=$(CLANG) BUILD=$(BUILD)/llvm-selfhost LLVM_LUNAC=$(LLVM_LUNAC) LLVM_RUNTIME=$(LLVM_RUNTIME) SELF_SRC=$(SELF_SRC) sh tests/llvm_self_host.sh

driver-check: compiler
	sh bin/luna tests/selfhost_memory.luna -o $(BUILD)/driver-memory
	$(BUILD)/driver-memory
	sh bin/luna tests/selfhost_structs.luna -o $(BUILD)/driver-structs
	$(BUILD)/driver-structs
	@echo 'Native Luna driver + memory + struct member parity: passed'

reference-selfhost: compiler
	BUILD=$(BUILD) sh tests/reference_selfhost.sh

test: compiler $(BUILD)/reference $(BUILD)/reference-llvm
	$(BUILD)/reference
	$(BUILD)/reference-llvm
	$(PYTHON) -m py_compile $(LUNAC) $(LLVM_LUNAC) $(BOOTSTRAP_GEN)
	$(MAKE) bootstrap-source-check
	$(MAKE) driver-check
	$(MAKE) reference-selfhost
	$(MAKE) selfhost
	$(MAKE) llvm-check
	$(MAKE) llvm-selfhost

clean:
	rm -rf $(BUILD) compiler/__pycache__ compiler/bootstrap/__pycache__
