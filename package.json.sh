#!/usr/local/bin/lsc -cj

name: 'derby-entity'
description: 'A Perfect DerbyJS CRUD Component'
version: '1.2.2'

author:
    name: 'Michael Brade'
    email: 'brade@kde.org'

keywords:
    'derby'
    'entity'
    'crud'
    'table'

main:
    'entity.js'

repository:
    type: 'git'
    url: 'michael-brade/derby-entity'

dependencies:
    # utils
    'lodash': '4.x'
    'jquery': '3.x'
    'jquery-highlight': '3.5.x'

    'font-awesome': '4.x'
    'compass-mixins': '*'

    # derby components
    'derby-entities-lib': '1.2.x'

    'derby-ui-toast': '*'
    'd-comp-palette': '*'

peerDependencies:
    'derby': 'michael-brade/derby'
    'derby-router': '*'


devDependencies:
    'bootstrap-sass': '3.4.x'
    'sass': '1.23.x'

    'livescript': '1.6.x'
    'uglify-js': '3.6.x'
    'html-minifier': '4.x'
    'browserify': '16.x'

scripts:
    ## building

    # make sure a stash will be created and stash everything not committed
    # beware: --all would be really correct, but it also removes node_modules, so use --include-untracked instead
    prebuild: '
        npm run clean;
        touch .create_stash && git stash save --include-untracked "npm build stash";
        npm test || { npm run postbuild; exit 1; };
    '

    # build the distribution under dist: create directory structure, compile to JavaScript, uglify
    build: "
        export DEST=dist;
        export SOURCES='*.ls';
        export VIEWS='*.html';
        export ASSETS='.*\.scss|./README\.md|./package\.json';
        export IGNORE=\"./$DEST|./test|./node_modules|./docs\";

        echo \"\033[01;32mCompiling and minifying...\033[00m\";
        find -regextype posix-egrep -regex $IGNORE -prune -o -name \"$SOURCES\" -print0
        | xargs -n1 -P8 -0 sh -c '
            echo $0...;
            mkdir -p \"$DEST/`dirname $0`\";
            lsc -cp \"$0\" | uglifyjs -cm -o \"$DEST/${0%.*}.js\"';

        echo \"\033[01;32mMinifying views...\033[00m\";
        find -regextype posix-egrep -regex $IGNORE -prune -o -name \"$VIEWS\" -print0
        | xargs -n1 -P8 -0 sh -c '
            echo \"$0 -> $DEST/$0\";
            mkdir -p \"$DEST/`dirname $0`\";
            html-minifier --config-file .html-minifierrc -o \"$DEST/$0\" \"$0\"'
        | column -t -c 3;

        sass -I node_modules -I node_modules/compass-mixins/lib -I node_modules/bootstrap-sass/assets/stylesheets entity.scss -s compressed --no-source-map $DEST/entity.css;

        echo \"\033[01;32mCopying assets...\033[00m\";
        find -regextype posix-egrep -regex $IGNORE -prune -o -regex $ASSETS -print0
        | xargs -n1 -0 sh -c '
            echo \"$0 -> $DEST/$0\";
            mkdir -p \"$DEST/`dirname \"$0\"`\";
            cp -a \"$0\" \"$DEST/$0\"'
        | column -t -c 3;

        echo \"\033[01;32mDone!\033[00m\";
    "
    # restore the original situation
    postbuild: 'git stash pop --index && rm .create_stash;'

    clean: "rm -rf dist;"   # the ; at the end is very important! otherwise "npm run clean ." would delete everything

    ## docs

    docs: "
        npm run build;
        export DEST=docs;
        node $DEST/build.js;
        cd dist; browserify -s Entity entity.js -o ../$DEST/js/entity.js; cd ..;
        cp dist/entity.css $DEST/css/entity.css;
        cp dist/entity.html dist/dialogs.html $DEST;
        mkdir $DEST/table;
        cp dist/table/native.html dist/table/datatables.html $DEST/table;
    "

    ## testing

    test: 'echo "TODO: no tests specified yet";'

    ## publishing
    release: "npm run build; cd dist; npm publish;"

engines:
    node: '>= 4.x'

license: 'MIT'

bugs:
    url: 'https://github.com/michael-brade/derby-entity/issues'

homepage: 'https://github.com/michael-brade/derby-entity#readme'
