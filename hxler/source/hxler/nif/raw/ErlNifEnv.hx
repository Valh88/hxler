package hxler.nif.raw;

/** Opaque C handle mapped to ::cpp::Pointer<ErlNifEnv> (implicit operator T*() at call sites). */
@:include("erl_nif.h")
@:native("::cpp::Pointer<ErlNifEnv>")
extern class ErlNifEnv {}
