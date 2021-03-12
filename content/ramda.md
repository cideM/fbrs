+++
title = "Functional Programming vs. Vanilla Javascript"
date = "2021-03-09"
[taxonomies]
tags=["javascript"]
+++

I'm a fan of functional programming (FP), especially when it's coupled with a powerful type system as in Haskell. But my day job revolves around Go and Javascript and involves fairly little FP. Unfortuntately the only person I can blame for that is myself! Apparently I'm not doing enough internal lobbying to convince people of the merits of FP.

If I'm honest, the reason I haven't really pushed for FP is because I'm not convinced that it is indeed the better, default choice for teams that don't have much FP expertise to begin with. Before I can convince anyone else, I'll have to convince myself. Therefore I will start gathering examples of real life code that I can analyze through both the FP and the imperative lens. Hopefully over time I'll come to a personal conclusion and it'll have the nice side effect of giving me plenty of arguments for future discussions.

Today's example is a run of the mill data transformation. I need to transform a flat list of objects into nested objects, which will then be passed to the view layer, where each component will peel off one layer. In other words, I'm denormalizing data for maximum ease in the view layer. The snippets and code will include some place holders here and there and I won't be mentioning the actual view layer and logic. The only thing that's relevant here is getting the data from shape A to shape B.

In the actual code the `heading` is derived from `first_name` and `last_name` but in the benchmarks and examples I replaced it with a placeholder, since it's irrelevant to this post.

The code, including benchmarks, can be found on [GitHub](https://github.com/cideM/ramda-vanilla-benchmark)!

```javascript
const input = [
  {
    section: "barsection",
    author: { first_name: "foo", last_name: "bar", id: "123" },
    content: "foo note",
  },
  {
    section: "barsection",
    author: { first_name: "bax", last_name: "bar", id: "111" },
    content: "bax note",
  },
  {
    section: "foosection",
    author: { first_name: "bert", last_name: "bar", id: "223" },
    content: "bert note",
  },
  {
    section: "foosection",
    author: { first_name: "bert", last_name: "bar", id: "223" },
    content: "another bert note",
  },
];

const output = {
  barsection: {
    len: 2,
    data: [
      { id: "111", heading: "bax'", contents: ["bax note"] },
      {
        id: "123",
        heading: "foos",
        contents: ["foo note"],
      },
    ],
  },
  foosection: {
    len: 2,
    data: [
      {
        id: "223",
        heading: "berts",
        contents: ["bert note", "another bert note"],
      },
    ],
  },
};
```

If you focus on the output you'll notice that we're doing two aggregations here. We group the input by its section key and we also group all entries by the same author per section. The resulting `data` value is an array so that the view layer can iterate over it without having to first call `Object.values` on it.

## Vanilla

The vanilla solution is imperative to a fault. Personally I can't glance at the code and immediately get an idea of what it's doing on a high level. There's too much plumbing going on, especially the checks and initializations to make sure we're not accessing a key on an undefined object. Others will consider this an advantage though, because there's absolutely no magic. Also note that the snippet doesn't include any imports because there are none! One thing I like about it is that object initialization makes the shape of the data clearer. Additionally, it's easy to see the execution model (e.g., number of iterations). Zero magic.

```javascript
const vanillaFn = (notes) => {
  const grouped = {};

  notes.forEach((note) => {
    const {
      author: { id: currentId },
      content,
      section,
    } = note;

    if (!grouped[section]) grouped[section] = { len: 0, data: {} };

    grouped[section].len += 1;

    if (!grouped[section].data[currentId])
      grouped[section].data[currentId] = {
        contents: [],
        heading: "",
        id: "",
      };

    const userNotes = grouped[section].data[currentId];
    userNotes.heading = "placeholder";
    userNotes.contents.push(content);
    userNotes.id = currentId;
  });

  Object.keys(grouped).forEach((sectionId) => {
    grouped[sectionId].data = Object.values(grouped[sectionId].data);
  });

  return grouped;
};
```

## Ramda

If you want to write functional JS in any significant capacity you'll need a third party library. For many people `lodash/fp` will be the first choice since `lodash` (without the fp part) is probably already in use anyway.

I would really encourage you to look into Ramda though, since it includes many functions that are simply missing from Lodash but which I'd consider an important part of the FP toolset and mindset. With Lodash you won't get to experience the full power and conciseness of FP.

Ramda's rich API made me write two different versions of the code in question. I can't help but notice that it's quite typical for me to spend more time thinking about how to solve something when I'm using FP. Contrast this with Go where iterating means `range` and that's it. With FP you might spend the next hour musing about the pros and cons of various list comprehension and traversal interfaces.

### Version A

The first version makes heavy use of lenses to assign data at various levels of nesting. Other than that it's essentially just a fold (`reduce` in JS). The second operation just converts objects into arrays at the `data` key (see the second code snippet below). I'd consider this version quite close to the vanilla implementation, since both operations in the call to `pipe` map to a block of code in the vanilla implementation.

```javascript
const lensProp = require("ramda/src/lensProp");
const compose = require("ramda/src/compose");
const values = require("ramda/src/values");
const reduce = require("ramda/src/reduce");
const map = require("ramda/src/map");
const defaultTo = require("ramda/src/defaultTo");
const lensPath = require("ramda/src/lensPath");
const set = require("ramda/src/set");
const concat = require("ramda/src/concat");
const inc = require("ramda/src/inc");
const over = require("ramda/src/over");
const pipe = require("ramda/src/pipe");

const safeIncrement = pipe(defaultTo(0), inc);
const safeConcat = (xs) => pipe(defaultTo([]), concat([xs]));

const reducer = (
  object,
  { author: { id: currentId }, content, section }
) => {
  const lenL = lensPath([section, "len"]);
  const userL = lensPath([section, "data", currentId]);
  const idL = compose(userL, lensProp("id"));
  const contentsL = compose(userL, lensProp("contents"));
  const headingL = compose(userL, lensProp("heading"));

  return pipe(
    over(lenL, safeIncrement),
    set(idL, currentId),
    over(contentsL, safeConcat(content)),
    set(headingL, "placeholder")
  )(object);
};

const ramdaFn = pipe(
  reduce(reducer, {}),
  map(over(lensProp("data"), values))
);
```

```javascript
const a = {
  dynamicKeyA: {
    dynamicKeyB: { foo: 1 },
    dynamicKeyC: { foo: 2 },
  },
};

const b = {
  dynamicKeyA: [{ foo: 1 }, { foo: 2 }],
};
```

### Version B

This version is quite different from the other two, and I'm finding it hard to correlate the individual operations to code in the vanilla implementation. The second part, replacing an object with an array of its values, is still the same. But the first part further differentiates between transforming a single input value and combining those transformed values. It doesn't use lenses at all, and instead introduces the concept of transducers (hello Clojure!). In my opinion this is the cleanest looking version, because it elegantly skirts the issue of having to deal with operations on potentially uninstantiated, nested objects.

```javascript
const mergeDeepWithKey = require("ramda/src/mergeDeepWithKey");
const pipe = require("ramda/src/pipe");
const concat = require("ramda/src/concat");
const transduce = require("ramda/src/transduce");
const map = require("ramda/src/map");
const over = require("ramda/src/over");
const lensProp = require("ramda/src/lensProp");
const values = require("ramda/src/values");

const mapper = ({ author: { id: currentId }, content, section }) => ({
  [section]: {
    len: 1,
    data: {
      [currentId]: {
        heading: "placeholder",
        contents: [content],
        id: currentId,
      },
    },
  },
});

const merger = (key, left, right) => {
  switch (key) {
    case "len":
      return left + right;
    case "heading":
      return left;
    case "id":
      return left;
    case "contents":
      return concat(left, right);
  }
};

const ramdaFn = pipe(
  transduce(map(mapper), mergeDeepWithKey(merger), {}),
  map(over(lensProp("data"), values))
);
```

## Discussion

We've looked at what the code is doing and how it's doing that in three different ways. Now it's time to wade into dangerous territory and attempt to compare FP and imperative programming in this tiny piece of code.

I'll analyze each snippet based on the following metrics:

- Performance
- Lines of Code & Dependencies
- Readability

If you think that I'm overlooking a really important metric please let me know at `yuuki at protonmail dot com` or on whatever website I publish this post. Lastly, I'm not an academic. I'm sorry if the discussion of the individual metrics lacks rigor. Again, do let me know!

### Performance

This one we can measure! The repository I linked at the start of this post includes not just the different snippets but also a benchmark. The benchmark consists of a list of 3 input objects for two sections and two authors, which I repeat `n` number of times. The resulting list of lists is flattened and then used as input to each code snippet. The test data isn't very refined but it should be good enough for a relative performance comparison.

```text
n = 30
ramda x 1,067 ops/sec ±6.83% (69 runs sampled)
ramda merge deep x 6,301 ops/sec ±4.96% (77 runs sampled)
vanilla x 223,259 ops/sec ±5.09% (76 runs sampled)
```

With an input list of length 30 the vanilla version is about 35 times faster
than the FP versions. Increasing it to 15000 makes the difference even more
drastic, with vanilla JS now 100 times faster. The difference between the two
FP versions is negligible.

```text
n = 15000
ramda x 2.19 ops/sec ±9.46% (10 runs sampled)
ramda merge deep x 7.70 ops/sec ±6.06% (24 runs sampled)
vanilla x 777 ops/sec ±3.42% (82 runs sampled)
```

I also did a _very basic_ memory consumption test, by just commenting out some of the benchmark code and running the functions directly with `$ command time -f '%M' node index.js`. Results:

```text
ramda            79756KB
ramda merge deep 79156KB
vanilla          32096KB
```

Don't take these values literally, they're only useful for comparison purposes. Just like with speed, vanilla clearly comes out ahead.

So what do we make of these results? I was expecting Ramda to be slow. I'd also suspect that if you can replicate some of the FP examples with `lodash/fp` you'll see a speed up. I've glanced at Ramda's source and it implements the FP concepts with much more rigor than Lodash. As an end user you don't care about that, but then again Lodash is missing a lot of important FP functions from its API.

Personally performance is not my primary worry when writing client side Javascript. Clients shouldn't have to deal with tens of thousands of objects. On the other hand Ramda is **a lot** slower. If you're trying to maintain 60FPS you don't have lot of wiggle room. I could very well imagine a rich client application that uses large enough lists for Ramda to become a problem.

On the backend side you're even more likely to work with sufficiently large data. Of course, always keep in mind that any network or file I/O might render these micro benchmarks meaningless. If your app is waiting 100ms for a request, it doesn't matter much if your Ramda code is 5ms slower.

My personal conclusion from this admittedly superficial look at performance is that while it doesn't rule out Ramda, it means that Ramda will have to be really convincing in all other comparisons.  

### Lines of Code & Dependencies

Why look at size (lines of code)? Users of concise languages will point out that there are studies that have shown that fewer LOC means fewer opportunities for bugs. Based on my own experience I agree with this statement but not without some nuance. One example in favor of reducing LOC is that in Go I constantly write exactly the same code for making a list of things unique, just with different types. At some point I'll make a dumb mistake that goes unnoticed and lands in production. On the other hand really dense code can be incredibly hard to understand (looking at you Haskell). And lack of understanding is the perfect breeding ground for bugs. In the end I believe that a reasonable reduction in LOC is a good thing, but you shouldn't become fanatic about it.

```shell
$ wc -l vanilla.js ramda.js ramda_merge_deep.js
  31 vanilla.js
  34 ramda.js
  41 ramda_merge_deep.js
```

There's just not enough code to draw a meaningful conclusion here. The primary reason why the vanilla version is the shortest is that it doesn't require almost a dozen imports. Without those things look a bit different:

```shell
$ wc -l vanilla.js ramda.js ramda_merge_deep.js
  31 vanilla.js
  21 ramda.js
  32 ramda_merge_deep.js
```

I think it's safe to assume that across an entire code base Ramda will end up being significantly shorter. You might just eat the added bundle size that comes from importing the entire library instead of individual functions. Even if you keep the imports granular, they don't add to the complexity of the code and in larger files their impact on LOC will diminish. I don't have access to a code base that was written in both vanilla JS and Ramda so this will have to remain a reasonable assumption.

Lastly, what is the impact of a library like Ramda on the overall bundle size? Depending on what you use as a point of reference, the [12kb](https://bestofjs.org/projects/ramda) that Ramda adds to your bundle size might be completely irrelevant. Many sites ship megabytes of Javascript after all. But if you do care about size then those 12kb will have to pull their weight. Any dependency also adds a bit of maintenance work, although that's less of an issue with general purpose utility libraries. It's not like the API for `map` changes every quarter.

### Readability

The final frontier. Few topics evoke such emotional responses as readability. It's actually kind of funny that readability is often used as both an argument for and against Haskell. My biggest problem is that I don't even know what I consider readable. I'm a web developer writing CRUD apps, as such ease of getting up to speed and developer velocity are really important for the code I write at work. Personally though I place a higher value on making the high level intent of code as clear as possible. But if you're a systems developer then clarity of execution might be the most important aspects of readability. By this I mean things like how often does this allocate, when exactly is this future woken up, does this stream in chunks or not at all, and so on. And as I'm writing this I'm not so sure anymore if I'd really favor high level intent over clarity of execution model. Do I want to be known as a developer who wastes resources?

It's tempting to draw a line between high level and low level coding and define two different sets of readability rules. But about people who do both? Code that needs to be super fast but that's dealing with really complicated logic?

In an ideal environment I'd focus only on the logic and leave performance to the compiler. But such an environment does not exist. Therefore I will analyze the snippets both with regards to high level intent and clarity of execution model.

The vanilla version makes it quite clear how many iterations will take place. There's a `forEach` at the start and another at the end. It also calls two `Object` methods, which probably do some iterating as well. You're also not left wondering if there's any deep cloning going on (there isn't). 

On the other hand it's not apparent what this code is trying to accomplish. You really need to read it line by line to understand that we're mostly gathering the `content` fields of each input value, by section and author.

The first Ramda version is more or less a translation of the imperative code but using lenses. Instead of `forEach` it's doing a `reduce`, but other than that you need to check what each `over` and `set` is doing. To make matters worse, I had to create two wrappers so that I can use `inc` and `concat` without having to first check for `undefined`.

I'd argue that this snippet is the worst of the bunch. You lose the clarity of execution model from the vanilla version, without gaining much in terms of high level intent. Developers who are new to FP will be confused by lenses, especially once they see them being composed. Lastly, threading an object through a pipe of `set` and `over` will probably look super confusing. We normally don't think of multiple assignments to object keys as multiple function calls.

So what about Ramda version two? I absolutely love the way I can convert a single input value into a single output value without having to even think about nested objects paths. The shape of the output data is crystal clear as well!

But then you stumble upon `mergeDeepWithKey` and whatever clarity was gained by the mapping is immediately lost. The switch statement only specifies some keys. You really need to read the documentation to understand what happens with the rest. If you come from an FP background then you'll probably make the connection between this and implementing semiring for your datastructure. But without that background knowledge it will seem pretty magical, and not in a good way. Additionally, you need to understand how the mapping and merging are used in the `transduce` call. Clojurists won't have any issues with that, but the average JS developer is unlikely to be familiar with transducers in general. Also I've seen it many times that JS developers are strangely averse to switch statements. I don't have an explanation for this though.

You could reduce the number of new concepts by separating the whole thing into a `map` followed by a `reduce` but then you're back at square one. You'd need to write code that merges every key in both objects, potentially handling `undefined` if your `reduce` starts with an empty object.

For me personally the third snippet is clearly the winner. It's about as concise as it gets. It shows how to transform a single value. Then it shows how the results will be merged, while omitting keys that use the default merging strategy. But it also requires quite a lot of buy in from a developer who's not familiar with FP.

## Conclusion

Ramda is much more concise, but also significantly slower than vanilla Javascript in this small example. The conciseness comes from using concepts such as lenses, transducers and higher order functions, which most developers are not familiar with. Careless use of functional programming concepts in a language without special support for that is, in my opinion, more likely to lead to unnecessary CPU usage and memory consumption. Of course you can write slow code in any paradigm, but if the most likely thing you'll do is write a single loop and cram all your functionality in there, you'll be more likely to experience a "pit of success" moment with regards to performance.

Ultimately, I was hoping to answer the question: would FP be my default paradigm in my next JS project? I don't know. I think that you'd need to invest a lot of time and energy into mentoring. You'd also need people curious enough to be mentored. I can guarantee you that some of the FP heavy code will come out needlessly complex and abstract in the beginning. This will lead to push back and endless discussions. I'm not sure if that's really worth it? Maybe it's better to use a language that was built with FP in mind rather than retrofitting it into JS.

