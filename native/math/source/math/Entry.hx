package math;

/**
 * Phase 4/5 entry: the generated glue defines the ErlNifFunc table,
 * trampolines, boot, resource callbacks and ERL_NIF_INIT for
 * "Elixir.Hxler.Math". The load callback registers the resource types.
 */
@:keep
@:headerCode('#include "erl_nif.h"')
@:buildXml('<files id="haxe">
	<compilerflag value="-I${hxler_erts_include}" />
	<compilerflag value="-I${hxler_sdk_include}" />
</files>
<files id="__main__">
	<compilerflag value="-I${hxler_erts_include}" />
	<compilerflag value="-I${hxler_sdk_include}" />
</files>')
@:build(hxler.macros.EntryBuilder.build(["math.MathNif"], "Elixir.Hxler.Math", "math.ResourceInit.load"))
class Entry {
}
