+++
title = "Two Years of Nix & Home Manager"
date = 2023-06-05
[taxonomies]
tags=["Nix", "Home Manager"]
+++

## Summary

After utilizing Nix and HM to manage both a MacOS and a NixOS
machine for a solid two years, I can confidently say that the experience
has been incredibly pleasant overall. Reflecting back, the major
advantages that stood out, and continue to do so, include:

- Seamless project environment management with
  [`nix-direnv`](https://github.com/nix-community/nix-direnv), which, in
  my opinion, is unmatched.
- Having a single package manager instead of one for each application.
  This not only simplifies package management but also enables upgrading
  everything with just a single command. Nix has effectively replaced
  the following plugin/package managers for me:
  - Neovim plugins
  - Fish shell plugins
  - System packages (for example AUR, MacPorts)
  - tmux plugins
  - Language package managers (npm, cargo, and so on)[^1]
  - Visual Studio Code plugins

At one point, I briefly reverted back to using only MacPorts and a basic
dotfiles repository. I questioned whether the added complexity of Nix
and HM was truly worth it. But without the integration between
`nix-direnv` and my shell, switching between projects became a chore.
Upgrading packages now meant interacting with multiple, different upgrade
processes instead of just a single command. Plus, if I ever decide
to upgrade my desktop computer and go back to Linux, I'll have to
painstakingly sync both setups manually.

If you're content with your current setup, then the effort of learning
Nix might not outweigh its benefits.

However, if you see room for improvement, I strongly recommend exploring
Nix.

## What worked well

### Unparalleled Reliability

If you're someone who enjoys tinkering with Linux, then in my opinion,
there's simply no better alternative to NixOS. The ability to replace
your boot loader, shell, Kernel parameters, and practically anything you
want, reboot, and effortlessly revert back to the previous state of
your system is an absolute superpower. It eradicates any fear of having
to troubleshoot issues from a rescue USB stick, thereby empowering you
to boldly experiment. The same level of confidence extends to system
updates as well. I can't recall a single instance where I was unable to
use my NixOS system.

Another aspect I appreciate is how NixOS configuration options often go
beyond merely mirroring the configuration of the underlying software in
a one-to-one manner. Take, for instance, enabling wireplumber, which not
only modifies files in `/etc/` but also adds a
`DBUS_SESSION_BUS_ADDRESS` environment variable, and so on. Another
example is enabling `bspwm`, a tiling window manager. Setting just
`bspwm.enable = true;` will install the package and add [xserver
configuration](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/x11/window-managers/bspwm.nix)
that also gets rid of some annoying issues in certain Java GUI
applicatoins. This relieves me from meticulously keeping track of
interactions between various services and tools. NixOS generally strikes
a good balance between making these options genuinely useful while not
having too many unexpected consequences. Ultimately, the ability to
enable something and have it reliably do the right thing is something I
really came to appreciate.

### Effortless Configuration Sharing

Sharing configuration between MacOS and NixOS has been very straight
forward overall. My approach is to have a `.nix` file to consolidate
shared packages and configuration. This file is then imported into the
host-specific `home.nix` file, which can include additional packages and
configuration specific to each host. To illustrate, here are two code
snippets demonstrating how to integrate tmux with the system clipboard
on each respective platform. Both snippets are merged with the shared
tmux configuration (in this case by simply appending the strings to the
end of the shared configuration).

```nix
# NixOS
{
  programs.tmux.extraConfig = ''
    bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "${pkgs.xsel}/bin/xsel -i --clipboard"
  '';
}
```

```nix
# MacOS
{
  programs.tmux.extraConfig = ''
    bind-key -T copy-mode-vi y send -X copy-pipe-and-cancel "pbcopy"
  '';
}
```

### Project Environments With `nix-direnv`

One of the features I really missed when attempting to go back to a
simpler setup was the ability to seamlessly switch between different
work repositories. Each repository often required a distinct set of
tools, such as varying NodeJS versions, language toolchains, database
clients, S3 tools, and so on. Even in 2023, it appears that efficiently
managing this is still an unsolved ~~mystery~~ problem.

You can put all of these things in a Docker container but to be honest,
I have never found developing through a Docker container a pleasant
experience. So in the end, at last at $DAY_JOB, we have Docker
containers to run the actual software either locally or in production,
but the development environment itself is something every developer
handles differently. Most people rely on a mix of global tools that
hopefully don't conflict and a gazillion version managers.

What I do is create a repository that has a single `flake.nix` file. In
that file, I define "development shells" for each project, like so:

```nix
{
  shared = [
    google-cloud-sdk
    kubectl # pinned to a specific version
    aws-mfa
  ];

  project1 = {
    buildInputs = [
      go
      go-migrate pgformatter
      gopls
      go-tools
      golangci-lint
      go-outline
      gopkgs
      delve
    ];
  };

  project2 = {
    buildInputs = [
      nodePackages.typescript-language-server
      nodePackages.prettier
    ];
  };
}
```

In every project directory, I then add a `.envrc` file, where I tell
`nix-direnv` to [use one of those development
environments](https://github.com/nix-community/nix-direnv#flakes-support) with
a simple one-liner like this: `use flake /path/to/flake#project`. I can also
put other code in that `.envrc` file[^2], but that's not really different from
using the non-nix version of `direnv`. Whenever I enter one of those
directories, my shell magically has the tools I specified for that project
available on `PATH`. This works with different shells (I use Fish for example).

In other words:

```shell
$ which go
$ cd my_project/
$ which go
/nix/store/rhmf86rrq5sksqhg1544dq6hvxrr5cvg-go-1.20.4/bin/go
$ cd ~
$ which go
```

I can not live without this feature anymore. The combination of
effortlessly having per-project tools and being able to maintain those
environments in a different repository if needed (so your coworkers
don't need to know about Nix), is just so good! Even if you don't want
to use `nix-direnv` I really encourage you to look at the non-Nix
version of [`direnv`](https://direnv.net/)!

### Simple but not Easy

According to [Rich Hickey](https://www.youtube.com/watch?v=LKtk3HCgTa8),
the distinction between "easy" and "simple" lies in the level of effort
and complexity involved. "Easy" implies something intuitive and
effortless initially but can lead to increasing complexity in the long
run. On the other hand, "simple" requires more upfront investment but
results in overall reduced complexity. This is how I'll be using these
terms in this chapter.

Recently, I contributed two packages to the MacPorts package repository.
While the onboarding process was considerably easier compared to Nix, it
didn't take long until I encountered issues related to leftover build
artifacts. Each build would yield different output, with the first build
often returning errors that didn't appear in subsequent ones. To address
this, I resorted to deleting certain folders containing build-related
files, hoping to restore a clean build environment. In other words, it
was easy to get started but difficult to reach a comprehensive
understanding of what's actually going on.

With Nix on the other hand, the first steps are anything but intuitive.
Nix is a functional programming language, which in itself can be quite
demanding. Because it is used in so many different areas[^3],
documentation is often abstract. There's no such thing as a "definitive
10-step guide for managing your home folder with Nix" in the official
manual. Compare this to MacPorts, which has a much narrower focus, and
as such the documentation can be a lot more specific and hands-on.

However, Nix also embodies a sense of simplicity: same input, same
output. This concept is tremendously powerful and empowering. It enables
a highly motivating edit-compile feedback loop. I believe it is this
simplicity that led me to contribute to Nixpkgs, making it the first
package repository I ever contributed to.

Undoubtedly, certain aspects of Nix can be challenging. For instance,
dealing with dependencies in JavaScript and Python applications can be
incredibly messy. I've come to really hate Javascript's `postInstall`
scripts, which serve as an escape hatch allowing arbitrary actions
during a build. They are often used to install binaries that are then
called by the Javascript code of that package. Consequently, some
packages incorporate a makeshift, ad-hoc package manager that determines
the platform, downloads a binary, and places it in the hopefully correct
location. However Nix doesn't allow network requests in its build
sandbox. Therefore, getting such Javascript packages to play nicely with
Nix can be a challenge.

And that's just one example. In general, the more complex and messy the
packaging process, the greater the difficulty in making it work
seamlessly with Nix.

But I believe that the eventual simplicity of Nix is often (not always)
worth the initial cost.

### Streamlined Package Management

When I switched from Nix to MacPorts, it became evident how many package
managers I relied on:

- MacPorts
- Fish plugin manager
- Vim/Neovim plugin manager
- Visual Studio Code plugin manager
- tmux plugin manager
- NPM or Yarn

However, with Nix and HM, I can consolidate all of these into
just Nix. This means I have a single command to update all my packages
across all my tools, a single command to install everything on a new
machine, and a unified set of concepts and knowledge applicable to all
my packaging needs.

How much this matters to you depends on how many package and plugin
managers you use right now. How well they work, how often you need to
fiddle with what they do. Many of my colleagues are content with using
an IntelliJ IDE and Homebrew, and that works perfectly well for them.

There is one aspect of this I want to emphasize. Even though Nixpkgs is already
one of the biggest package repositories out there, I occasionally come across
missing packages. For instance, as of writing this article,
[`ojroques/nvim-lspfuzzy`](https://github.com/ojroques/nvim-lspfuzzy) is not
part of Nixpkgs. In the absence of Nix, I would have resorted to manually
cloning the repository and placing the files in the appropriate directories (or
install a Neovim plugin manager). However, with Nix, I can leverage the power
of _overlays_[^4]:

```nix
(self: super: {
  vimPlugins =
    super.vimPlugins
    // {
      lspfuzzy = super.pkgs.vimUtils.buildVimPluginFrom2Nix rec {
        version = "latest";
        pname = "lspfuzzy";
        src = lspfuzzy;
      };
    };
})
```

Applying this overlay to the Nix package set allows me to introduce a
new package called nix-env-fish into my locally available packages. It
works as a form of dependency injection, seamlessly integrating into my
configuration as if it were a part of Nixpkgs itself. The fact that it's
added through an overlay doesn't matter.

Overlays are a bit like a gateway drug into authoring your own packages.
They let you quickly experiment with something locally, while still
using the infrastructure of Nixpkgs. Once your overlay is stable, it's
easy to convert it into a standalone package and create a pull request.

## What didn't work so well {#what-didnt-work-so-well}

### Missing or Broken GUI Apps

At times, certain GUI apps on NixOS would simply display a black screen.
This issue appeared to be specific to Electron-based applications,
although I never found the motivation to debug these problems. On MacOS,
I faced another limitation as not all the GUI apps I wanted to install
were available. Some apps were either unavailable for the Darwin
platform or failed to launch. For example, [Sublime Text
Editor](https://search.nixos.org/packages?channel=unstable&show=sublime4&from=0&size=50&sort=relevance&type=packages&query=sublime),
[Obsidian](https://search.nixos.org/packages?channel=unstable&show=obsidian&from=0&size=50&sort=relevance&type=packages&query=obsidian),
and [Ledger Live
Desktop](https://search.nixos.org/packages?channel=unstable&show=ledger-live-desktop&from=0&size=50&sort=relevance&type=packages&query=ledger)
are examples of applications that are not accessible for Darwin systems,
as can be seen in each respective package's "Platforms" list.

### Small Frustrations

A Nix and HM setup can come with its fair share of small
nuisances. I sometimes wish I were the type of person who kept a
meticulous journal with tags and all, as the issues I've listed here are
just the few that I can recall from memory.

One of the trade-offs of having Nix manage your configuration files is
that it's more or less no longer possible to edit them directly in place
(which is a somewhat obvious requirement for such a highly deterministic
build system). Even if you do make edits, they will eventually be
overwritten. If you tweak your Vim configuration file every five
minutes then this will really annoy you.

On MacOS, launcher entries for applications may be missing. For example,
if I install the Alacritty terminal emulator through HM, I
can't simply use "cmd+space" and type "Alacritty", to launch it because
MacOS is unaware of its existence. Although HM creates the necessary
files, Finder does not index them. Here's the [GitHub
issue](https://github.com/nix-community/home-manager/issues/1341).

I was also missing some man pages at some point, but I think that was
fixable, and I think that [this is the now closed GitHub
issue](https://github.com/nix-community/home-manager/issues/432).

Integrating Nix and HM with Fish requires you to find some plugins
first. Initially I used
[https://github.com/lilyball/nix-env.fish](https://github.com/lilyball/nix-env.fish)
but later I switched to [https://github.com/kidonng/nix.fish](https://github.com/kidonng/nix.fish).

It took a few years until Visual Studio Code in Nix was in a state where
most things just work. It's still a bit complicated to setup because
there are various options that all have some pros and cons. You can see
the [documentation here](https://nixos.wiki/wiki/Visual_Studio_Code).
Also getting LiveShare to work on MacOS and NixOS requires you to be a
bit mindful about which plugins you need on which platform.

Nix also demands more hard disk space, and the installer needs to create
a new volume. Fortunately, the [Determinate Nix
Installer](https://determinate.systems/posts/determinate-nix-installer)
project nowadays provides a straightforward installation process on
MacOS.

### Added Complexity & Home Manager Abstractions

This was the reason I tried to live without Nix and HM for a while!
Nixpkgs is an enormous repository, and the Nix language itself adds to
the complexity. According to `tokei`, the
[`nix-community/home-manager`](https://github.com/nix-community/home-manager)
repository has over 50_000 lines of code! It can be a bit unsettling to
think about the sheer number of the layers of technology involved in
"just" installing a few applications and placing files in specific
locations.

Of course, for the most part you don't care how many lines of code go
into `home-manager`. Similar to how I have no idea about the size of Vim
and Neovim, yet I rely on them daily.

However, you'll notice the complexity when something breaks. Fixing
issues in individual packages is usually manageable, but problems
stemming from the underlying infrastructure of Nixpkgs can be daunting.
Nix, being a functional, domain-specific language, is used with a
significant level of abstraction in Nixpkgs. It can be frustratingly
difficult to trace the origin of certain function arguments for example.

I also have some doubts about the level of abstraction in HM.
For instance, the existence of options like
[`programs.neovim.enable`](https://nix-community.github.io/home-manager/options.html#opt-programs.neovim.enable)
in both HM and
[NixOS](https://search.nixos.org/options?channel=unstable&show=programs.neovim.enable&from=0&size=50&sort=relevance&type=packages&query=neovim)
is highly confusing. And it's not just confusing for beginners; I still
find it confusing after 2 years. Are these options equivalent? How can I
spot the differences? Options like `programs.alacritty.settings` allow
you to write Nix code that gets translated into a `.yaml` file, which is
neat, I suppose. However, I personally prefer the less sophisticated
approach of directly writing `.yaml` inline within my Nix script (or
write a separate `.yaml` file and import it). Otherwise I need to
understand both the upstream configuration and the Nix equivalent of it.
Many packages also have an `extraConfig` option for adding configuration
that doesn't have a HM equivalent. This abstraction level
sometimes feels a bit off. I assume it creates a significant maintenance
burden, as upstream configuration options need to be reflected in Home
Manager options. Of course, you can ignore all this and manually create
your configuration files with `xdg.configFile`.

I'd probably find the level of abstraction of
[`nix-darwin`](https://github.com/LnL7/nix-darwin) better, but I haven't
had the time and energy to try it yet.

At the end of the day I really don't need the per-user installation of
packages and elaborate modules that HM gives me. I'd be perfectly
content with providing a list of packages to install system-wide and a
few basic primitives to generate configuration files in my home folder.
Having said all that, I'm still a happy HM user.

## Exploring Life Beyond Nix & Home Manager

I recently decided to give living without Nix and HM a try.
This decision was actually inspired by a brief conversation I had with
[Gabriella Gonzalez](https://github.com/Gabriella439) years ago. I had
noticed her using an incredibly simple setup during some Twitch streams,
so I reached out and asked about it. She kindly provided thoughtful
replies (thank you, Gabriella!) and, at least back then, seemed to be
using a mostly stock macOS setup. That got me thinking... if someone
like her can live without a billion fancy shell integrations and still
be a billion times more productive than me, maybe I could achieve the
same level of competence by emulating her approach?[^5]

So I reverted to a [simpler
configuration](https://github.com/cideM/dotfiles-simple) where I relied
on MacPorts for installing my system-wide tools. I kept Nix around for
running `nix develop` and accessing the project-specific environments I
mentioned earlier. However, I abandoned the fancy automation.

So, how did it turn out?

Well, typing `nix develop ~/path/to/flake#project` a thousand times a
day isn't exactly fun. And I dread the day I install a Neovim plugin
that requires a Rust toolchain. Instead of using a Vim/Neovim plugin
manager, I resorted to learning how packages work and ended up becoming
my own package manager with Git submodules. As for tmux and Fish
plugins, I simply stopped using tmux altogether. It's a bit annoying
because Alacritty lacks splits and tabs. Going without Fish plugins
means living without a Git prompt in my shell, as the bundled Git
prompts are unusable in large repositories like `nixpkgs`. Without
`nix-direnv`, I no longer have the convenience of automatic sourcing of
environment variables. Every time I try to replay a database dump on my
local Postgres instance, I'm reminded of this when I encounter the error
message: `AWS_S3_REGION is not set.`

Also, it's quite funny when you run `nix-store --gc` to reclaim some
space, only to realize that `nix-direnv` was also preventing your
development environments from being cleaned up (check out this [this
insightful
post](https://ianthehenry.com/posts/how-to-learn-nix/saving-your-shell/)).

But here's the thing: Despite its flaws and complexity, I've become
incredibly accustomed to the convenience of running `nix flake update`
and having almost everything on my system updated. I've grown accustomed
to typing `cd` and witnessing my environment magically and instantly
switch.

## Resources

- [Determinate Systems Nix Installer](https://determinate.systems/posts/determinate-nix-installer)
- [`kidonng/nix.fish`](https://github.com/kidonng/nix.fish)
- [My dotfiles](https://github.com/cideM/dotfiles/)
- [Home Manager](https://nix-community.github.io/home-manager/)
- [Very good blog post series about Nix](https://ianthehenry.com/posts/how-to-learn-nix/)
- [Twitch videos by (among others) Gabriella Gonzalez](https://www.twitch.tv/videos/824384307)
- [Nix direnv](https://github.com/nix-community/nix-direnv)
  - [Nix direnv project shells](https://github.com/nix-community/nix-direnv#flakes-support)

---

[^1]:
    Sometimes you want to install a tool that's not yet packaged up in
    your system package manager of choice. In such cases it can be
    tempting to just use something like `npm` or `cargo` to install
    something globally in your system.

[^2]:
    I really like
    [`PATH_add`](https://direnv.net/man/direnv-stdlib.1.html#codepathadd-ltpathgtcode)
    to automatically add `./node_modules/.bin/` to your `$PATH` whenever
    you are in a NodeJS project. That way it's trivial to use the
    project-local formatter and linter, and so on.

[^3]:
    You can manage your developer machine, build applications (kind of
    like Bazel), deploy code to remote machines, define those machines,
    and more.

[^4]: I've ellided some details. You also need to add this input to your Nix Flake, so it can keep track of which version you've installed. This is done like this:

```nix
{
  lspfuzzy.url = "github:ojroques/nvim-lspfuzzy";
  lspfuzzy.flake = false;
}
```

[^5]: It didn't work.
