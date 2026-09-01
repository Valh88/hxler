package math;

/**
 * Phase 4 entry: the generated glue defines the ErlNifFunc table,
 * trampolines, boot and ERL_NIF_INIT for "Elixir.Hxler.Math".
 */
@:keep
@:headerCode('#include "erl_nif.h"')
@:buildXml('<files id="haxe">
	<compilerflag value="-I${hxler_erts_include}" />
</files>
<files id="__main__">
	<compilerflag value="-I${hxler_erts_include}" />
</files>')
@:build(hxler.macros.EntryBuilder.build(["math.MathNif"], "Elixir.Hxler.Math"))
class Entry {
}
