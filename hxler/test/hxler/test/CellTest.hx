package hxler.test;

import hxler.nif.ValueTypes.Cell;
import hxler.nif.ValueTypes.TupleView;

/** Small Haxe value types of the wrapper layer. */
class CellTest extends utest.Test {
	function testCellFields() {
		var c = new Cell(11, 22);
		utest.Assert.equals(11, c.head);
		utest.Assert.equals(22, c.tail);
	}

	function testTupleViewArity() {
		var t = new TupleView(3, null);
		utest.Assert.equals(3, t.arity);
	}
}

