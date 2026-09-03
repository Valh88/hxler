package hxler.nif.raw;

/** Opaque C handle mapped to ::cpp::Pointer<ErlNifRWLock> (implicit operator T*() at call sites). */
@:include("erl_nif.h")
@:native("::cpp::Pointer<ErlNifRWLock>")
extern class ErlNifRWLock {}
