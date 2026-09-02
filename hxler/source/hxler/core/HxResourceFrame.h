#ifndef HXLER_HX_RESOURCE_FRAME_H
#define HXLER_HX_RESOURCE_FRAME_H

#include <hxcpp.h>

namespace hxler {

// The resource-payload frame embedded at the START of every BEAM
// resource allocated by the hxler SDK (phase-5 handshake, see
// AGENTS.md "Memory model"). Mirrors hxler.nif.raw.ErlNifResourceFrame.
//
// PHASE-5 HANDSHAKE: `root` does NOT hold a raw hx::Object* (hxcpp's Immix
// compactor cannot relocate slots in foreign BEAM memory, so GCAddRoot on
// the frame was unreliable). Instead `root` stores the integer SLOT INDEX
// of the object in ResourceCache's immortal holders table (a boot-rooted
// static array that hxcpp never moves). Decode reads the index and fetches
// the object back through ResourceCache.fetch(index).
struct HxResourceFrame {
	void* root;   // SLOT INDEX into the immortal holders table (not an object pointer)
	int size;     // total resource size in bytes (frame + user payload)
	::String kind; // full Haxe class path of the stored type
	HxResourceFrame() : root(0), size(0) {}
};

} // namespace hxler

#endif
