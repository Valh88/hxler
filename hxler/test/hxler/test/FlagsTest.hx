package hxler.test;

import hxler.nif.raw.NifSelectFlags;
import hxler.nif.raw.NifResourceFlags;
import hxler.nif.raw.NifCharEncoding;
import hxler.nif.raw.NifMapIteratorEntry;
import hxler.nif.raw.NifUniqueInteger;
import hxler.nif.raw.NifBin2TermOpts;
import hxler.nif.raw.NifHash;
import hxler.nif.raw.NifTermType;
import hxler.nif.raw.NifThreadType;
import hxler.nif.raw.NifOption;
import hxler.nif.raw.NifIOQueueOpts;
import hxler.nif.raw.NifFuncFlags;

/**
 * Flag constants must match erl_nif.h / erl_drv_nif.h exactly (ABI values).
 */
class FlagsTest extends utest.Test {
	function testSelectFlags() {
		utest.Assert.equals(1 << 0, NifSelectFlags.READ);
		utest.Assert.equals(1 << 1, NifSelectFlags.WRITE);
		utest.Assert.equals(1 << 2, NifSelectFlags.STOP);
		utest.Assert.equals(1 << 3, NifSelectFlags.CANCEL);
		utest.Assert.equals(1 << 4, NifSelectFlags.CUSTOM_MSG);
		utest.Assert.equals(1 << 5, NifSelectFlags.ERROR);
	}

	function testResourceFlags() {
		utest.Assert.equals(1, NifResourceFlags.CREATE); // ERL_NIF_RT_CREATE
		utest.Assert.equals(2, NifResourceFlags.TAKEOVER); // ERL_NIF_RT_TAKEOVER
	}

	function testCharEncoding() {
		utest.Assert.equals(1, NifCharEncoding.LATIN1);
		utest.Assert.equals(2, NifCharEncoding.UTF8);
	}

	function testMapIteratorEntry() {
		utest.Assert.equals(1, NifMapIteratorEntry.FIRST);
		utest.Assert.equals(2, NifMapIteratorEntry.LAST);
	}

	function testUniqueInteger() {
		utest.Assert.equals(1 << 0, NifUniqueInteger.POSITIVE);
		utest.Assert.equals(1 << 1, NifUniqueInteger.MONOTONIC);
	}

	function testBin2TermOpts() {
		utest.Assert.equals(0x20000000, NifBin2TermOpts.SAFE); // ERL_NIF_BIN2TERM_SAFE
	}

	function testHash() {
		utest.Assert.equals(1, NifHash.INTERNAL);
		utest.Assert.equals(2, NifHash.PHASH2);
	}

	function testTermType() {
		utest.Assert.equals(1, NifTermType.ATOM);
		utest.Assert.equals(2, NifTermType.BITSTRING);
		utest.Assert.equals(3, NifTermType.FLOAT);
		utest.Assert.equals(4, NifTermType.FUN);
		utest.Assert.equals(5, NifTermType.INTEGER);
		utest.Assert.equals(6, NifTermType.LIST);
		utest.Assert.equals(7, NifTermType.MAP);
		utest.Assert.equals(8, NifTermType.PID);
		utest.Assert.equals(9, NifTermType.PORT);
		utest.Assert.equals(10, NifTermType.REFERENCE);
		utest.Assert.equals(11, NifTermType.TUPLE);
	}

	function testThreadType() {
		utest.Assert.equals(0, NifThreadType.UNDEFINED);
		utest.Assert.equals(1, NifThreadType.NORMAL_SCHEDULER);
		utest.Assert.equals(2, NifThreadType.DIRTY_CPU_SCHEDULER);
		utest.Assert.equals(3, NifThreadType.DIRTY_IO_SCHEDULER);
		utest.Assert.isTrue(NifThreadType.isSchedulerThread(1));
		utest.Assert.isTrue(NifThreadType.isSchedulerThread(3));
		utest.Assert.isFalse(NifThreadType.isSchedulerThread(0));
	}

	function testFuncFlags() {
		utest.Assert.equals(0, NifFuncFlags.NORMAL);
		utest.Assert.equals(1, NifFuncFlags.DIRTY_CPU); // ERL_NIF_DIRTY_JOB_CPU_BOUND
		utest.Assert.equals(2, NifFuncFlags.DIRTY_IO); // ERL_NIF_DIRTY_JOB_IO_BOUND
	}

	function testOtherFlags() {
		utest.Assert.equals(1, NifOption.DELAY_HALT);
		utest.Assert.equals(2, NifOption.ON_HALT);
		utest.Assert.equals(3, NifOption.ON_UNLOAD_THREAD);
		utest.Assert.equals(1, NifIOQueueOpts.NORMAL);
	}
}
