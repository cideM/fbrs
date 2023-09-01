+++
title = "Multiple Routes And Compiled Splices"
date = "2023-08-31"
[taxonomies]
tags=["haskell", "heist-journal"]
+++

Yesterday I got my feet wet by rendering a single, measly splice. And at first it didn't look like I'd even accomplish that before the end of the day. Today I want to extend the example by adding more splices that operate on different data. In the [compiled splices tutorial](http://snapframework.com/docs/tutorials/compiled-splices) they have an example that shows how to render a list of persons. But in a real world application with dozens of routes you will have dozens of splices that all require different data. But if all of those compiled splices end up in your Heist state under a single type, would that type end up being the concatentation of all the parameters of all splices? Let's find out.

The goal for today is this: Make a (fake) database call and use the data to generate two splices, one for a `Text` and one for an `Int`, that are then used in a template.

I specifically do not want to create some application monad and access it from within splices. My major concern with this is that individual splices are now free to make database calls, much like a GraphQL API where each field is backed by an independent resolver, which can make as many database calls as it wants. I'm actually not a fan of this application monad pattern, because it makes it all too easy to have code access your logger or your database that really shouldn't.

Here's how I imagine this will work in pseudo-code:

```text
main = do
  data <- fakeDatabaseCall
  heistState <- initHeist { ... }
  
  let spliceA = genSpliceA (data.someNumber)
  let spliceB = genSpliceB (data.someText)

  heistState.splices = heistState.splices
    // { spliceA = spliceA, spliceB = spliceB }

  renderTemplate heistState "foo"
```

I suspect that merging splices into the Heist state will be a major undertaking. I have no idea how I can modify Heist state. Indeed, the documentation for `initHeist` says this:
> We don't provide functions to add either type of loadtime splices to your HeistState after initHeist because it doesn't make any sense unless you re-initialize all templates with the new splices.

The documentation does mention
>  Heist's HeistState -> HeistState "filter" functions. 

but I don't know where they are. They do have a few functions that all work in the `HeistT n m ()` environment, but I don't know how I would use them. I could call `modifyHS` in a splice function, but then I'm once again in a load-time splice function and I want to avoid the whole runtime stuff-everything-into-an-application monad.

So I guess modifying the Heist state is not an option after all. What else can I do then, that's not the giant-all-encompassing-application-monad-of-doom? The tutorial code has this snippet in it:

```haskell
hs <- load baseDir ("people" ## allPeopleSplice)
let runtime = fromJust $ C.renderTemplate hs "people"
builder <- evalStateT (fst runtime)
            [ Person "John" "Doe" 42
            , Person "Jane" "Smith" 21
            ]
return $ toByteString builder
```

Notice that they're supplying the data for this view through a simple, hard coded state monad. I could create runtime splices that use a bespoke reader monad and then in my route handlers fill that reader monad with all the data for that route. I suspect that this will hamper re-use though. If you have a splice that needs an int and its used in two different templates that use a different reader monad each, then I can think of two options:
- duplicate the splice
- make the splice a bit more generic with a type class and then implement that type class for each monad

```haskell
class HasNewsCount a where
  getNewsCount :: a -> Int

instance HasNewsCount ViewA where
  getNewsCount = undefined

instance HasNewsCount ViewB where
  getNewsCount = undefined
```

Anyway, let's give this a try. First, I need a somewhat more realistic example. I created two views for two routes:

```text
// view_a.tpl
<apply template="index">
  <person />
  <foo />
</apply>

// view_b.tpl
<apply template="index">
  <count />
  <foo />
</apply>
```

They both have `<foo />` in common, so that I can go through the use case of having a shared splice that gets its data from different reader monads (unless I figure out a solution that doesn't need those monads, but I doubt it). They also each have a splice that's exclusive to the view, so that the data for each view as a whole is different.

I cleaned up `main.hs` which now looks like this:

```haskell
mainSplices :: Monad m => Splices (C.Splice m)
mainSplices = return mempty

main :: IO ()
main = do
  let spliceConfig =
        mempty
          & scLoadTimeSplices .~ defaultLoadTimeSplices
          & scTemplateLocations .~ [loadTemplates "app"]

  eitherHeistState <-
    initHeist $
      emptyHeistConfig
        & hcNamespace .~ ""
        & hcErrorNotBound .~ False
        & hcSpliceConfig .~ spliceConfig
        & hcCompiledSplices .~ mainSplices

  case eitherHeistState of
    Left err ->
      putStrLn $ "Heist init failed: " ++ show err
    Right heistState -> do
      case C.renderTemplate heistState "view_a" of
        Nothing -> do
          putStrLn "Index not found!"
        Just (docRuntime, _) -> do
          docBuilder <- docRuntime
          print $ toByteString docBuilder
```

I'm already scared of this `Monad m => Splices (C.Splice m)` being my downfall. This `m` will have to be specialized to an appropriate reader monad for each view. But without having it be the amalgamation of all views (or their data).

And just as I thought, this doesn't work. In retrospect it's rather obvious.

```haskell
fooSplice :: (MonadIO m, MonadReader e m, HasFoo e) => C.Splice m
fooSplice = do
  return $ C.yieldRuntimeText $ do
    fooValue <- lift $ asks foo
    return $ T.pack $ show fooValue
```

If you build a few splices like that, all with a different `Has*` constraint, the top level splices list must gather up all those constraints.

Recapping:
- modifying the list of splices after `initHeist` seems hard and not what you're supposed to do
- any concrete type in a splice will bubble up to the top level splices definition, where you'll be forced to have a type that is the concatenation of all child types

I took another look at the [Stack Overflow answer](https://stackoverflow.com/questions/8023191/using-values-not-from-the-application-monad-with-heist-templates) here and specifically looked at the source code mentioned in a comment. But that source code seems to reference a Heist version that is practically ancient at this point. I don't think the option mentioned by "mightybyte" is viable anymore.

I updated the example repository at [this commit](https://github.com/cideM/heist_getting_started/tree/498e072a9aab8f06b1d7a3f4601e5062198e1b57).

Next I'll have to figure out which other templating library I can use or if I want to just drop Haskell for this project.
