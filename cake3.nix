{ nixpkgs ? import <nixpkgs> {}, ghcver ? "ghc7103" } :
let
    pkgs = nixpkgs;

    stdenv = pkgs.stdenv;

    ghcenv = pkgs.haskell.packages.${ghcver};

in
ghcenv.mkDerivation {

    pname = "mtlm";
    version = "0.4.1";
    src = ./cake3;
    isLibrary = false;
    isExecutable = true;
    license = stdenv.lib.licenses.unfree;

    buildDepends = with ghcenv ; [
      haskell-src-meta template-haskell
      filepath containers text monadloc mtl
      bytestring deepseq system-filepath text-format
      directory attoparsec mime-types
      language-javascript syb parsec process
      optparse-applicative ];

    doCheck = false;
}
