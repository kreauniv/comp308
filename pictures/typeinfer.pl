
:- module(infer, [infer/3]).

infer(_Env, num(X), t_number) :- number(X).
infer(_Env, bool(true), t_bool).
infer(_Env, bool(false), t_bool).
infer(Env, add(X,Y), t_number) :-
    infer(Env, X, t_number),
    infer(Env, Y, t_number).
infer(Env, sub(X,Y), t_number) :-
    infer(Env, X, t_number),
    infer(Env, Y, t_number).
infer(Env, mul(X,Y), t_number) :-   
    infer(Env, X, t_number),
    infer(Env, Y, t_number).
infer(Env, if(B,Then,Else), Ty) :-
    infer(Env, B, t_bool),
    % This is one possibility.
    % Another possibility is to create a union
    % of the two types if our language supports
    % that.
    infer(Env, Then, Ty),
    infer(Env, Else, Ty).
infer(Env, and(A,B), t_bool) :-
    infer(Env, A, t_bool),
    infer(Env, B, t_bool).
infer(Env, or(A,B), t_bool) :-
    infer(Env, A, t_bool),
    infer(Env, B, t_bool).
infer(Env, xor(A,B), t_bool) :-
    infer(Env, A, t_bool),
    infer(Env, B, t_bool).
infer(Env, not(A), t_bool) :-
    infer(Env, A, t_bool).
infer(Env, fun(ArgSym, Expr), arrow(ArgTy,ExprTy)) :-
    alpha_rename(fun(ArgSym, Expr), fun(NewArgSym, NewExpr)),
    infer([NewArgSym => ArgTy | Env], NewExpr, ExprTy).
infer(Env, apply(Fun,Arg), Ty) :-
    infer(Env, Arg, ArgTy),
    infer(Env, Fun, arrow(ArgTy,Ty)).
infer(Env, id(Sym), Ty) :-
    member(Sym => Ty, Env).

alpha_rename(fun(ArgSym, Expr), fun(NewArgSym, NewExpr)) :-
    gensym('var', NewArgSym),
    replace(ArgSym, NewArgSym, Expr, NewExpr).

replace(Sym, NewSym, fun(ArgSym, Expr), fun(NewArgSym, NewExpr)) :-
    alpha_rename(fun(ArgSym, Expr), fun(NewArgSym, Expr2)),
    replace(Sym, NewSym, Expr2, NewExpr).

replace(Sym, NewSym, apply(Fun,Arg), apply(NewFun, NewArg)) :-
    replace(Sym, NewSym, Fun, NewFun),
    replace(Sym, NewSym, Arg, NewArg).

replace(Sym, NewSym, id(Sym), id(NewSym)).
replace(Sym, NewSym, add(A,B), add(NewA, NewB)) :-
    replace(Sym, NewSym, A, NewA),
    replace(Sym, NewSym, B, NewB).
replace(Sym, NewSym, sub(A,B), sub(NewA, NewB)) :-
    replace(Sym, NewSym, A, NewA),
    replace(Sym, NewSym, B, NewB).
replace(Sym, NewSym, mul(A,B), mul(NewA, NewB)) :-
    replace(Sym, NewSym, A, NewA),
    replace(Sym, NewSym, B, NewB).
replace(Sym, NewSym, if(B,Then,Else), if(NewB, NewThen, NewElse)) :-
    replace(Sym, NewSym, B, NewB),
    replace(Sym, NewSym, Then, NewThen),
    replace(Sym, NewSym, Else, NewElse).
replace(Sym, NewSym, and(A,B), and(NewA,NewB)) :-
    replace(Sym, NewSym, A, NewA),
    replace(Sym, NewSym, B, NewB).
replace(Sym, NewSym, or(A,B), or(NewA,NewB)) :-
    replace(Sym, NewSym, A, NewA),
    replace(Sym, NewSym, B, NewB).
replace(Sym, NewSym, xor(A,B), xor(NewA,NewB)) :-
    replace(Sym, NewSym, A, NewA),
    replace(Sym, NewSym, B, NewB).
replace(Sym, NewSym, not(A), not(NewA)) :-
    replace(Sym, NewSym, A, NewA).
replace(_, _, X, X).

