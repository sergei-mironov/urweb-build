#!/bin/sh
die() { echo $@ >&2 ; exit 1; }

ME=`basename $0`
CWD=`pwd`
PNAM=`echo $1 | tr '[A-Z]' '[a-z]'`

if test -z "$PNAM" ; then
  echo -n "Enter project name (use dot to take the name of current directory): "
  read PNAM
  if test -z "$PNAM" ; then
    die "usage: $ME PROJECT_NAME"
  fi
fi

if test "$PNAM" = "." ; then
  CWD=`pwd`
  PNAM=`basename $CWD`
else
  mkdir $PNAM
  cd $PNAM
fi

case "$PNAM" in
  urweb-*)
    BASE=`echo "$PNAM" | sed  's/urweb-\(.\)\(.*\)/\u\1\2/g'`
    ;;
  *)
    BASE=`echo "$PNAM" | sed  's/\(.\)\(.*\)/\u\1\2/g'`
    ;;
esac

UR=./${BASE}.ur
URS=./{$BASE}.urs

set -x
set -e

cat >$URS <<EOF

val main : unit -> transaction page

EOF

cat >$UR <<EOF


fun main {} : transaction page =
  return <xml><head/><body/></xml>

EOF

cat >build.nix <<EOF
{ libraries ? {}
, uwb ? (import <urweb-build>) { inherit libraries; }
} :

with uwb;

rec {

  oilprice = mkExe {
    name = "$BASE";
    dbms = "sqlite";

    libraries = {
      xmlw = external ./lib/urweb-xmlw;
      soup = external ./lib/urweb-soup;
      prelude = external ./lib/urweb-prelude;
      monad-pack = external ./lib/urweb-monad-pack;
      bootstrap = external ./lib/uru3/Bootstrap;
      uru = external ./lib/uru3/Uru;
    };

    statements = [
      (set "allow mime text/css")
      (set "allow url https://github.com/$USER/$PNAM*")
      (sys "list")
      (sys "char")
      (sys "string")
      (sys "option")
      (src $UR $URS)
    ];
  };

}
EOF

cat >.gitignore <<EOF
*.exe
*.sql
*.db
*_P.hs
.*
*.o
Cakegen
*urp
EOF

git init
git submodule init
git add $UR $URS build.nix

mkdir lib
cd lib

git submodule add https://github.com/grwlf/urweb-prelude
git submodule add https://github.com/grwlf/uru3
git submodule add https://github.com/grwlf/urweb-monad-pack
git submodule add https://github.com/grwlf/urweb-soup
git submodule add https://github.com/grwlf/urweb-xmlw


