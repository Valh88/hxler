package hxler.core;

/**
 * Phase-8 placeholders for the monitor callback signatures (the real
 * OwnedEnv/Pid plumbing lands in phase 6). ErlNifPid is @:stackOnly in
 * the raw layer, so Pid keeps a POINTER to a stack ErlNifPid instead of
 * the struct itself.
 */
@:keep
@:unreflective
@:headerCode('#include "erl_nif.h"')
class Pid {
	public var raw(default, null):cpp.Pointer<hxler.nif.raw.ErlNifPid>;

	@:allow(hxler)
	function new(raw:cpp.Pointer<hxler.nif.raw.ErlNifPid>) {
		this.raw = raw;
	}
}

@:keep
@:unreflective
class Monitor {
	public var raw(default, null):hxler.nif.raw.ErlNifMonitor;

	@:allow(hxler.core.ResourceArc)
	function new(raw:hxler.nif.raw.ErlNifMonitor) {
		this.raw = raw;
	}
}
