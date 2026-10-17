#ifndef PEAK_NATIVE_RUNTIME_H
#define PEAK_NATIVE_RUNTIME_H
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/string.hpp>
namespace godot {
class PeakNativeRuntime : public Node {
    GDCLASS(PeakNativeRuntime, Node)
protected:
    static void _bind_methods();
public:
    String get_build_info() const;
};
}
#endif
