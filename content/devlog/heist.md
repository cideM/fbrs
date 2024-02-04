+++
title = "Revisiting Haskell"
date = "2023-08-29"
[taxonomies]
tags=["haskell"]
+++

A while ago I wrote a [blog post](@/fp.md) that summarized my experiences with Haskell, Nix and Purescript. The bottom line is that I wasn't too happy with the mix of technologies since it added a lot of complexity for very little gain.

Now I'd like to revisit this project and make a few changes, while always striving to one, overarching goal: make it simpler (not easier).

Here's my todo list:

- separate views from code; I don't like writing HTML in a DSL implemented in a powerful programming language
- get rid of bootstrap
- remove as much client side Javascript as possible
- remove the ReaderT pattern
- write a QEMU integration (or black box) text

I also want to experiment with keeping a journal that captures the raw and unfiltered experience of revisiting Haskell with these goals in mind. I've never done anything like this before and I don't really know what I'd like to achieve with it. It's probably equal parts a motivation aid for myself and maybe a helpful resource for other beginner Haskellers who feel like everyone else is a PhD wielding type theory wizard.

The first step will be to setup a little prototype in a separate repository where I can experiment with [Heist](http://snapframework.com/docs/tutorials/heist), the templating engine used in [Snap](http://snapframework.com/docs/)

