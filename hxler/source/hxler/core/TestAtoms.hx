package hxler.core;

/**
 * Example/verification target for the AtomBuilder macro: keyword names
 * ("true") and digit-leading names ("42") must map to valid identifiers.
 * Used by the check build; user NIFs declare their own atom groups.
 */
@:build(hxler.macros.AtomBuilder.build(["ok", "error", "nil", "undefined", "true", "false", "badarg", "nif_panicked", "42"]))
class TestAtoms {
}
