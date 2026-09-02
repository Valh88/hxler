package hxler.test;

import hxler.nif.ValueTypes.Cell;
import hxler.nif.ValueTypes.TupleView;
import hxler.nif.ValueTypes.BinaryView;
import hxler.nif.ValueTypes.NewBinaryView;
import hxler.nif.raw.NifTerm;
import cpp.Pointer;
import cpp.UInt8;

/**
 * Wrapper-layer value types (Cell / TupleView / BinaryView / NewBinaryView).
 * Pure runtime (no ERTS) - data is supplied via pointers or written manually.
 */
class ValueTypesTest extends utest.Test {
	function testCellFields() {
		var c = new Cell(11, 22);
		utest.Assert.equals(11, c.head);
		utest.Assert.equals(22, c.tail);
		// fields are read-only via defaults, but hold a new value semantically
		utest.Assert.equals(11, c.head);
	}

	function testCellNullTail() {
		var c = new Cell(0, 0);
		utest.Assert.equals(0, c.head);
		utest.Assert.equals(0, c.tail);
	}

	function testTupleViewArity() {
		var t = new TupleView(4, null);
		utest.Assert.equals(4, t.arity);
	}

	function testTupleViewGet() {
		var buf:Array<NifTerm> = [10, 20, 30];
		var p = cpp.Pointer.ofArray(buf);
		var t = new TupleView(3, p);
		utest.Assert.equals(10, t.get(0));
		utest.Assert.equals(20, t.get(1));
		utest.Assert.equals(30, t.get(2));
	}

	function testBinaryView() {
		var buf:Array<UInt8> = [0x01, 0x7F, 0x80, 0xFF];
		var p = cpp.Pointer.ofArray(buf);
		var b = new BinaryView(4, p);
		utest.Assert.equals(4, b.size);
		utest.Assert.equals(0x01, b.getByte(0));
		utest.Assert.equals(0x7F, b.getByte(1));
		utest.Assert.equals(0x80, b.getByte(2));
		utest.Assert.equals(0xFF, b.getByte(3));
	}

	function testNewBinaryViewRoundTrip() {
		var buf:Array<UInt8> = [0, 0, 0];
		var p = cpp.Pointer.ofArray(buf);
		var n = new NewBinaryView(0, 3, p);
		utest.Assert.equals(3, n.size);
		n.setByte(0, 5);
		n.setByte(1, 250);
		n.setByte(2, 42);
		utest.Assert.equals(5, n.getByte(0));
		utest.Assert.equals(250, n.getByte(1));
		utest.Assert.equals(42, n.getByte(2));
	}
}