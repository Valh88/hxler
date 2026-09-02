package math;

import hxler.core.Env;
import hxler.core.EnvKind;
import hxler.core.Term;
import hxler.core.Resource;
import hxler.core.ResourceArc;

/**
 * Phase-5 demo resource: a growable accumulator holding an Array<Int>.
 * The Haxe object lives on the hxcpp heap, rooted inside the BEAM
 * resource frame; Elixir only sees the opaque resource term.
 */
@:keep
class Accum implements Resource {
	public var items:Array<Int>;
	public var freed:Bool;
	public var count:Int;

	public function new() {
		items = [];
		freed = false;
		count = 0;
	}

	public function push(v:Int):Void {
		items.push(v);
		count++;
	}

	public function sum():Int {
		var s = 0;
		for (v in items) {
			s += v;
		}
		return s;
	}
}
