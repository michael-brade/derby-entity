#!/usr/local/bin/lsc -cj

name: 'derby-entity'
description: 'A Perfect DerbyJS CRUD Component'
version: '1.1.0'

author:
    name: 'Michael Brade'
    email: 'brade@kde.org'

keywords:
    'derby'
    'entity'
    'crud'


repository:
    type: 'git'
    url: 'michael-brade/derby-entity'

dependencies:
    # utils
    'lodash': '3.x'

    # derby components
    'derby-entities-lib': '1.1.x'
    'derby-entity-select2': '1.0.x'

    'derby-ui-toast': '*'
    'd-comp-palette': '*'

peerDependencies:
    'derby': 'michael-brade/derby'



devDependencies:
    'livescript': '1.x'
    'node-sass': '3.3.x'

    # possibly, depending on how you set it up
    'browserify-livescript': '0.2.x'

engines:
    node: '4.x'

license: 'MIT'

bugs:
    url: 'https://github.com/michael-brade/derby-entity/issues'

homepage: 'https://github.com/michael-brade/derby-entity#readme'
