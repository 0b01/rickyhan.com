---
layout: post
title:  "TensorScript Type Inference: Hindley-Milner in Rust"
date:   2018-05-26 00:00:00 -0400
categories: jekyll update
---

Type inference is useful in statically and gradually typed langauges which are easier to write, maintain and refactor. However, the concept and implementation of type inference elude many. In this blog post, I will go over the type inference engine in my current project TensorScript to the dozen programmers who are interested in the obscure art of type reconstruction.

# Type Inference

In the compiler pipeline, typing happens after lexing/parsing. The goal is to produce "typed AST" where each node is tagged with a concrete type. The compiler throws otherwise(if the program is not well-typed). Type reconstruction may be further divided into type inference and type checking, although the boundary is usually blurred in practice.

# Hindley-Milner(HM)

HM is a classical type inference algorithm and can be extended in various ways to suit different needs(parametric types, lifetimes, scopes, etc.). The idea, demonstrated below, is *very* intuitive. As an example, given the following program.

```rust
if isEven(2) {
    a
} else {
    b
}
```

We can infer the following:

1. `is_even` returns a boolean value
2. `a` and `b` have the same type

Constraint solver algorithm such as HM uses a 3-step process to figure out the above:

1. Annotate with "dummy" types known as *type variables*
2. Collect constraint set
3. Unify(solve) constraints

Concretely, for the above example, first annotate the variables with integer placeholders.

```
if is_even(2: '0) { a: '1 } else { b: '2 }
    where is_even: '3 -> '4
```

The second pass is constraint collection. Based on context, we can make assumptions about the program. The idea is similar to system of equations: `'0` is integer, return type of `'4` is bool, `'1` and `'2` must be the same type:

```
'0 = int
'0 = '3
'1 = '2
'4 = bool
```

Given the system of equivalences, we can now unify the constraints, which is similar to gauss-jordan elimination to rref the types. The algorithm behaves like this: take the head of the constraint set, if it's solved(type var = concrete type, e.g. `'0 = bool`), replace every occurence of the type variable in the tail. So the unifier yields a set of substitutions that maps type variables to concrete types.

```
'4 -> bool
'0 -> int
'3 -> int
```

And finally, we can take the substitution set, replace the type variables in the annotated AST and get a concretely typed AST.

# Code sample

The function `unify` looks for 1 substitution with the head of the constraint set and applies the substitution to the tail of the constraint set.

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

The function `unify_one` pattern matches against types.

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

The `Substitution` struct is just a wrapper around a map.

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

TensorScript brings static types to ML(Machine Learning, not the language) which is dominated by Python. I believe neural network is an important application and warrants its own DSL - rationale is explained in a previous blog post. The gist is tensor shapes are checked during compile time.

If you have used Java, C# or any other languages that support generic programming, you've seen `Vec<T>` where `T` can be `int`, `complex`, or `Vec<T>` etc. Now what if `T` is a number? `Vec<3>` is a vector that contains 3 elements. In modern C++, array takes a number as type parameter(`array<int,3> myarray {10,20,30};`). The consequence is that there is no intermediate states - everything has to be immutably initialized and vector length stays the same in static lifetime. This model fits nicely with neural networks. For ML(Machine Learning), where tensor(and tensor operation) is the core abstration, dependent types(or dimensioned types) are immensely useful.

To add type level computation over tensor dimensions, I simply modified generic HM algorithm. For every Op(convolution, relu, etc..), information(such as the input and ouput shapes, initialization of the op) is supplied to a resolver. Now two things may occur: 

1. the resolver returns the type. If enough information is supplied to make out the Op type
2. return None. Say, when input type is a type variable

The modified HM runs many times on the AST, each time typing a little bit more as type information "flows" to the ops and the AST gets resolved gradually. The annotate-collect-unify-replace loop breaks when the AST anneals(stops changing) to borrow a term from integer programming.

As an example of the resolver, Here is `maxpool2d`.

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
            }
            _ => None
        }
    }
}
```

# Type Environment (and Scoping)

As mentioned above, type variables are just numbers. Type environment(denoted as the uppercase gamma(Γ) in PL literature, ![](https://wikimedia.org/api/rest_v1/media/math/render/svg/4c96ef28327313f53f6deb407cd795c885e4be57)), among other things, keeps track of type variable counter, variables and corresponding types in different scopes. In my use case, during the annotation stage, when entering a new scope, a new `Scope` is pushed onto a stack, and when leaving a scope, the popped scope is "recycled" into a queue. This way, during the constraint collection stage, the scopes environments are reused.

```rust
/// Represents a single level of scope
pub struct Scope {
    /// type information of aliases
    types: BTreeMap<Alias, Type>,
}
type ScopeStack = VecDeque<Scope>;
type ScopeQueue = VecDeque<Scope>;
pub struct TypeEnv {
    counter: TypeId,
    current_mod: ModName,
    modules: BTreeMap<ModName, (ScopeStack, ScopeQueue, InitMap)>,
}
impl TypeEnv {
    // ...omitted...
    /// push scope onto stack
    pub fn push_scope(&mut self, mod_name: &ModName) {
        let stack = self.modules.get_mut(mod_name).unwrap();
        stack.0.push_back(Scope::new());
    }
    /// push the popped scopes into queue
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

# Development update

Recently, I got sidetracked and decided to lift the type level computation to language level (or at least proc macro level) to no avail. In the future, I want to:

1. support most PyTorch operations

2. write quickstart tutorials

3. implement codegen for TensorFlow and mxnet

However, I am interning at a prop trading shop this summer so chances are tensorscript development will slow down(to a halt?) and will pick up pace this coming September.

# Conclusion

[This video](https://www.youtube.com/watch?v=oPVTNxiMcSU) goes over concepts and implements a type inference engine for a reduced set of ML in Scala. Very helpful! Highly recommend!

In this blog post, I demonstrated how to write a type inference engine for a langauge. If you find this post useful, consider subscribing to my mailing list!
