CLANG ?= clang
BUILD := build
SEED ?= bootstrap/seed/lithc-linux-x86_64
LLVM_RUNTIME := runtime/luna_runtime.ll
BYTES_RUNTIME := runtime/lith_bytes.ll
FS_RUNTIME := runtime/lith_fs.ll
FS_POSIX_RUNTIME := runtime/lith_fs_posix.ll
PATH_RUNTIME := runtime/lith_path.ll
PROCESS_POSIX_RUNTIME := runtime/lith_process_posix.ll
LITH_BUILD := $(BUILD)/lith-build
SELF_LITHC := $(BUILD)/lithc
LITH_DRIVER := $(BUILD)/lith-driver
LITH_SEED_TOOL := $(BUILD)/lith-seed

.PHONY: all compiler native-rebuild seed-export driver-check native-surfaces-check semantic-check core-check backend-boundary-check ir-middle-end-check test clean

all: compiler

$(BUILD):
	mkdir -p $(BUILD)

$(LITH_BUILD): tools/lith_build.lith $(SEED) | $(BUILD)
	chmod +x $(SEED)
	$(SEED) tools/lith_build.lith $(BUILD)/lith-build.ll
	$(CLANG) -Wno-override-module -O2 \
		$(BUILD)/lith-build.ll \
		$(LLVM_RUNTIME) \
		$(BYTES_RUNTIME) \
		$(FS_RUNTIME) \
		$(FS_POSIX_RUNTIME) \
		$(PATH_RUNTIME) \
		$(PROCESS_POSIX_RUNTIME) \
		-o $(LITH_BUILD)

compiler: $(LITH_BUILD)
	LITH_SEED=$(SEED) CLANG=$(CLANG) $(LITH_BUILD)
	$(LITH_DRIVER) tools/lith_seed.lith -o $(LITH_SEED_TOOL)
	chmod +x bin/lith bin/lithc $(SELF_LITHC) $(LITH_DRIVER) $(LITH_BUILD) $(LITH_SEED_TOOL) 2>/dev/null || true
	@echo 'Self-hosted Lith compiler: $(SELF_LITHC)'
	@echo 'Lith-native driver: $(LITH_DRIVER)'
	@echo 'Lith-native build orchestrator: $(LITH_BUILD)'

native-rebuild: compiler
	LITH_SEED=$(SELF_LITHC) CLANG=$(CLANG) $(LITH_BUILD)

seed-export: native-rebuild
	$(LITH_DRIVER) tools/lith_seed.lith -o $(LITH_SEED_TOOL)
	$(LITH_SEED_TOOL)

driver-check: compiler
	bin/lith tests/selfhost_memory.lith -o $(BUILD)/driver-memory
	$(BUILD)/driver-memory
	bin/lith tests/selfhost_structs.lith -o $(BUILD)/driver-structs
	$(BUILD)/driver-structs
	bin/lith tests/selfhost_arrays.lith -o $(BUILD)/driver-arrays
	$(BUILD)/driver-arrays
	bin/lith tests/selfhost_operators.lith -o $(BUILD)/driver-operators
	$(BUILD)/driver-operators
	@echo 'Lith-native driver + memory + struct + array + operator parity: passed'

native-surfaces-check: compiler
	bin/lith tools/native_surfaces_runner.lith -o $(BUILD)/native-surfaces-runner
	$(BUILD)/native-surfaces-runner

semantic-check: compiler
	sh tests/semantic_errors.sh

core-check: compiler
	sh tests/core_language.sh

backend-boundary-check:
	sh tests/backend_boundary.sh

ir-middle-end-check: compiler
	BUILD=$(BUILD)/ir-middle-end LITHC=bin/lithc CLANG=$(CLANG) LLVM_RUNTIME=$(LLVM_RUNTIME) sh tests/ir_middle_end.sh

test: compiler
	$(MAKE) backend-boundary-check
	$(MAKE) ir-middle-end-check
	$(MAKE) driver-check
	$(MAKE) native-surfaces-check
	$(MAKE) semantic-check
	$(MAKE) core-check

clean:
	rm -rf $(BUILD)
