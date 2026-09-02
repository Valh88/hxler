package hxler.test;

import hxler.macros.AtomNames;

/** Atom-name -> identifier sanitization (used by AtomBuilder). */
class AtomNamesTest extends utest.Test {
	function testSimple() {
		utest.Assert.equals("ok", AtomNames.identifier("ok"));
		utest.Assert.equals("error", AtomNames.identifier("error"));
		utest.Assert.equals("hello_world", AtomNames.identifier("hello_world"));
		utest.Assert.equals("nif_panicked", AtomNames.identifier("nif_panicked"));
	}

	function testKeywords() {
		utest.Assert.equals("true_", AtomNames.identifier("true"));
		utest.Assert.equals("false_", AtomNames.identifier("false"));
		utest.Assert.equals("null_", AtomNames.identifier("null"));
		utest.Assert.equals("new_", AtomNames.identifier("new"));
	}

	function testSpecialChars() {
		utest.Assert.equals("Elixir_Hxler_Math", AtomNames.identifier("Elixir.Hxler.Math"));
		utest.Assert.equals("__struct__", AtomNames.identifier("__struct__"));
		utest.Assert.equals("foo_bar", AtomNames.identifier("foo-bar"));
	}

	function testDigitLeading() {
		utest.Assert.equals("_42", AtomNames.identifier("42"));
	}

	function testEmpty() {
		utest.Assert.equals("_", AtomNames.identifier(""));
	}

	function testDigitInside() {
		// digits after the first char stay untouched
		utest.Assert.equals("foo2bar", AtomNames.identifier("foo2bar"));
		utest.Assert.equals("a1b2c3", AtomNames.identifier("a1b2c3"));
	}

	function testNonAscii() {
		// non-ASCII (and punctuation) become "_" (only a-z/A-Z/0-9/_ are kept)
		utest.Assert.equals("______", AtomNames.identifier("привет"));
		utest.Assert.equals("a_c", AtomNames.identifier("a-c"));
		utest.Assert.equals("a_c", AtomNames.identifier("a.c"));
	}

	function testLeadingUnderscore() {
		utest.Assert.equals("__struct__", AtomNames.identifier("__struct__"));
		utest.Assert.equals("_x", AtomNames.identifier("_x"));
	}

	function testOnlyUnderscore() {
		utest.Assert.equals("___", AtomNames.identifier("---"));
	}
}
