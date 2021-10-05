+++
title = "Building A Website With Haskell And Nix"
date = "2021-09-23"
[taxonomies]
tags=["haskell", "nix", "purescript"]
+++

## Introduction

I built a website so trivial that you might wonder why I even bother writing
about it. It consists of a static site which is, unfortunately, still built
with Gatsby, a Javascript framework. The content comes from a content
management system called Contentful. The most complex part is the members-only
area, which is the part I rebuilt and what this post is all about. The first
version was hacked together with Firebase and some serverless functions,
because I didn't want to maintain a proper backend. The UI was awkwardly fit
into the static site. It worked but it was ugly.

And so one day I decided that it was time for a rewrite! The official reason is
that I considered it too risky to depend on Firebase for everything. Also the
local developer experience was a bit lacking at that time. The honest answer is
that, for quite a long time, I had been looking for a project that is small but
not too small, has some semblance of a deadline, and actual users. Something
that's close to what I do for a living as a web developer. Except that I would
throw the full force of functional programming (FP) at that project. And so the idea
was born to rewrite the entire website with Haskell, Nix and PureScript.
Essentially I had an FP-shaped hammer and was looking for a nail.

The project is something I did for a family member, so no money was involved.
And I had a lot of freedom when it came to what features would get built. But
since I'm unlikely to work professionally with functional programming
technologies in the short and medium term future, it was as close to a real
world project as it would get.

In this post I want to share my experiences building this simple backend in
Haskell, Nix and PureScript. You don't need to know any of these technologies
to follow the blog post. You might not understand every little detail, but I
hope that the overall message is still valuable. I'll also start the post with
a short summary, so you don't have to read the entire article if you just want
the main conclusions.

## Summary

### Haskell

I'm neutral about using Haskell again in the future.

On the one hand, algebraic data types and an excellent type system make it very
easy to translate my thoughts into code, since branching control flow, based on
a finite number of options, seems to make up the majority of my coding. It's
kind of liberating to make sweeping changes across the code base, knowing that
the compiler will prevent a lot of mistakes. Haskell also has a surprisingly
large selection of web development frameworks and libraries. I didn't have to
implement any mission critical functionality myself (encryption, database
communication, routing, and so on).

On the other hand, one of the biggest time sinks was mere plumbing. Many
Haskell libraries invent little domain specific languages (DSL), and
translating between them turned out to be really tedious.

Haskell also has its fair share of historical baggage, which includes, but is
not limited to, an annoying module system, complicated tooling, and a rather
anemic standard library. The last point means you'll have way too many lines of
code dedicated to imports.

### Nix

I would 100% use Nix again to provide a basic developer environment, which
includes compilers, formatters, database libraries, and so on. It is, in my
opinion, best in class in this area and entirely unrivalled. Think `nix develop`.

Whether or not I'd use it to build the actual project depends on the
programming language and how well supported it is in Nix. Haskell is the Nix
posterchild, Node on the other hand can be hit and miss.

I would not use Nix again to deploy my code. It was fun playing around with
Systemd and SOPS, but the container ecosystem is just too big. Luckily you can
generate Docker containers with nix, which is something I'd like to explore in
the future. Running my NixOS image locally through QEMU was and still is,
frustrating, especially on MacOS.

### SQLite

Yes, yes, yes! I love SQLite. It has quirks and historical baggage but at the
end of the day it's a robust, battle tested and simple tool that I find to be a
joy to use. You can easily spin up an in-memory database for unit tests, it
comes with a surprising number of features, such as JSON tooling, and it's just
a file at the end of day. This kind of simplicity is refreshing. Also shoutout
to [Litestream](https://litestream.io/) for database backups.

### PureScript

I've written 140 lines of PureScript (PS) code in this project, which is
nothing.  It's used for progressive enhancement of markup rendered on the
server, which means inserting DOM elements and interactivity into existing DOM
nodes. Unfortunately I couldn't find any good libraries for this, so I had to
resort to writing very verbose and tedious code that looks like a one-to-one
translation from Javascript. All of the PS web frameworks and libraries I saw
want to own the markup they render, like React. So instead of surgically
injecting interactivity into existing DOM elements, you hand control over an
entire subtree of the DOM to PureScript. But that would have meant
re-implementing the rendering in PS, which seemed like too much work.

For this project PS was not a good choice, as it meant additional complexity
and an unnecessarily large bundle for little to no gain. I like the language
though.

## Deep Dive

### Haskell

Haskell the language is really not complicated. But the ecosystem can be. I
frequently found myself spending too much time solving problems that only exist
in Haskell. These problems are usually the result of having to combine DSLs
from different libraries, something I alluded to already in the summary.  For
example, I struggled
[quite](https://www.reddit.com/r/haskell/comments/jyzc3w/how_to_avoid_infinite_type_when_lifting/)
a bit with logging, which has only ever happened once before, in Clojure, where
logging is [the final
frontier](https://lambdaisland.com/blog/2020-06-12-logging-in-clojure-making-sense-of-the-mess).
But let me explain in a bit more detail why logging can be surprisingly tricky
and what I mean by DSL.

Here's a snippet from the README of [scotty](https://hackage.haskell.org/package/scotty), a well known web framework:

```haskell
main = scotty 3000 $
  get "/:word" $ do
    beam <- param "word"
    html $ mconcat ["<h1>Scotty, ", beam, " me up!</h1>"]
```

It doesn't matter if you know Haskell or not. I'd like to direct your attention
at `param "word"`, or, applying the function `param` to the string `"word"`.
Maybe you can guess that this extracts the value of the route parameter we
defined in the preceding line, with `"/:word"`. But isn't it weird that we're
not also passing the HTTP request to the `param` function? Where does it get
the _request_ paramter from, then?  The answer is too complicated for this blog
post, but suffice it to say that there's some magic going on behind the scenes.
And this magic is made possible by the Scotty DSL!

Now, what if you want to also do some logging in your HTTP handlers? There's a
really nice library called
[katip](https://hackage.haskell.org/package/katip-0.8.5.0), and it also has
this very neat but also weird looking code:

```haskell
main :: IO ()
main = do
  -- ellided for brevity
  katipAddNamespace "additional_namespace" $ katipAddContext (sl "some_context" True) $ do
    $(logTM) WarningS "Now we're getting fancy"
  katipNoLogging $ do
    $(logTM) DebugS "You will never see this!"
```

The `katipAddNamespace` function does the same thing as any other structured,
hierarchical logging framework. Any log expressions in the indentend block of
code on the following lines will have this new namespace added to them. This
way the caller can add some additional context to the logger and the callee
doesn't need to know or care about these things. As a proponent of structured,
hierarchical logging, I find this super neat. But, unlike in Go, where you'd do
something like

```go
newLogger := oldLogger.With("key", "value")
newLogger.Info("whatever")
```

the `newLogger` variable is nowhere to be seen. You might at first glance think
that we're passing an anonymous function to `katipAddNamespace` (the `$ do`
part maybe?), but even if that were the case, we're clearly not accepting any
arguments in that anonymous function. So what happens to the modified logger?
Well, the answer is, it's complicated. Just like with Scotty, there's a DSL
that takes care of all this plumbing for us behind the scenes.

If the stars align, these DSLs allow you write very concise and expressive code
that's also type safe, because Haskell. But getting different DSLs to agree
with each other can also be the source of great frustration. If you want to do
logging in the HTTP handler and maybe also make use of another DSL for
propagating application configuration (`ReaderT` pattern for those Haskellers)
and yet another for inversion-of-control
([capability](https://github.com/tweag/capability)[^1] or just use `mtl` for
that too) then you need to write some non-trivial plumbing code for that. [Half
of this
file](https://github.com/cideM/lions-backend/blob/c97365af6b44ef122f1df45e66dc7ded870b4a18/backend/src/Wai.hs)
and [the entirety of this
file](https://github.com/cideM/lions-backend/blob/c97365af6b44ef122f1df45e66dc7ded870b4a18/backend/src/Error.hs)
in my application exist only to translate between different DSLs. And that's on
top of the various libraries out there that already try to help with that task.
[Here I asked a question on
Reddit](https://www.reddit.com/r/haskell/comments/krke1o/how_to_create_colog_instance_for_scotty/)
about this very problem, and also asked on [StackOverflow
(SO)](https://stackoverflow.com/questions/65599741/how-to-make-co-logs-withlog-work-with-scotty),
where someone suggested the following, untested code:

```haskell
data AppEnv = AppEnv
  { appLogAction :: LogAction App Message
  , actLogAction :: LogAction (ActionT TL.Text App) Message
  }

instance HasLog AppEnv Message App where
  getLogAction = appLogAction
  setLogAction newact env = env { appLogAction = newact }

instance HasLog AppEnv Message (ActionT TL.Text App) where
  getLogAction = actLogAction
  setLogAction newact env = env { actLogAction = newact }
```

The snippet tries to mediate between a custom DSL for my application
configuration and the `co-log` logging library. One of the `co-log` maintainers
was nice enough to help with this, after I created an issue on GitHub. [Their
solution](https://github.com/cideM/co_log_issue/pull/1/files) is pretty
straight foward, but I wasn't too happy with it, since it creates some coupling
between my application environment and the logging. I'm sure there are even
better solutions that I'm just not aware of, but the lengths I went through to
introduce this logging library into my application is something I never
encountered, might not even have thought possible, in many other language
ecosystems.

Many libraries in the Haskell ecosystem advertise two different aspects:
expressiveness and type safety. In my **personal experience**, the first is
highly overrated, the second is what you actually want.

Aside from DSLs, there was at least one other recurring topic that made me
scratch my head, and that's how to deal with control flow and early return.

Here's what 90% of my Go code looks like:

```go
someValue, err := someFunc()
if err != nil {
  return errors.WithMessagef(err, "something went wrong with thing %s", id)
}
```

Countless people have complained about the repetitiveness and boilerplate, but
I actually don't mind it at all. The pattern is always the same, so it's very
easy for me to follow the control flow inside a function. Additionally, it's
trivial to return as early as possible. In fact, returning early is something
most people probably don't even give a second thought to, since it's just so
easy in imperative languages.

What does the above look like in Haskell then?

```haskell
case someFunc of
  Left err -> Left ([i|something went wrong with thing #{s}: #{err}|])
  Right -> -- keep going
```

I suspect that many seasoned Haskellers will take fault with the above snippet
though, because it's needlessly verbose. And I kind of agree, and I've spent
way too much time converting to and from various control flow patterns in this
project. とにかく, anyway, what's going on here? `someFunc` doesn't return a
normal value and an error, it also doesn't throw exceptions, rather it returns
a `Result` type (called `Either`). We then pattern match on the two possible
variations of this result type. `Left` if there's an error, `Right` if
everything's fine. Think [Rust's result](https://doc.rust-lang.org/std/result/)
type.

But what if you have several function calls that all return different kinds of
results? Consider the following scenario:

- Unmarshal query parameters
- Check if user is authorized
- Get entity from database
- Perform some business logic with user and database entity

Pretty much all of these things can fail in some expected way (meaning
exceptions wouldn't be appropriate).

```haskell
case param "foo" of
  Nothing -> -- return early?
  Just foo -> case isAuthorized user of
                False -> -- return early?
                True -> case talkToDatabase of
                          Nothing -> -- return early?
                          Just fooThing -> -- ...
```

You can see where I'm going with this, right? The increasing indentation level
looks ugly and it's unclear how we can actually return early since Haskell
doesn't even have a return keyword in the traditional sense. The astute reader
might even notice that the above code could not possibly compile.
`talkToDatabase` won't return a simple `Either` type, rather it will return
something more complicated -- `IO Either` -- but that's irrelevant here.

There are [some
tricks](https://www.haskellforall.com/2021/05/the-trick-to-avoid-deeply-nested-error.html)
for dealing with this, but in **my personal experience** they often don't work
in real world scenarios, where more complicated types are involved,
particularly anything with `IO`. What does work is making liberal use of syntax
sugar, combinators and mini-DSLs though.

Here's a snippet I copied verbatim from my code base, which shows what such a
DSL can look like:

```haskell
tok@Token {..} <- get value >>= E.note' (NotFound value)
ok <- User.exists tokenUserId
E.unless ok $ E.throwError (NoUser tokenUserId)
now <- liftIO $ Time.getCurrentTime
E.when (now >= tokenExpires) (E.throwError $ Expired tok)
return $ Valid tok
```

This is probably illegible to folks who are not familiar with Haskell, so here's a hopefully human readable translation.

```text
Get some value and abort with a NotFound error if it's not there
Unless the user exists, abort with a NoUser error
Get the current time
When the current time is greater than the token expiration, abort
Return a valid token
```

This version of the Haskell snippet doesn't suffer from increasing indentation.
We also return early since behind the scenes Haskell still sort of pattern
matches on the various result types and it knows how it can short-circuit the
computation. For example, if `ok` is false, this will immediately return the
`NoUser` error, it will not run the remaining lines of that function. There's
also very little to no Go-style line noise about error checking. I dare say
it's expressive and concise. But it took me a lot of experimenting to get there
and also required writing [some
utility](https://github.com/cideM/lions-backend/blob/770f3e481ee0a7fed27742d0cd8d5f050acfcbfb/backend/src/Error.hs)
functions for translating between various DSLs, again. There are more things I
could complain about here[^2], but I hope that my main point here is clear:
translating a simple pattern, early return, to Haskell, without making
the code untolerably ugly, is not straight forward and it can be hard to find
this kind of advice in tutorials and books.

That was a lot of negativity now, so let's move on to something more positive:
algebraic data types (ADT) and pattern matching. Together, these two features
form the basis for how I model the world in code. Nothing beats the ease with
which this let's me design branching control flow based on a finite number of
options. I currently write Go for a living and the lack of ADTs has caused more
than one logic bug and runtime panic. Generally, few languages give me the same
confidence as Haskell. It's really hard to overstate the peace of mind that
comes from not having to worry about nil pointer exceptions and unhandled
cases. While I was writing this blog post I suddenly had an insight and removed
one field from a record that's used everywhere in my application. In many
languages I would have dreaded this task but in Haskell I simply removed the
field and then followed the compiler errors. At the end I was pretty much 100%
certain that I didn't break anything.

There are a lot of other things I could write about here, but I think most of
the usual suspects have already been covered in great detail in other blog
posts, on Reddit or on Hackernews. This includes:

- Historical baggage like a string type no one really uses
- An anemic standard library resulting in lots and lots of imports
- No one likes records
- Slightly confusing build systems
- Modules that are at the same time tedious and not powerful
- Lazy evaluation can be tricky for performance and debugging
- The typical issues of working with a niche language
- ...

But I don't find any of these things particularly intersting and they're also
not deal breakers for me.

I wanted to write about the experience of using Haskell, not the nitty gritty
technical details. So what does it feel like, then? For the most part it's just
like writing a backend in any other language. Define routes, parse query
parameters, do some authorization and authentication checks, fetch something
from the database, render a document. On a good day, Haskell makes me more
efficient and productive because I spend less time fixing bugs and less time
translating the problem to data structures, because ADTs and the type checker
are just that good. On a bad day, I still find myself deciphering runtime
issues, for example caused by a mismatch between database and Haskell types,
while also spending several evenings just solving Haskell issues.

I'm neutral about using Haskell for future projects, because there are things
about the language I love and others that drive me crazy.

### Nix

According to `tokei` this project has 1206 lines of Nix code, which fall into
three categories: developer environment, building parts of the application,
building and deploying the NixOS image that runs on a digital ocean droplet.

I can't think of a better way to provide all the tools necessary to work with a
project than Nix. Every new project I start uses Nix[^3] to provide
instructions for how to create a shell that includes things like compiler,
formatter, database tools, terraform, and so on. In combination with
[direnv.net](direnv.net/) whenever I `cd` into such a project my shell
environment is updated automatically. Doing this is as easy as adding the stuff
you need to [a
list](https://github.com/cideM/lions-backend/blob/3aff0eabd91bfd37824a6b814b8dbcdb1edb4c58/shell.nix#L44),
and it usually just works (and keeps working).

Building the various parts of this application with Nix was also not too much
work, but your mileage here depends on the languages and tools you use in your
project and how well they're supported in Nix. For Haskell there's a tool you
can use -- `cabal2nix` -- which generates Nix code that contains instructions
for how to build your project, including its Haskell dependencies. You can
mostly just follow the documentation to get something up and running. But
Haskell is an outlier and many other languages don't enjoy the same level of
support. For some of those languages there are tools that translate lock files
to Nix instructions, but they're [not without
issues](https://discourse.nixos.org/t/status-of-lang2nix-approaches/14477/20).
If no such tool exists you're out of luck and building your application with
Nix will quickly become very, very challenging. Nix limits your ability to make
HTTP requests and interact with the file system. You therefore can't just take
a command like `yarn install`, which would download Javascript libraries, and
wrap it in some Nix code. Instead, Nix needs to download each of those
dependencies, and for that it needs at least a URL and a hash to verify the
contents. Good luck quickly whipping up a tool that does that.

In this project I ran into little to no problems in that area though. What I
get in return for building everything with Nix is great caching of build
artefacts, and incredible reproducibility. I can clone the project, run a
single command, and it Just Works™. Additionally, even if it took me a few
hours to figure something out, it was usually a one-time cost.

What did not spark a lot of joy was running my application with Nix, both
locally and remotely. Nix is already a niche technology, but deploying with Nix
is a niche within a niche. Documentation is lackluster and there's a real
chance that you'll be the first person to use a bunch of tools in a certain
combination and as such there's no StackOverflow answer you can just copy from.
Here are some things that tripped me up in no particular order.

You can't build a NixOS image on a Darwin machine, so you need to run things
through Docker. It's another layer of indirection and resource usage for no
gain. It's generally frustrating if you develop on one machine for a while,
only to realize that everything's broken when you to switch to another OS,
especially in 2021. I wouldn't go so far as calling Darwin a second class
citizen in Nix, but you'll have to put in extra effort here and there.

If you run your application inside a NixOS image, how do you actually
(re-)start and monitor the application? I went with Systemd, which was another
piece of technology I needed to learn. Documentation is OK but outside of the
official manpages I found far fewer articles that talked about using Systemd
for backend services than I expected. It therefore took me longer than I wished
to figure out how to pass credentials to my application, share a database
directory between different Systemd services, which syntax goes where, and so
on. If I wanted to debug things on MacOS I needed to build the image through
Docker and then I also ended up running a QEMU VM through Docker.  You're
really on your own for a lot of these tasks and at some point I was tired of
figuring out one thing only be the stuck on the next task.

The biggest time sink is just figuring out what arguments a Nix function takes,
which arguments are magically and silently passed through but can be customized
(and how), and what the function returns. My secret weapon here is GitHub code
search. Nothing beats seeing working code. I rarely benefit from reading the
official manual, since it doesn't contain enough runnable examples. I do spend
a lot of time in issues, PRs and in source code.

Consider Nix a slider that goes from local environment all the way to
production environment. The further right you go, the less likely it is that
you can just follow a cookbook. It's therefore not a big surprise that I would:

- Always use Nix for local development
- Sometimes use it for building the application
- Probably not use it again for deployment

### PureScript

This project was originally meant to be a super simple, single Haskell file
that implements a server that does not require any client side code. I really missed that mark.

I added PureScript (PS) because there's no HTML-only way of toggling a bunch of
checkboxes at once. The use case is to select a few (or all) users from a list
and then click a button to send an email with all selected users added as
recipients.

The idea was to progressively enhance the server-side markup. On page load,
reveal the hidden "send email" button and inject a checkbox into every cell of
the users table. Do not replace the entire users table with markup rendered on
the client, because that would have meant reimplementing all of the markup in
PS. Or figuring out a way of sharing my Haskell template code with PS, but that
sounded like a lot of work. Unfortunately PureScript doesn't seem to have any
libraries that help with that kind of task. Most of its ecosystem seems to
revolve around React-like libraries that want full control over a DOM node.

So I ended up translating Javascript to PS almost word by word and as such the code looks like this:

```purescript
getCheckboxState :: Node -> Effect { email :: String, checked :: Boolean }
getCheckboxState checkbox = do
  checkboxAsEl <- maybe (throw "couldn't convert checkbox to element") pure $ Element.fromNode checkbox
  checkbox' <- maybe (throw "couldn't convert checkbox to input element") pure $ InputElement.fromNode checkbox
  isChecked <- InputElement.checked checkbox'
  email <- Element.getAttribute "data-email" checkboxAsEl >>= maybe (throw "no data-email attr") pure
  pure { email: email, checked: isChecked }
```

This is the same as chaining `document.querySelector` and getting and setting
DOM node attributes. Except that in PS I had to cast from one node type to
another a lot. It's a bit puzzling and I'm still not sure if I overlooked
something really obvious, but take a look at
[`Web.DOM.Element`](https://pursuit.purescript.org/packages/purescript-web-dom/5.0.0/docs/Web.DOM.Element)
and see for yourself. I think you're not meant to write "low-level" code like
that. It's probably better to wrap it in more expressive, high-level APIs.
Since I couldn't find any of those in the form of ready-to-use libraries, and
didn't want to abstract something I only did once, ugly code it is.

I was pleasently surprised by the Nix support though, which seems to mostly be
the work of a single person,
[https://github.com/justinwoo](https://github.com/justinwoo).

I wish I could say more about PS, because it's actually a nice language, but it
just wasn't a good fit for this project. I think the client side code is in the
kilobytes, whereas a vanilla JS implementation would have been much, much
leaner.

## Conclusion

Haskell is still my favorite programming language. Rust sounds like a modern
and more refined take on the concept of pair programming with a very capable
compiler, but whenever I tried it I quickly missed the ease of writing code in
a high level language. But as much as I enjoy using Haskell, I can't ignore the
frustration it has caused me, and how much slower it often makes me during the
initial implementation of something.

My goal for the next 12 months is to do another project of roughly the same
complexity level but use tools that value simplicity above everything else.

I still believe that Haskell, with a good enough understanding of its more
advanced language extensions, can be an incredibly productive language. The
more potential bugs you can rule out through the type system, the less
maintenance down the road. But getting there takes a long time.

---

[^1]: I experimented with that library and found it surprisingly straight
  forward to include. But because I wasn't making use of most of its effects
  and instead only needed a simple way of threading some configuration values
  through various functions, I ended up removing it again.

[^2]: For example, I would strongly recommend to immediately catch potential
  exceptions thrown by a function that has `MonadThrow` (if I recall
  correctly), because I've had surprising errors when the exception type was
  not what I thought, because somewhere a function happened to have a
  `MonadThrow` in its signature but with the exception type hardcoded to
  string. I've also created subtle bugs in code where I thought I was
  short-circuiting but I was actually just returning `IO Left` instead of
  `Left`. So this `mtl`-style control flow is not without its pitfalls.

[^3]: More specifically a Nix Flake