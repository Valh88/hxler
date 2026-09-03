package hxler.nif.raw;

/** ErlNifEvent is void* on Windows, int elsewhere. */
#if (windows || HX_WINDOWS)
typedef NifEvent = cpp.Star<cpp.Void>;
#else
typedef NifEvent = Int;
#end
