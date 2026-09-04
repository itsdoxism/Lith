PYTHON ?= python3
CC ?= cc
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror
BUILD := build
LUNAC := compiler/lunac.py

.PHONY: all test clean

all: $(BUILD)/reference

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/reference.c: examples/reference.luna $(LUNAC) | $(BUILD)
	$(PYTHON) $(LUNAC) $< $@

$(BUILD)/reference: $(BUILD)/reference.c
	$(CC) $(CFLAGS) $< -o $@

test: $(BUILD)/reference
	$(BUILD)/reference
	$(PYTHON) -m py_compile $(LUNAC)

clean:
	rm -rf $(BUILD) compiler/__pycache__