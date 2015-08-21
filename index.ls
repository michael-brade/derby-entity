require! {
    'lodash': _
    '../../lib/entity/entity': { Entities }
}

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

    # if declared here (part of the prototype), these are not private and visible in the view!
    repository: null

    # called on the server and the client before rendering
    init: (model) !->
        model.ref('$locale', model.root.at('$locale'))

        @item = model.ref('_page.item', 'item')             # the item being added or edited - parameter, thus not _page!

        @items = model.root.at(@getAttribute("entity").id)  # the list of entity instances to be displayed
        model.ref '_page.items', @items.filter(null)        # make items available in the local model as a list with a null-filter

        @repository = new Entities(model, model.get('entities'))

        # make all dependent entity items available as lists under "_page.<entity id>"
        @getAttribute("entity").attributes.forEach (attr) ->
            if (attr.type == 'entity')
                model.ref '_page.' + attr.entity, model.root.filter(attr.entity, null)




    /* Only called on the client before rendering. It is possible to use jQuery in here.
     *
     *  "this" (Entity) has:
     *   - context (Context)
     *   - model (ChildModel, aka ViewModel)
     *   - model.root (Model, parent/global model)
     *   - dom (Dom)
     *          on/addListener/once(type, [target=document], listener, useCapture)
     *          removeListener()
     *   - app (App)
     *          use for e.g. this.app.history.back()
     *   - page, parent (AppPage)
     *          e.g. page.redirect('/home')
     *          also has all view methods that were defined as <app>.proto.something
     *
     *  this.app.model is global model
     */
    create: (model, dom) ->
        #console.log("Entity.create: ", @getAttribute("entity").id)

        #dom.on 'keydown', (e) ~>   # this registers several dom listeners

        $(document).keydown (e) ~> @keyActions.call(@, e)

        # init the table
        require('datatables')
        require('datatables.bootstrap')
        require('datatables.responsive')
        require('datatables.colVis')
        require('datatables.colReorder')

        #$(@table).DataTable(
        settings =
            autowidth: true    # takes cpu, see also column.width
            #lenghthChange: false

            dom: "t" # 'C<"clear">t' for ColVis
            info: false
            paging: false
            searching: false

            colReorder:
                fixedColumnsLeft: 1

            colVis:
                aiExclude: [ 0 ]

            #scrollY: 300
            #scrollCollapse: true

            stateSave: true
            stateDuration: 0
            fnStateSaveCallback: (settings, data) !->
                try localStorage.setItem 'EditorTables_' + settings.sInstance, JSON.stringify(data)

            fnStateLoadCallback: (settings) ->
                try JSON.parse(localStorage.getItem 'EditorTables_' + settings.sInstance)


            renderer: "bootstrap"
            responsive:
                details:
                    type: "column"
                    target: 0
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

            data: @repository.getItems @getAttribute("entity").id
            rowId: 'id'

            order: [[ 1, "asc" ]]

            columnDefs: [
                {
                    targets: "respond"
                    className: "control"
                    orderable: false
                    searchable: false
                    data: null
                    render: (data, type, full, meta) ->
                        return ''
                }
                {
                    targets: "attr"
                    data: null
                    render: (data, type, full, meta) ~>
                        #console.log("render:", @, data, type, full, meta)
                        #console.log "entity:", @getAttribute("entity")
                        #console.log "attrib:", @getAttribute("entity").attributes[meta.col - 1]

                        attr = @getAttribute("entity").attributes[meta.col - 1]
                        return "err" if not attr

                        if type == 'display' and attr.type == 'color'
                            api = meta.settings.oInstance.api(true)
                            $(api.cell(meta.row, meta.col).node()).css("background-color", full[attr.id])

                        return @repository.getItemAttr full, attr.id, @getAttribute("entity").id    # TODO: , locale!!!
                }
                {
                    targets: "actions",
                    orderable: false,
                    searchable: false,
                    data: "id",
                    render: (data, type, full, meta) ->
                        return '<span class="glyphicon glyphicon-remove" on-click="remove(' + data + ', $event)"></span>'
                }
            ]


        $.fn.dataTable.Api.register 'deselect()', ->
            this.$('tr.selected').removeClass('selected')

        $.fn.dataTable.Api.register 'select()', (itemId) ->
            this.$('tr#' + itemId).addClass('selected')

        @dtApi = $(@table).DataTable(settings)

        @enableMouseSelection 'td:not(.control, .actions)'


        # EVENT REGISTRATION

        @tableUpdater = model.on("all", "_page.items.*.**", (rowindex, pathsegment, event) ~>
            $(@table).DataTable().state.save()
        )

        # this finds the correct row to invalidate after a change
        @tableUpdater = model.on "change", "_page.items.*.**", (rowindex, path, cur, old) ~>
            # id = model.get("_page.items." + rowindex).id
            # row = @dtApi.row('#' + id)
            row = @dtApi.row(rowindex)
            item = row.data!
            _.set(item, path, cur)
            row.invalidate!
            requestAnimationFrame !~> row.draw!   # requestAnimationFrame because draw is slow

        @tableUpdater = model.on "change", "_page.items", (index, values) ~>
            console.log("change items: ", index, values)

        # locale changes
        @tableUpdater = model.on("all", "$locale.**", (index, removed) ~>
            $(@table).DataTable().state.save()
        )

        # insert and remove
        @tableUpdater = model.on "remove", "_page.items", (index, removed) ~>
            console.log("REMOVE: ", index, removed)

        @tableUpdater = model.on "insert", "_page.items", (index, values) ~>
            console.log("INSERT: ", index, values)



        #model.on "all", "**", ~> console.log(arguments)

        # prefill the fields

        # if app.history.push() is called with render, destroy() and create() are called, but the old listener is never removed!

        # dom.on 'click', (e) ~>
        #     @deselect! unless @table.contains(e.target)

        if @item.get!
            @dtApi.select(@item.get().id)
            $(@form).find(':input[type!=hidden]').first().focus()
            @startValidation!


    /* Called when leaving the "page".
     *
     *   - release memory
     *   - stop reactive functions
     *   - remove client libraries
     */
    destroy: (model, dom) ->
        # TODO: Bug: dom is always null!
        #console.log("Entity.destroy: ", @getAttribute("entity").id, dom)

        $(document).off 'keydown'



    enableMouseSelection: (selector) ->
        body = $(@dtApi.table().body())
        body.on 'click.dtSelect', selector, (e) ~>

            # Ignore clicks inside a sub-table
            if $(e.target).closest('tbody')[0] != body[0]
                return

            cell = @dtApi.cell(e.target)
            # Check the cell actually belongs to the host DataTable (so child rows, etc, are ignored)
            if not cell.any()
                return

            rowIdx = cell.index().row
            $row = @dtApi.rows(rowIdx).nodes().to$()
            itemId = @dtApi.row(rowIdx).data().id

            if $row.hasClass('selected')
                @dtApi.deselect!
                @deselect!
            else
                @dtApi.deselect!
                $row.addClass('selected')
                @select itemId



        # blurable: clicking outside of the table deselects
        $('body').on 'click.dtSelect', (e) ~>
            # if the click was inside the DataTables container, don't blur
            if $(e.target).parents().filter( @dtApi.table().container() ).length
                return

            # don't blur in edit form
            if e.target == @form or $(e.target).parents().filter(@form).length
                return

            # only blur if an element was selected
            if @item.get!
                @dtApi.deselect!
                @deselect!



    keyActions: (e) ->
        return if not e

        switch e.keyCode
        | 13 =>
            # no form shown yet -> start new item
            if !@item.get()
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

        newItem = @item.get!

        if newItem && !newItem.id  # add only if exists and not in db yet
            @items.add newItem
            #@emit("added" + @getAttribute("entity").id, newItem)

            @entityMessage newItem, 'messages.entityAdded'

        @deselect!


    select: (id) ->
        if @item.get("id") == id    # if id is already selected, deselect
            @deselect!
        else
            # otherwise @item points to the selected item and the first input is focused
            @item.ref(@items.at(id))
            $(@form).find(':input[type!=hidden]').first().focus()
            @app.history.push(@app.pathFor(@getAttribute("entity").id, id), false)
            @startValidation!

    deselect: (push = true) ->
        @stopValidation!
        @item.removeRef!
        # in case of done(): Wait for all model changes to go through before going to the next page, mainly because
        # in non-single-page-app mode (basically IE < 10) we want changes to save to the server before leaving the page
        @model.whenNothingPending ~>
            if push
                @app.history.push(@app.pathFor(@getAttribute("entity").id), false)
            else
                @app.history.replace(@app.pathFor(@getAttribute("entity").id), false)

    remove: (id) ->
        # check if the item to be deleted is still referenced
        if @repository.itemReferences id, @getAttribute("entity").id
            usages = ""
            loc = @model.get("$locale")
            for usage in that
                usages += "<br> * " + @page.t(loc, usage.entity + '.one') + " " + usage.item

            @model.toast('error', @page.t(loc, 'messages.itemReferenced', { 'ENTITY': @page.t(loc, @getAttribute("entity").id + '.one') }) + usages)
            return

        # if id is already selected, deselect
        if @item.get("id") == id
            @deselect false

        # actually delete the item
        item = @items.del(id)

        @entityMessage item, 'messages.entityDeleted'

    cancel: ->
        @dtApi.deselect!
        @deselect!

    entityMessage: (item, message) ->
        loc = @model.get("$locale")
        itemName = @repository.getItemAttr(item, 'name', @getAttribute("entity").id, @page.l(loc))

        @model.toast('success', @page.t(loc, message, {
            'ENTITY': @page.t(loc, @getAttribute("entity").id + '.one')
            'ITEM': itemName
        }))

    startValidation: ->
        # there should be one output root path (containing an object with field IDs) and always a fn "validate()"
        # input path is to the entity object (item? or item id?)

        # @repository.forEachAttr @getAttribute("entity").attributes, (attrId) ~>
        #     path = "$validation.form." + attrId
        #     fn = @repository.getValidator attr, @getAttribute("entity").id, loc
        #     @model.start(path, "_page.item." + attrId, fn)


        @getAttribute("entity").attributes.forEach (attr) ~>
            if attr.i18n
                for loc in @model.get("$locale.supported")
                    path = "$validation.form." + attr.id + "_" + loc
                    if fn = @repository.getValidator attr, @getAttribute("entity").id, loc  # TODO: performance: don't call @getAttribute each iteration?!
                        @model.start(path, "_page.item.id", "_page.item." + attr.id + "." + loc, fn)
            else
                path = "$validation.form." + attr.id
                if fn = @repository.getValidator attr, @getAttribute("entity").id
                    @model.start(path, "_page.item.id", "_page.item." + attr.id, fn)

    stopValidation: ->
        @model.stopAll("$validation.form")

        # now clear the validation paths
        @model.set("$validation.form", null)
