+++
title = "Prefer Higher Order Component for Branching Logic"
date = "2020-08-09"
[taxonomies]
tags=["React", "Javascript"]
+++

Hooks have taken the React world by storm and they're here to stay whether you like it or not. I can understand the appeal of their simplicity since it's hard to be more concise than `const [foo, setFoo] = useState()`. But there are use cases where I think that higher-order component (HOC) fare better than hooks and one of them is _branching logic_.

## The Contagious Effect of Defensive Coding

Imagine a component a that makes a network request and depending on the result, you either render a loading spinner or an entire subtree of components.

```javascript
const Foo = (url) => {
  const [data, loading] = useRequest(url);

  if (loading) return <Loading />;
  else return <Subtree data={data} />;
};
```

Where this style of writing your components falls apart is once you start adding more hooks to `Foo`.

```javascript
const Foo = (url) => {
  const [data, loading] = useRequest(url);

  const [state, setState] = useState(data.whatever);

  useSomeEffect(data);

  if (loading) return <Loading />;
  else return <Subtree data={data} />;
};
```

Both `useState` and `useSomeEffect` expect the request to have succeeded and `data` to be available. But that's not the case if the request is still loading and/or if it failed. You have two options for handling this: make both hooks fail gracefully in case of missing data or not render the hooks at all. Option 1 is what I see most people reach for instinctively. It's the safe and easy thing to do. But I consider `if !x then else` an anti-pattern and the worst thing about it is that it spreads like wildfire. The next person who works on this code will see the _defensive coding_ and conclude that all bets are off and `data` can be whatever, so they to will litter their code with `if !x then else`.

Therefore I try to use option 2 as much as possible. But you can't conditionally return before rendering a hook, it [just doesn't work](https://reactjs.org/docs/hooks-rules.html#only-call-hooks-at-the-top-level).

## Conditionally Rendering Hooks

What you can do however is **conditionally render a component containing all the hooks**.

```javascript
const FooWithHooks = (data) => {
  const [state, setState] = useState(data.whatever)

  useSomeEffect(data)

  return <Subtree data={data} />
}

const Foo = (url) => {
  const [data, loading] = useRequest(url)

  if (loading) return <Loading />
  else return <FooWithHooks data={data}>
}
```

What's unsatisfying about these two components is that `Foo` contains very little code but it's hardcoded to always render `FooWithHooks` (and `Loading`). Luckily HOCs make it trivial to extract this logic.

```javascript
const withFoo = WrappedComponent = props => {
  const { url } = props

  const [data, loading] = useRequest(url)

  if (loading) return <Loading />
  else return <WrappedComponent data={data}>
}

const Foo = withFoo(FooWithHooks)
```

I suspect that this pattern isn't exactly news to many people, since it's how many libraries used to expose their functionality before hooks (think `graphql` HOC from Apollo). But I know very well that it can be super attractive to throw out the old and replace it with the new One True Way of doing things. And in many cases, hooks will probably make your life easier. But HOCs are still a really important design pattern and an essential part of every React developer's toolkit. Right tool for the job and all.
