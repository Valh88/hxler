package hxler.nif.raw;

/** ErlDrvMonitor: opaque 32-byte blob. */
@:include("erl_nif.h")
@:native("::cpp::Pointer<ErlNifMonitor>")
extern class ErlNifMonitor {}
