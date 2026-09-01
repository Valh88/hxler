package hxler.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import hxler.macros.EntryBuilder.TypeStr;

typedef NifDefMeta = {
	var func:String; // Haxe method name
	var nif:String; // exported NIF name
	var arity:Int;
	var flags:Int; // ErlNifFunc.flags
	var schedule:String; // "normal" | "dirty_cpu" | "dirty_io"
	var isRaw:Bool; // (env, argc, argv) -> NifTerm
	var envFirst:Bool; // auto-mode: first Haxe param is Env
	var paramTypes:Array<String>; // Haxe type strings of the NIF args
	var retType:String; // Haxe type string of the return
}

/**
 * Build macro for NIF-function classes:
 *
 *   @:build(hxler.macros.NifBuilder.build())
 *   class MathNif {
 *     @:nif static function add(a:Int, b:Int):Int return a + b;
 *     @:nif(schedule = "dirty_cpu", name = "renamed")
 *     static function heavy(n:haxe.Int64):haxe.Int64 { ... }
 *   }
 *
 * For every @:nif static method this generates `__hx_nif_<method>`
 * (envRaw, argc, argv) -> NifTerm wrapper: decodes args per declared types
 * (decode error -> NifReturn.errorTerm), calls the function, encodes the
 * result (NifResult<T> -> NifReturn.apply; Void -> :ok), and catches Haxe
 * exceptions -> RaiseAtom("nif_panicked") (rustler panic semantics).
 *
 * Raw functions: signature (env:ErlNifEnv, argc:Int, argv:cpp.Pointer<NifTerm>):NifTerm
 * pass through unchanged; require @:nif(arity = N).
 *
 * Supported arg/ret types: Int, Float, Bool, String, haxe.Int64,
 * cpp.UInt64, hxler.core.Atom, hxler.core.Term, Null<T>, Array<T>,
 * Map<K,V>, and user classes with static hxDecode/hxEncode.
 */
class NifBuilder {
	public static function build():Array<Field> {
		var fields = Context.getBuildFields();
		var pos = Context.currentPos();
		var defs = collectDefs(fields, pos);

		for (d in defs) {
			if (d.isRaw) {
				continue; // raw functions are used as-is
			}
			fields.push(makeWrapper(d, pos));
		}
		return fields;
	}

	// ------------------------------------------------------------- collect --

	public static function collectDefs(fields:Array<Field>, pos:Position):Array<NifDefMeta> {
		var defs = [];
		for (f in fields) {
			var meta = findNifMeta(f.meta);
			if (meta == null) {
				continue;
			}
			if (!Lambda.has(f.access, AStatic)) {
				Context.fatalError('@:nif must be on a static function: ${f.name}', f.pos);
			}
			var fn = switch (f.kind) {
				case FFun(fn): fn;
				default: Context.fatalError('@:nif must be on a function: ${f.name}', f.pos);
			};

			var nifName = camelToSnake(f.name);
			var schedule = "normal";
			var arityOverride:Null<Int> = null;
			for (p in meta.params) {
				switch (p.expr) {
					case EConst(CString(s, _)):
						nifName = s; // @:nif("name")
					case EConst(CIdent(id)):
						schedule = normalizeSchedule(id);
					case EBinop(OpAssign | OpEq, {expr: EConst(CIdent(field))}, value):
						// @:nif(name = "x", schedule = "y", arity = N)
						switch (field) {
							case "name":
								nifName = exprString(value);
							case "schedule":
								schedule = normalizeSchedule(exprString(value));
							case "arity":
								arityOverride = exprInt(value);
							case other:
								Context.fatalError('@:nif unknown option "$other"', f.pos);
						}
					case EObjectDecl(fs):
						for (fd in fs) {
							switch (fd.field) {
								case "name":
									nifName = exprString(fd.expr);
								case "schedule":
									schedule = normalizeSchedule(exprString(fd.expr));
								case "arity":
									arityOverride = exprInt(fd.expr);
								case other:
									Context.fatalError('@:nif unknown option "$other"', f.pos);
							}
						}
					default:
						Context.fatalError('@:nif unsupported meta argument', f.pos);
				}
			}

			var raw = isRawSignature(fn.args, fn.ret);
			var envFirst = false;
			var paramTypes:Array<String> = [];
			var argCount = fn.args.length;
			if (raw) {
				if (arityOverride == null) {
					Context.fatalError('@:nif raw function "${f.name}" requires @:nif(arity = N)', f.pos);
				}
				paramTypes = [];
				argCount = arityOverride;
			} else {
				var start = 0;
				if (fn.args.length > 0 && typeString(fn.args[0].type) == "hxler.core.Env") {
					envFirst = true;
					start = 1;
				}
				for (i in start...fn.args.length) {
					paramTypes.push(typeString(fn.args[i].type));
				}
				argCount = paramTypes.length;
			}
			if (arityOverride != null && !raw && arityOverride != argCount) {
				Context.fatalError('@:nif arity mismatch on "${f.name}": declared ${arityOverride}, actual ${argCount}', f.pos);
			}

			defs.push({
				func: f.name,
				nif: nifName,
				arity: raw ? arityOverride : argCount,
				flags: scheduleFlags(schedule),
				schedule: schedule,
				isRaw: raw,
				envFirst: envFirst,
				paramTypes: paramTypes,
				retType: typeString(fn.ret),
			});
		}
		return defs;
	}

	static function findNifMeta(meta:Metadata):Null<MetadataEntry> {
		for (m in meta) {
			if (m.name == ":nif") {
				return m;
			}
		}
		return null;
	}

	public static function normalizeSchedule(s:String):String {
		return switch (StringTools.trim(s).toLowerCase()) {
			case "normal": "normal";
			case "dirty_cpu" | "dirtycpu": "dirty_cpu";
			case "dirty_io" | "dirtyio": "dirty_io";
			default: Context.fatalError('unknown schedule "$s" (normal|dirty_cpu|dirty_io)', Context.currentPos());
		}
	}

	public static function scheduleFlags(s:String):Int {
		return switch (s) {
			case "dirty_cpu": 1;
			case "dirty_io": 2;
			default: 0;
		};
	}

	static function isRawSignature(args:Array<FunctionArg>, ret:Null<ComplexType>):Bool {
		if (args.length != 3 || ret == null) {
			return false;
		}
		// NifTerm is a typedef over the machine word (cpp.UInt64 under
		// HXCPP_M64): resolveType unwraps it, so accept both spellings.
		var retStr = typeString(ret);
		return typeString(args[0].type) == "hxler.nif.raw.ErlNifEnv"
			&& typeString(args[1].type) == "Int"
			&& StringTools.startsWith(typeString(args[2].type), "cpp.Pointer<")
			&& (retStr == "hxler.nif.raw.NifTerm" || retStr == "cpp.UInt64");
	}

	/**
	 * Type text as written in the source (Printer keeps it verbatim).
	 * RULE: @:nif signatures must use FULL type paths for the types the
	 * builder dispatches on (hxler.core.Env, haxe.Int64, hxler.core.Term,
	 * hxler.core.NifResult<...>, hxler.core.Atom, cpp.UInt64); plain Int,
	 * Float, Bool, String, Array<...>, Map<...>, Null<...> are fine as-is.
	 */
	static function typeString(ct:Null<ComplexType>):String {
		if (ct == null) {
			return "Void";
		}
		return new haxe.macro.Printer().printComplexType(ct).split(" ").join("").split("\n").join("").split("\t").join("");
	}

	static function exprString(e:Expr):String {
		return switch (e.expr) {
			case EConst(CString(s, _)): s;
			case EConst(CIdent(id)): id;
			default: Context.fatalError("expected string literal", e.pos);
		};
	}

	static function exprInt(e:Expr):Int {
		return switch (e.expr) {
			case EConst(CInt(v, _)): Std.parseInt(v);
			default: Context.fatalError("expected integer literal", e.pos);
		};
	}

	/** camelCase -> snake_case (Elixir convention for default NIF names). */
	public static function camelToSnake(s:String):String {
		var buf = new StringBuf();
		var prevUpper = false;
		for (i in 0...s.length) {
			var c = s.charAt(i);
			var isUpper = c >= "A" && c <= "Z";
			if (isUpper) {
				if (i > 0 && (!prevUpper || (i + 1 < s.length && isLowerChar(s.charAt(i + 1))))) {
					buf.add("_");
				}
				buf.add(c.toLowerCase());
			} else {
				buf.add(c);
			}
			prevUpper = isUpper;
		}
		return buf.toString();
	}

	static function isLowerChar(c:String):Bool {
		return c >= "a" && c <= "z";
	}

	// ------------------------------------------------------------- wrapper --

	/** Generates the (envRaw, argc, argv) wrapper via text + Context.parse. */
	static function makeWrapper(d:NifDefMeta, pos:Position):Field {
		var buf = new StringBuf();
		var cls = Context.getLocalClass().get();
		var fn = '${cls.pack.length > 0 ? cls.pack.join(".") + "." : ""}${cls.name}';

		buf.add('\tvar env = new hxler.core.Env(envRaw, hxler.core.EnvKind.ProcessBound);\n');
		buf.add('\ttry {\n');
		for (i in 0...d.paramTypes.length) {
			var t = d.paramTypes[i];
			buf.add('\t\tvar _a$i:Null<$t> = null;\n');
			buf.add('\t\tswitch (${decExpr(t, 'new hxler.core.Term(env, argv[$i])')}) {\n');
			buf.add('\t\t\tcase Ok(v): _a$i = v;\n');
			buf.add('\t\t\tcase Error(e): return hxler.core.NifReturn.errorTerm(env, e);\n');
			buf.add('\t\t}\n');
		}
		var callArgs = [];
		if (d.envFirst) {
			callArgs.push("env");
		}
		for (i in 0...d.paramTypes.length) {
			callArgs.push('_a$i');
		}
		var call = '$fn.${d.func}(${callArgs.join(", ")})';
		buf.add('\t\treturn ${retExpr(d.retType, call, "env")};\n');
		buf.add('\t} catch (e:Dynamic) {\n');
		buf.add('\t\treturn hxler.core.NifReturn.errorTerm(env, hxler.core.NifError.RaiseAtom("nif_panicked"));\n');
		buf.add('\t}\n');
		var wrapperName = '__hx_nif_${d.func}';
		var field = MacroUtil.makeFunction(wrapperName, [
			{name: "envRaw", type: "hxler.nif.raw.ErlNifEnv"},
			{name: "argc", type: "Int"},
			{name: "argv", type: "cpp.Pointer<hxler.nif.raw.NifTerm>"},
		], "hxler.nif.raw.NifTerm", buf.toString(), pos);
		// EntryBuilder reads the NIF name/schedule/arity back from this meta:
		field.meta.push({
			name: ":nif",
			params: [
				{expr: EBinop(OpAssign, {expr: EConst(CIdent("name")), pos: pos}, {expr: EConst(CString(d.nif, DoubleQuotes)), pos: pos}), pos: pos},
				{expr: EBinop(OpAssign, {expr: EConst(CIdent("schedule")), pos: pos}, {expr: EConst(CIdent(d.schedule)), pos: pos}), pos: pos},
				{expr: EBinop(OpAssign, {expr: EConst(CIdent("arity")), pos: pos}, {expr: EConst(CInt(Std.string(d.arity), null)), pos: pos}), pos: pos},
			],
			pos: pos
		});
		return field;
	}

	/** Expression decoding a Term (expr string) into the Haxe type. */
	public static function decExpr(type:String, termExpr:String):String {
		return switch (type) {
			case "Int": 'hxler.core.Decoders.int($termExpr)';
			case "Float": 'hxler.core.Decoders.float($termExpr)';
			case "Bool": 'hxler.core.Decoders.bool($termExpr)';
			case "String": 'hxler.core.Decoders.string($termExpr)';
			case "haxe.Int64": 'hxler.core.Decoders.int64($termExpr)';
			case "cpp.UInt64": 'hxler.core.Decoders.uint64($termExpr)';
			case "hxler.core.Atom": 'hxler.core.Decoders.atom($termExpr)';
			case "hxler.core.Term": 'hxler.core.Decoders.term($termExpr)';
			default:
				if (StringTools.startsWith(type, "Null<")) {
					var inner = type.substring(5, type.length - 1);
					'hxler.core.Decoders.option($termExpr, (t) -> ${decExpr(inner, "t")})';
				} else if (StringTools.startsWith(type, "Array<")) {
					var inner = type.substring(6, type.length - 1);
					'hxler.core.Decoders.list($termExpr, (t) -> ${decExpr(inner, "t")})';
				} else if (StringTools.startsWith(type, "Map<")) {
					var inner = type.substring(4, type.length - 1);
					var comma = inner.indexOf(",");
					var k = inner.substring(0, comma);
					var v = inner.substring(comma + 1);
					'(function(t) { return switch (hxler.core.Decoders.map(t, (t) -> ${decExpr(k, "t")}, (t) -> ${decExpr(v, "t")})) { case Ok(pairs): { var m = new Map<$k, $v>(); for (p in pairs) m.set(p.k, p.v); Ok(m); } case Error(e): Error(e); }; })($termExpr)';
				} else if (hasStatic(type, "hxDecode")) {
					'$type.hxDecode($termExpr)';
				} else {
					Context.fatalError('NifBuilder: unsupported parameter type "$type"', Context.currentPos());
				}
		}
	}

	/** Expression encoding `valueExpr` (of `type`) into raw NifTerm. */
	public static function retExpr(type:String, valueExpr:String, envVar:String):String {
		if (type == "hxler.nif.raw.NifTerm") {
			return '($valueExpr)';
		}
		if (type == "Void") {
			return 'hxler.core.AtomCache.intern("ok").toTerm($envVar).raw';
		}
		if (StringTools.startsWith(type, "hxler.core.NifResult<")) {
			var inner = type.substring("hxler.core.NifResult<".length, type.length - 1);
			return 'switch ($valueExpr) { case Ok(v): ${retExpr(inner, "v", envVar)}; case Error(e): hxler.core.NifReturn.errorTerm($envVar, e); }';
		}
		return '${encTermExpr(type, valueExpr, envVar)}.raw';
	}

	/** Expression encoding `valueExpr` into a hxler.core.Term (NOT raw). */
	public static function encTermExpr(type:String, valueExpr:String, envVar:String):String {
		return switch (type) {
			case "Int": 'hxler.core.Encoders.int($envVar, $valueExpr)';
			case "Float": 'hxler.core.Encoders.float($envVar, $valueExpr)';
			case "Bool": 'hxler.core.Encoders.bool($envVar, $valueExpr)';
			case "String": 'hxler.core.Encoders.string($envVar, $valueExpr)';
			case "haxe.Int64": 'hxler.core.Encoders.int64($envVar, $valueExpr)';
			case "cpp.UInt64": 'hxler.core.Encoders.uint64($envVar, $valueExpr)';
			case "hxler.core.Atom": 'hxler.core.Encoders.atom($envVar, $valueExpr)';
			case "hxler.core.Term": '($valueExpr)';
			default:
				if (StringTools.startsWith(type, "Null<")) {
					var inner = type.substring(5, type.length - 1);
					'($valueExpr) == null ? hxler.core.AtomCache.intern("nil").toTerm($envVar) : ${encTermExpr(inner, valueExpr, envVar)}';
				} else if (StringTools.startsWith(type, "Array<")) {
					var inner = type.substring(6, type.length - 1);
					'hxler.core.Encoders.list($envVar, $valueExpr, (x) -> ${encTermExpr(inner, "x", envVar)})';
				} else if (StringTools.startsWith(type, "Map<")) {
					var inner = type.substring(4, type.length - 1);
					var comma = inner.indexOf(",");
					var k = inner.substring(0, comma);
					var v = inner.substring(comma + 1);
					'hxler.core.Encoders.map($envVar, $valueExpr, (k) -> ${encTermExpr(k, "k", envVar)}, (vv) -> ${encTermExpr(v, "vv", envVar)})';
				} else if (hasStatic(type, "hxEncode")) {
					'$type.hxEncode($envVar, $valueExpr)';
				} else {
					Context.fatalError('NifBuilder: unsupported return type "$type"', Context.currentPos());
				}
		}
	}

	/** True if the module type has a public static `name` function. */
	public static function hasStatic(modulePath:String, name:String):Bool {
		try {
			var t = Context.getType(modulePath);
			return switch (t) {
				case TInst(cl, _):
					var c = cl.get();
					for (f in c.statics.get()) {
						if (f.name == name) {
							return true;
						}
					}
					false;
				default: false;
			}
		} catch (e:Dynamic) {
			return false;
		}
	}
}




