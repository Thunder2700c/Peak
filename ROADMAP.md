# Roadmap

Statuses apply to the initial foundation; nothing is marked tested without an actual result.

## Phase 0 — Repository/build foundation (in progress)
- [x] Set umbrella name and two edition names.
- [x] Keep the engine source-tree separate from game assets in this staged branch.
- [x] Add manual CI definitions for Android editor, native extension and Linux editor.
- [x] Add a native C++ GDExtension scaffold and isolated smoke-test project.
- [ ] Move current clean staging tree to a new standalone GitHub repository.
- [ ] Pin upstream revisions and confirm the license bundle.
**Gate:** dedicated engine repository, no PEAK assets, repeatable manual build.

## Phase 1 — Native C++ proof (scaffolded, not runtime-verified)
- [x] Implement PeakNativeRuntime::get_build_info().
- [x] Add on-screen smoke test.
- [ ] Build the artifact from this engine repository.
- [ ] Confirm class registration, instance creation and build info on target.
**Gate:** extension loads in matching Godot 4.7 editor; log/UI says SMOKE TEST PASSED.

## Phase 2 — First stylized visual slice (not started)
- [ ] Create an isolated mesh/light/environment demo.
- [ ] Implement a low-cost anime-surface shader with colour palette and optional albedo/normal/AO.
- [ ] Preserve UV and triplanar workflows with explicit safe texture-scale defaults.
- [ ] Keep expensive GI/reflection features off by default.
- [ ] Record FPS/frame time before promoting material to PEAK.
**Gate:** visible art-direction improvement with no severe performance regression on S23 FE.

## Phase 3 — Mobile renderer baseline
- [ ] Mobile/Balanced/High profiles.
- [ ] Centralized environment/light ownership for streamed chunks.
- [ ] Resolution scaling, shadow distance, LOD/culling, instancing and texture budgets.
- [ ] Measure cold start, frame time, memory and thermal behavior.
**Gate:** stable documented baseline on target hardware.

## Phase 4 — Engine-source renderer/editor work
- [ ] Check if each feature needs a Godot patch or can live in a shader/GDExtension.
- [ ] Add small reviewed patches only for justified engine limitations.
- [ ] Pin upstream revision and validate all patches with git apply --check.
- [ ] Rebuild after a coherent patch batch and compare with unmodified Godot using the same scene.
**Gate:** reproducible benefit in benchmark or authoring workflow.

## Phase 5 — Beginner workflows and releases
- [ ] Mobile 3D project template, starter controller, lighting/material presets and diagnostics.
- [ ] Test that a beginner can create/run a small project without local command-line setup.
- [ ] Versioned artifacts, checksums, changelog, notices and rollback steps.
- [ ] ARUT Mobile Android ARM64; HARDT Studio desktop first, other platforms later.

**Test policy:** don't ask for an APK test until Phase 1 plus Phase 2 form a complete vertical slice. Run one combined cloud build at that gate.
