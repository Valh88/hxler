package hxler.test;

import hxler.core.Schedule;
import hxler.nif.raw.NifFuncFlags;

/** Scheduler selection values must match ErlNifFunc.flags (ABI). */
class ScheduleTest extends utest.Test {
	function testValues() {
		utest.Assert.equals(0, Schedule.Normal);
		utest.Assert.equals(1, Schedule.DirtyCpu);
		utest.Assert.equals(2, Schedule.DirtyIo);
	}

	function testMatchesFuncFlags() {
		// the schedule an @:nif(schedule=...) wraps into must agree with the
		// raw ErlNifFunc.flags the BEAM scheduler dispatches on.
		utest.Assert.equals(NifFuncFlags.NORMAL, Schedule.Normal);
		utest.Assert.equals(NifFuncFlags.DIRTY_CPU, Schedule.DirtyCpu);
		utest.Assert.equals(NifFuncFlags.DIRTY_IO, Schedule.DirtyIo);
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
