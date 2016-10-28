Urweb-Build
-----------

This repository contains base expression for building
[Ur/Web](http://impredicative.com/ur/)
projects using nix-build tool. For the complex usage example, see
[urweb-fviewer project](https://github.com/grwlf/urweb-fviewer)


Install
-------

0. Install [Nix](http://nixos.org/nix/) package manager. You may like it so much,
   it will be the last package manager for you to install. The installation provides
   you with the `nix-build` tool and the `/nix/store` package collection.
   Note, that it is surely possible to install Nix on computers running common
   Linux distribution like Ubuntu. Installation of NixOS distribution is not
   required.

1. Add the urweb-build directory to your NIX\_PATH. This will allow Nix to
   interpret instructions like `import <urweb-build> {}` correctly.
   ```
   export NIX_PATH="$NIX_PATH:urweb-build=/path/to/urweb-build"
   ```

2. Clone the project and its submodule
   ```
   $ git clone https://github.com/grwlf/urweb-build
   $ cd urweb-build
   $ git submodule update --init
   ```
