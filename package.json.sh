#!/usr/local/bin/lsc -cj

name: 'derby-entity'
description: 'A Perfect DerbyJS CRUD Component'
version: '1.2.1'

author:
    name: 'Michael Brade'
    email: 'brade@kde.org'

keywords:
    'derby'
    'entity'
    'crud'
    'table'


repository:
    type: 'git'
    url: 'michael-brade/derby-entity'

dependencies:
    # utils
    'lodash': '4.x'

    # derby components
    'derby-entities-lib': '1.2.x'

    'derby-ui-toast': '*'
    'd-comp-palette': '*'

peerDependencies:
    'derby': 'michael-brade/derby'
    'derby-router': '*'


devDependencies:
    'livescript': '1.5.x'
    'node-sass': '3.10.x'
    'uglify-js': '2.7.x'
    'html-minifier': '3.x'

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
    # TODO: compile scss to dist/css
    build: "
        export DEST=dist;
        export SOURCES='*.ls';
        export VIEWS='*.html';
        export ASSETS='.*\.scss|./README\.md|./package\.json';
        export IGNORE=\"./$DEST|./test|./node_modules\";

        echo \"\033[01;32mCompiling and minifying...\033[00m\";
        find -regextype posix-egrep -regex $IGNORE -prune -o -name \"$SOURCES\" -print0
        | xargs -n1 -P8 -0 sh -c '
            echo $0...;
            mkdir -p \"$DEST/`dirname $0`\";
            lsc -cp \"$0\" | uglifyjs - -cm -o \"$DEST/${0%.*}.js\"';

        echo \"\033[01;32mMinifying views...\033[00m\";
        find -regextype posix-egrep -regex $IGNORE -prune -o -name \"$VIEWS\" -print0
        | xargs -n1 -P8 -0 sh -c '
            echo \"$0 -> $DEST/$0\";
            mkdir -p \"$DEST/`dirname $0`\";
            html-minifier --config-file .html-minifierrc -o \"$DEST/$0\" \"$0\"'
        | column -t -c 3;

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
