package hxler.check;

import hxler.check.TInline;

@:keep
class TMain {
	public static function main() {
		var x = TInline.f(1, 2);
		var y = TInline.g(1, 2, 3, 4);
	}
}
