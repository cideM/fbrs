+++
title = "Making Cypress Work in NixOS"
date = "2021-03-02"
[taxonomies]
tags=["nix"]
+++

## Introduction

I recently wanted to refactor a small Javascript code base at work. Especially when working in a dynamic language, I always make sure that the code in question is well tested, because refactoring without tests is a nightmare.

In this particular code base everything interacts with the DOM, `window` and the mobile clients rendering the WebView in which this JS is running. In other words, there's nothing to unit test, unless you want to double the size of the code base just to add dependency inversion and dozens of mock implementations. Because of that, I decided to give Cypress a shot, because effortless end-to-end tests sounded like the perfect tool for this job.

On my MacBook Pro things worked perfectly. I have a little `shell.nix` which just sets up NodeJS. The project itself is built with Webpack and doesn't use Nix at all. I can therefore use normal NPM commands, and so `npm install cypress` followed by `./node_modules/.bin/cypress open` just works.

## ENOENT

At home on my desktop machine I use NixOS though. And I knew that this wasn't going to work because a project as complicated as Cypress surely uses a ton of global stuff, think dynamic linking and such. And indeed, the normal installation doesn't work at all. The first thing that failed was just `npm install`, because a Cypress dependency had to be compiled from source. This was easy enough to fix by adding `autoreconfHook` to my Nix shell. This hook makes [working with autotools](https://nixos.wiki/wiki/Packaging/Quirks_and_Caveats) a lot easier.

Now that Cypress was installed, the next step was actually running it. To my surprise, Cypress is actually [packaged in Nixpkgs](https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/web/cypress/default.nix), but you won't find it with the online search on the Nixpkgs website. I think it has something to do with this not being a top level package, but something in the web development section.

I tried this derviation with `nix-shell -p cypress` and it worked well. Unfortunately it greets you with a warning, that you're not running Cypress in the officially intended way through NPM. Additionally, the Cypress version used in your project might now be different from what you're actually using through Nix, which doesn't sound like a good idea. Sure you can override the version in the derivation, provide a new `sha256`, maybe patch missing dependencies. But I really wanted to see if I can also run Cypress by just making its dependencies available in a Nix shell.

At first I tried adding [the Cypress dependencies](https://docs.cypress.io/guides/continuous-integration/introduction.html#Dependencies) to my `mkShell` call. But that would always fail with a strange `ENOENT` error. At first I was a bit confused, because it didn't tell me what was missing. But when you search for "Nix ENOENT" you'll realize that this is because the filesystem on NixOS doesn't conform to the Filesystem Hierarchy Standard (FHS).

Luckily, there's a derivation called `buildFHSUserEnv` which does exactly that (here's an [excellent Stack Exchange answer](https://unix.stackexchange.com/questions/522822/different-methods-to-run-a-non-nixos-executable-on-nixos) with more info). I replaced `mkShell` with `buildFHSUserEnv` and tried again. This time I got an error message I could work with, namely that some dependency was missing (some shared object file). What now followed was a game of whack-a-mole where I would add the missing dependency to my Nix shell, run Cypress, watch it burn and add the next dependency.

What I ended up with is this beauty:

```text
xorg.libXScrnSaver
xorg.libXdamage
xorg.libX11
xorg.libxcb
xorg.libXcomposite
xorg.libXi
xorg.libXext
xorg.libXfixes
xorg.libXcursor
xorg.libXrender
xorg.libXrandr
mesa
cups
expat
ffmpeg
libdrm
libxkbcommon
at_spi2_atk
at_spi2_core
dbus
gdk_pixbuf
gtk3
cairo
pango
xorg.xauth
glib
nspr
atk
nss
gtk2
alsaLib
gnome2.GConf
unzip
(lib.getLib udev)
```

That's significantly more than the Cypress derivation in Nixpkgs uses. At first I thought it's because I'm using 6.5.0 whereas Nixpkgs still has 6.0.0. But after [opening a PR](https://github.com/NixOS/nixpkgs/pull/114889) to update the version, which didn't require any change in dependencies, I must admit that I have no idea why these requirements are so different. I must be missing something important here.

With the entire universe now being part of my Nix shell, things finally worked. At least sort of. Apparently `lorri` doesn't work with `buildFHSUserEnv`. So now I need to call `nix-shell` manually.

This entire episode was a mixed bag of emotions. On the one hand I'm just glad I made it work. It feels good to know exactly what Cypress requires and that all of it will be garbage collected when I stop using it. On the other hand, this just works on my MacBook. Judging by their documentation, it's not expected to work out of the box even on mainstream Linux distros.

This was another evening spent fixing something that shouldn't be broken in the first place. On the other hand I learned a few things:

- I memorized random words (libXdamage anyone?)
- `lorri` does not heart `buildFHSUserEnv`
- This will surely not work under Wayland

## What About Docker

For CI I use a Docker file that runs Cypress in non-interactive mode. I actually tried using the same (official) Dockerfile together with X11. Here's what I ended up calling:

```shell
$ docker run -it \
    -v (pwd):/e2e \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -w /e2e \
    --entrypoint cypress \
    -h "$HOSTNAME" \
    --env DISPLAY="$DISLPAY" \
    cypress/included:6.6.0 open --project .
```

This doesn't explode, but it also doesn't do anything whatsoever. It just sits there. Once I hit CTRL+C I get an error about Cypress being killed unexpectedly. That makes me think that it does start and that it's the X11 stuff that doesn't work. But who knows, I didn't want to debug this any further.

## Final Nix Shell

For posterity, here's the result. You'd want to make all of the `buildFHSUserEnv` conditional because it's not needed and will likely fail on Darwin (MacOS).

```nix
let
  sources = import ./nix/sources.nix;

  pkgs = import sources.nixpkgs { };

in
(pkgs.buildFHSUserEnv {
  name = "cypress";

  targetPkgs = pkgs: (with pkgs; [
    xorg.libXScrnSaver
    xorg.libXdamage
    xorg.libX11
    xorg.libxcb
    xorg.libXcomposite
    xorg.libXi
    xorg.libXext
    xorg.libXfixes
    xorg.libXcursor
    xorg.libXrender
    xorg.libXrandr
    mesa
    cups
    expat
    ffmpeg
    libdrm
    libxkbcommon
    at_spi2_atk
    at_spi2_core
    dbus
    gdk_pixbuf
    gtk3
    cairo
    pango
    xorg.xauth
    glib
    nspr
    atk
    nss
    gtk2
    alsaLib
    gnome2.GConf
    unzip
    (lib.getLib udev)
    # Needed to compile some of the node_modules dependencies from source
    autoreconfHook
    autoPatchelfHook

    nodePackages.prettier
    nodePackages.eslint
    nodejs
  ]);
}).env
```
