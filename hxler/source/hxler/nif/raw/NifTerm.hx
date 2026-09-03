package hxler.nif.raw;

/** ERL_NIF_TERM = machine word. */
#if HXCPP_M64
typedef NifTerm = cpp.UInt64;
#else
typedef NifTerm = cpp.UInt32;
#end
