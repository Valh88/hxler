package hxler.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

typedef NifDef = {
	var owner:String; // Haxe class path (dots)
	var func:String; // Haxe method name (raw) or original name (wrapper)
	var wrapper:String; // call target: __hx_nif_<name> for normal, <name> for raw
	var nif:String; // exported NIF name
	var arity:Int;
	var flags:Int;
}

/**
 * Build macro for the NIF entry class:
 *
 *   @:build(hxler.macros.EntryBuilder.build([MathNif], "Elixir.Hxler.Math"))
 *   class Entry {}
 *
 * Collects every @:nif static of the listed classes (NifBuilder has already
 * added __hx_nif_* wrappers to them; raw functions are used as-is) and
 * generates:
 *  - `__hx_dispatch(envRaw, argc, argv, fnIndex)` switch over all functions,
 *  - `__hx_load(envRaw, loadInfoRaw)` for the optional Haxe load callback,
 *  - C++ glue via @:cppFileCode: per-function trampolines, the ErlNifFunc
 *    table, hxler_ensure_boot (std::call_once) + HxStackGuard and
 *    ERL_NIF_INIT (Windows/Unix variants come from erl_nif.h itself).
 */
class EntryBuilder {
	public static function build(nifClasses:Array<String>, elixirModule:String, ?loadFn:String):Array<Field> {
		var fields = Context.getBuildFields();
		var pos = Context.currentPos();

		var defs:Array<NifDef> = [];
		for (cls in nifClasses) {
			var t = Context.getType(cls);
			switch (t) {
				case TInst(cl, _):
					for (d in classDefs(cl.get(), cls)) {
						defs.push(d);
					}
				default:
					Context.fatalError('EntryBuilder: $cls is not a class', pos);
			}
		}
		if (defs.length == 0) {
			Context.fatalError("EntryBuilder: no @:nif functions found in the listed classes", pos);
		}

		fields.push(makeDispatch(defs, pos));
		if (loadFn != null) {
			fields.push(makeLoadCall(loadFn, pos));
		}
		// C++ glue goes to the CLASS meta (build macros cannot return a
		// nameless field; a dummy field would leak into the type).
		var glueText = makeGlueText(elixirModule, defs, loadFn, pos);
		Context.getLocalClass().get().meta.add(":cppFileCode", [{expr: EConst(CString(glueText, DoubleQuotes)), pos: pos}], pos);
		return fields;
	}

	// ------------------------------------------------------------- collect --

	static function classDefs(c:ClassType, ownerPath:String):Array<NifDef> {
		var owner = c.pack.concat([c.name]).join(".");
		var defs = [];
		var names = new StringBuf();
		for (f in c.statics.get()) {
			names.add(f.name + "(" + f.meta.has(":nif") + ") ");
			var cf:ClassField = f;
			var metas = cf.meta.extract(":nif");
			if (metas.length == 0) {
				metas = cf.meta.extract("nif");
			}
			if (metas.length == 0) {
				names.add("[extract-empty] ");
				continue;
			}
			var isFun = switch (haxe.macro.TypeTools.follow(cf.type)) {
				case TFun(_, _): true;
				default: false;
			};
			if (!isFun) {
				continue;
			}
			var fn = switch (haxe.macro.TypeTools.follow(cf.type)) {
				case TFun(args, _): args;
				default: continue; // unreachable
			};

			var isWrapper = StringTools.startsWith(cf.name, "__hx_nif_");
			var funcName = isWrapper ? cf.name.substring("__hx_nif_".length) : cf.name;
			var nifName = NifBuilder.camelToSnake(funcName);
			var schedule = "normal";
			var arityOverride:Null<Int> = null;
			for (m in metas) {
				for (p in m.params) {
					switch (p.expr) {
						case EConst(CString(s, _)):
							nifName = s;
						case EConst(CIdent(id)):
							schedule = NifBuilder.normalizeSchedule(id);
						case EBinop(OpAssign | OpEq, {expr: EConst(CIdent(field))}, value):
							switch (field) {
								case "name":
									nifName = exprString(value);
								case "schedule":
									schedule = NifBuilder.normalizeSchedule(exprString(value));
								case "arity":
									arityOverride = exprInt(value);
							}
						case EObjectDecl(fs):
							for (fd in fs) {
								switch (fd.field) {
									case "name":
										nifName = exprString(fd.expr);
									case "schedule":
										schedule = NifBuilder.normalizeSchedule(exprString(fd.expr));
									case "arity":
										arityOverride = exprInt(fd.expr);
								}
							}
						default:
					}
				}
			}

			if (isWrapper) {
				// wrapper meta carries name/schedule/arity (stashed by NifBuilder)
				defs.push({
					owner: owner,
					func: funcName,
					wrapper: cf.name,
					nif: nifName,
					arity: arityOverride == null ? 0 : arityOverride,
					flags: NifBuilder.scheduleFlags(schedule),
				});
			} else if (isRawField(fn)) {
				// raw function: (ErlNifEnv, Int, Pointer<NifTerm>) -> NifTerm
				if (arityOverride == null) {
					Context.fatalError('@:nif raw function "$funcName" requires @:nif(arity = N)', Context.currentPos());
				}
				defs.push({
					owner: owner,
					func: cf.name,
					wrapper: cf.name,
					nif: nifName,
					arity: arityOverride,
					flags: NifBuilder.scheduleFlags(schedule),
				});
			}
		}
		Context.info('EntryBuilder statics of $owner: ' + names.toString(), Context.currentPos());
		return defs;
	}

	static function findStatic(c:ClassType, name:String):Null<ClassField> {
		for (f in c.statics.get()) {
			if (f.name == name) {
				return f;
			}
		}
		return null;
	}

	/** Raw NIF signature check at the Type level. */
	static function isRawField(args:Array<{name:String, t:Type}>):Bool {
		if (args.length != 3) {
			return false;
		}
		var a0 = TypeStr.ofType(args[0].t);
		var a1 = TypeStr.ofType(args[1].t);
		var a2 = TypeStr.ofType(args[2].t);
		return a0 == "hxler.nif.raw.ErlNifEnv" && a1 == "Int" && StringTools.startsWith(a2, "cpp.Pointer<");
	}

	static function origArgCount(t:Type):Int {
		return switch (t) {
			case TFun(args, _):
				var n = args.length;
				if (n > 0 && TypeStr.ofType(args[0].t) == "hxler.core.Env") {
					n - 1;
				} else {
					n;
				}
			default: 0;
		};
	}

	static function origEnvFirst(t:Type):Bool {
		return switch (t) {
			case TFun(args, _): args.length > 0 && TypeStr.ofType(args[0].t) == "hxler.core.Env";
			default: false;
		};
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

	// ------------------------------------------------------------- generate --

	static function makeDispatch(defs:Array<NifDef>, pos:Position):Field {
		var buf = new StringBuf();
		buf.add('\tswitch (fn) {\n');
		var i = 0;
		for (d in defs) {
			buf.add('\t\tcase $i: return ${d.owner}.${d.wrapper}(envRaw, argc, argv);\n');
			i++;
		}
		buf.add('\t\tdefault: return hxler.core.NifReturn.errorTerm(new hxler.core.Env(envRaw, hxler.core.EnvKind.ProcessBound), hxler.core.NifError.BadArg);\n');
		buf.add('\t}\n');
		return MacroUtil.makeFunction("__hx_dispatch", [
			{name: "envRaw", type: "hxler.nif.raw.ErlNifEnv"},
			{name: "argc", type: "Int"},
			{name: "argv", type: "cpp.Pointer<hxler.nif.raw.NifTerm>"},
			{name: "fn", type: "Int"},
		], "hxler.nif.raw.NifTerm", buf.toString(), pos);
	}

	static function makeLoadCall(loadFn:String, pos:Position):Field {
		var buf = new StringBuf();
		buf.add('\tvar env = new hxler.core.Env(envRaw, hxler.core.EnvKind.Init);\n');
		buf.add('\ttry {\n');
		buf.add('\t\treturn $loadFn(env, new hxler.core.Term(env, loadInfoRaw));\n');
		buf.add('\t} catch (e:Dynamic) {\n');
		buf.add('\t\treturn false;\n');
		buf.add('\t}\n');
		return MacroUtil.makeFunction("__hx_load", [
			{name: "envRaw", type: "hxler.nif.raw.ErlNifEnv"},
			{name: "loadInfoRaw", type: "hxler.nif.raw.NifTerm"},
		], "Bool", buf.toString(), pos);
	}

	static function makeGlueText(elixirModule:String, defs:Array<NifDef>, loadFn:Null<String>, pos:Position):String {
		var cls = Context.getLocalClass().get();
		var clsSym = cls.pack.join("::") + (cls.pack.length > 0 ? "::" : "") + cls.name + "_obj";

		var buf = new StringBuf();
		buf.add('// ---- generated by hxler.macros.EntryBuilder ----\n');
		buf.add('#include <mutex>\n');
		buf.add('#include "hxler/core/HxResourceFrame.h"\n');
		buf.add('#include "hxler/core/ResourceCache.h"\n');
		// __boot_all()/hx::Boot() are declared by hxcpp.h (hx/Boot.h)
		buf.add('static void hxler_ensure_boot() {\n');
		buf.add('\tstatic std::once_flag once;\n');
		buf.add('\tstd::call_once(once, []() {\n');
		buf.add('\t\tint top = 0;\n');
		buf.add('\t\thx::SetTopOfStack(&top, true);\n');
		buf.add('\t\thx::Boot();\n');
		buf.add('\t\t__boot_all();\n');
		buf.add('\t\thx::SetTopOfStack(0, true);\n');
		buf.add('\t});\n');
		buf.add('}\n');
		buf.add('struct HxStackGuard {\n\tint marker;\n\tHxStackGuard() { hx::SetTopOfStack(&marker, true); }\n\t~HxStackGuard() { hx::SetTopOfStack(0, true); }\n};\n');
		// ---- phase 5: resource handshake ----
		// The Haxe object for a BEAM resource is parked in ResourceCache's
		// immortal holders table; the frame carries only its slot index.
		// The dtor hands the BEAM-allocated block back to the Haxe side
		// (onResourceFree) to release that slot. dtor/down are invoked by
		// BEAM during process GC (NOT inside a NIF trampoline) on a
		// scheduler thread with no hxcpp context -> MUST run under
		// hxler_ensure_boot() + HxStackGuard, else any Haxe access there
		// aborts with "Bad local allocator - unregistered thread".
		buf.add('static void hx_res_dtor(ErlNifEnv* env, void* obj) {\n');
		buf.add('\thxler_ensure_boot();\n');
		buf.add('\tHxStackGuard guard;\n');
		buf.add('\thxler::core::ResourceCache_obj::onResourceFree(obj);\n');
		buf.add('}\n');
		buf.add('static void hx_res_down(ErlNifEnv* env, void* obj, ErlNifPid* pid, ErlNifMonitor* mon) {\n');
		buf.add('\thxler_ensure_boot();\n');
		buf.add('\tHxStackGuard guard;\n');
		buf.add('\t// monitor callbacks arrive in phase 6/8; noop placeholder\n');
		buf.add('}\n');
		buf.add('static void* hx_resource_dtor_upvalue() { return (void*)&hx_res_dtor; }\n');
		buf.add('static void* hx_resource_down_upvalue() { return (void*)&hx_res_down; }\n');
		// Fills ErlNifResourceTypeInit with the trampolines (Env.registerResource
		// calls this: fn-pointers cannot be assigned from Haxe on MSVC).
		buf.add('extern "C" ErlNifResourceTypeInit* hxler_resource_type_init() {\n');
		buf.add('\tstatic ErlNifResourceTypeInit init;\n');
		buf.add('\tinit.dtor = &hx_res_dtor;\n');
		buf.add('\tinit.stop = 0;\n');
		buf.add('\tinit.down = &hx_res_down;\n');
		buf.add('\tinit.members = 3;\n');
		buf.add('\tinit.dyncall = 0;\n');
		buf.add('\treturn &init;\n');
		buf.add('}\n');

		var i = 0;
		for (d in defs) {
			buf.add('static ERL_NIF_TERM hx_tramp_');
			buf.add(Std.string(i));
			buf.add('(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {\n');
			buf.add('\thxler_ensure_boot();\n');
			buf.add('\tHxStackGuard guard;\n');
			buf.add('\treturn ');
			buf.add(clsSym);
			buf.add('::__hx_dispatch(env, argc, argv, ');
			buf.add(Std.string(i));
			buf.add(');\n}\n');
			i++;
		}
		if (loadFn != null) {
			buf.add('static int hx_load_cb(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {\n');
			buf.add('\thxler_ensure_boot();\n');
			buf.add('\tHxStackGuard guard;\n');
			buf.add('\t*priv_data = nullptr;\n');
			buf.add('\treturn ');
			buf.add(clsSym);
			buf.add('::__hx_load(env, load_info) ? 0 : 1;\n}\n');
		} else {
			buf.add('static int hx_load_cb(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {\n');
			buf.add('\thxler_ensure_boot();\n');
			buf.add('\t*priv_data = nullptr;\n');
			buf.add('\treturn 0;\n}\n');
		}
		buf.add('static ErlNifFunc hx_funcs[] = {\n');
		i = 0;
		for (d in defs) {
			buf.add('\t{"');
			buf.add(d.nif);
			buf.add('", ');
			buf.add(Std.string(d.arity));
			buf.add(', hx_tramp_');
			buf.add(Std.string(i));
			buf.add(', ');
			buf.add(Std.string(d.flags));
			buf.add('},\n');
			i++;
		}
		buf.add('};\n');
		buf.add('ERL_NIF_INIT(');
		buf.add(elixirModule);
		buf.add(', hx_funcs, hx_load_cb, NULL, NULL, NULL)\n');

		// Write a manifest of {nif_name, arity} so the Elixir side can
		// auto-generate stubs without owning the function list. The macro runs
		// with cwd = the nif dir (Hxler.Compiler runs haxe with cd: nif_dir).
		writeManifest(defs);
		return buf.toString();
	}

	/** Emits `bin/cpp/hxler_manifest.txt` (one `name arity` per line). */
	static function writeManifest(defs:Array<NifDef>):Void {
		var out = new StringBuf();
		for (d in defs) {
			out.add(d.nif);
			out.add(' ');
			out.add(Std.string(d.arity));
			out.add('\n');
		}
		var dirPath = haxe.io.Path.join(['bin', 'cpp']);
		try {
			sys.FileSystem.createDirectory(dirPath);
			sys.io.File.saveContent(haxe.io.Path.join([dirPath, 'hxler_manifest.txt']), out.toString());
		} catch (e:Dynamic) {
			Context.warning('EntryBuilder: could not write hxler_manifest.txt: $e', Context.currentPos());
		}
	}

	static function extractFunction(parsed:Expr, name:String, pos:Position):Field {
		var fnExpr:Null<Function> = null;
		switch (parsed.expr) {
			case EBlock(exprs):
				var last = exprs[exprs.length - 1];
				switch (last.expr) {
					case EFunction(_, f):
						fnExpr = f;
					default:
				}
			default:
		}
		if (fnExpr == null) {
			return Context.fatalError("EntryBuilder internal: unexpected parse result", pos);
		}
		return {name: name, access: [APublic, AStatic], kind: FFun(fnExpr), pos: pos, meta: [{name: ":keep", params: [], pos: pos}]};
	}
}

class TypeStr {
	/** Full type path with generic parameters (typedefs unwrap). */
	public static function ofType(t:Type):String {
		return switch (t) {
			case TInst(c, params):
				pathWithParams(c.get().pack, c.get().name, params);
			case TEnum(e, params):
				pathWithParams(e.get().pack, e.get().name, params);
			case TAbstract(a, params):
				var m = a.get();
				pathWithParams(m.pack, m.name, params);
			case TFun(_, _): "Function";
			case TType(t2, params):
				// typedef: unwrap to the underlying type
				ofType(t2.get().type);
			default: "Dynamic";
		};
	}

	static function pathWithParams(pack:Array<String>, name:String, params:Array<Type>):String {
		var s = pack.concat([name]).join(".");
		if (params != null && params.length > 0) {
			var ps = [];
			for (p in params) {
				ps.push(ofType(p));
			}
			s += "<" + ps.join(", ") + ">";
		}
		return s;
	}
}







