Urweb-Build
-----------

This repository contains base expression for building
[Ur/Web](http://impredicative.com/ur/) projects using nix-build tool. For an
complex usage example, see [urweb-fviewer project](https://github.com/grwlf/urweb-fviewer)


Install
-------

1. Clone the project and its submodule

    $ git clone https://github.com/grwlf/urweb-build
    $ cd urweb-build
    $ git submodule update --init

2. Build cake3 submodule (optional, required for cake3-based embedding)

    $ cd cake3
    $ cabal configure && build build

3. Add the urweb-build directory to your NIX\_PATH.

    export NIX_PATH="$NIX_PATH:urweb-build=/path/to/urweb-build"
