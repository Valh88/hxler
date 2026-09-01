package hxler.check;

import hxler.core.Env;
import hxler.core.EnvKind;
import hxler.core.Term;
import hxler.core.AtomCache;
import hxler.core.Binary;
import hxler.core.OwnedBinary;
import hxler.core.NewBinary;
import hxler.core.TestAtoms;
import hxler.core.NifError;
import hxler.core.NifResult;
import hxler.core.NifReturn;
import hxler.core.Schedule;
import hxler.core.Encoders;
import hxler.core.Decoders;
import hxler.nif.Wrapper;
import hxler.nif.raw.Raw;
import hxler.nif.raw.NifTerm;
import hxler.nif.raw.ErlNifEnv;
import hxler.nif.raw.ErlNifResourceType;
import hxler.nif.raw.ErlNifBinary;
import hxler.nif.raw.ErlNifPid;
import hxler.nif.raw.ErlNifMapIterator;
import hxler.nif.raw.NifCharEncoding;
import hxler.nif.raw.NifMapIteratorEntry;
import hxler.nif.raw.NifHash;
import cpp.Pointer;

/**
 * Compile-only verification of the raw + wrapper + core layers: every
 * generated call site must compile against the real erl_nif.h prototypes
 * on MSVC. Nothing here runs (Check.dll has no main invocation).
 */
@:keep
@:headerCode('#include "erl_nif.h"')
// Standalone check build has no ERL_NIF_INIT (that comes from the glue in
// phase 4), so define the Windows callback table here; a real NIF gets it
// from ERL_NIF_INIT_GLOB.
@:cppFileCode('TWinDynNifCallbacks WinDynNifCallbacks;')
@:buildXml('<files id="haxe">
	<compilerflag value="-I${hxler_erts_include}" />
</files>
<files id="__main__">
	<compilerflag value="-I${hxler_erts_include}" />
</files>')
class Check {
	public static function main() {}

	// exercise every wrapper/raw surface once so the compiler checks ABI
	static function exercise():Void {
		var env:ErlNifEnv = null;
		var term:NifTerm = 0;

		// numbers
		Wrapper.getInt(env, term);
		Wrapper.getUInt(env, term);
		Wrapper.getInt64(env, term);
		Wrapper.getUInt64(env, term);
		Wrapper.getDouble(env, term);
		Wrapper.makeInt(env, 1);
		Wrapper.makeUInt(env, 1);
		Wrapper.makeInt64(env, 1);
		Wrapper.makeUInt64(env, 1);
		Wrapper.makeDouble(env, 1.5);

		// atoms
		Wrapper.getAtom(env, term, NifCharEncoding.UTF8);
		Wrapper.makeAtom(env, "ok", NifCharEncoding.UTF8);
		Wrapper.makeExistingAtom(env, "ok", NifCharEncoding.LATIN1);

		// env
		Wrapper.allocEnv();
		Wrapper.makeCopy(env, term);
		Wrapper.privData(env);

		// list/tuple
		Wrapper.getListCell(env, term);
		Wrapper.getListLength(env, term);
		Wrapper.getTuple(env, term);

		// maps
		Wrapper.getMapSize(env, term);
		Wrapper.getMapValue(env, term, term);

		// resources
		var rt:ErlNifResourceType = null;
		Wrapper.getResource(env, term, rt);

		// pids
		var pid = ErlNifPid.make();
		var pidP = Pointer.addressOf(pid);
		Wrapper.self(env, pidP);
		Wrapper.getLocalPid(env, term, pidP);
		Wrapper.whereisPid(env, term, pidP);
		Wrapper.send(env, pidP, env, term);
		Wrapper.isProcessAlive(env, pidP);
		Wrapper.makeRef(env);

		// term ops
		Wrapper.isIdentical(term, term);
		Wrapper.compare(term, term);
		Wrapper.termType(env, term);
		Wrapper.hasPendingException(env);
		Wrapper.raiseException(env, term);
		Wrapper.makeBadarg(env);
		Wrapper.makeErrorTuple(env, term);
		Wrapper.consumeTimeslice(env, 50);
		Wrapper.termToString(env, term);

		// binaries
		Wrapper.inspectBinary(env, term);
		Wrapper.inspectIolistAsBinary(env, term);
		Wrapper.allocBinary(16);
		Wrapper.termToBinary(env, term);
		Wrapper.makeNewBinary(env, 16);
		Wrapper.binaryToTerm(env, null, 0, 0, Pointer.addressOf(term));

		// time
		Wrapper.monotonicTime(0);
		Wrapper.convertTimeUnit(0, 0, 0);
		Wrapper.nowTime(env);
		Wrapper.cpuTime(env);
		Wrapper.makeUniqueInteger(env, 0);

		// threads
		Wrapper.threadType();

		// raw-only surfaces (not wrapped): map iterator
		var it = ErlNifMapIterator.make();
		var itP = Pointer.addressOf(it);
		Raw.map_iterator_create(env, term, itP, NifMapIteratorEntry.FIRST);
		Raw.map_iterator_get_pair(env, itP, Pointer.addressOf(term), Pointer.addressOf(term));
		Raw.map_iterator_destroy(env, itP);
		Raw.hash(NifHash.PHASH2, term, 0);

		// raw variadic-replacements
		var arr = [term, term];
		Raw.make_tuple_from_array(env, Pointer.ofArray(arr), 2);
		Raw.make_list_from_array(env, Pointer.ofArray(arr), 2);

		// ---- core layer (phase 2) ----
		var e = new Env(env, EnvKind.ProcessBound);
		var t:Term = e.term(term);
		t.isAtom();
		t.isBinary();
		t.isList();
		t.isEmptyList();
		t.isMap();
		t.isTuple();
		t.isNumber();
		t.isPid();
		t.isRef();
		t.isFun();
		t.isPort();
		t.isException();
		t.termType();
		t.compare(t);
		t.isIdentical(t);
		t.getInt();
		t.getUInt();
		t.getInt64();
		t.getUInt64();
		t.getFloat();
		t.asAtom();
		t.asBinary();
		t.toList();
		t.mapGet(t);
		t.copyTo(e);
		t.termToBinary();
		t.hash();
		t.toString();

		e.int(1);
		e.uint(1);
		e.int64(haxe.Int64.ofInt(1));
		e.uint64(1);
		e.float(1.5);
		e.bool(true);
		e.atom("ok");
		var bytes = haxe.io.Bytes.ofString("x");
		e.binaryFromBytes(bytes);
		e.listFromArray([t, t]);
		e.tupleFromArray([t, t]);
		e.mapNew();
		e.mapPut(t, t, t);
		e.makeRef();
		e.errorTuple(t);
		e.consumeTimeslice(50);
		e.binaryToTerm(bytes);

		hxler.core.Atom.make(e, "x");
		hxler.core.Atom.existing(e, "x");
		hxler.core.Atom.fromTerm(t);
		AtomCache.intern("x");
		AtomCache.sharedEnv();

		var bin = Binary.fromTerm(t);
		Binary.fromIolist(t);
		bin.getByte(0);
		bin.toBytes();
		bin.getString();
		bin.subTerm(0, 1);
		bin.toTerm();

		var ob = OwnedBinary.alloc(4);
		OwnedBinary.fromBytes(bytes);
		ob.getByte(0);
		ob.setByte(0, 1);
		ob.toBytes();
		ob.releaseToTerm(e);
		ob.free();

		var nb = NewBinary.make(e, 4);
		nb.getByte(0);
		nb.setByte(0, 1);
		nb.fillFrom(bytes);
		nb.toTerm();

		// AtomBuilder-generated getters (compile-time generated code)
		TestAtoms.ok();
		TestAtoms.error();
		TestAtoms.true_();
		TestAtoms.nil();
		TestAtoms._42();

		// ---- phase 3: errors/results/encoders/decoders/schedule ----
		var r:NifResult<Term> = Ok(t);
		NifReturn.apply(e, r);
		NifReturn.errorTerm(e, NifError.BadArg);
		NifReturn.errorTerm(e, NifError.Atom("x"));
		NifReturn.errorTerm(e, NifError.RaiseAtom("x"));
		NifReturn.errorTerm(e, NifError.RaiseTerm(t));
		NifReturn.errorTerm(e, NifError.Term(t));

		Encoders.int(e, 1);
		Encoders.int64(e, haxe.Int64.ofInt(1));
		Encoders.uint(e, 1);
		Encoders.uint64(e, 1);
		Encoders.float(e, 1.5);
		Encoders.bool(e, true);
		Encoders.string(e, "s");
		Encoders.atom(e, TestAtoms.ok());
		Encoders.term(e, t);
		Encoders.option(e, cast 1, (x:Int) -> Encoders.int(e, x));
		Encoders.list(e, [1, 2], (x:Int) -> Encoders.int(e, x));
		Encoders.map(e, ["a" => 1], (k:String) -> Encoders.string(e, k), (v:Int) -> Encoders.int(e, v));
		Encoders.tuple2(e, t, t);
		Encoders.tuple3(e, t, t, t);
		Encoders.ok(e, t);
		Encoders.error(e, t);
		Encoders.hashTerm(t);

		Decoders.int(t);
		Decoders.uint(t);
		Decoders.int64(t);
		Decoders.uint64(t);
		Decoders.float(t);
		Decoders.bool(t);
		Decoders.string(t);
		Decoders.atom(t);
		Decoders.term(t);
		Decoders.option(t, Decoders.int);
		Decoders.list(t, Decoders.int);
		Decoders.map(t, Decoders.string, Decoders.int);
		Decoders.result(t, Decoders.int, Decoders.atom);

		// user-type interfaces (an example impl lives in ImplEncoder below)
		var enc:hxler.core.Encoder = cast null;
		var dec:hxler.core.Decoder<Int> = cast null;
		if (enc != null) {
			enc.encode(e);
		}
		if (dec != null) {
			dec.decode(t);
		}

		// Schedule values flow into NifFuncFlags
		var s:hxler.core.Schedule = Schedule.Normal;
		s = Schedule.DirtyCpu;
		s = Schedule.DirtyIo;
	}
}


