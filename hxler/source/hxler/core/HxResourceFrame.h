#ifndef HXLER_HX_RESOURCE_FRAME_H
#define HXLER_HX_RESOURCE_FRAME_H

#include <hxcpp.h>

namespace hxler {

// The resource-payload frame embedded at the START of every BEAM
// resource allocated by the hxler SDK (phase-5 handshake, see
// AGENTS.md "Memory model"). Mirrors hxler.nif.raw.ErlNifResourceFrame.
struct HxResourceFrame {
	void* root;   // GCAddRoot slot (hx::Object*): hxcpp updates it when the object moves
	int size;     // total resource size in bytes (frame + user payload)
	::String kind; // full Haxe class path of the stored type
	HxResourceFrame() : root(0), size(0) {}
};

} // namespace hxler

#endif
