package my_nif;

/**
 * Generated glue: ErlNifFunc table, trampolines, boot, resource callbacks
 * and ERL_NIF_INIT for "Elixir.Example.MyNif".
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
@:build(hxler.macros.EntryBuilder.build(["my_nif.MyNifNif"], "Elixir.Example.MyNif"))
class Entry {
}
