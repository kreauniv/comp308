:- module(interp, [interp/3]).

% This is our basic interpreter expressed in Prolog.
% This interpreter does basic arithmetic and supports
% functions of one argument.
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

interp(_Env, num(N), N).

interp(Env, add(E1, E2), Result) :-
    interp(Env, E1, R1),
    interp(Env, E2, R2),
    Result is R1 + R2.

interp(Env, sub(E1, E2), Result) :-
    interp(Env, E1, R1),
    interp(Env, E2, R2),
    Result is R1 - R2.

interp(Env, mul(E1, E2), Result) :-
    interp(Env, E1, R1),
    interp(Env, E2, R2),
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


