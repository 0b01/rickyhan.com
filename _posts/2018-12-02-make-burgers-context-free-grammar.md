---
layout: post
title:  "CFG Game"
date:   2018-12-03 00:37:02 -0400
# menu: main
categories: jekyll update
---

Put your CS skills to good use and craft burgers.

<iframe src="/static/mcrecursion/index.html" style="border:0px #ffffff none;" name="myiFrame" scrolling="no" frameborder="1" marginheight="0px" marginwidth="0px" height="600px" width="800px" allowfullscreen></iframe>

This past weekend I made a game for Ludum Dare 43. Tools used: [Aseprite](http://aseprite.org), [quicksilver](https://github.com/ryanisaacg/quicksilver). Inspired by Zachtronics.

It is written in Rust and compiled to WebAssembly. Checkout the [source code](https://github.com/rickyhan/dyn-grammar).

# How the game is implemented

The core of the game is a pretty standard LL(1) parser whose grammar is defined dynamically in game by player.

```rust
type RuleID = usize;

struct Grammar<T: Debug + Clone + PartialEq + Hash + Eq> {
    start: String,
    rules: Vec<Rule<T>>,
    first_sets: Option<HashMap<String, HashSet<(Token<T>, Rule<T>)>>>,
}

struct Rule<T: Debug + Clone + PartialEq + Hash + Eq> {
    name: String,
    id: RuleID,
    production: Vec<Token<T>>,
}

enum Token<T: Debug + Clone + PartialEq + Hash + Eq> {
    Terminal(T),
    Epsilon,
    NonTerminal(String),
}
```

Note the rule has an `id` field so the the parse result is traceable, i.e. which paths the parser took.

```rust
enum AbstractBurgerTree<T: Debug + Clone + PartialEq + Hash + Eq> {
    NonTerm((RuleID, Vec<Box<AbstractBurgerTree<T>>>)),
    Term(Token<T>),
    /// errors:
    IncompleteParse,
    WrongToken,
    Cyclic,
    AdditionalTokens(Box<AbstractBurgerTree<T>>),
}
```

The parser errors are also valid AST elements.

Next, there are two helper functions that operates on the AST:

1. `fn to_burger()` converts the parse tree, which may or may not include errors, back into a burger.

```rust
pub fn to_burger(&self) -> Burger {
    let mut bg = Burger::new();
    bg.toks = self.to_burger_aux();
    bg
}

fn to_burger_aux(&self) -> Vec<Token<BurgerItem>> {
    use self::AbstractBurgerTree::*;
    let mut ret = vec![];
    match &self {
        Term(Token::Epsilon) => { }
        Term(t) => { ret.push(t.clone()); }
        NonTerm((_,t)) => {
            for i in t.iter() {
                ret.extend(i.to_burger_aux());
            }
        }
        AdditionalTokens(i) => { ret.extend(i.to_burger_aux()); }
        _ => (), // all the errors are ignored
    }
    ret
}
```

2. `fn to_delta_seq()` converts an AST into an sequence of animations ...

```rust
fn to_delta_seq(&self) -> Vec<AnimDelta> {
    use self::AbstractBurgerTree::*;
    let mut ret = vec![];
    match self {
        Term(Token::Epsilon) => {
            ret.push(AnimDelta::Noop);
        }
        Term(Token::Terminal(_t)) => {
            ret.push(AnimDelta::Incr);
            ret.push(AnimDelta::StepAnim);
        }
        Term(Token::NonTerminal(_)) => panic!("Impossible"),
        NonTerm(t) => {
            ret.push(AnimDelta::Incr);
            ret.push(AnimDelta::EnterPtr(t.0));
            for i in &t.1 {
                ret.extend(i.to_delta_seq());
            }
            ret.push(AnimDelta::ExitPtr(t.0));
        }
        IncompleteParse | WrongToken | Cyclic => {
            ret.push(AnimDelta::PauseIndefinitely);
        }
        AdditionalTokens(i) => {
            ret.extend(i.to_delta_seq());
            ret.push(AnimDelta::PauseIndefinitely);
        }
    }
    ret
  }
```

which are then dispatched by the main game state.

Everything else(~1400 loc) is game UI which is pretty tedious to write. I've never written a game before so it took several refactors.