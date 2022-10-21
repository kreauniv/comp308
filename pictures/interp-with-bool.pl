:- module(interp, [interp/3]).

% This is an enhanced version of the basic interpreter which
% also supports calculation using booleans and if-then-else
% expression too.
%
% Terms are -
%
% num(N)
% add(Expr,Expr)
% sub(Expr,Expr)
% mul(Expr,Expr)
% id(Sym)
% fun(Sym,Expr)
% apply(Fun,Expr)

% Interpreter is interp(Env, Expr, Result).

minterp(_Env, [], []).
minterp(Env, [T|Ts], [R|Rs]) :-
    interp(Env, T, R),
    minterp(Env, Ts, Rs).

interp(_Env, num(N), numv(N)).

interp(Env, add(E1, E2), numv(Result)) :-
    minterp(Env, [E1, E2], [numv(R1), numv(R2)]),
    Result is R1 + R2.

interp(Env, sub(E1, E2), numv(Result)) :-
    minterp(Env, [E1, E2], [numv(R1), numv(R2)]),
    Result is R1 - R2.

interp(Env, mul(E1, E2), numv(Result)) :-
    minterp(Env, [E1, E2], [numv(R1), numv(R2)]),
    Result is R1 * R2.

interp(Env, id(Sym), Result) :-
    member(Sym => Result, Env).

interp(DefEnv, fun(Sym, Expr), Result) :-
    Result = funv(DefEnv, Sym, Expr).

interp(Env, apply(FunExpr, Expr), Result) :-
    interp(Env, FunExpr, funv(DefEnv, Sym, BodyExpr)),
    interp(Env, Expr, Arg),
    interp([Sym => Arg | DefEnv], BodyExpr, Result).
    % The expression [Sym => Arg | DefEnv] is equivalent
    % to writing the following --
    %   NewBinding = Sym => Arg,
    %   NewEnv = [NewBinding | DefEnv],
    %   interp(NewEnv, BodyExpr, Result).

interp(_Env, bool(true), boolv(true)).
interp(_Env, bool(false), boolv(false)).

interp(Env, if(B,Then,Else), Result) :-
    interp(Env, B, boolv(TF)),
    if(TF, interp(Env, Then), interp(Env, Else), Result). 

interp(Env, gt(A, B), boolv(Result)) :-
    minterp(Env, [A,B], [numv(RA), numv(RB)]),
    reify(RA > RB, Result).

interp(Env, lt(A, B), boolv(Result)) :-
    minterp(Env, [A,B], [numv(RA), numv(RB)]),
    reify(RA < RB, Result).

interp(Env, leq(A, B), boolv(Result)) :-
    minterp(Env, [A,B], [numv(RA), numv(RB)]),
    reify(RA =< RB, Result).

interp(Env, geq(A, B), boolv(Result)) :-
    minterp(Env, [A,B], [numv(RA), numv(RB)]),
    reify(RA >= RB, Result).

interp(Env, eq(A, B), boolv(Result)) :-
    minterp(Env, [A,B], [numv(RA), numv(RB)]),
    reify(RA = RB, Result).

interp(Env, or(A,B), boolv(Result)) :-
    minterp(Env, [A,B], [numv(RA), numv(RB)]),
    reify(or(RA,RB), Result).

interp(Env, and(A,B), boolv(Result)) :-
    minterp(Env, [A,B], [numv(RA), numv(RB)]),
    reify(and(RA,RB), Result).

interp(Env, xor(A,B), boolv(Result)) :-
    minterp(Env, [A,B], [numv(RA), numv(RB)]),
    reify(xor(RA,RB), Result).

interp(Env, not(A), boolv(Result)) :-
    interp(Env, A, boolv(RA)),
    reify(not(RA), Result).

if(true, Then, _Else, Result) :- call(Then, Result).
if(false, _Then, Else, Result) :- call(Else, Result).
reify(Cond, X) :- call(Cond) -> X = true; X = false.
or(false,false, false).
or(false,true, true).
or(true,true, true).
or(true,false, true).
and(true,false, false).
and(false,false, false).
and(false,true, false).
and(true,true, true).
xor(true,false, true).
xor(false,false, false).
xor(false,true, true).
xor(true,true, false).
not(false,true).
not(true,false).

