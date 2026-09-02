package hxler.test;

import utest.Runner;
import utest.ui.Report;

/**
 * utest runner for the hxler SDK. These tests verify everything that can
 * run without a live BEAM: type constants, flag values, small Haxe value
 * types. ABI/compile-level verification lives in check.hxml (MSVC build),
 * E2E verification lives in the mix project (spike.exs / phase 7 tests).
 */
class TestMain {
	public static function main() {
		var runner = new Runner();
		runner.addCase(new FlagsTest());
		runner.addCase(new CellTest());
		runner.addCase(new ValueTypesTest());
		runner.addCase(new AtomNamesTest());
		runner.addCase(new ScheduleTest());
		Report.create(runner);
		runner.run();
	}
}
