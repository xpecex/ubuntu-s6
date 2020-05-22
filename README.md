# UBUNTU-S6
[![](https://images.microbadger.com/badges/image/xpecex/ubuntu-s6.svg)](https://microbadger.com/images/xpecex/ubuntu-s6 "Get your own image badge on microbadger.com") [![](https://images.microbadger.com/badges/version/xpecex/ubuntu-s6.svg)](https://microbadger.com/images/xpecex/ubuntu-s6 "Get your own version badge on microbadger.com") [![](https://api.travis-ci.org/xpecex/ubuntu-s6.svg?branch=master)](https://travis-ci.org/github/xpecex/ubuntu-s6)

UBUNTU-S6 is an image created from Ubuntu Core with S6-Overlay


## What is UBUNTU ?
>Linux distribution based on Debian. Ubuntu is officially released in three editions: Desktop, Server, and Core for the internet of things devices and robots. All the editions can run on the computer alone, or in a virtual machine. Ubuntu is a popular operating system for cloud computing, with support for OpenStack.

>Ubuntu is developed by Canonical, and a community of other developers, under a meritocratic governance model. Canonical provides security updates and support for each Ubuntu release, starting from the release date and until the release reaches its designated end-of-life (EOL) date. Canonical generates revenue through the sale of premium services related to Ubuntu.

See more: [ubuntu.com](https://ubuntu.com/about)



## What is S6-OVERLAY ?
>The s6-overlay-builder project is a series of init scripts and utilities to ease creating Docker images using s6 as a process supervisor.

See more: [github.com/just-containers/s6-overlay](https://github.com/just-containers/s6-overlay#s6-overlay-)



# How to use
###### Tag's:

`trusty` or `14.04` - Ubuntu 14.04 LTS ([Trusty Tahr](https://wiki.ubuntu.com/TrustyTahr/ReleaseNotes))

`xenial` or `16.04` - Ubuntu 16.04 LTS ([Xenial Xerus](https://wiki.ubuntu.com/XenialXerus/ReleaseNotes))

`bionic` or `18.04` - Ubuntu 18.04 LTS ([Bionic Beaver](https://wiki.ubuntu.com/BionicBeaver/ReleaseNotes))

`eoan`   or `19.10` - Ubuntu 19.10 ([Eoan Ermine](https://wiki.ubuntu.com/EoanErmine/ReleaseNotes))

`focal` or `20.04` - Ubuntu 20.04 LTS ([Focal Fossa](https://wiki.ubuntu.com/FocalFossa/ReleaseNotes))

`groovy` or `20.10` - Ubuntu 20.10 ([Groovy Gorilla](https://wiki.ubuntu.com/GroovyGorilla/ReleaseNotes))

`latest` - Ubuntu 20.10 ([Groovy Gorilla](https://wiki.ubuntu.com/GroovyGorilla/ReleaseNotes))

`docker run -it xpecex/ubuntu-s6:<tag>`