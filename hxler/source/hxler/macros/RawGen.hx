package hxler.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
using StringTools;

/**
 * Generates the raw enif_* bindings (hxler.nif.raw.Raw) at compile time by
 * parsing the ERTS header snapshot (hxler/include/erl_nif_api_funcs.h).
 *
 * Replaces the former python generator (tools/gen_nif_raw.py): no external
 * dependency, regenerated on every build. Header path resolution:
 *  - define hxler_nif_header=<path> overrides the snapshot (e.g. point at a
 *    live ERTS include dir when updating bindings),
 *  - otherwise <packageRoot>/include/erl_nif_api_funcs.h where packageRoot
 *    is the directory containing the hxler/ source tree.
 *
 * Mapping rules (verified in the phase-1 check build):
 *  - ERL_NIF_TERM -> Types.NifTerm (machine word),
 *  - out-params: cpp.Pointer<T> (implicit operator T*() at the call site),
 *  - opaque struct pointers: Types.<X> (::cpp::Pointer<X> extern classes),
 *  - double pointers (**): inline wrappers with an explicit C cast of
 *    `{N}.ptr` (MSVC has no user conversion for nested Pointer<T>),
 *  - C enum params (ErlNifCharEncoding, ErlNifTimeUnit, ...): inline
 *    wrappers with explicit casts (MSVC forbids implicit int<->enum),
 *  - size_t params: Haxe Int (C++ converts at the call site; prototype in
 *    scope).
 *  - Excluded: variadic functions, functions taking C function pointers,
 *    and get_long/make_long/get_ulong/make_ulong (platform-dependent long
 *    ABI; the int64/uint64 variants are the portable replacements).
 */
class RawGen {
	static inline var HEADER_RELATIVE = "hxler/include/erl_nif_api_funcs.h";

	static var EXCLUDE:Map<String, String> = [
		"enif_make_tuple" => "variadic; use enif_make_tuple_from_array",
		"enif_make_list" => "variadic; use enif_make_list_from_array",
		"enif_fprintf" => "variadic",
		"enif_vfprintf" => "variadic",
		"enif_snprintf" => "variadic; Wrapper.termToString uses it inline",
		"enif_vsnprintf" => "variadic",
		"enif_set_option" => "variadic",
		"enif_dlopen" => "takes fn-pointer (err_handler)",
		"enif_dlsym" => "takes fn-pointer (err_handler)",
		"enif_thread_create" => "takes fn-pointer (thread body)",
		"enif_schedule_nif" => "takes fn-pointer (nif); wired via glue later",
		"enif_open_resource_type" => "takes fn-pointer (dtor); use enif_init_resource_type",
		"enif_get_long" => "long ABI differs per platform; use enif_get_int64",
		"enif_make_long" => "long ABI differs per platform; use enif_make_int64",
		"enif_get_ulong" => "long ABI differs per platform; use enif_get_uint64",
		"enif_make_ulong" => "long ABI differs per platform; use enif_make_uint64",
	];

	static var ENUM_TYPES:Array<String> = [
		"ErlNifCharEncoding", "ErlNifTimeUnit", "ErlNifUniqueInteger",
		"ErlNifMapIteratorEntry", "ErlNifHash", "ErlNifSelectFlags",
		"ErlNifResourceFlags", "ErlNifOption", "ErlNifIOQueueOpts"
	];

	public static function build():Array<Field> {
		var fields = Context.getBuildFields();
		var header = Context.definedValue("hxler_nif_header");
		if (header == null) {
			header = findHeader();
		}
		if (header == null || !sys.FileSystem.exists(header)) {
			Context.fatalError("RawGen: erl_nif_api_funcs.h not found (set -D hxler_nif_header=<path> or keep hxler/include/ snapshot)",
				Context.currentPos());
		}
		var src = sys.io.File.getContent(header);
		var version = readVersion(sys.FileSystem.fullPath(header));
		Context.info('RawGen: NIF API ${version.major}.${version.minor} -> ${header}', Context.currentPos());

		var generated = 0;
		for (decl in parseDecls(src)) {
			var sig = hxSig(decl);
			if (sig == null) {
				continue;
			}
			fields.push(sig);
			generated++;
		}
		Context.info('RawGen: generated ${generated} raw functions', Context.currentPos());
		return fields;
	}

	// ------------------------------------------------------------ locating --

	static function findHeader():String {
		for (cpRaw in Context.getClassPath()) {
			var cp = cpRaw;
			// strip trailing slashes: Path.directory("dir/") misbehaves
			while (cp.length > 1 && (StringTools.endsWith(cp, "/") || StringTools.endsWith(cp, "\\"))) {
				cp = cp.substring(0, cp.length - 1);
			}
			// candidate 1: class path is the package root (contains hxler/)
			var cand = haxe.io.Path.join([cp, HEADER_RELATIVE]);
			if (sys.FileSystem.exists(cand)) {
				return cand;
			}
			// candidate 2: class path is a source dir inside the package
			// root (e.g. -cp source where the package root holds include/)
			cand = haxe.io.Path.join([haxe.io.Path.directory(cp), "include", "erl_nif_api_funcs.h"]);
			if (sys.FileSystem.exists(cand)) {
				return cand;
			}
			// candidate 3: package root nested one level deeper
			cand = haxe.io.Path.join([haxe.io.Path.directory(cp), HEADER_RELATIVE]);
			if (sys.FileSystem.exists(cand)) {
				return cand;
			}
		}
		return null;
	}

	static function readVersion(headerFile:String):{major:String, minor:String} {
		var dir = haxe.io.Path.directory(headerFile);
		var erlNif = haxe.io.Path.join([dir, "erl_nif.h"]);
		var src = sys.FileSystem.exists(erlNif) ? sys.io.File.getContent(erlNif) : sys.io.File.getContent(headerFile);
		var major = "?", minor = "?";
		var reM = new EReg("#define ERL_NIF_MAJOR_VERSION\\s+(\\d+)", "");
		var reN = new EReg("#define ERL_NIF_MINOR_VERSION\\s+(\\d+)", "");
		if (reM.match(src)) {
			major = reM.matched(1);
		}
		if (reN.match(src)) {
			minor = reN.matched(1);
		}
		return {major: major, minor: minor};
	}

	// ------------------------------------------------------------- parsing --

	static var RE_DECL = ~/ERL_NIF_API_FUNC_DECL\((.*?)\)\s*;/s;

	static function parseDecls(src:String):Array<{ret:String, name:String, args:String}> {
		var out = [];
		var rest = src;
		while (RE_DECL.match(rest)) {
			var inner = RE_DECL.matched(1);
			rest = RE_DECL.matchedRight();
			var nameRe = ~/\s*(.*?)\s*,\s*(enif_\w+)\s*,\s*(.*)/s;
			if (!nameRe.match(inner)) {
				continue;
			}
			var ret = nameRe.matched(1);
			var name = nameRe.matched(2);
			var args = extractArgs(nameRe.matched(3));
			if (args == null) {
				continue;
			}
			args = new EReg("\\s+", "g").replace(args, " ");
			out.push({ret: ret, name: name, args: args});
		}
		return out;
	}

	static function extractArgs(rest:String):String {
		var i = rest.indexOf("(");
		if (i < 0) {
			return null;
		}
		var depth = 0, j = i;
		while (j < rest.length) {
			var c = rest.charAt(j);
			if (c == "(") {
				depth++;
			} else if (c == ")") {
				depth--;
				if (depth == 0) {
					break;
				}
			}
			j++;
		}
		var args = rest.substring(i + 1, j);
		return new EReg("\\s+", "g").replace(args, " ");
	}

	// ------------------------------------------------------ param splitting --

	static function splitParams(args:String):Array<{ct:String, pn:String}> {
		if (args == "" || args == "void") {
			return [];
		}
		var parts = [];
		var depth = 0, cur = new StringBuf();
		for (i in 0...args.length) {
			var c = args.charAt(i);
			if (c == "(") {
				depth++;
			} else if (c == ")") {
				depth--;
			}
			if (c == "," && depth == 0) {
				parts.push(StringTools.trim(cur.toString()));
				cur = new StringBuf();
			} else {
				cur.add(c);
			}
		}
		if (cur.length > 0) {
			parts.push(StringTools.trim(cur.toString()));
		}
		var res = [];
		var idx = 0;
		for (p in parts) {
			if (p == "...") {
				return null; // variadic
			}
			// 'ErlNifEnv *env' -> 'ErlNifEnv* env' so the name splits off
			var normed = new EReg("\\*\\s*", "g").replace(p, "* ");
			var nameRe = ~/^(.+?)\s+([A-Za-z_][A-Za-z0-9_]*)$/s;
			if (nameRe.match(normed)) {
				res.push({ct: nameRe.matched(1), pn: nameRe.matched(2)});
			} else {
				res.push({ct: normed, pn: 'arg${idx}'});
			}
			idx++;
		}
		return res;
	}

	static function stripEnumKw(t:String):String {
		t = new EReg("\\benum\\b\\s*", "g").replace(t, "");
		t = new EReg("\\bconst\\b\\s*", "g").replace(t, "");
		return t;
	}

	static function countStars(t:String):Int {
		var n = 0;
		for (i in 0...t.length) {
			if (t.charAt(i) == "*") {
				n++;
			}
		}
		return n;
	}

	static function collapse(t:String):String {
		t = stripEnumKw(t);
		t = new EReg("\\s*\\*\\s*", "g").replace(t, "*");
		t = new EReg("\\*+", "g").replace(t, "*");
		return t;
	}

	/** Like collapse, but keeps star count AND const: for C cast text. */
	static function collapseKeepStars(t:String):String {
		t = new EReg("\\benum\\b\\s*", "g").replace(t, "");
		t = new EReg("\\s*\\*\\s*", "g").replace(t, "*");
		t = t.trim();
		return t;
	}

	/** Base C type name for enum checks (strips const/enum/pointers/name). */
	static function baseOf(ct:String):String {
		var t = stripEnumKw(ct);
		t = t.split("[]")[0];
		var nameRe = ~/^(.+?)\s+([A-Za-z_][A-Za-z0-9_]*)$/s;
		if (nameRe.match(t)) {
			var base = nameRe.matched(1);
			if (StringTools.endsWith(base, "*") || Lambda.has(ENUM_TYPES, base) || StringTools.startsWith(base, "ErlNif")
				|| base == "void" || base == "int" || base == "unsigned" || base == "long"
				|| base == "double" || base == "char" || base == "size_t" || base == "ERL_NIF_TERM") {
				t = base;
			}
		}
		return collapse(t);
	}

	// --------------------------------------------------------- type mapping --

	static function mkPath(s:String):ComplexType {
		// dotted path with optional generics: cpp.Pointer<NifTerm>
		var generic = null;
		var gStart = s.indexOf("<");
		if (gStart >= 0 && s.charAt(s.length - 1) == ">") {
			generic = s.substring(gStart + 1, s.length - 1);
			s = s.substring(0, gStart);
		}
		// hxler.nif.raw.* types live in their own modules (one type per
		// file) - canonical TPath with the full module path.
		if (StringTools.startsWith(s, "hxler.nif.raw.")) {
			var parts0 = s.split(".");
			var nm = parts0.pop();
			return TPath({
				pack: parts0,
				name: nm,
				params: generic != null ? [TPType(mkType(generic))] : null
			});
		}
		var parts = s.split(".");
		var name = parts.pop();
		var tp:haxe.macro.TypePath = {
			pack: parts,
			name: name,
			params: generic != null ? [TPType(mkType(generic))] : null
		};
		return TPath(tp);
	}

	static function mkType(s:String):ComplexType {
		return mkPath(s);
	}

	static function hxType(t:String):Null<ComplexType> {
		var stars = countStars(t);
		var c = collapse(t);

		// array parameter form: ERL_NIF_TERM argv[]
		if (StringTools.endsWith(c, "[]")) {
			// strip a param name: 'ERL_NIF_TERM arr[]'
			var arrRe = ~/^(.+?)\s+([A-Za-z_][A-Za-z0-9_]*)\[\]$/s;
			if (arrRe.match(c)) {
				c = collapse(arrRe.matched(1)) + "[]";
			}
			var base = c.substring(0, c.length - 2);
			if (base == "ERL_NIF_TERM") {
				return mkPath("cpp.Pointer<hxler.nif.raw.NifTerm>");
			}
			return null;
		}

		if (StringTools.endsWith(c, "*")) {
			var base = c.substring(0, c.length - 1);
			if (stars >= 2) {
				var inner = hxType(base + "*");
				if (inner == null) {
					return null;
				}
				return mkPath('cpp.Pointer<${typeToString(inner)}>');
			}
			switch (base) {
				case "void":
					return mkPath("cpp.Star<cpp.Void>");
				case "ErlNifEnv" | "ErlNifResourceType" | "ErlNifMutex" | "ErlNifCond" | "ErlNifRWLock"
					| "ErlNifThreadOpts" | "ErlNifIOQueue" | "ErlNifTid" | "ErlNifSysInfo" | "ErlNifMonitor":
					return mkPath('hxler.nif.raw.$base');
				case "ErlNifBinary":
					return mkPath("cpp.Pointer<hxler.nif.raw.ErlNifBinary>");
				case "ErlNifPid":
					return mkPath("cpp.Pointer<hxler.nif.raw.ErlNifPid>");
				case "ErlNifPort":
					return mkPath("cpp.Pointer<hxler.nif.raw.ErlNifPort>");
				case "ErlNifMapIterator":
					return mkPath("cpp.Pointer<hxler.nif.raw.ErlNifMapIterator>");
				case "ErlNifResourceTypeInit":
					return mkPath("cpp.Pointer<hxler.nif.raw.ErlNifResourceTypeInit>");
				case "ErlNifIOVec":
					return mkPath("cpp.Pointer<hxler.nif.raw.ErlNifIOVec>");
				case "ErlNifResourceFlags":
					return mkPath("cpp.Star<cpp.Void>");
				case "ErlNifTSDKey" | "int":
					return mkPath("cpp.Pointer<Int>");
				case "unsigned" | "unsigned int":
					return mkPath("cpp.Pointer<cpp.UInt32>");
				case "long" | "unsigned long":
					return null;
				case "double":
					return mkPath("cpp.Pointer<Float>");
				case "ErlNifSInt64":
					return mkPath("cpp.Pointer<cpp.Int64>");
				case "ErlNifUInt64":
					return mkPath("cpp.Pointer<cpp.UInt64>");
				case "size_t":
					return mkPath("cpp.Pointer<cpp.UInt64>");
				case "char":
					return mkPath("cpp.Pointer<cpp.Char>");
				case "unsigned char":
					return mkPath("cpp.Pointer<cpp.UInt8>");
				case "ERL_NIF_TERM":
					return mkPath("cpp.Pointer<hxler.nif.raw.NifTerm>");
				case "SysIOVec":
					return mkPath("cpp.Star<cpp.Void>");
				default:
					return null;
			}
		}

		// value forms
		switch (c) {
			case "void":
				return mkPath("Void");
			case "int" | "unsigned" | "unsigned int" | "ErlNifCharEncoding" | "ErlNifTimeUnit"
				| "ErlNifUniqueInteger" | "ErlNifMapIteratorEntry" | "ErlNifHash" | "ErlNifSelectFlags"
				| "ErlNifResourceFlags" | "ErlNifTSDKey" | "ErlNifOption" | "ErlNifIOQueueOpts"
				| "ErlNifTermType":
				return mkPath("Int");
			case "double":
				return mkPath("Float");
			case "ErlNifSInt64" | "ErlNifTime":
				return mkPath("cpp.Int64");
			case "ErlNifUInt64":
				return mkPath("cpp.UInt64");
			case "size_t":
				return mkPath("Int");
			case "char":
				return mkPath("Int");
			case "ErlNifEvent":
				return mkPath("hxler.nif.raw.NifEvent");
			case "ErlNifTid":
				return mkPath("hxler.nif.raw.ErlNifTid");
			case "ERL_NIF_TERM":
				return mkPath("hxler.nif.raw.NifTerm");
			case "ErlNifEnv" | "ErlNifMutex" | "ErlNifCond" | "ErlNifRWLock" | "ErlNifIOQueue":
				return mkPath('hxler.nif.raw.${c}');
			default:
				return null;
		}
	}

	/** Renders an already-built Type back to a dotted string (for nesting). */
	static function typeToString(t:ComplexType):String {
		switch (t) {
			case TPath(p):
				var s = p.pack.concat([p.name]).join(".");
				if (p.params != null) {
					for (param in p.params) {
						switch (param) {
							case TPType(inner):
								s += "<" + typeToString(inner) + ">";
							default:
						}
					}
				}
				return s;
			default:
				return "Dynamic";
		}
	}

	static function hxName(enifName:String):String {
		return enifName.substring(5); // strip "enif_"
	}

	// ---------------------------------------------------------- sig building --

	static function hxSig(decl:{ret:String, name:String, args:String}):Null<Field> {
		var params = splitParams(decl.args);
		if (params == null) {
			return null;
		}
		var pos = Context.currentPos();
		var args:Array<FunctionArg> = [];
		for (p in params) {
			var h = hxType(p.ct);
			if (h == null) {
				return null;
			}
			args.push({name: p.pn, type: h});
		}
		var ret = hxType(decl.ret);
		if (ret == null) {
			return null;
		}

		var hasDoublePtr = false;
		var hasEnum = false;
		for (p in params) {
			if (countStars(p.ct) >= 2) {
				hasDoublePtr = true;
			}
			if (Lambda.has(ENUM_TYPES, baseOf(p.ct))) {
				hasEnum = true;
			}
		}

		if (!hasEnum && !hasDoublePtr) {
			// plain extern-style: no body, routed through the C symbol
			var meta = [{name: ":native", params: [{expr: EConst(CString(decl.name)), pos: pos}], pos: pos}];
			return {
				name: hxName(decl.name),
				access: [APublic, AStatic],
				kind: FFun({args: args, ret: ret, expr: null}),
				pos: pos,
				meta: meta
			};
		}

		// inline wrapper: enum casts / double-pointer casts via __cpp__
		var pieces:Array<String> = [];
		var i = 0;
		for (p in params) {
			if (countStars(p.ct) >= 2) {
				// (const ERL_NIF_TERM **)foo.ptr — placeholder must close
				// before `.ptr`: {3}.ptr; stars preserved for the cast
				pieces.push('(${collapseKeepStars(p.ct)}){${i}}.ptr');
			} else if (Lambda.has(ENUM_TYPES, baseOf(p.ct))) {
				pieces.push('(${baseOf(p.ct)}){${i}}');
			} else {
				pieces.push('{${i}}');
			}
			i++;
		}
		var call = '${decl.name}(' + pieces.join(", ") + ")";

		var argExprs:Array<Expr> = [];
		for (p in params) {
			argExprs.push(macro $i{p.pn});
		}

		// build `return untyped __cpp__(fmt, a, b, ...)` as an explicit
		// ECall (do NOT use $a{} reification - it creates an array
		// literal instead of spreading the call arguments).
		var cppArgs:Array<Expr> = [macro $v{call}];
		cppArgs = cppArgs.concat(argExprs);
		var callExpr:Expr = {
			expr: ECall({expr: EConst(CIdent("__cpp__")), pos: pos}, cppArgs),
			pos: pos
		};
		var untypedExpr:Expr = {
			expr: EUntyped(callExpr),
			pos: pos
		};
		var body:Expr = {
			expr: EReturn(untypedExpr),
			pos: pos
		};
		return {
			name: hxName(decl.name),
			access: [APublic, AStatic, AInline],
			kind: FFun({args: args, ret: ret, expr: body}),
			pos: pos,
			meta: []
		};
	}
}








