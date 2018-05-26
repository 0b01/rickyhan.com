---
layout: post
title:  "TensorScript Type Inference: Hindley-Milner in Rust"
date:   2018-05-26 00:00:00 -0400
categories: jekyll update
---

Type-inferred gradually typed languages are a joy to use: easy to write, analyze, and refactor. In this blog post, I will showcase to the other dozen of programmers who are interested in the obscure art of programming language type inference.

# Type Inference

In the compilation process, type reconstruction happens after the AST has been constructed - that is, after lexing and parsing. The goal is to traverse and type the AST to produce a Typed AST or throw if the program is not well-typed. Type reconstruction may be further divided into type inference and type checking, although the boundary is usually blurred in practice.

# Hindley-Milner(HM)

HM is a classical type inference algorithm and can be extended in various ways. The idea is very intuitive. As an example, given following statement.

```rust
if isEven(2) {
    a
} else {
    b
}
```

We can infer the following:

1. `is_even` returns a boolean value
2. `a` and `b` must have the same type

HM and other constraint based type inference algorithm does the same thing in 3 steps:

1. Annotate with "dummy" types
2. Collect constraints
3. Unification

Concretely, for the above example, first annotate the variables `a b c` with "type variables" placeholders which can just be intergers. The AST is now typed:

```
    if is_even(2: '0) { a: '1 } else { b: '2 }
        where is_even: '3 -> '4
```

In another pass of the AST, we can collect the constraints based on context. In essense, we write down a system of equations: `'0` is integer, return type of `'4` must be bool, `'1` and `'2` must be the same type:

```
'0 = int
'0 = '3
'1 = '2
'4 = bool
```

Given the equivalence relations, we can apply unify the constraints which is really just gauss-jordan elimination to put the types in row reduced echelon form. If we know that a type variable is equal to a concrete type, replace every occurence of the type variable in the constraint set until the constraint set is empty. So in the end, the unifier yields a set of substitions that maps type variables to concrete types.

```
'4 -> bool
'0 -> int
'3 -> int
```

And finally, we can use the substitution set to replace the type variables in the annotated AST to get a concretely typed AST.

# Code example

The function `unify` first finds 1 substitution with the first item in the constraint set and applies the substitution to the tail of the constraint set.

```rust
    fn unify(&mut self, cs: Constraints) -> Substitution {
        if cs.is_empty() {
            Substitution::empty()
        } else {
            let emitter = cs.emitter.clone();
            let tenv = cs.tenv.clone();
            let mut it = cs.set.into_iter();
            let mut subst = self.unify_one(it.next().unwrap());
            let subst_tail = subst.apply(&Constraints {set: it.collect(), emitter, tenv});
            let subst_tail: Substitution = self.unify(subst_tail);
            subst.compose(subst_tail)
        }
    }
```

The function `unify_one` pattern against against possible types and seeks to replace type variables with concrete types.

```rust
    fn unify_one(&mut self, eq: Equals) -> Substitution {
        use self::Type::*;
        let emitter = Rc::clone(&self.emitter);
        let tenv = Rc::clone(&self.tenv);
        match eq {
            Equals(Unit(_), Unit(_)) => Substitution::empty(),
            Equals(INT(_), INT(_)) => Substitution::empty(),
            Equals(FLOAT(_), FLOAT(_)) => Substitution::empty(),
            Equals(BOOL(_), BOOL(_)) => Substitution::empty(),
            Equals(INT(_), ResolvedDim(_, _)) => Substitution::empty(),
            Equals(ResolvedDim(_, _), INT(_)) => Substitution::empty(),
            Equals(a @ ResolvedDim(_, _), b @ ResolvedDim(_, _)) => {
                if a.as_num() == b.as_num() {
                    Substitution::empty()
                } else {
                    // self.add_err(TensorScriptDiagnostic::DimensionMismatch(a.clone(), b.clone()));
                    // error!()
                    Substitution::empty()
                }
            }
            Equals(VAR(tvar, _), ty) => self.unify_var(tvar, ty),
            Equals(ty, VAR(tvar, _)) => self.unify_var(tvar, ty),
            Equals(DIM(tvar, _), ty) => self.unify_var(tvar, ty),
            Equals(ty, DIM(tvar, _)) => self.unify_var(tvar, ty),
            Equals(FnArgs(v1, _), FnArgs(v2, _)) => self.unify(
                Constraints {
                    set: v1.into_iter().zip(v2).map(|(i, j)| Equals(i, j)).collect(),
                    emitter,
                    tenv,
                },
            ),
            Equals(FnArg(Some(a), ty1, _), FnArg(Some(b), ty2, _)) => {
                if a == b {
                    self.unify(
                        Constraints {
                            set: btreeset!{ Equals(*ty1, *ty2)},
                            emitter,
                            tenv,
                        },
                        )
                } else {
                    panic!("supplied parameter is incorrect! {} != {}", a, b);
                }
            }
            Equals(FUN(m1,n1,p1, r1, _), FUN(m2,n2,p2, r2, _)) => {
                if n1 == n2 {
                    self.unify(
                        Constraints{
                            set: btreeset!{
                                Equals(*p1, *p2),
                                Equals(*r1, *r2),
                            },
                            emitter,
                            tenv,
                        },
                    )
                } else {
                    println!("{} {} {} {}", m1, m2, n1, n2);
                    panic!()
                }
            },
            Equals(Tuple(vs1, _), Tuple(vs2, _)) => self.unify(
                Constraints {
                    set: vs1.into_iter().zip(vs2).map(|(i,j)| Equals(i,j)).collect(),
                    emitter,
                    tenv,
                },
            ),
            Equals(ts1 @ TSR(_, _), ts2 @ TSR(_, _)) => {
                if ts1.as_rank() == ts2.as_rank() {
                    match (ts1, ts2) {
                        (TSR(dims1, s1), TSR(dims2, s2)) => self.unify(
                            Constraints {
                                set: dims1
                                    .into_iter()
                                    .zip(dims2)
                                    .map(|(i, j)| Equals(i.with_span(&s1), j.with_span(&s2)))
                                    .collect(),
                                emitter,
                                tenv,
                            },
                        ),
                        _ => unimplemented!(),
                    }
                } else {
                    // self.add_err(TensorScriptDiagnostic::RankMismatch(ts1, ts2));
                    // error!
                    Substitution::empty()
                }
            }
            _ => {
                panic!("{:#?}", eq);
            }
        }
    }
    fn unify_var(&mut self, tvar: TypeId, ty: Type) -> Substitution {
        use self::Type::*;
        let span = CSpan::fresh_span();
        match ty.clone() {
            VAR(tvar2, _) => {
                if tvar == tvar2 {
                    Substitution::empty()
                } else {
                    Substitution(btreemap!{ VAR(tvar, span) => ty })
                }
            }
            DIM(tvar2, _) => {
                if tvar == tvar2 {
                    Substitution::empty()
                } else {
                    Substitution(btreemap!{ VAR(tvar, span) => ty })
                }
            }
            _ => if occurs(tvar, &ty) {
                panic!("circular type")
            } else {
                Substitution(btreemap!{ VAR(tvar, span) => ty })
            },
        }
    }
}
```

The occurs check eliminates circular type definition (omega combinator) such as `'1 = '1 -> '2`.

```rust
fn occurs(tvar: TypeId, ty: &Type) -> bool {
    use self::Type::*;
    match ty {
        FUN(_,_, ref p, ref r, _) => occurs(tvar, &p) | occurs(tvar, &r),
        VAR(ref tvar2, _) => tvar == *tvar2,
        _ => false,
    }
}
```

Finally, substitution is just a wrapper around a map.

```rust
#[derive(Debug, PartialEq)]
pub struct Substitution(pub BTreeMap<Type, Type>);
impl Substitution {
    /// apply substitution to a set of constraints
    pub fn apply(&mut self, cs: &Constraints) -> Constraints {
        Constraints {
            set: cs.set
                .iter()
                .map(|Equals(a, b)| Equals(self.apply_ty(a), self.apply_ty(b)))
                .collect(),
            tenv: cs.tenv.clone(),
            emitter: cs.emitter.clone(),
        }
    }
    pub fn apply_ty(&mut self, ty: &Type) -> Type {
        self.0.iter().fold(ty.clone(), |result, solution| {
            let (ty, solution_type) = solution;
            if let Type::VAR(ref tvar, ref span) = ty {
                substitute_tvar(result, tvar, &solution_type.with_span(span))
            } else {
                panic!("Impossible!");
            }
        })
    }
    pub fn compose(&mut self, mut other: Substitution) -> Substitution {
        let mut self_substituded: BTreeMap<Type, Type> = self.0
            .clone()
            .into_iter()
            .map(|(k, s)| (k, other.apply_ty(&s)))
            .collect();
        self_substituded.extend(other.0);
        Substitution(self_substituded)
    }
    pub fn empty() -> Substitution {
        Substitution(BTreeMap::new())
    }
}

/// replace tvar with replacement in ty
fn substitute_tvar(ty: Type, tvar: &TypeId, replacement: &Type) -> Type {
    use self::Type::*;
    // println!("\nTVAR:::\n{:?}, \n'{:?}, \n{:?}\n", ty, tvar, replacement);
    match ty {
        UnresolvedModuleFun(_, _, _, _) => {
            println!("{:?}, replacement: {:?}", ty, replacement);
            ty
        },
        Unit(_) => ty,
        INT(_) => ty,
        BOOL(_) => ty,
        FLOAT(_) => ty,
        ResolvedDim(_, _) => ty,
        VAR(tvar2, span) => {
            if *tvar == tvar2 {
                replacement.with_span(&span)
            } else {
                ty
            }
        }
        DIM(tvar2, span) => {
            if *tvar == tvar2 {
                replacement.with_span(&span)
            } else {
                ty
            }
        }
        FnArgs(args, span) => FnArgs(
            args.into_iter()
                .map(|ty| match ty {
                    FnArg(name, a, s) => FnArg(name, box substitute_tvar(*a, tvar, replacement), s),
                    _ => panic!(ty),
                })
                .collect(),
            span,
        ),
        Tuple(tys, s) => Tuple(tys.into_iter().map(|t| substitute_tvar(t, tvar, replacement)).collect(), s),
        FUN(module,name,p, r, s) => FUN(
            module,
            name,
            box substitute_tvar(*p, tvar, &replacement),
            box substitute_tvar(*r, tvar, &replacement),
            s,
        ),
        TSR(_, _) => ty,

        Module(n, Some(box ty), s) => {
            Module(n, Some(box substitute_tvar(ty, tvar, replacement)), s)
        }

        Module(_, None, _) => ty,
        FnArg(name, box ty, s) => FnArg(name, box substitute_tvar(ty, tvar, replacement), s),
    }
}
```


# What are dependent types?

Recently, I started working on a language that brings the static type experience to ML(Machine Learning, not the language) which is dominated by Python. Neural network is an important domain and warrants its own DSL. 

If you have used Java, C# or any other languages that support generic programming, you have seen `Vec<T>` where `T` is some type `int`, `complex`, or even `Vec<T>`. Now imagine this: what if `T` refers to something else, say a number, denote `Vec<N>` as a vector that contains N elements: `Vec<1> v1 = {0}; Vec<2> v2 = {1, 2};` etc. What would happen? First thing is that there cannot be intermediate states - everything has to be immutably initialized and vector length cannot change over the course of program execution. The programming model fits nicely with neural networks. By dependently typed, I actually meant dimensioned tensor types such as `Tensor<[?,1,3,3]>` so far from the sophistication Idris, LiquidHaskell and the other research languages. For ML(Machine Learning), where tensors and tensor operations are the core abstration, dependent types are immensely useful.

To add rudimentary type level computation, I simply used modified the generic HM algorithm. For every neural network operation, I supply all the necessary information such as the shape of tensors that's coming and out to a resolver which returns the type if enough information is supplied, otherwise it'll return None. So running HM iteratively on the AST, type information "flows" to the operations and the AST gets resolved gradually. The annotate-collect-unify-replace loop breaks when the AST anneals.

Here is the shape computation for `maxpool2d`.

```rust
impl Resolve for maxpool2d {
    fn resolve(
        &self,
        _tenv: &mut TypeEnv,
        fn_name: &str,
        arg_ty: Type,
        _ret_ty: Type,
        args: Vec<TyFnAppArg>,
        _inits: Option<Vec<TyFnAppArg>>,
    ) -> Option<Result<Type, Diag>> {
        match fn_name {
            "forward" => {
                let args_ty_map = arg_ty.as_args_map()?;
                let x_ty = args_ty_map.get("x").expect("No x argument");
                let args_map = args.to_btreemap()?;
                if !x_ty.is_resolved() {
                    None
                } else {
                    let (k0, k1) = read_from_init!(args_map.get("kernel_size"), (0, 0));
                    let (p0, p1) = read_from_init!(args_map.get("padding"), (0, 0));
                    let (d0, d1) = read_from_init!(args_map.get("dilation"), (1, 1));
                    let (s0, s1) = read_from_init!(args_map.get("stride"), (k0, k1));
                    let dims = x_ty.as_vec()?;
                    let (n, c_in, h_in, w_in) = (
                        dims[0].to_owned(),
                        dims[1].to_owned(),
                        dims[2].to_owned().as_num().unwrap(),
                        dims[3].to_owned().as_num().unwrap()
                    );
                    let h_out = (h_in + 2 * p0 - d0 * (k0 -1) - 1) / s0 + 1;
                    let w_out = (w_in + 2 * p1 - d1 * (k1 -1) - 1) / s1 + 1;
                    let span = x_ty.span();
                    Some(Ok( // returns a function
                        fun!(
                            "maxpool2d",
                            "forward",
                            arg_ty,
                            Type::TSR(vec![
                                n,
                                c_in.clone(),
                                Type::ResolvedDim(h_out, span),
                                Type::ResolvedDim(w_out, span),
                            ], span)
                        )
                    ))
                }
            },
            _ => None,
        }
    }
}
```

# Type Environement and Scopes

As shown above, a type variable is a number. Type environment is used to increment the counter. Another major use of type environment is keeping track of variables and their corresponding types in local scopes. A type environement consists of a stack. During the annotation stage, when entering a new scope, a new Scope struct is pushed onto the stack, and when leaving a scope, the popped scope is "recycled" into a queue(FIFO) which is used during the next pass, constraint collection.

```rust
/// Represents a single level of scope
pub struct Scope {
    /// type information of aliases
    types: BTreeMap<Alias, Type>,
}
type ScopeStack = VecDeque<Scope>;
pub struct TypeEnv {
    counter: TypeId,
    current_mod: ModName,
    modules: BTreeMap<ModName, (ScopeStack, ScopeStack, InitMap)>,
}
impl TypeEnv {
    // ...omitted...
    /// push scope onto stack
    pub fn push_scope(&mut self, mod_name: &ModName) {
        let stack = self.modules.get_mut(mod_name).unwrap();
        stack.0.push_back(Scope::new());
    }
    /// during constraint collection, push the popped scopes into queue
    pub fn push_scope_collection(&mut self, mod_name: &ModName) {
        let stack = self.modules.get_mut(mod_name).unwrap();
        let scp = stack.1.pop_front().unwrap();
        stack.0.push_back(scp);
    }
    /// exit a block 
    pub fn pop_scope(&mut self, mod_name: &ModName) {
        let stack = self.modules.get_mut(mod_name).unwrap();
        let popped = stack.0.pop_back().unwrap();
        stack.1.push_back(popped);
    }
    // ...omitted...
}
```

# Conclusion

TensorScript is pretty straightforward to implement. Recently I got sidetracked and tried to lift the type level computation to language level(or at least proc macro level) but it is hopeless. I am still working on the language. I want to add support for all the operation in PyTorch, write some quickstart tutorials, implement codegen for TensorFlow and mxnet. I'll be interning at a prop trading firm for the next 3 months so chances are the work on TensorScript will be on pause until September.
