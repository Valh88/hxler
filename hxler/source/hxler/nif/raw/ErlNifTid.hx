package hxler.nif.raw;

/** ErlNifTid is itself a pointer typedef (struct ErlDrvTid_*). */
@:include("erl_nif.h")
@:native("::cpp::Pointer<ErlNifTid>")
extern class ErlNifTid {}
