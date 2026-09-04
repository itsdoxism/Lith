PYTHON ?= python3
CC ?= cc
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror
BUILD := build
LUNAC := compiler/lunac.py
RUNTIME := runtime/luna_runtime.c
RUNTIME_H := runtime/luna_runtime.h

.PHONY: all test selfhost clean

all: $(BUILD)/reference

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/reference.c: examples/reference.luna $(LUNAC) $(RUNTIME_H) | $(BUILD)
	$(PYTHON) $(LUNAC) $< $@

$(BUILD)/reference: $(BUILD)/reference.c $(RUNTIME) $(RUNTIME_H)
	$(CC) $(CFLAGS) -Iruntime $< $(RUNTIME) -o $@

selfhost:
	PYTHON=$(PYTHON) CC=$(CC) CFLAGS='$(CFLAGS)' BUILD=$(BUILD)/selfhost sh tests/self_host.sh

test: $(BUILD)/reference
	$(BUILD)/reference
	$(PYTHON) -m py_compile $(LUNAC)
	$(MAKE) selfhost

clean:
	rm -rf $(BUILD) compiler/__pycache__
