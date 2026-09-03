package hxler.core;

/**
 * NIF error kinds (rustler::Error analog). What the generated glue does
 * with them (NifReturn.apply):
 *  - BadArg     -> raises :badarg
 *  - Atom(n)    -> the atom itself is RETURNED as the call result
 *                  (not an error; for atoms-as-values protocols)
 *  - RaiseAtom  -> throw(Atom)
 *  - RaiseTerm  -> throw(Term)
 *  - Term(t)    -> {:error, t}
 */
enum NifError {
	BadArg;
	Atom(name:String);
	RaiseAtom(name:String);
	RaiseTerm(term:Term);
	Term(reason:Term);
}
