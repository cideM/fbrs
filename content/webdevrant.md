+++
title = "Clojure or Haskell for Web Dev? Neither"
date = "2021-03-21"
[taxonomies]
tags=["rant", "clojure", "haskell"]
+++

_I'm writing this in anger, you've been warned_

About a year ago or so I created a small website for a family member. It consists of a static site and a members area. The content for the static site is managed through Contentful, a CMS. The static site came first, and I used Gatsby for that. The members area came next and I decided to use Gatsby for that as well, and hack it into the same codebase. It works and people are happy with the site, but it's a mess. I threw this stuff together over the course of a few weekends and it's extremely flimsy and untested Javascript. I also can't upgrade the site because a JS project that wasn't updated for a more than 6 months is usually 10 major versions behind and any upgrade will break half your code.

Fast forward to 2021 and after having had a lot of fun with Haskell in Advent of Code I decided it was time for a rewrite. I would separate the static site from the members area and write both with simplicity in mind. Get rid of Firebase and instead host the entire thing on a Digital Ocean droplet.

The first attempt was a textbook Haskell web app. It used the ReaderT pattern and type classes as a functional way of doing dependency injection ([this](https://thomashoneyman.com/guides/real-world-halogen/push-effects-to-the-edges/) is a great guide for FP dependency inversion). It was nice at first but I quickly lost interest because it was a crazy amount of overengineering. The boilerplate required to implement all these fancy patterns doubled the size of the code base.

I don't know why, but for some reason I then implemented another version in Clojure! I have very little Clojure experience and even less ecosystem chops. So I just searched for "how to web app Clojure" and went with Reitit (routing) and Hiccup (HTML templating). I quickly realized that many of the Ring middlewares I knew weren't really compatible with Reitit. After perusing some open issues and pull requests I ended up porting a whole bunch of Ring middlewares to Reitit, but never bothered with creating any PRs for them (yet?).

At first Clojure felt great! It's ecosystem is much stronger than Haskells and the REPL driven development was super cool. But as the code base grew my REPL was out of sync more often. Basically your REPL still has an old version of a function in memory and now your code does weird things. Restarting the REPL is slow though, so I added Integrant to the code base. Problem solved, yay! But it feels weird to add a significant amount of code that is only relevant for development. The things you do for REPLs.

The coolest part about REPL driven development is that you can interactively discover dependencies and that you can use your actual productoin code to talk to the database! Want to know insert some dummy data? Just fire up the Integrant system and run your normal DB functions to get and set data. All of my namespaces had `(comment)` expressions that I used for quick feedback during development.

So where's the but? I can't stand dynamic languages anymore it seems. Everytime I made a sweeping refactor things were horribly broken. I'm too lazy to be my own linter and compiler. I don't want to write thousands of unit tests for every little function. Figuring out null pointer exceptions is a waste of time. I have zero confidence in my Clojure code and it quickly sucked the fun out of the project.

So I went back to Haskell. This time I threw out all the fancy patterns and went back to the basics. Just Warp and no fancy extensions. At first it was exhilarating! But then the usual Haskell fatigue started to creep in again. First Blaze (HTML templating) was missing some attributes. No problem, I can just create a PR. But then I need to figure out how to use that in my Nix setup and so on. So I switched to Lucid, which exposes some of its internal functions, and thanks to that I can create the missing attribute on the fly.

I guess now is a great time to rant about HTML templating. I hate all of it. I don't want to learn yet another DSL for generating the same HTML. And you know what? All of them lack typical utility stuff. Want to conditionally apply CSS classes? I couldn't find any info about this in three templating libraries in two languages (Hiccup, Blaze, Lucid). Sure, it's not rocket science, but spending even one hour trying to figure out a basic and ergonomic way of doing that is an hour I shouldn't have to invest. People have been generating HTML for how long now? 

But I haven't even talked about the elephant in the room: form validation. Small CRUD projects are basically 40% boilerplate (setting up migrations, database, deployment, CSS library, and so on), 80% form data validation and 30% asking yourself why you do this. You have input fields, they have rules, users then need to see localized error messages. It's been like that since roughly 1872 when the first settlers arrived on the moon, but we're still struggling with this. At least I am. Maybe I'm just stupid? What a sad thought.

Clojure has what appears to be one of the nicest libraries in this space, Malli. I was able to very quickly get the kind of validation I want and the system seems like it can handle everything without crazy contortions. The holy grail is obviously ~~some irrelevant type safety shenanigans~~ one field's validation depending on another field. And it does that and it's even mentioned in the docs.

But that still requires me to then somehow connect the validation results to my bespoke CSS class solution.

Let's talk about something else though: databases. I'm a full stack developer and I've been doing backend development for the past two years but I really don't like databases. For a small project key value stores seem kinda great. Simplicity of a single file but the freedom of a schema on read, rather than write. Seemed like a good idea! But how do you get data into the DB for development purposes? How do you inspect it? In Clojure it's easy, just write Clojure code using all the libraries you want and use them from the REPL. But in Haskell? Are you going to litter your production code with special functions just for interacting with LMDB? Then run them from a GHCI session?

SQLite doesn't look so bad now, does it? Alright, let's replace the key value store with a relational database. Now you need to think about migrations. Will you just write idempotent SQL queries and run them at startup? Or a proper migration system? Fun fact: `dbmigrations-sqlite` is marked as broken in Nixpkgs. Nothing new, I've already fixed such things in the past, but it's yet another little obstacle. Death by a thousand cuts. Maybe I'll just use the Go migrate package to run migrations throught the CLI. At least it works.

Ultimately, I'm just an idiot when it comes to personal projects like this. I'm bored by mainstream, batteries included frameworks and yet I then complain about not having Django level nice stuff to play with. Clojure has an amazing REPL driven flow unless that REPL is working against you. Its dynamic nature often brings me to the brink of insanity. Haskell has this amazing type system which let's me focus on the application rather than such menial details as is this variable a string or not. But it also has the ecosystem power of a complicated niche language, meaning none.

I want a minimalistic language with an amazing type system that people use for pragmatic libraries to solve real world problems. Bonus points for functional programming.



