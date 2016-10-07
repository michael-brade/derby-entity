# A Perfect DerbyJS CRUD Component

This is a completely generic, responsive, and realtime collaborative DerbyJS component to create, read, update,
and delete entities in a database using Racer. The items of an entity are displayed using either the great jQuery
DataTables plugin, or a native DerbyJS implementation. Realtime collaboration and conflict resolution is achieved
through RacerJS and ShareJS.

That said, perfection is hard to achieve and there always seems something more that could be done. You are welcome
to provide ideas or pull requests.


## Screenshots

TODO


## Prerequisites

`derby-entity` depends on the following packages:

* **[my DerbyJS fork](https://github.com/michael-brade/derby)** because I added
    - support for component styles
    - support for subcomponents
    - support for components written using ES6 inheritance

  all of which are currently needed for `derby-entity`, `derby-entities-lib`, and `derby-select2`. Also, I merged
  Racer's pull request [238](https://github.com/derbyjs/racer/pull/238) for much better performance.

* **[derby-router](https://github.com/derbyparty/derby-router)**

* **[derby-entities-lib](https://github.com/michael-brade/derby-entities-lib)**, which contains some purely model- and
    entity-specific functions as well as view components that are needed and shared by `derby-entity` and `derby-entity-visualization`

* **[derby-sass](https://github.com/michael-brade/derby-sass)** for being able to compile scss files on the fly...
  actually, a better way is to do it using gulp, see below.

* i18n: **derby-lang**, **[derby-lang-locale](https://github.com/michael-brade/derby-lang-locale)** and
  **[derby-locale](https://github.com/michael-brade/derby-locale)**, plus the following shortcuts:

    - model path `$locale.locale` to point the current lowercase locale (en, de, ...)
    - view function `t($locale, path, params)` to return the translation of path in the current locale

  See below for detailed i18n information.

* in case you want the DataTables implementation: a browserify bundle that provides `jQuery` and exposes the following
DataTables requires:
```
require('datatables')
require('datatables.bootstrap')
require('datatables.responsive')
require('datatables.colReorder')
require('datatables.colResize')
require('jquery.highlight')
require('datatables.searchHighlight')
```

* **[my Bootstrap fork](https://github.com/michael-brade/bootstrap)** where I added proper placement support for popovers
    when combining `trigger: manual` with `container` and `selector`.

* **Font-Awesome**, use bower for that one.


## Usage

An object with entity definitions is needed to tell derby-entity what to display, it doesn't analyze the database by
itself. Each entity, the items of which are to be displayed and edited, has to be defined with all its attributes.
How that is to be done is documented in [derby-entities-lib](https://github.com/michael-brade/derby-entities-lib).

Since I wanted this component to be really real-time, I created an unusual editing model: there is no cancel or save
when you select an item, changes are instantly written to the model and visible from all clients. This carries a
drawback I haven't been able to solve yet: there is no undo (hard to implement with Derby at the moment), and it is
thus possible to inadvertently change something, maybe even without noticing. I need a good idea on this one. So far
I thought about saving the current item in local storage as soon as it is changed, but I am not sure if that is an ideal
way... how to recover it? How to display it?

Now, about technical usage: you need to load the component with

```ls
app.component require('derby-entity')
```

then in your view, use  

```html
<view name="entity" entity="{{_page.entity}}" item="{{_page.item}}" />
```

to instantiate it, and provide it with an `entity` schema object. Optionally, pass along an `item`
that should already be selected initially.


### jQuery DataTables vs native DerbyJS implementation

Depending on which version you want to use, comment the correct line in `index.ls` (line 3 or 4) and `index.scss` (line 27 or 30).


### i18n

You need to provide the following strings. All entities need to define their name to be displayed, singular and plural:

* <entity>.title
* <entity>.one

In addition to that, each entity attribute needs to be defined.

The actions and dialogs of this component are using these strings:

```
actions
{
    "title": "Actions",

    "new": "New {ITEM}",
    "edit": "Edit",
    "add": "Add",
    "delete": "Delete",
    "done": "Done",
    "cancel": "Cancel"
},

dialogs
{
    "deleteEntityTitle": "Delete {ENTITY}",

    "referencePopoverTitle": "<em>{ITEM}</em> is used by:",
    "referencePopoverUnused": "This {ENTITY} is not referenced."
},

messages
{
    "entityAdded": "New {ENTITY} \"{ITEM}\" added.",
    "deleteEntity": "Do you really want to delete this {ENTITY}?",
    "entityDeleted": "{ENTITY} \"{ITEM}\" deleted.",
    "itemReferenced": "Cannot delete {ENTITY} because it is still referenced by:"
}
```

### Style

To be more flexible I added some fine-graned color definition variables to the standard `$brand-primary`. derby-entity
uses:
```sass
    $brand-primary
    $brand-primary-light
    $brand-secondary
    $brand-aux-1-med-light
```

#### CSS Compilation

I am not using a task runner anymore, I just call the shell commands directly. I used to have gulp but found it to be
too much code and too many dependencies to download. Even though, jake seems to be a beautiful alternative should
the build become more complex in the future.

If you really want to use gulp, you can use something like the following code to compile the `scss`. Note that the sass
call has to be sync, otherwise the includes get messed up and random errors occur. Also note that I was using `nconf`,
replace those paths with whatever is correct for you.

```ls
    require! {
        lodash: _
        fs
        path
        'node-sass'
        gulp
        'merge-stream': merge    # to be able to use several streams in one task
    }

    notify     = require 'gulp-notify'
    plumber    = require 'gulp-plumber'
    sass       = require 'gulp-sass'
    prefix     = require 'gulp-autoprefixer'
    cssmin     = require 'gulp-cssmin'
    sourcemaps = require 'gulp-sourcemaps'


    # create CSS from Sass, autoprefix it to target 99% of web browsers, minifies it.
    gulp.task 'components:sass', ->
        streams = _.map componentsDirs, (dir) ->
            gulp.src path.join dir, 'index.scss'
                .pipe plumber!
                #.pipe sourcemaps.init!
                .pipe sass.sync {
                    includePaths: nconf.get 'paths:sass-includes'
                    outputStyle: if nconf.get 'debug:css' then 'expanded' else 'compressed'
                    sourceComments: nconf.get 'debug:css'

                    # url is the path in import as is, which libsass encountered.
                    # prev is the previously resolved path.
                    # done is an optional callback, either consume it or return value synchronously.
                    # @options contains this options hash
                    # @callback contains the node-style callback
                    importer: (url, prev, done) ->
                        if _.endsWith url, '.css'
                            for sassIncludePath in @options.includePaths.split path.delimiter
                                try
                                    cssData = fs.readFileSync path.resolve(process.cwd!, sassIncludePath, url), "utf8"
                                    return contents: cssData
                        else
                            return node-sass.NULL
                }
                .on 'error', sass.logError
                #.pipe prefix "> 1%"
                #.pipe cssmin keepSpecialComments: 0
                #.pipe sourcemaps.write './maps' # relative to gulp.dest
                .pipe gulp.dest dir

        merge streams
```



## TODO

* more documentation...
* drop jQuery DataTables, it is just too fat and slow (takes at least 500ms to display *after* the page
    has been rendered, and with just around 150 items it slows down to 1.5s)
* reimplement the DataTables features using what Derby already provides, as well as using:
    - [responsive table demos](http://elvery.net/demo/responsive-tables/)
    - responsive table plugins:
        * [basic table](https://github.com/jerrylow/basictable) ([demo](http://www.jerrylow.com/basictable/demo/))
        * [tablesaw](https://github.com/filamentgroup/tablesaw) ([stack table demo](http://filamentgroup.github.io/tablesaw/demo/stackonly.html))
        * [pure CSS stacked table](https://css-tricks.com/examples/ResponsiveTables/responsive.php)
        * alternative using scrolling: [zurb](http://zurb.com/playground/responsive-tables)
        * another good advanced one: http://fooplugins.github.io/FooTable/docs/getting-started.html
          I'm just not sure yet if this one does too much to the DOM to combine it with Derby
    - resize table columns:
        - [colResizable](https://github.com/alvaro-prieto/colResizable)
        - [jquery-resizable-columns](http://dobtco.github.io/jquery-resizable-columns)
    - reorder table columns:
        - http://stackoverflow.com/questions/16660672/reorder-div-table-cells-using-media-queries
        - http://stackoverflow.com/questions/19144985/flexbox-box-ordinal-group-on-table-cells
        - [dragtable](http://akottr.github.io/dragtable/)

## License

MIT

Copyright (c) 2015-2016 Michael Brade
