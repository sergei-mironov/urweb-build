{ pkgs ? import <nixpkgs> {} , debug ? false }:

with pkgs;

stdenv.mkDerivation rec {
  basename = "urweb";
  name = basename + (pkgs.lib.optionalString debug "-debug");

  src = ./urweb;
  # fetchurl {
  #   url = "http://www.impredicative.com/ur/urweb-20161022.tgz";
  #   sha256 = "060682ad4f2andi9z7liw5z8c2nz7h6k8gd32fm3781qp49i60ks";
  # };

  buildInputs = [ openssl mlton mysql.client postgresql sqlite autoconf automake
                  libtool ];

  configureFlags = "--with-openssl=${openssl.dev}";

  preConfigure = ''
    ./autogen.sh
    sed -e 's@/usr/bin/file@${file}/bin/file@g' -i configure
    ${if debug then "export CFLAGS='-g -O0';" else ""}
    export PGHEADER="${postgresql}/include/libpq-fe.h";
    export MSHEADER="${lib.getDev mysql.client}/include/mysql/mysql.h";
    export SQHEADER="${sqlite.dev}/include/sqlite3.h";

    export CCARGS="-I$out/include \
                   -L${lib.getLib mysql.client}/lib/mysql \
                   -L${postgresql.lib}/lib \
                   -L${sqlite.out}/lib";
  '';

  # Be sure to keep the statically linked libraries
  dontDisableStatic = true;

  dontStrip = debug;

  meta = {
    description = "Advanced purely-functional web programming language";
    homepage    = "http://www.impredicative.com/ur/";
    license     = stdenv.lib.licenses.bsd3;
    platforms   = stdenv.lib.platforms.linux;
    maintainers = [ stdenv.lib.maintainers.thoughtpolice ];
  };
}
