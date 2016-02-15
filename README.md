Install
------

1. Clone the project and its submodule

    $ git clone https://github.com/grwlf/urweb-build
    $ cd urweb-build
    $ git submodule update --init

2. Build cake3 submodule

    $ cd cake3
    $ cabal configure && build build

3. Add the following lines to your .bash\_profile

    export NIX_PATH="$NIX_PATH:urweb-build=/path/to/urweb-build"
