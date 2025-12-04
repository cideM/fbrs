+++
title = "Getting a Raspberry Pi 5"
date = 2025-07-19
[taxonomies]
tags=["Raspberry Pi"]
+++

I bought a Raspberry Pi 5 because I wanted to run a temperature sensor. Mostly
so I can check how effective my portable air conditioning unit from DeLonghi
actually is in my apartment.

I naively assumed that v5 of the Pi (as opposed to my ancient v3) would support
video over USB-C, or at least have a standard USB-C port. I also assumed I
could just flash Home Assistant onto a USB stick and it would magically install
itself onto the SSD I got (together with the M.2 HAT).

My assumptions were all wrong.

It has a micro HDMI port (didn't know that existed), USB-C is for power, and,
as far as I can tell, plugging in a USB stick won't do anything.

So now I ordered a cable, a SD card, an SD card adapter, and I also added a SD
card reader for good measure. I now expect NOTHING to work, so I won't assume
that my MacBook Pro's SD card reader will work with these cards. Hence the USB
pluggable SD card reader.

I'm sure the Pi is great, but right now I just want to throw it in the trash.

---

The idea is now to copy the standard Raspberry Pi image onto the SD card and
boot the Pi from that. Then SSH into it and use the imager tool to install Home
Assistant onto the SSD card. Finally, change the boot order so the SSD card
comes first.

---

In the end I couldn't wait for my SD card to arrive. I had to re-assemble my
old desktop computer anyway, before I could sell it. So I used the NVMe slot on
its mainboard to plugin the Rasperry Pi NVMe SSD, and used `rpi-imager` to
flash Home Assistant onto it.

The Pi immediately booted from the NVMe, without having to change anything in
the boot order.

It then took me a while to realize that my old, crappy ethernet cable was
constantly wiggling itself loose, resulting in a lost connection to the HA web
interface.

Then I tried to setup my ConBee 3 stick. The web updater gave me an error (of
course), and the `GCFFlasher` tool in NixOS is some minor versions behind and
also didn't work. It took me a while to realize that that was the case. I then
had to compile it from scratch. [devenv](https://devenv.sh/) came in very
handy. I was in a hurry and had no intention to figure out how to setup a C
environment. So I just did `devenv init` and set `languages.cplusplus.enable`
to true. Worked flawlessly.

Now my sensor is finally connected. It's 27 degrees Celsius in my bed room,
apparently.

What an adventure.
