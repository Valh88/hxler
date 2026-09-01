package hxler.nif.raw;

/** Opaque C handle mapped to ::cpp::Pointer<ErlNifSysInfo> (implicit operator T*() at call sites). */
@:include("erl_nif.h")
@:native("::cpp::Pointer<ErlNifSysInfo>")
extern class ErlNifSysInfo {}
