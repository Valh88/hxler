package hxler.core;

/**
 * Scheduler selection for NIF functions (ErlNifFunc.flags). Mapped by the
 * `@:nif(schedule = "...")` macro (phase 4) into the generated func table.
 *
 *   Normal    (0): quick work on a regular BEAM scheduler (blocks it).
 *   DirtyCpu  (1): heavy CPU work on the dirty CPU pool.
 *   DirtyIo   (2): blocking IO on the dirty IO pool.
 *
 * Long Normal NIFs should call env.consumeTimeslice(pct) to yield.
 */
enum abstract Schedule(Int) {
	var Normal = 0;
	var DirtyCpu = 1;
	var DirtyIo = 2;

	public function toString():String {
		var i:Int = this;
		return switch (i) {
			case 0: "Normal";
			case 1: "DirtyCpu";
			case 2: "DirtyIo";
			default: "Schedule(" + i + ")";
		};
	}
}
