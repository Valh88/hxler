package hxler.nif.raw;

/**
 * Raw 1:1 bindings over the erl_nif API, GENERATED at compile time by
 * hxler.macros.RawGen from the ERTS header snapshot (hxler/include/).
 * Do not add fields here by hand - extend RawGen or the Wrapper instead.
 *
 * Every caller must compile with erl_nif.h in scope: put
 * @:headerCode('#include "erl_nif.h"') directly above each Haxe class that
 * calls into Raw (hxcpp emits plain call names; on Windows erl_nif.h routes
 * enif_* through the WinDynNifCallbacks table).
 *
 * RawGen excludes: variadic functions (use *_from_array variants),
 * functions taking C function pointers, and get_long/make_long/get_ulong/
 * make_ulong (platform-dependent long ABI; int64/uint64 variants are the
 * portable replacements).
 */
@:keep
@:headerCode('#include "erl_nif.h"')
@:build(hxler.macros.RawGen.build())
extern class Raw {
}
