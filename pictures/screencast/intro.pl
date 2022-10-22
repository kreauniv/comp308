
:- module(intro, [interp/3]).

interp(_Env, num(N), numv(N)).

interp(Env, add(A,B), numv(Result)) :-
    interp(Env, A, numv(ResultA)),
    interp(Env, B, numv(ResultB)),
    Result is ResultA + ResultB.

interp(Env, sub(A,B), numv(Result)) :-
    interp(Env, A, numv(ResultA)),
    interp(Env, B, numv(ResultB)),
    Result is ResultA - ResultB.

interp(Env, mul(A,B), numv(Result)) :-
    interp(Env, A, numv(ResultA)),
    interp(Env, B, numv(ResultB)),
    Result is ResultA * ResultB.

% id(Sym)
% apply(Fun,Arg)
% fun(ArgSym,Expr)
interp(Env, id(Sym), Result) :-
    member(Sym => Result, Env).

interp(DefEnv, fun(ArgSym, Expr), funv(DefEnv, ArgSym, Expr)).

interp(Env, apply(FunExpr, ArgExpr), Result) :-
    interp(Env, FunExpr, funv(DefEnv, ArgSym, Expr)),
    interp(Env, ArgExpr, Arg),
    interp([ArgSym => Arg | DefEnv], Expr, Result).




