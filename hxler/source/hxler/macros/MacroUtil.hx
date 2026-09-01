package hxler.macros;

import haxe.macro.Context;
import haxe.macro.Expr;

/** Shared helpers for code-generating build macros. */
class MacroUtil {
	/** Parses a code snippet as a block expression: { statements... }. */
	public static function parseBlock(code:String, pos:Position):Expr {
		var e = Context.parse("{" + code + "}", pos);
		return switch (e.expr) {
			case EBlock(exprs):
				{expr: EBlock(exprs), pos: pos};
			default:
				Context.fatalError("MacroUtil.parseBlock: unexpected shape", pos);
		}
	}

	/** Parses a `pack.Type` (or generic `pack.Type<T>`) into a ComplexType. */
	public static function tpath(s:String):ComplexType {
		var generic = null;
		var gStart = s.indexOf("<");
		if (gStart >= 0 && StringTools.endsWith(s, ">")) {
			generic = s.substring(gStart + 1, s.length - 1);
			s = s.substring(0, gStart);
		}
		var parts = s.split(".");
		var name = parts.pop();
		var params = null;
		if (generic != null) {
			var inner = tpath(generic);
			params = [TPType(inner)];
		}
		return TPath({pack: parts, name: name, params: params});
	}

	/** Wraps expr code into a static function Field with the given args. */
	public static function makeFunction(name:String, argsCode:Array<{name:String, type:String}>, retType:String, bodyCode:String,
			pos:Position):Field {
		var args = [];
		for (a in argsCode) {
			args.push({name: a.name, type: tpath(a.type)});
		}
		var f:Function = {
			args: args,
			ret: tpath(retType),
			expr: parseBlock(bodyCode, pos),
		};
		return {
			name: name,
			access: [APublic, AStatic],
			kind: FFun(f),
			pos: pos,
			meta: [{name: ":keep", params: [], pos: pos}]
		};
	}
}
