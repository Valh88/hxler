package hxler.macros;

import haxe.macro.Context;
import haxe.macro.Expr;

/**
 * Generates lazily-initialized atom getters (rustler `atoms!` analog):
 *
 *   @:build(hxler.macros.AtomBuilder.build(["ok", "error", "nil", "true"]))
 *   class Atoms {}
 *
 * produces `Atoms.ok():Atom`, `Atoms.error():Atom`, ..., each interning
 * the atom on first use through AtomCache (thread-safe, one shared env).
 * Atom texts are exact; identifiers are sanitized via AtomNames.
 */
class AtomBuilder {
	public static function build(names:Array<String>):Array<Field> {
		var fields = Context.getBuildFields();
		var pos = Context.currentPos();
		var seen = new Map<String, Bool>();

		for (name in names) {
			var ident = AtomNames.identifier(name);
			if (seen.get(ident)) {
				Context.fatalError('AtomBuilder: duplicate identifier "$ident" for atom "$name"', pos);
			}
			seen.set(ident, true);

			var cacheField = "_" + ident;
			var atomNameExpr:Expr = {expr: EConst(CString(name, DoubleQuotes)), pos: pos};

			fields.push({
				name: cacheField,
				access: [AStatic, APrivate],
				kind: FVar(macro:Null<hxler.core.Atom>, macro null),
				pos: pos
			});

			var getter:Field = {
				name: ident,
				access: [APublic, AStatic],
				kind: FFun({
					args: [],
					ret: macro:hxler.core.Atom,
					expr: macro {
						if ($i{cacheField} == null) {
							$i{cacheField} = hxler.core.AtomCache.intern($e{atomNameExpr});
						}
						return $i{cacheField};
					}
				}),
				pos: pos,
				doc: 'Atom "$name" (lazily interned).'
			};
			fields.push(getter);
		}
		return fields;
	}
}
