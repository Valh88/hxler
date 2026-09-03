package hxler.nif;

import cpp.NativeArray;
import cpp.Pointer;

/**
 * The ONLY place with raw memory plumbing (untyped __cpp__), so the rest of
 * the SDK stays clean Haxe. Rules:
 *  - bytesBase is fully typed (NativeArray.address over BytesData = Array<cpp.UInt8>);
 *  - the two memcpy wrappers are unavoidable: Haxe-side blit works only
 *    between Haxe arrays, not between Haxe Bytes and raw pointers. Keep
 *    them; replace only if a typed API appears in hxcpp.
 */
@:keep
@:headerCode('#include "erl_nif.h"')
class Mem {
	/** Base pointer of Haxe bytes (zero-copy view over BytesData). */
	public inline static function bytesBase(b:haxe.io.Bytes):Pointer<cpp.UInt8> {
		return cast NativeArray.address(b.getData(), 0);
	}

	/** memcpy raw pointer -> Haxe bytes. */
	public inline static function toBytes(dst:haxe.io.Bytes, src:Pointer<cpp.UInt8>, count:Int):Void {
		if (count > 0) {
			untyped __cpp__("memcpy({0}->b->GetBase(), {1}, {2})", dst, src, count);
		}
	}

	/** memcpy Haxe bytes -> raw pointer (with dst offset). */
	public inline static function fromBytes(dst:Pointer<cpp.UInt8>, dstOffset:Int, src:haxe.io.Bytes, count:Int):Void {
		if (count > 0) {
			untyped __cpp__("memcpy({0} + {1}, {2}->b->GetBase(), {3})", dst, dstOffset, src, count);
		}
	}

	/** ASCII/Latin-1 string -> malloc-free null-terminated char pointer (caller keeps the buffer). */
	public inline static function charPointer(s:String):Pointer<cpp.Char> {
		var buf = new Array<cpp.Char>();
		for (i in 0...s.length) {
			buf.push(s.charCodeAt(i));
		}
		buf.push(0);
		return cpp.Pointer.ofArray(buf);
	}
}
