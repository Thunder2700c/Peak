# PEAK Native C++ layer

PEAK is moving toward **C++ for performance-critical gameplay systems**, using Godot's official `godot-cpp` GDExtension API.

## Why this approach

- The Godot engine and its renderer are already implemented largely in C++.
- A GDExtension lets PEAK add compiled native classes without first rebuilding the entire engine.
- The Android ARM64 build is compiled in GitHub Actions, so the Chromebook/phone does not need to compile the native toolchain locally.
- Existing GDScript systems remain in the project during migration. They are not automatically converted by compiling a C++ extension.

## First native class

`PeakNativeRuntime` is a deliberately small proof that the compiled Android extension loads and registers a native Godot node. Its `get_build_info()` method reports its build identity.

The extension currently targets Godot 4.7 and Android ARM64. Its release and debug libraries are built separately.

## Build

Run the `Build PEAK Godot Android Editor (ARM64)` GitHub Actions workflow. It produces two artifacts:

- `peak-godot-4.7-android-editor-arm64`: the custom-build editor APK (currently a clean Godot baseline plus any files under `engine/patches/`).
- `peak-native-extension-android-arm64`: the compiled C++ extension package.

The extension ZIP contains an `addons/peak_native/` directory. Copy that directory into the root of the Godot project before opening the project with the matching Godot 4.7 editor.

## Migration strategy

1. Verify that the native extension loads on the S23 FE.
2. Port one self-contained CPU-side system, with tests and parity checks, before porting more code.
3. Profile the game on-device to confirm whether each native port helps.
4. Add renderer/engine-source patches only when the public extension API cannot provide the needed capability.

C++ will not automatically improve GPU-bound rendering, shader cost, draw-call overhead, or asset memory use. PEAK still needs separate mobile graphics and content optimization.

GDScript remains available as optional glue during migration; the goal is to make new performance-critical gameplay systems native C++ rather than rewrite everything blindly.
