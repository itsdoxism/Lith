# Lith trusted bootstrap seed

This directory is reserved for a verified native Lith compiler seed.

Current canonical seed path for the supported POSIX target:

- `bootstrap/seed/lithc-linux-x86_64`

The seed must not be created from an arbitrary compiler binary. Export it only from a build where Lith self-host verification has already proven:

- `build/lithc-stage2.ll == build/lithc-stage3.ll`
- `build/lithc-stage3.ll == build/lithc-stage4.ll`

Use `tools/lith_seed.lith` to perform that check and export the compiler binary plus `manifest.txt`.

Bootstrap selection order in `tools/lith_build.lith`:

1. `LITH_SEED` environment variable, when explicitly provided.
2. `bootstrap/seed/lithc-linux-x86_64`, when present.
3. Python bootstrap fallback for a clean checkout with no trusted seed.

A checked-in seed therefore removes Python from the normal clean-build path, while keeping Python as a recovery/reference bootstrap.

The seed binary itself should only be committed after it has been produced on a known system, self-host equality has passed, and its provenance has been reviewed. Do not fabricate or hand-edit the seed artifact.
