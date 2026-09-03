package hxler.core;

/**
 * Interface for user data stored in BEAM resources (rustler Resource
 * trait analog). Register the type once from the load callback with
 * Env.registerResource(T), then move instances across NIF calls as
 * ResourceArc<T> terms.
 *
 * On the BEAM heap only the HxResourceFrame {root, size, kind} lives;
 * the Haxe object itself stays on the hxcpp heap, held through the
 * GCAddRoot slot inside the frame (moves are tracked by hxcpp).
 *
 * NOTE: destructor/down hooks fire from the C glue (phase 5a wires only
 * GCRemoveRoot in dtor); the Haxe callback dispatch lands with phase 6.
 */
interface Resource {
}
