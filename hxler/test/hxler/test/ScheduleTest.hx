package hxler.test;

import hxler.core.Schedule;
import hxler.nif.raw.NifFuncFlags;

/** Scheduler selection values must match ErlNifFunc.flags (ABI). */
class ScheduleTest extends utest.Test {
	function testValues() {
		// cast to Int: utest's `equals` is generic (git) vs Dynamic (release),
		// so an enum abstract only typechecks when explicitly cast.
		utest.Assert.equals(0, (cast Schedule.Normal : Int));
		utest.Assert.equals(1, (cast Schedule.DirtyCpu : Int));
		utest.Assert.equals(2, (cast Schedule.DirtyIo : Int));
	}

	function testMatchesFuncFlags() {
		// the schedule an @:nif(schedule=...) wraps into must agree with the
		// raw ErlNifFunc.flags the BEAM scheduler dispatches on.
		utest.Assert.equals(NifFuncFlags.NORMAL, (cast Schedule.Normal : Int));
		utest.Assert.equals(NifFuncFlags.DIRTY_CPU, (cast Schedule.DirtyCpu : Int));
		utest.Assert.equals(NifFuncFlags.DIRTY_IO, (cast Schedule.DirtyIo : Int));
	}

	function testToString() {
		utest.Assert.equals("Normal", Schedule.Normal.toString());
		utest.Assert.equals("DirtyCpu", Schedule.DirtyCpu.toString());
		utest.Assert.equals("DirtyIo", Schedule.DirtyIo.toString());
	}

	function testIntCast() {
		var i:Int = cast Schedule.DirtyCpu;
		utest.Assert.equals(1, i);
	}
}
