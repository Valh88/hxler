package hxler.test;

import hxler.core.Schedule;

/** Scheduler selection values must match ErlNifFunc.flags (ABI). */
class ScheduleTest extends utest.Test {
	function testValues() {
		utest.Assert.equals(0, Schedule.Normal);
		utest.Assert.equals(1, Schedule.DirtyCpu);
		utest.Assert.equals(2, Schedule.DirtyIo);
	}

	function testToString() {
		utest.Assert.equals("Normal", Schedule.Normal.toString());
		utest.Assert.equals("DirtyCpu", Schedule.DirtyCpu.toString());
		utest.Assert.equals("DirtyIo", Schedule.DirtyIo.toString());
	}
}
