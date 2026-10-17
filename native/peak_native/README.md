# Native C++ layer

This is the initial GDExtension proof, not a claim that all GDScript has been converted. `PeakNativeRuntime` exposes `get_build_info()` so a small test project can confirm class registration and instantiation.

Build dynamic libraries for the exact Godot API, platform, architecture and build type. The workflow packages libraries and the .gdextension manifest; generated binaries must not be committed.

Only port measured CPU hot paths one at a time. Keep existing scenes and scripts working while validating native code.
