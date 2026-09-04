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

.PHONY: all test selfhost llvm llvm-check llvm-selfhost clean

all: $(BUILD)/reference-llvm

$(BUILD):
	mkdir -p $(BUILD)

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

test: $(BUILD)/reference $(BUILD)/reference-llvm
	$(BUILD)/reference
	$(BUILD)/reference-llvm
	$(PYTHON) -m py_compile $(LUNAC) $(LLVM_LUNAC)
	$(MAKE) selfhost
	$(MAKE) llvm-check
	$(MAKE) llvm-selfhost

clean:
	rm -rf $(BUILD) compiler/__pycache__
