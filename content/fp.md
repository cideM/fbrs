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
area, which is the part I rebuilt and what this post is all about.

The members area consists of a handful of routes:
- A news feed where administrators can post new messages. It's plain text with the exception of URLs, which are replaced with proper anchor links. No images.
- User management area, where administrators can invite new members or edit and delete existing members. Here you can also filter by user groups and send emails to users you select through checkboxes. That's the part where I used progressive enhancement. This route also hooks into email sending functionality for messaging someone who was invited to the site.
- People can create events, and others can then sign up for these events and also indicate how many guests they bring. Everyone can see who's coming and who declined, how many guests there are in total. Events can also have attachements, such as PDF files, which are stored on the droplet itself.
- People can request a link that let's them change their password.

The first version was hacked together with Firebase and some serverless functions,
because I didn't want to maintain a proper backend. The UI was awkwardly fit
into the static site. It worked but it was ugly.

And so one day I decided that it was time for a rewrite! The official reason is
that I considered it too risky to depend on Firebase for everything. Also the
local developer experience was a bit lacking at that time. The honest answer is
that, for quite a long time, I had been looking for a real-world project to
which I could apply all the fancy functional programming (FP) technologies I
picked up over the years. I was holding an FP-shaped hammer and I was just
looking for a suitable nail.  This project seemed perfect, since it's small,
has actual users and even a deadline, but since it's a project for a family
member there's no money on the line and I could do whatever I wanted in terms
of tech. And so the idea was born to rewrite the entire website with Haskell,
Nix and PureScript.

In this post I want to share my experiences building this simple backend in
Haskell, Nix and PureScript. You don't need to know any of these technologies
to follow the blog post. You might not understand every little detail, but I
hope that the overall message is still valuable. I'll start the post with a
short summary, so you don't have to read the entire article if you just want
the main conclusions.

Here's the [source code](https://github.com/cideM/lions-backend).

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
Haskell libraries revolve around specific Monads, created just for that
library. You don't need to know what Monads are for this blog post, but the
gist is that you often need to write a little bit of glue code, so that
different Monads of different libraries can talk to each other. I'll write more
about this later. But the end result was I spent way more time on glue code
than I thought. To make things worse, this glue code did not feel like
meaningful progress. It's a Haskell solution for a Haskell problem after all.

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
frustrating, especially on MacOS. Additionally, my GitHub action workflow that
builds the application, runs end-to-end tests and deploys it, takes 25 minutes.
For a website of this size that is insane.

### SQLite

I love SQLite. It has quirks and historical baggage but at the end of the day
it's a robust, battle tested and simple tool that I find to be a joy to use.
You can easily spin up an in-memory database for unit tests, it comes with a
surprising number of features, such as JSON tooling, and it's just a file at
the end of day. This kind of simplicity is refreshing. Also shoutout to
[Litestream](https://litestream.io/) for database backups.

10/10 would use again.

### PureScript

I've written 140 lines of PureScript (PS) code in this project, which is
nothing. It's used for progressive enhancement of markup rendered on the
server, which means inserting DOM elements and interactivity into existing DOM
nodes. Unfortunately I couldn't find any good PS libraries for this, so I had
to resort to writing very verbose and tedious code that looks like a one-to-one
translation from Javascript. All of the PS web frameworks and libraries I saw
want to own the markup they render, like React. So instead of surgically
injecting interactivity into existing DOM elements, you hand control over an
entire subtree of the DOM to PS. But that would have meant duplicating the
rendering (first render with Haskell on the server then with PS on the client)
of some routes in PS, which seemed like too much work.

For this project PS was not a good choice, as it meant additional complexity
and an unnecessarily large bundle for little to no gain. I like the language
though. As such I just can't say if I would use PS again in the future based on
this project alone.

## Deep Dive

### Haskell

Haskell the language is really not complicated. But the ecosystem can be. I
frequently found myself spending too much time solving problems that only exist
in Haskell. These problems are usually the result of having to combine custom
Monads (which you can think of as small, domain specific languages) from
different libraries, something I alluded to already in the summary. For
example, I struggled [quite a
bit](https://www.reddit.com/r/haskell/comments/jyzc3w/how_to_avoid_infinite_type_when_lifting/)
with logging, which has only ever happened once before, in Clojure, where
logging is [the final
frontier](https://lambdaisland.com/blog/2020-06-12-logging-in-clojure-making-sense-of-the-mess).
But let me explain in a bit more detail why logging can be surprisingly tricky.

Here's a snippet from the README of
[scotty](https://hackage.haskell.org/package/scotty), a well known web
framework:

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
not passing the HTTP request to the `param` function? Where does it get
the _request_ paramter from, then? The answer is too complicated for this blog
post, but suffice it to say that there's some magic going on behind the scenes.
And this magic is made possible by the Scotty Monad.

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
Well, the answer is, it's complicated. Just like with Scotty, there's a custom Monad
that takes care of all this plumbing for us behind the scenes.

Of course the logger and its contexts and namespaces need to live somewhere. In
a typical setup you create a record that holds your application environment.
And in that environment you store the logger. You then need to teach Katip how
it can access and modify the logger in that environment. It's essentially like
implementing an interface for a struct, if you're a Go person.

But then you also need to teach Scotty about this custom Monad. Instead of
working with
[`Web.Scotty`](https://hackage.haskell.org/package/scotty-0.12/docs/Web-Scotty.html)
you import
[`Web.Scotty.Trans`](https://hackage.haskell.org/package/scotty-0.12/docs/Web-Scotty-Trans.html),
which states in its opening paragraph:

> The functions in this module allow an arbitrary monad to be embedded in
> Scotty's monad transformer stack in order that Scotty be combined with other
> DSLs.

Which is exactly what I wanted to do. And at this point the whole house of
cards may or may not fall apart. Because custom Monads often come with
constraints. As in, if you want to run this custom Monad you need to make sure
that the context in which it runs supplies X, Y and Z. And then you start
wondering how those constraints will fit into the bigger picture of all the
other custom Monads you need to satisfy. For Scotty and Katip this ended up
being not too
[crazy](https://www.reddit.com/r/haskell/comments/jyzc3w/how_to_avoid_infinite_type_when_lifting/),
but for another library -- `co-log` -- I was unable to achieve my goal at all.
If this whole paragraph sounds a bit hand-wavy, please check out [this Reddit
question](https://www.reddit.com/r/haskell/comments/krke1o/how_to_create_colog_instance_for_scotty/)
[and this StackOverflow
(SO)](https://stackoverflow.com/questions/65599741/how-to-make-co-logs-withlog-work-with-scotty)
post.

So yes, Haskell can be concise, expressive and type safe. But getting there can
be a pain, at least in the beginning. I do believe that over time this stops
being a problem, as you get more and more familiar with the Haskell type system
and the ecosystem.

Aside from Monads, there was at least one other recurring topic that made me
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
easy in imperative languages with statements.

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
exceptions wouldn't be appropriate). Here's a snippet from an older commit that
shows what such code could look like.

```haskell
getTokenByValue dbConn token >>= \case
  Nothing -> return $ Left $ TokenNotFound token
  Just tok@Token {..} -> do
    ok <- hasUser dbConn tokenUserId
    if not ok
      then (return . Left $ UserForTokenNotFound tokenUserId)
      else do
        now <- Time.getCurrentTime
        if now >= tokenExpires
          then return $ Left $ TokenExpired tok
          else do undefined -- ...
```

You can see where I'm going with this, right? The increasing indentation level
looks ugly. In all fairness though, this isn't any more verbose than the
equivalent Go or Typescript code. **I really wish that I had just stuck with
the ugly and verbose version** instead of trying out various different
patterns. I believe that this code is simple, and readable and very easy to
understand. Refactoring this for vanity reasons is not something I'm proud of.

There are [some
tricks](https://www.haskellforall.com/2021/05/the-trick-to-avoid-deeply-nested-error.html)
for dealing with the ugliness, but in **my personal experience** they often don't work
in real world scenarios, where more complicated types are involved,
particularly anything with `IO`. What does work is making liberal use of syntax
sugar, combinators and Monad transformers though.

Here's a snippet I copied verbatim from my code base, which shows what the
previous code looks like once you throw Monad transformers at the problem:

```haskell
token@Token {..} <- Token.get value >>= E.note' (NotFound value)
ok <- User.exists tokenUserId
E.unless ok $ E.throwError (NoUser tokenUserId)
now <- liftIO $ Time.getCurrentTime
E.when (now >= tokenExpires) (E.throwError $ Expired token)
return $ Valid token
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
functions for translating between various custom Monads, again. There are more things I
could complain about here[^1], but I hope that my main point here is clear:
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
project than Nix. Every new project I start uses Nix[^2] to provide
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
Docker and then I also ended up running a QEMU VM through Docker. You're
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
sounded like a lot of work. Unfortunately PS doesn't seem to have any
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

I still believe that Haskell, with a good enough understanding of its more
advanced language extensions, can be an incredibly productive language. The
more potential bugs you can rule out through the type system, the less
maintenance down the road. But getting there takes a long time.

My goal for the next 12 months is to do another project of roughly the same
complexity level, but use tools that value simplicity above everything else.

For example, instead of devising a complicated secret management solution, that
could end up being risky because you don't understand how it works, I could
also just `ssh` into the server and create a file with the secrets and call it
a day. Instead of using Nix to manage the complexity of a sprawling dependency
tree, what if my app barely had any dependencies?

---

[^1]: For example, I would strongly recommend to immediately catch potential
    exceptions thrown by a function that has `MonadThrow` (if I recall
    correctly), because I've had surprising errors when the exception type was
    not what I thought, because somewhere a function happened to have a
    `MonadThrow` in its signature but with the exception type hardcoded to
    string. I've also created subtle bugs in code where I thought I was
    short-circuiting but I was actually just returning `IO Left` instead of
    `Left`. So this `mtl`-style control flow is not without its pitfalls.

[^2]: More specifically a Nix Flake
