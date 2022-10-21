
:- module(typecheck, [typecheck/3]).

typecheck(_Env, num(X), t_number) :- number(X).
typecheck(_Env, bool(true), t_bool).
typecheck(_Env, bool(false), t_bool).
typecheck(Env, add(X,Y), t_number) :-
    typecheck(Env, X, t_number),
    typecheck(Env, Y, t_number).
typecheck(Env, sub(X,Y), t_number) :-
    typecheck(Env, X, t_number),
    typecheck(Env, Y, t_number).
typecheck(Env, mul(X,Y), t_number) :-   
    typecheck(Env, X, t_number),
    typecheck(Env, Y, t_number).
typecheck(Env, if(B,Then,Else), Ty) :-
    typecheck(Env, B, t_bool),
    % This is one possibility.
    % Another possibility is to create a union
    % of the two types if our language supports
    % that.
    typecheck(Env, Then, Ty),
    typecheck(Env, Else, Ty).
typecheck(Env, and(A,B), t_bool) :-
    typecheck(Env, A, t_bool),
    typecheck(Env, B, t_bool).
typecheck(Env, or(A,B), t_bool) :-
    typecheck(Env, A, t_bool),
    typecheck(Env, B, t_bool).
typecheck(Env, xor(A,B), t_bool) :-
    typecheck(Env, A, t_bool),
    typecheck(Env, B, t_bool).
typecheck(Env, not(A), t_bool) :-
    typecheck(Env, A, t_bool).
typecheck(Env, fun(ArgSym, ArgTy, ExprTy, Expr), arrow(ArgTy,ExprTy)) :-
    typecheck([ArgSym => ArgTy | Env], Expr, ExprTy).
typecheck(Env, apply(Fun,Arg), Ty) :-
    typecheck(Env, Fun, arrow(ArgTy,Ty)),
    typecheck(Env, Arg, ArgTy).
typecheck(Env, id(Sym), Ty) :-
    member(Sym => Ty, Env).


