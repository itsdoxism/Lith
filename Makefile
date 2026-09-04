PYTHON ?= python3
CC ?= cc
CLANG ?= clang
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror
BUILD := build
LUNAC := compiler/lunac.py
LLVM_LUNAC := compiler/lunac_llvm.py
RUNTIME := runtime/luna_runtime.c
RUNTIME_H := runtime/luna_runtime.h
LLVM_RUNTIME := runtime/luna_runtime.ll
BOOTSTRAP_PARTS := \
	compiler/bootstrap/lunac_llvm.part1.luna \
	compiler/bootstrap/lunac_llvm.part2.luna \
	compiler/bootstrap/lunac_llvm.part3.luna
BOOTSTRAP_SRC := $(BUILD)/lunac_llvm.luna
SELF_LUNAC := $(BUILD)/lunac

.PHONY: all compiler driver-check test selfhost llvm llvm-check llvm-selfhost clean

all: compiler

$(BUILD):
	mkdir -p $(BUILD)

$(BOOTSTRAP_SRC): $(BOOTSTRAP_PARTS) | $(BUILD)
	cat $(BOOTSTRAP_PARTS) > $@

$(BUILD)/lunac-stage1.ll: $(BOOTSTRAP_SRC) $(LLVM_LUNAC) | $(BUILD)
	$(PYTHON) $(LLVM_LUNAC) $< $@

$(BUILD)/lunac-stage1: $(BUILD)/lunac-stage1.ll $(LLVM_RUNTIME)
	$(CLANG) -Wno-override-module -O2 $< $(LLVM_RUNTIME) -o $@

$(BUILD)/lunac-stage2.ll: $(BOOTSTRAP_SRC) $(BUILD)/lunac-stage1
	$(BUILD)/lunac-stage1 $(BOOTSTRAP_SRC) $@

$(SELF_LUNAC): $(BUILD)/lunac-stage2.ll $(LLVM_RUNTIME)
	$(CLANG) -Wno-override-module -O2 $< $(LLVM_RUNTIME) -o $@

compiler: $(SELF_LUNAC)
	chmod +x bin/luna bin/lunac
	@echo 'Self-hosted Luna compiler: $(SELF_LUNAC)'

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
	PYTHON=$(PYTHON) CLANG=$(CLANG) BUILD=$(BUILD)/llvm-selfhost LLVM_LUNAC=$(LLVM_LUNAC) LLVM_RUNTIME=$(LLVM_RUNTIME) sh tests/llvm_self_host.sh

driver-check: compiler
	sh bin/luna tests/llvm_runtime.luna -o $(BUILD)/driver-test
	@test "$$($(BUILD)/driver-test)" = 'a=hello n=5 eq=1 starts=1 cut=ell ch=! num=42'
	@echo 'Native Luna driver: passed'

test: compiler $(BUILD)/reference $(BUILD)/reference-llvm
	$(BUILD)/reference
	$(BUILD)/reference-llvm
	$(PYTHON) -m py_compile $(LUNAC) $(LLVM_LUNAC)
	$(MAKE) driver-check
	$(MAKE) selfhost
	$(MAKE) llvm-check
	$(MAKE) llvm-selfhost

clean:
	rm -rf $(BUILD) compiler/__pycache__
