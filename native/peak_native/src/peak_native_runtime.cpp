#include "peak_native_runtime.h"
namespace godot {
void PeakNativeRuntime::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_build_info"), &PeakNativeRuntime::get_build_info);
}
String PeakNativeRuntime::get_build_info() const {
    return String("ARUT-HARDT Engine native layer | Godot 4.7 | C++");
}
}
