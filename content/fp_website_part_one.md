+++
title = "Building a Website with Haskell and Nix: Part One"
date = "2021-06-16"
[taxonomies]
tags=["nix", "haskell"]
+++

For most of my career I've kept telling people that I'm a functional programming fan. It was part of my developer identity and I always dreamed of a future where I would write Haskell and Purescript for a living. What's crazy about this is that I never finished any project in any functional programming language. I wrote some blog posts, did Advent of Code in Haskell, read books and did little experiments here and there, but I never used it for any real world application. That is, until now!

Over the past months I've been rewriting a project in Haskell, Nix and Purescript that was originally done in Javascript. The FP code lives in [this repository](https://github.com/cideM/lions-backend). Don't be confused by the `-backend` suffix, initially I didn't think I'd need any client code but then I added a tiny Purescript file for progressive enhancement. It really is the entire project, including deployment and infrastructure.

The original version was a hacked together Gatsby codebase which even included a dynamically rendered members-only area. I relied on Firebase for authentication and data storage, there were 0 tests and the whole members-only area felt like a giant hack. After all, Gatsby is used for static site generation, not for building single page applications (SPA). One of the primary reasons that I abandoned that project was that whenever I came back after a 6 month hiatus I'd be blasted with security warnings when trying to update the JS dependencies. Additionally, the project just wouldn't run after updating and, without tests, debugging a dynamic language is extremely tedious. Also, I was looking for an excuse to use extremely bleeding edge, fringe technologies, and so here we are.

This post is intended to share my experience with using Haskell, Purescript and Nix together. You don't need to know anything about these technologies, since I'll keep things very high level. There will be more posts, where I'll talk about each technology in more detail, but this post's target audience is basically everyone out there. Let's start with a very short introduction of who I am, so you can put my experience into context. In other words, if, later in the post, I proclaim that something is hard, it will help to know how experienced I am. Maybe the same thing would have been trivial for you, who knows.

## Introduction: Who I Am

I'm a self-taught developer with about 4.5 years of experience in web development, both front and back end. At work we never build an entire project from 0 to production. What I mean by this is that one person would typically work on either the UI or the back end, but not both. We have a dedicated team for platform tooling, such as Jenkins and Kubernetes, and there are subteams for authentication, and so on. That makes this project a pretty novel experience for me, since I had to deal with infrastructure, deployment, back end, front end, design, security, stakeholders, and whatever else was required.

If I had to rate my experience in each of the three technologies on a scale from beginner to expert I'd say that I'm between beginner plus and intermediate at Haskell[^1] and a beginner at Nix and Purescript. I use Nix and NixOS to manage my desktop computer and laptop but I had never used it to deploy something and I had never used the Haskell tooling to build a Haskell project. Not that I have ever built any real world project in Haskell.

Other than that, thanks to having spent about 2 years as a front end developer, I knew what I wanted to build as a UI and that I'd use bootstrap for it. Generally I was pretty confident in anything relating to client side. On the other hand I had literally 0 experience with traditional multi page websites. Everything newish at work is API plus SPA.

## The Tech

The backend is a fairly simple Haskell application, written in the most low-fi of libraries you can find[^2]. SQLite is used to store data and I use `litestream` to replicate it to S3 for backups. Speaking of S3, the site itself runs on a digital ocean droplet, but AWS is used for sending emails through SES and for database backups and Terraform state via S3. Deployment is done via [`deploy-rs`](https://github.com/serokell/deploy-rs), a Nix tool. One of the most interesting aspects is that I'm not deploying a Docker container, rather I'm deploying a NixOS system, to a droplet running NixOS. The application itself is started through Systemd. Caddy is used as a reverse proxy and handles certificates. There's a tiny amount of Purescript for progressive enhancement. Both Haskell and Purescript code is built with Nix. And if that's not crazy enough, I'm also using Nix Flakes, an experiment feature. So in other words using a fringe technology wasn't crazy enough, I also had to pick an even fringier (is that a word?) subset of that fringe technology. I'm using Bootstrap for the UI and icons and SOPS for secrets. Yes, the secrets are all there in the repository, but encrypted.

## The Experience

When I had the idea to redo the project, I thought that I'd create a single, super minimalistic Haskell file and have 80% done in a weekend. Ridiculous! If I could go back in time, I would slap myself really hard. I have no idea how many hours it took, but I'm probably well past the 100 hour mark. There were times when I was about to give up, but I'm glad that I didn't. The biggest motivation killer was not knowing how to achieve something, not even conceptually, but at the same time being absolutely certain that there wouldn't be documentation, nor a straight forward path. I'll give more concrete examples of this later. As a result, the project advanced in bursts. I'd think of a feature, have no idea how to begin, and avoid the project for a week. But when I actually sat down and got over the initial hump, I'd become crazy obsessed and would forget about basic things like food or the outside world, until I had tackled the current feature.

The most important question is: would I do it again? Would I choose the same technology for my next web project? Very unlikely. Let's talk about why.




[^1]: The Haskell community on Reddit and Discourse is full of PhDs and extremely intelligent people. Compared to them I'm probably nowhere near intermediate Haskell. But if I compare my Haskell knowledge to how much I know about other languages I work with, and how I would rate my expertise within those other communities, I chose to put myself roughtly in the intermediate range. Basically I'm assuming that the most renowned Haskellers are not necessarily representative of the overall Haskell userbase.

[^2]: I'm using plain WAI/Warp, and I removed `mtl` and `capability` from the project. I'm not even using `ReaderT`.
