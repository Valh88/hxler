package hxler.nif.raw;

/** Opaque C handle mapped to ::cpp::Pointer<ErlNifResourceType> (implicit operator T*() at call sites). */
@:include("erl_nif.h")
@:native("::cpp::Pointer<ErlNifResourceType>")
extern class ErlNifResourceType {}
