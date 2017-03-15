{ libraries ? {}
, pkgs ?  import <nixpkgs> {}
} :

let

  top_libraries = libraries;

  lib = pkgs.lib;

  trace = builtins.trace;
  trace1 = desc : x:  builtins.trace "trace1: ${desc}: ${x}" x;

  urweb = import ./urweb.nix { inherit pkgs; };
  urweb-debug = import ./urweb.nix { inherit pkgs; debug = true; };

  cake3 = import ./cake3.nix { nixpkgs = pkgs; };

  removeUrSuffixes = s :
    with lib;
    removeSuffix ".ur" (removeSuffix ".urs" s);

  lastSegment = sep : str : lib.last (lib.splitString sep str);

  unhashedBasename = src : suffix : lib.removeSuffix suffix (unhashedFilename src);

  unhashedBasenameWithSuffixes = src : suffixes : lib.fold (s : acc : lib.removeSuffix s acc) (unhashedFilename src) suffixes;

  unhashedFilename = src :
    with lib; with builtins;
    let
      x =  lastSegment "/" src;
      trimmed = concatStringsSep "-" ( drop 1 (splitString "-" x));
    in
    if ((stringLength x) < 30) || (trimmed == "")
      then x
      else trimmed;

  uwModuleName = src :
    with lib; with builtins;
      replaceStrings ["-" "." "\n"] ["_" "_" ""] (
        unhashedFilename (removeUrSuffixes src)
      );

  defs = with lib ; with builtins ; rec {

    inherit (pkgs) stdenv postgresql sqlite openssl;

    sqlite_bin = if sqlite ? bin then sqlite.bin else sqlite;

    urembed = "${cake3}/bin/urembed";

    defaultDbms = "postgres";

    public = rec {

      inherit pkgs urweb urweb-debug;

      set = rule;
      rule = txt :
        let
          etxt = escape (stringToCharacters "\"'") txt;
        in
        trace "Set option: ${etxt}"
        ''
          echo "${etxt}" >> lib.urp.header
        '';

      sql = file : rule "sql ${file}";

      database = arg : rule "database ${arg}";

      link = file :
        let
          lfile = unhashedBasename file "";
        in
        trace "Linking ${file} as ${lfile}"
        ''
          cp ${file} ${lfile}
          echo "link ${lfile}" >> lib.urp.header
        '';

      obj = {compiler, source, suffixes, cflags ? [], lflags ? []} :
        let
          base = unhashedBasenameWithSuffixes source suffixes;
        in
        trace "Producing rule for compiling ${source} into ${base}.o"
        ''
          UWCC=`${urweb}/bin/urweb -print-ccompiler`
          IDir=`${urweb}/bin/urweb -print-cinclude`
          CC=`$UWCC -print-prog-name=${compiler}`
          $CC -c -I$IDir -I. ${concatStringsSep " " cflags} -o ${base}.o ${source}
          echo "link ${base}.o" >> lib.urp.header
        '' + (lib.optionalString (lflags != []) ''
          echo "link ${concatStringsSep " " lflags}" >> lib.urp.header
        '');

      obj-c = source : obj { compiler = "gcc"; suffixes = [".c"]; inherit source; };

      obj-cpp = source : obj { compiler = "g++"; suffixes = [".cpp" ".cxx" ".c++"];
                              inherit source; };
      obj-cpp-11 = source : obj { compiler = "g++"; suffixes = [".cpp" ".cxx" ".c++"];
                                  inherit source; cflags = ["-std=c++11"]; lflags = ["-lstdc++"]; };

      include = file :
        trace "Producing rule for including ${file} as ${unhashedFilename file}"
        ''
          cp ${file} ${unhashedFilename file}
          echo "include ${unhashedFilename file}" >> lib.urp.header
        '';

      ffi = file : ''
          cp ${file} ${uwModuleName file}.urs
          echo "ffi ${uwModuleName file}" >> lib.urp.header
        '';

      thirdparty = l : { thirdparty = l; };
      external = thirdparty;

      embed_ = { css ? false, js ? false } : file :
        let

          sn = uwModuleName file;
          snc = "${sn}_c";
          snj = "${sn}_j";
          flag_css = if css then "--css-mangle-urls" else "";
          flag_js = if js then "-j ${snj}.urs" else "";

          e = rec {
            urFile = "${out}/${sn}.ur";
            urpFile = "${out}/lib.urp.header";

            out = stdenv.mkDerivation {
              name = "embed";
              buildCommand = ''
                . $stdenv/setup
                mkdir -pv $out ;
                cd $out

                (
                ${urembed} -c ${snc}.c -H ${snc}.h -s ${snc}.urs  -w ${sn}.ur ${flag_css} ${flag_js} ${file}
                echo 'ffi ${snc}'
                echo 'include ${snc}.h'
                echo 'link ${snc}.o'
                ${if js then "echo 'ffi ${snj}'" else ""}
                ) > lib.urp.header


                UWCC=`${urweb}/bin/urweb -print-ccompiler`
                IDir=`${urweb}/bin/urweb -print-cinclude`
                CC=`$UWCC -print-prog-name=gcc`

                echo $CC -c -I$IDir -o ${snc}.o ${snc}.c
                $CC -c -I$IDir -o ${snc}.o ${snc}.c

              '';
            };
          };

          o = e.out;

        in
        ''
        cp ${o}/*c ${o}/*h ${o}/*urs ${o}/*ur ${o}/*o .
        cat ${o}/lib.urp.header >> lib.urp.header
        echo ${uwModuleName e.urFile} >> lib.urp.body
        '';

      embed = embed_ {} ;
      embed-css = embed_ { css = true; };
      embed-js = embed_ { js = true; };

      src = ur : urs : ''
        cp ${ur} `echo ${ur} | sed 's@.*/[a-z0-9]\+-\(.*\)@\1@'`
        cp ${urs} `echo ${urs} | sed 's@.*/[a-z0-9]\+-\(.*\)@\1@'`
        echo ${uwModuleName ur} >> lib.urp.body
        '';

      src1 = ur : ''
        cp ${ur} `echo ${ur} | sed 's@.*/[a-z0-9]\+-\(.*\)@\1@'`
        echo ${uwModuleName ur} >> lib.urp.body
        '';

      sys = nm : ''
        echo $/${nm} >> lib.urp.body
        '';

      mkUrp = {name, libraries ? {}, statements, isLib ? false, dbms ?
              defaultDbms, dbname ? "", buildInputs ? [], shellHook ? "",
              protocol ? "http" } :
        with lib; with builtins;
        let
          isExe = !isLib;
          isPostgres = dbms == "postgres";
          isSqlite = dbms == "sqlite";
          urp = if isLib then "lib.urp" else "${name}.urp";
          db = name;

          mkPostgresDB = ''
            (
            echo "#!/bin/sh"
            echo set -x
            echo ${postgresql}/bin/dropdb --if-exists ${db}
            echo ${postgresql}/bin/createdb ${db}
            echo ${postgresql}/bin/psql -f $out/${name}.sql ${db}
            ) > ./mkdb.sh
            chmod +x ./mkdb.sh
          '';

          mkSqliteDB = ''
            (
            echo "#!/bin/sh"
            echo set -x
            echo ${sqlite_bin}/bin/sqlite3 ${name}.db \< $out/${name}.sql
            ) > ./mkdb.sh
            chmod +x ./mkdb.sh
          '';

          libraries_ = rec {

            local = mapAttrs (n : v :
              if v ? thirdparty then (
                if hasAttr n top_libraries then
                    (
                    let
                      up = getAttr n top_libraries;
                    in
                      if up ? thirdparty then
                        trace "Library ${n} (source) is taken from toplevel project"
                          (getAttr n (import "${builtins.toPath up.thirdparty}/build.nix" { libraries = all; }))
                      else
                        trace "Library ${n} (pre-compiled) is taken from toplevel project"
                          up
                    )
                else
                  trace "Library ${n} (source) is taken from local project"
                    (getAttr n (import "${builtins.toPath v.thirdparty}/build.nix" { libraries = all; }))
                )
              else
                trace "Library ${n} (pre-compiled) is taken from local project"
                  v) libraries;

            all = top_libraries // local;

          };

          librariesS = mapAttrsToList (n : pkg :
            trace "Placing ${n}"
            ''
              P=`readlink -f ${pkg}`
              L=`basename $P`
              echo "library $P" >> lib.urp.header
            '')
            libraries_.local;

          urpscript = ''

            # set -x

            echo -n > lib.urp.header
            echo "link -L${openssl.out}/lib -L${sqlite.out}/lib" >> lib.urp.header
            echo -n > lib.urp.body

            ${concatStrings statements}
            ${concatStrings librariesS}
            ${optionalString isExe (sql "${name}.sql")}
            ${optionalString isPostgres (database "dbname=${name}")}
            ${optionalString isSqlite (database "dbname=${name}.db")}

            {
              cat lib.urp.header
              if test "$IN_NIX_SHELL" = 1 ; then echo 'debug' ; fi
              echo
              cat lib.urp.body
            } > ${urp}

            ${optionalString isExe "cp ${urp} lib.urp"}
          '';

        in
        stdenv.mkDerivation {
          name = "urweb-urp-${name}";
          inherit buildInputs;
          shellHook = ''
            rm -rf ./out || true
            mkdir ./out
            (cd ./out
             ${urpscript}
            )
            P=./out/${name}
            echo '$P is set to ' $P
            ${shellHook}
          '';
          buildCommand = ''
            . $stdenv/setup
            mkdir -pv $out
            cd $out
            echo "Current dir is `pwd`"

            ${urpscript}

            ${optionalString isPostgres mkPostgresDB}
            ${optionalString isSqlite mkSqliteDB}

            ${optionalString isExe "${urweb}/bin/urweb -dbms '${dbms}' -protocol '${protocol}' ${name}"}
          '';
        };

      mkLib = args : mkUrp (args // { dbms = ""; isLib = true; });
      mkExe = args : mkUrp (args // { isLib = false; });

    };
  };

in
  defs.public
