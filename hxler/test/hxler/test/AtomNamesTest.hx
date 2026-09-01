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
}
