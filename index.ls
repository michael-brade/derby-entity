_ = require 'lodash'  # use prelude.ls ?

# Display one entity with a table listing all instances on the left and
# the attibutes of a selected entity on the right.
#
# view parameters:
#  * item     - either a new item (empty Object), no item (null), or points to the currently selected item
#  * entity   - the entity definition object
#  * entities - all entity definitions
#
#
# Parameters are accessible by
#   @getAttribute("entity")
# or
#   @model.get("entity")
export class Entity

    view: __dirname
    style: __dirname


    # called on the server and the client before rendering
    init: (model) !->
        model.ref('$locale', model.root.at('$locale'))

        @item = model.at('item')    # the item being added or edited - parameter, thus not _page!
        @items = model.root.at(@getAttribute("entity").id)  # the list of entity instances to be displayed

        # make items available in the local model as a list with a null-filter
        model.ref '_page.items', @items.filter(null)

        # make all dependent entity items available as lists under "_page.<entity id>"
        @getAttribute("entity").attributes.forEach( (attr) ->
            if (attr.type == 'entity')
                model.ref '_page.' + attr.entity, model.root.filter(attr.entity, null)
        )

        ## change the entities array, as well as the attributes arrays of each entity to a map
        # important to deep-copy it!
        entities = _.indexBy(model.getDeepCopy('entities'), (entity) ->
            entity.attributes = _.indexBy(entity.attributes, 'id')
            return entity.id
        )

        model.set('_page.entities', entities)


    /* Only called on the client before rendering. It is possible to use jQuery in here.
     *
     *  "this" (Entity) has:
     *   - context (Context)
     *   - model (ChildModel, aka ViewModel)
     *   - model.root (Model, parent/global model)
     *   - dom (Dom)
              on/addListener/once(type, [target=document], listener, useCapture)
              removeListener()
     *   - app (App) [use for e.g. this.app.history.back()]
     *   - page, parent (AppPage) [e.g. page.redirect('/home')]
     *
     *  this.app.model is global model
     */
    create: (model, dom) ->
        console.log("Entity.create: ", @getAttribute("entity").id)

        model.set '_page.refreshTable', 0

        #dom.on 'keydown', (e) ~>   # this registers several dom listeners

        $(document).keydown (e) ~> @keyActions.call(@, e)

        # init the table
        require('datatables')
        require('datatables.tableTools')
        require('datatables.responsive')
        require('datatables.bootstrap')

        #$(@table).DataTable(
        settings =
            autowidth: true    # takes cpu, see also column.width
            #lenghthChange: false

            dom: "t"  # "tT"
            info: false
            paging: false
            searching: false

            tableTools:
                aButtons: []        # only use selection features of TableTools
                sRowSelect: "single"
                sSelectedClass: "selected active"
                #fnRowSelected: @select

            #scrollY: 300
            #scrollCollapse: true

            stateSave: true
            stateDuration: 0
            fnStateSaveCallback: (settings, data) !->
                try localStorage.setItem 'EditorTables_' + settings.sInstance, JSON.stringify(data)

            fnStateLoadCallback: (settings) ->
                try JSON.parse(localStorage.getItem	'EditorTables_' + settings.sInstance)


            renderer: "bootstrap"
            responsive:
                details:
                    type: "column"
                    renderer: (api, rowIdx) ->
                        # Select hidden columns for the given row
                        data = api.cells(rowIdx, ':hidden').eq(0).map( (cell) ->
                            header = $(api.column(cell.column).header())

                            return '<tr>' +
                                       '<td>' +
                                           header.text() + ':' +
                                       '</td>' +
                                       '<td>' +
                                           api.cell(cell).data() +
                                       '</td>' +
                                   '</tr>'
                        ).toArray().join('');

                        return if data then $('<table/>').append(data) else false

            columnDefs:
                * className: 'control'
                  targets:   0
                ...

            order: [[ 1, "asc" ]]

        $(@table).DataTable(settings)


        # EVENT REGISTRATION

        @tableUpdater = model.on("all", "_page.items.*.**", (rowindex, pathsegment, event) ~>
            console.log("ALL: ", arguments)

            if event == 'change' && !pathsegment && rowindex != undefined # added/deleted a row
                console.log("ALL: redo table ", arguments)
                $(@table).DataTable().state.save()
                $(@table).DataTable().destroy(false)
                model.increment '_page.refreshTable'
                requestAnimationFrame !~> $(@table).DataTable(settings)
            else
                $(@table).DataTable().row("#" + @model.get("_page.items." + rowindex).id)
                    .invalidate()
                    .draw()
        )

        # locale changes
        @tableUpdater = model.on("all", "$locale.**", (index, removed) ~>
            model.increment '_page.refreshTable'
            requestAnimationFrame !~> $(@table).DataTable(settings)
        )

        # insert and remove
        /*
        @tableUpdater = model.on("remove", "_page.items", (index, removed) ~>
            console.log("REMOVE: ", index, removed)
        )

        @tableUpdater = model.on("insert", "_page.items", (index, values) ~>
            console.log("INSERT: ", index, values)
        )

        @tableUpdater = model.on("change", "_page.items", (index, values) ~>
            console.log("change: ", index, values)
        )

        # this finds the correct row to invalidate after a change
        @tableUpdater = model.on("change", "_page.items.*.**", (rowindex, tail, cur, old) ~>
            console.log("CHANGE: ", arguments)
        )
        */

        # prefill the fields

        # if app.history.push() is called with render, destroy() and create() are called, but the old listener is never removed!

        # dom.on 'click', (e) ~>
        #     @deselect! unless @table.contains(e.target)


    /* Called when leaving the "page".
     *
     *   - release memory
     *   - stop reactive functions
     *   - remove client libraries
     */
    destroy: (model, dom) ->
        console.log("Entity.destroy: ", @getAttribute("entity").id, dom)

        $(document).off 'keydown'


    keyActions: (e) ->
        return if not e

        switch e.keyCode
        | 13 =>
            # if an item is edited or new -> done, else create a new one
            if @item.get!
                @done!
            else
                @app.history.push(@app.pathFor(@getAttribute("entity").id, 'new'))

        | 27 => @cancel!


    # The following functions can be called from the view


    /* Add a new entity.
     *
     * When called as "add(this)" from the view, "this", the argument, will be the object with the current model data,
     * which is the same as this.model.data
     */
    done: (entity) !->
        # entity == this.model.data
        #console.log("userid " + @model.root.get('_session.userId'))

        if !(newItem = @item.get!) || newItem.id  # add only if exists and not in db yet
            @deselect!
            return

        @item.del! # TODO: is this needed??

        @items.add(newItem)
        console.log("add: ", newItem.id)

        @emit("addedEntity", newItem)
        @emit("added" + @getAttribute("entity").id, newItem)

        # TODO: use t() with parameters for this string! check if newItem is an object and/or .name is i18n
        @model.toast('success', 'New <Entity> ' + newItem.name + ' added.')

        # Wait for all model changes to go through before going to the next page, mainly because
        # in non-single-page-app mode (basically IE < 10) we want changes to save to the server before leaving the page
        @model.whenNothingPending ~>
            @app.history.push(@app.pathFor(@getAttribute("entity").id), false)

    select: (id) ->
        if @item.get("id") == id    # if id is already selected, deselect
            @deselect!
        else
            @item.ref(@items.at(id)) # otherwise @item points to the selected item
            @app.history.push(@app.pathFor(@getAttribute("entity").id, id), false)

    deselect: ->
        @item.removeRef!
        @app.history.push(@app.pathFor(@getAttribute("entity").id), false)

    remove: (id, e) ->
        console.log("remove: ", id)
        @items.del(id)
        e.stopPropagation! # don't select the row by bubbling up the event

    cancel: ->
        @deselect!
