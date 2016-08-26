Hi. I have repaired my build system for Ur/Web applications called urweb-build. One may say it has some properties of package manager, but in fact, all the packaging functionality is derived from Git-Submodules and Nix package manager (www.nixos.org/nix). System itself contains 300-lines long URP-file generator written in Nix expression language.

Anyway, I am quite happy with the results I get, so I'd like to invite others to try it.

Base expression is located at https://github.com/grwlf/urweb-build
The demo project is https://github.com/grwlf/urweb-fviewer

[1] and a set of projects [2] which use it. I think that , the system is usable.
