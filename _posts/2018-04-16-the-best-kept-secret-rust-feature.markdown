---
layout: post
title:  "Pretty Printer: A Useful Feature Few Rust Programmers Know About"
date:   2018-04-16 00:00:00 -0400
categories: jekyll update
---

Surprisingly few know about the built-in pretty-printer. In the book, there is only a [short passage](https://doc.rust-lang.org/book/second-edition/ch05-02-example-structs.html) that mentions `{:#?}` in passing.

It aligns structs and enums based on nested positions and is automatically derived with `Debug`. Recently, I'm working with some custom AST. Here is the print out for `println("{:#?}", typed_ast)`:

```rust
TyProgram(
    [
        TyUseStmt(
            TyUseStmt {
                mod_name: "conv",
                imported_names: [
                    "Conv2d",
                    "Dropout2d",
                    "maxpool2d"
                ]
            }
        ),
        TyUseStmt(
            TyUseStmt {
                mod_name: "nonlin",
                imported_names: [
                    "relu"
                ]
            }
        ),
        TyUseStmt(
            TyUseStmt {
                mod_name: "lin",
                imported_names: [
                    "Linear"
                ]
            }
        ),
        TyNodeDecl(
            TyNodeDecl {
                name: "Mnist",
                ty_sig: ([!6, !7, !8, !9] -> [!6, <10>])
            }
        ),
        TyWeightsDecl(
            TyWeightsDecl {
                name: "Mnist",
                ty_sig: ([!6, !7, !8, !9] -> [!6, <10>]),
                inits: [
                    TyWeightsAssign {
                        name: "conv1",
                        ty: '11,
                        mod_name: "Conv2d",
                        fn_ty: '10,
                        fn_name: "new",
                        fn_args: [
                            TyFnAppArg {
                                name: "in_ch",
                                arg: TyExpr {
                                    items: TyInteger(
                                        '12,
                                        1
                                    ),
                                    ty: '13
                                }
                            },
                            TyFnAppArg {
                                name: "out_ch",
                                arg: TyExpr {
                                    items: TyInteger(
                                        '14,
                                        10
                                    ),
                                    ty: '15
                                }
                            },
                            TyFnAppArg {
                                name: "kernel_size",
                                arg: TyExpr {
                                    items: TyInteger(
                                        '16,
                                        5
                                    ),
                                    ty: '17
                                }
                            }
                        ]
                    },
                    TyWeightsAssign {
                        name: "conv2",
                        ty: '19,
                        mod_name: "Conv2d",
                        fn_ty: '18,
                        fn_name: "new",
                        fn_args: [
                            TyFnAppArg {
                                name: "in_ch",
                                arg: TyExpr {
                                    items: TyInteger(
                                        '20,
                                        10
                                    ),
                                    ty: '21
                                }
                            },
                            TyFnAppArg {
                                name: "out_ch",
                                arg: TyExpr {
                                    items: TyInteger(
                                        '22,
                                        20
                                    ),
                                    ty: '23
                                }
                            },
                            TyFnAppArg {
                                name: "kernel_size",
                                arg: TyExpr {
                                    items: TyInteger(
                                        '24,
                                        5
                                    ),
                                    ty: '25
                                }
                            }
                        ]
                    },
                    TyWeightsAssign {
                        name: "dropout",
                        ty: '27,
                        mod_name: "Dropout2d",
                        fn_ty: '26,
                        fn_name: "new",
                        fn_args: [
                            TyFnAppArg {
                                name: "p",
                                arg: TyExpr {
                                    items: TyFloat(
                                        '28,
                                        0.5
                                    ),
                                    ty: '29
                                }
                            }
                        ]
                    },
                    TyWeightsAssign {
                        name: "fc1",
                        ty: '31,
                        mod_name: "Linear",
                        fn_ty: '30,
                        fn_name: "new",
                        fn_args: []
                    },
                    TyWeightsAssign {
                        name: "fc2",
                        ty: '33,
                        mod_name: "Linear",
                        fn_ty: '32,
                        fn_name: "new",
                        fn_args: []
                    }
                ]
            }
        ),
        TyGraphDecl(
            TyGraphDecl {
                name: "Mnist",
                ty_sig: ([!6, !7, !8, !9] -> [!6, <10>]),
                fns: [
                    TyFnDecl {
                        name: "new",
                        fn_params: [],
                        fn_ty: '34,
                        param_ty: '35,
                        return_ty: ([!6, !7, !8, !9] -> [!6, <10>]),
                        func_block: TyBlock {
                            stmts: TyList(
                                [
                                    TyStmt {
                                        items: TyList(
                                            [
                                                TyExpr {
                                                    items: TyFnApp(
                                                        TyFnApp {
                                                            mod_name: Some(
                                                                "fc1"
                                                            ),
                                                            name: "init_normal",
                                                            args: [
                                                                TyFnAppArg {
                                                                    name: "std",
                                                                    arg: TyExpr {
                                                                        items: TyFloat(
                                                                            '36,
                                                                            1.0
                                                                        ),
                                                                        ty: '37
                                                                    }
                                                                }
                                                            ],
                                                            ret_ty: '38
                                                        }
                                                    ),
                                                    ty: '39
                                                }
                                            ]
                                        )
                                    },
                                    TyStmt {
                                        items: TyList(
                                            [
                                                TyExpr {
                                                    items: TyFnApp(
                                                        TyFnApp {
                                                            mod_name: Some(
                                                                "fc2"
                                                            ),
                                                            name: "init_normal",
                                                            args: [
                                                                TyFnAppArg {
                                                                    name: "std",
                                                                    arg: TyExpr {
                                                                        items: TyFloat(
                                                                            '40,
                                                                            1.0
                                                                        ),
                                                                        ty: '41
                                                                    }
                                                                }
                                                            ],
                                                            ret_ty: '42
                                                        }
                                                    ),
                                                    ty: '43
                                                }
                                            ]
                                        )
                                    }
                                ]
                            ),
                            ret: TyExpr {
                                items: TyIdent(
                                    ([!6, !7, !8, !9] -> [!6, <10>]),
                                    "self"
                                ),
                                ty: '44
                            }
                        }
                    },
                    TyFnDecl {
                        name: "forward",
                        fn_params: [
                            TyFnDeclParam {
                                name: "b",
                                ty_sig: [!6, !7, !8, !9]
                            }
                        ],
                        fn_ty: '46,
                        param_ty: '47,
                        return_ty: [!6, <10>],
                        func_block: TyBlock {
                            stmts: TyList(
                                []
                            ),
                            ret: TyExpr {
                                items: TyFnApp(
                                    TyFnApp {
                                        mod_name: None,
                                        name: "log_softmax",
                                        args: [
                                            TyFnAppArg {
                                                name: "x",
                                                arg: TyFnApp(
                                                    TyFnApp {
                                                        mod_name: Some(
                                                            "self"
                                                        ),
                                                        name: "fc2",
                                                        args: [
                                                            TyFnAppArg {
                                                                name: "x",
                                                                arg: TyFnApp(
                                                                    TyFnApp {
                                                                        mod_name: None,
                                                                        name: "relu",
                                                                        args: [
                                                                            TyFnAppArg {
                                                                                name: "x",
                                                                                arg: TyFnApp(
                                                                                    TyFnApp {
                                                                                        mod_name: None,
                                                                                        name: "fc1",
                                                                                        args: [
                                                                                            TyFnAppArg {
                                                                                                name: "x",
                                                                                                arg: TyViewFn(
                                                                                                    TyViewFn {
                                                                                                        ty: [!6, <320>],
                                                                                                        arg: TyFnAppArg {
                                                                                                            name: "x",
                                                                                                            arg: TyFnApp(
                                                                                                                TyFnApp {
                                                                                                                    mod_name: None,
                                                                                                                    name: "maxpool2d",
                                                                                                                    args: [
                                                                                                                        TyFnAppArg {
                                                                                                                            name: "x",
                                                                                                                            arg: TyFnApp(
                                                                                                                                TyFnApp {
                                                                                                                                    mod_name: None,
                                                                                                                                    name: "dropout",
                                                                                                                                    args: [
                                                                                                                                        TyFnAppArg {
                                                                                                                                            name: "x",
                                                                                                                                            arg: TyFnApp(
                                                                                                                                                TyFnApp {
                                                                                                                                                    mod_name: None,
                                                                                                                                                    name: "conv2",
                                                                                                                                                    args: [
                                                                                                                                                        TyFnAppArg {
                                                                                                                                                            name: "x",
                                                                                                                                                            arg: TyFnApp(
                                                                                                                                                                TyFnApp {
                                                                                                                                                                    mod_name: None,
                                                                                                                                                                    name: "maxpool2d",
                                                                                                                                                                    args: [
                                                                                                                                                                        TyFnAppArg {
                                                                                                                                                                            name: "x",
                                                                                                                                                                            arg: TyFnApp(
                                                                                                                                                                                TyFnApp {
                                                                                                                                                                                    mod_name: None,
                                                                                                                                                                                    name: "conv1",
                                                                                                                                                                                    args: [
                                                                                                                                                                                        TyFnAppArg {
                                                                                                                                                                                            name: "x",
                                                                                                                                                                                            arg: TyIdent(
                                                                                                                                                                                                '45,
                                                                                                                                                                                                "b"
                                                                                                                                                                                            )
                                                                                                                                                                                        }
                                                                                                                                                                                    ],
                                                                                                                                                                                    ret_ty: '48
                                                                                                                                                                                }
                                                                                                                                                                            )
                                                                                                                                                                        },
                                                                                                                                                                        TyFnAppArg {
                                                                                                                                                                            name: "kernel_size",
                                                                                                                                                                            arg: TyExpr {
                                                                                                                                                                                items: TyInteger(
                                                                                                                                                                                    '49,
                                                                                                                                                                                    2
                                                                                                                                                                                ),
                                                                                                                                                                                ty: '50
                                                                                                                                                                            }
                                                                                                                                                                        }
                                                                                                                                                                    ],
                                                                                                                                                                    ret_ty: '51
                                                                                                                                                                }
                                                                                                                                                            )
                                                                                                                                                        }
                                                                                                                                                    ],
                                                                                                                                                    ret_ty: '52
                                                                                                                                                }
                                                                                                                                            )
                                                                                                                                        }
                                                                                                                                    ],
                                                                                                                                    ret_ty: '53
                                                                                                                                }
                                                                                                                            )
                                                                                                                        },
                                                                                                                        TyFnAppArg {
                                                                                                                            name: "kernel_size",
                                                                                                                            arg: TyExpr {
                                                                                                                                items: TyInteger(
                                                                                                                                    '54,
                                                                                                                                    2
                                                                                                                                ),
                                                                                                                                ty: '55
                                                                                                                            }
                                                                                                                        }
                                                                                                                    ],
                                                                                                                    ret_ty: '56
                                                                                                                }
                                                                                                            )
                                                                                                        }
                                                                                                    }
                                                                                                )
                                                                                            }
                                                                                        ],
                                                                                        ret_ty: '57
                                                                                    }
                                                                                )
                                                                            }
                                                                        ],
                                                                        ret_ty: '58
                                                                    }
                                                                )
                                                            }
                                                        ],
                                                        ret_ty: '59
                                                    }
                                                )
                                            },
                                            TyFnAppArg {
                                                name: "dim",
                                                arg: TyExpr {
                                                    items: TyInteger(
                                                        '60,
                                                        1
                                                    ),
                                                    ty: '61
                                                }
                                            }
                                        ],
                                        ret_ty: '62
                                    }
                                ),
                                ty: '63
                            }
                        }
                    },
                    TyFnDecl {
                        name: "fc2",
                        fn_params: [
                            TyFnDeclParam {
                                name: "x",
                                ty_sig: '64
                            }
                        ],
                        fn_ty: '65,
                        param_ty: '66,
                        return_ty: [!6, <10>],
                        func_block: TyBlock {
                            stmts: TyList(
                                []
                            ),
                            ret: TyExpr {
                                items: TyFnApp(
                                    TyFnApp {
                                        mod_name: None,
                                        name: "relu",
                                        args: [
                                            TyFnAppArg {
                                                name: "x",
                                                arg: TyFnApp(
                                                    TyFnApp {
                                                        mod_name: None,
                                                        name: "fc2",
                                                        args: [
                                                            TyFnAppArg {
                                                                name: "x",
                                                                arg: TyIdent(
                                                                    '64,
                                                                    "x"
                                                                )
                                                            }
                                                        ],
                                                        ret_ty: '67
                                                    }
                                                )
                                            }
                                        ],
                                        ret_ty: '68
                                    }
                                ),
                                ty: '69
                            }
                        }
                    },
                    TyFnDecl {
                        name: "test",
                        fn_params: [
                            TyFnDeclParam {
                                name: "x",
                                ty_sig: '70
                            }
                        ],
                        fn_ty: '71,
                        param_ty: '72,
                        return_ty: [],
                        func_block: TyBlock {
                            stmts: TyList(
                                []
                            ),
                            ret: TyExpr {
                                items: TyFnApp(
                                    TyFnApp {
                                        mod_name: None,
                                        name: "relu",
                                        args: [
                                            TyFnAppArg {
                                                name: "x",
                                                arg: TyFnApp(
                                                    TyFnApp {
                                                        mod_name: None,
                                                        name: "fc2",
                                                        args: [
                                                            TyFnAppArg {
                                                                name: "x",
                                                                arg: TyIdent(
                                                                    '70,
                                                                    "x"
                                                                )
                                                            }
                                                        ],
                                                        ret_ty: '73
                                                    }
                                                )
                                            }
                                        ],
                                        ret_ty: '74
                                    }
                                ),
                                ty: '75
                            }
                        }
                    }
                ]
            }
        )
    ]
)
```

Also, it is not mutually exclusive with `impl Debug` for individual components, for example:

```rust
impl Debug for Type {
    fn fmt(&self, f: &mut Formatter) -> Result<(), Error> {
        use self::Type::*;
        match self {
            Unit => write!(f, "()"),
            INT => write!(f, "int"),
            BOOL => write!(f, "bool"),
            VAR(ref t_id) => write!(f, "'{:?}", t_id),
            DIM(ref t_id) => write!(f, "!{:?}", t_id),
            ResolvedDim(ref d) => write!(f, "<{}>", d),
            FUN(ref p, ref r) => write!(f, "({:?} -> {:?})", p, r),
            TSR(ref dims) => {
                if dims.len() > 0 {
                    write!(f, "[")?;
                    for i in dims[0..dims.len() - 1].iter() {
                        write!(f, "{:?}, ", i)?;
                    }
                    write!(f, "{:?}]", dims[dims.len() - 1])
                } else {
                    write!(f, "[]")
                }
            }
        }
    }
}
```

# Conclusion

In this click bait article, I introduced the pretty printer flag that few Rust programmers know about.
