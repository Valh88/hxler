package hxler.nif.raw;

/** Opaque C handle mapped to ::cpp::Pointer<ErlNifIOQueue> (implicit operator T*() at call sites). */
@:include("erl_nif.h")
@:native("::cpp::Pointer<ErlNifIOQueue>")
extern class ErlNifIOQueue {}
