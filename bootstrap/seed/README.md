# Lith trusted bootstrap seed

This directory is reserved for a verified native Lith compiler seed.

Current canonical seed path for the supported Linux target:

- `bootstrap/seed/lithc-linux-x86_64`

The normal Lith build does not fall back to Python. A clean checkout requires either:

1. an explicit compiler supplied through `LITH_SEED`, or
2. the bundled trusted seed at the path above.

The seed must not be copied from an arbitrary compiler binary. It is accepted only after self-host verification proves, byte-for-byte:

- `build/lithc-stage2.ll == build/lithc-stage3.ll`
- `build/lithc-stage3.ll == build/lithc-stage4.ll`

`tools/lith_seed.lith` performs the same equality check before exporting a seed from an already trusted native build.

## Creating the first bundled seed

`.github/workflows/bootstrap-seed.yml` is a manual, provenance-preserving bootstrap path. It temporarily recovers the historical trusted Python LLVM bootstrap from the pinned commit documented in the workflow, uses it to produce a native compiler, verifies stage equality, and then verifies the resulting seed through a clean `make compiler` and `make test` run.

The historical Python bootstrap is not restored to the repository or used by the normal build path.

If the workflow passes, it uploads these candidate artifacts for review:

- `lithc-linux-x86_64`
- `manifest.txt`

The manifest records the current source commit, historical bootstrap commit, verification method, and SHA-256 digest. Review those artifacts before committing the seed into this directory.

Do not fabricate or hand-edit the seed binary or its provenance metadata.
