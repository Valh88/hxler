package hxler.nif.raw;

/** Opaque C handle mapped to ::cpp::Pointer<ErlNifCond> (implicit operator T*() at call sites). */
@:include("erl_nif.h")
@:native("::cpp::Pointer<ErlNifCond>")
extern class ErlNifCond {}
