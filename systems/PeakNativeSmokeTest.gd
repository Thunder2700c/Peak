extends Node

func _ready() -> void:
	print("=== PEAK NATIVE EXTENSION SMOKE TEST ===")

	if not ClassDB.class_exists("PeakNativeRuntime"):
		push_error("[PEAK Native] PeakNativeRuntime is NOT registered. Check the Output/Debugger for GDExtension load errors.")
		return

	print("[PEAK Native] Class registered successfully.")

	var native_object: Object = ClassDB.instantiate("PeakNativeRuntime")
	if native_object == null:
		push_error("[PEAK Native] Class exists, but instantiation failed.")
		return

	if not native_object.has_method("get_build_info"):
		push_error("[PEAK Native] Instance is missing get_build_info().")
		native_object.free()
		return

	print("[PEAK Native] ", native_object.call("get_build_info"))
	native_object.free()
	print("[PEAK Native] SMOKE TEST PASSED")
