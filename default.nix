{ libraries ? {} } :

let

  top_libraries = libraries;

  pkgs = import <nixpkgs> {};

  urweb = pkgs.urweb;

  lib = pkgs.lib;

  trace = builtins.trace;

  removeUrSuffixes = s :
    with lib;
    removeSuffix ".ur" (removeSuffix ".urs" s);

  lastSegment = sep : str : lib.last (lib.splitString sep str);

  clearNixStore = x : builtins.readFile (builtins.toFile "tmp" x);

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

    inherit (pkgs) stdenv postgresql sqlite;

    urembed = ./cake3/dist/build/urembed/urembed;

    defaultDbms = "postgres";

    public = rec {

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

      obj = {compiler, source, suffixes, cflags ? [], lflags ? []} :
        let
          base = unhashedBasenameWithSuffixes source suffixes;
        in
        trace "Compiling ${source} into ${base}.o"
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
        trace "Including ${file} as ${unhashedFilename file}"
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

          sn = clearNixStore (uwModuleName file);
          snc = "${sn}_c";
          snj = "${sn}_j";
          flag_css = if css then "--css-mangle-urls" else "";
          flag_js = if js then "-j ${snj}.urs" else "";

          e = rec {
            urFile = "${out}/${sn}.ur";
            urpFile = "${out}/lib.urp.header";

            out = stdenv.mkDerivation {
              name = "embed-${sn}";
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

      mkUrp = {name, libraries ? {}, statements, isLib ? false, dbms ?  defaultDbms, dbname ? ""} :
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
            echo ${postgres}/bin/dropdb --if-exists ${db}
            echo ${postgres}/bin/createdb ${db}
            echo ${postgres}/bin/createdb/psql -f $out/${name}.sql ${db}
            ) > ./mkdb.sh
            chmod +x ./mkdb.sh
          '';

          mkSqliteDB = ''
            (
            echo "#!/bin/sh"
            echo set -x
            echo ${sqlite}/bin/sqlite3 ${name}.db \< $out/${name}.sql
            ) > ./mkdb.sh
            chmod +x ./mkdb.sh
          '';

          libraries_ = rec {

            local = mapAttrs (n : v :
              if v ? thirdparty then (
                if hasAttr n top_libraries then
                  trace "Library ${n} is taken from the upstream"
                    (getAttr n top_libraries)
                else
                  trace "Library ${n} is imported by path"
                    (getAttr n (import "${builtins.toPath v.thirdparty}/build.nix" { libraries = all; }))
                )
              else
                trace "Library ${n} is taken by value"
                  v) libraries;

            all = top_libraries // local;

          };

          librariesS = mapAttrsToList (n : pkg :
            trace "Placing ${n}"
            ''
              echo "library ${pkg}" >> lib.urp.header
            '')
            libraries_.local;

        in
        stdenv.mkDerivation {
          name = "urweb-urp-${name}";
          buildCommand = ''
            . $stdenv/setup
            mkdir -pv $out
            cd $out
            echo "Current dir is `pwd`"

            # set -x

            echo -n > lib.urp.header
            echo -n > lib.urp.body

            ${concatStrings statements}
            ${concatStrings librariesS}
            ${optionalString isExe (sql "${name}.sql")}
            ${optionalString isPostgres (database "dbname=${name}")}
            ${optionalString isSqlite (database "dbname=${name}.db")}

            {
              cat lib.urp.header
              echo
              cat lib.urp.body
            } > ${urp}
            # rm lib.urp.header lib.urp.body

            ${optionalString isPostgres mkPostgresDB}
            ${optionalString isSqlite mkSqliteDB}

            ${optionalString isExe "${urweb}/bin/urweb -dbms ${dbms} ${name}"}
          '';
        };

      mkLib = args : mkUrp (args // { dbms = ""; isLib = true; });
      mkExe = args : mkUrp (args // { isLib = false; });

    };
  };

in
  defs.public