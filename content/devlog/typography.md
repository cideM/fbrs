+++
title = "Typography rabbit hole"
date = "2024-02-01"
[taxonomies]
tags=["design"]
+++

I just want this website to look good. Last week I redid the CSS and tried incorporating a typographic scale based on the golden ratio. But I'm still not really happy with the result; I think my approach is too simplistic. I created a scale of 8 values (from small text all the way up to `h1`) and I'm using this for font sizes, line heights and spacing. But I didn't consider how the possible combinations of sizes relate to the baseline or vertical rhythm of the page. Apparently the holy grail for typography is to make sure all the elements of the page align with an imaginary grid. I'm pretty sure that's not the case for my current CSS. I'm also confused about UI design and article layouting. Can I apply the same variables to both? I then had somewhat of an epiphany: this is a blog, not an app. I want this blog to look and feel like print media. I shouldn't have to think about buttons and menus. Therefore one idea I have right now is to make sure that every single route is a document. That way I can hopefully eliminate a lot of CSS so that I can focus on just the layouting of articles; a topic daunting enough on its own.

Here are some resources, with spontaneous comments:

- https://grtcalculator.com/ really cool maths but the blog itself doesn't look so great; I think the author makes the mistake of applying this golden ratio scale everywhere, at the expense of other readability considerations
- https://www.modularscale.com/ pretty simple but what about line height, and so on?
- https://spencermortensen.com/articles/typographic-scale/ again, what about line height?

What I've learned so far is that using something like the golden ratio to create a scale is a good idea. But you can't just apply this blindly. Larger font sizes require relatively smaller line heights, or else the lines are too far apart. Ideally, any combination of font size and line height is a multiple of some base unit, such as the line height. Longer lines require bigger line heights. Avoiding "weird" numbers probably makes fonts look nicer, since who knows how a browser will render 13.412412px?

[Here's](https://www.smashingmagazine.com/2011/03/technical-web-typography-guidelines-and-techniques/#tt-grid) another article that discusses concrete steps to improve web typography. The general idea is always to start with a body font size and line height and then make sure that all spaces are multiples of that line height. How does changing the font size affect that? Assuming 16px and 24px, I'd use the following CSS:

```css
body {
  line-height: 1.5;
}
```

Quick aside: I did not know that `rem` units are related to the `html` element, as explained [here](https://stackoverflow.com/questions/37592083/font-size-value-scaling-with-browser-zooming). I thought they related to `body`. Anyway... I always use `px` for the `body` tag, but now I'm wondering if I should actually be using relative units here too? I assume using `px` will overwrite any custom font size set by the user, so it would be pretty bad for accessibility. You can still zoom in though. Well, after some reading and considering, I'll just use the default font size from now on, and only use relative units if I want to adjust it.

Back to the original question: if I don't know the exact font size, only the relative line height, then how can I make sure my elements are aligned to some imaginary grid? Let's start with a concrete body font size of 16px. All spacing should then be a multiple of 24px. If an element has a font size of 2em, what would be its line height `x`? The actual height of that element's line would be `16 * 2 * x` or `32 * x`. Incorporating th grid we get something like `n * 24 = x * 32`, re-arranging to `(n * 24) / 32 = x`. You can see that I know next to nothing about maths. If I want to make this a multiple of 24, I can just use `n = 1` so we get `x = 0.75`. And indeed, `32 * 0.75` is a multiple of 24. I could also use `n = 2` and get a line height of 1.5. What about a font size of 2.2em?

```text
n * 24 = x * 35.2
(n * 24) / 35.2 = x
for n = 1: x = 0.681818181
for n = 2: 1.36
```

So what if I don't know the actual font size? Let's forget about the weird `n`; for the element with font size 2.2 I now get: `x = (body * 1.5) / (body * 2.2)` or `x = 1.5/2.2` or `x = 0.68`. Makes sense, even without knowing the actual body font size I can calculate suitable line height values based on relative units. Let's put this to the test, using a modular scale based on the golden ratio.

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <link rel="stylesheet" href="/style.css" >
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>FBRS</title>
    <style>
*,
*::before,
*::after {
  box-sizing: border-box;
}

* {
  margin: 0;
}

body {
  line-height: 1.5;
}

h1 {
  font-size: 6.854em;
  line-height: calc(5 * 1.5/6.854);
}

h2 {
  font-size: 4.236em;
  line-height: calc(3 * 1.5/4.236);
}

article * + * {
  margin-block-start: 1.5rem;
}
    </style>
  </head>

  <body>
    <article>
    <h1>Hello, this is a title</h1>
    <p>I specifically do not want to create some application monad and access it from within splices. My major concern with this is that individual splices are now free to make database calls, much like a GraphQL API where each field is backed by an independent resolver, which can make as many database calls as it wants. I’m actually not a fan of this application monad pattern, because it makes it all too easy to have code access your logger or your database that really shouldn’t.</p>
    <h2>Here is another title!</h2>
    <p>I specifically do not want to create some application monad and access it from within splices. My major concern with this is that individual splices are now free to make database calls, much like a GraphQL API where each field is backed by an independent resolver, which can make as many database calls as it wants. I’m actually not a fan of this application monad pattern, because it makes it all too easy to have code access your logger or your database that really shouldn’t.</p>
    </article>
  </body>
</html>
```

What's going on here? I picked two large font sizes from a golden ratio type scale and gave them line heights that are multiples of the base line height. I had to eyeball the relative size. You can't just do `calc(1.5/6.854);` since the line height will be comically small. I found [this website](https://imperavi.com/books/ui-typography/elements/headings/) surprisingly helpful since it skips all the theory and just gives you a few concrete values as ideas for spacing and type scale.
