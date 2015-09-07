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

    components: [require('../modal')]

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
        # console.log("Entity.create: ", @getAttribute("entity").id)

        #dom.on 'keydown', (e) ~>   # this registers several dom listeners

        $(document).keydown (e) ~> @keyActions.call(@, e)

        require('datatables')
        require('datatables.bootstrap')
        require('datatables.responsive')
        require('datatables.colReorder')
        require('datatables.colResize')
        require('jquery.highlight')
        require('datatables.searchHighlight')

        $.fn.dataTable.Api.register 'deselect()', ->
            $tr = this.$('tr.selected').addClass('animate-selection')
            requestAnimationFrame -> $tr.removeClass('selected')
            setTimeout (-> $tr.removeClass('animate-selection')), 1000      # don't use transitionend because it can be prolonged with the mouse!
            return $tr

        $.fn.dataTable.Api.register 'select()', (itemId) ->
            this.$('.animate-selection').removeClass('animate-selection')   # don't animate deselect if we just change the selection
            this.$('tr#' + itemId).addClass('selected')

        # init the table
        @createTable!


        # EVENT REGISTRATION

        #model.on "all", "**", -> console.log(arguments)

        model.on "all", "_page.items.*.**", (rowindex, path, event) ~>
            # on "change" events, the path is:
            #   "" if a new item was added
            #   undefined if an item was deleted
            return if not path

            # no need to modify table data, we have the data getter in columnDefs
            row = @dtApi.row(rowindex).invalidate!
            requestAnimationFrame !-> row.draw!

            #@dtApi.state.save()

        # locale changes
        model.on "all", "$locale.**", ~>
            #@dtApi.rows().invalidate().draw()
            @dtApi.state.save()
            model.increment '_page.recreateTable'
            requestAnimationFrame !~> @createTable!



        # insert and remove -- first the captures, then the rest
        # items is an array
        model.on "insert", "_page.items", (rowindex, items) ~>
            for item in items
                row = @dtApi.row.add(item)
                requestAnimationFrame !-> row.draw!

        model.on "remove", "_page.items", (rowindex, removed) ~>
            row = @dtApi.row(rowindex).remove!
            requestAnimationFrame !-> row.draw!



        # if app.history.push() is called with render, destroy() and create() are called, but the old listener is never removed!

        if @item.get!
            @select!


    /* Called when leaving the "page" with the Entity component.
     *
     *   - release memory
     *   - stop reactive functions
     *   - remove client libraries
     */
    destroy: (model, dom) ->
        # TODO: Bug: dom is always null!
        # console.log("Entity.destroy: ", @getAttribute("entity").id, dom)

        $(document).off 'keydown'



    createTable: ->
        settings =
            language: @model.root.get("$lang.dict.strings." + @page.l(@model.get("$locale")) + ".dataTables")
            autowidth: true    # takes cpu, see also column.width
            #lenghthChange: false

            dom: "Zft" # Z for ColResize
            info: false
            paging: false
            searching: true
            searchHighlight: true

            colReorder:
                fixedColumnsLeft: 1

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
                *   targets: "respond"
                    className: "control"
                    orderable: false
                    searchable: false
                    data: null
                    render: (data, type, full, meta) ->
                        return ''

                *   targets: "attr"
                    data:  (data, type, value, meta) ~>
                        if type == 'set'
                            console.warn "setting values not supported!"
                            return

                        api = meta.settings.oInstance.api(true)
                        col = meta.col #api.colReorder.order()[meta.col]
                        try
                            col = api.colReorder.order()[meta.col]
                        catch e

                        attr = @getAttribute("entity").attributes[col - 1]
                        return "err" if not attr

                        if type == 'display' and attr.type == 'color'
                            $(api.cell(meta.row, col).node()).css("background-color", data[attr.id])

                        return @repository.getItemAttr data, attr.id, @getAttribute("entity").id, @page.l(@model.get("$locale"))

                *   targets: "actions"
                    className: "actions"
                    orderable: false
                    searchable: false
                    data: "id"
                    render: (data, type, full, meta) ->
                        return '<span class="action-references"><i class="fa fa-external-link"></i></span>&nbsp;' +
                               '<span class="action-remove"><i class="fa fa-remove"></i></span>'
            ]


        @dtApi = $(@table).DataTable(settings)

        @enableMouseSelection 'td:not(.control, .actions)'
        @enableActions!


    enableMouseSelection: (selector) ->
        body = $(@dtApi.table().body())
        body.on 'click.dtSelect', selector, (e) ~>

            # Ignore clicks inside a sub-table
            return if $(e.target).closest('tbody')[0] != body[0]

            # Check the cell actually belongs to the host DataTable (so child rows, etc, are ignored)
            cell = @dtApi.cell(e.target)
            return if not cell.any()

            rowIdx = cell.index().row
            $row = @dtApi.rows(rowIdx).nodes().to$()
            itemId = @dtApi.row(rowIdx).id()

            if $row.hasClass('selected')
                @deselect!
            else
                @dtApi.deselect!
                $row.addClass('selected')
                @select itemId

    enableActions: !->
        $tbody = $(@dtApi.table().body())

        # delete
        $tbody.on 'click', 'tr > td.actions .action-remove', (e) ~>
            @showDeleteModal @dtApi.row( $(e.target).parents('tr') ).data!

        # references
        entity = this
        $tbody.popover(
            placement: 'top'
            selector: 'span.action-references i'
            container: '#' + entity.getAttribute("entity").id
            viewport:
                selector: '#' + entity.getAttribute("entity").id
                padding: 0

            trigger: 'manual'

            html: true
            title: ->
                item = entity.dtApi.row( $(this).parents('tr') ).data!
                name = entity.getItemName item
                entity.page.t(entity.model.get("$locale"), 'dialogs.referencePopoverTitle', { ITEM: name })

            content: ->
                id = entity.dtApi.row( $(this).parents('tr') ).id!
                loc = entity.model.get("$locale")

                if entity.repository.itemReferences id, entity.getAttribute("entity").id
                    referencees = "<ul>"
                    for usage in that
                        referencees += "<li>" + entity.page.t(loc, usage.entity + '.one') + ": " + usage.item + "</li>"
                    return referencees + "</ul>"

                entity.page.t(loc, 'dialogs.referencePopoverUnused', {
                    ENTITY: entity.page.t(loc, entity.getAttribute("entity").id + '.one')
                })
        )

        $tbody.on 'click', '> tr > td.actions .action-references', (e) ~>
            @repository.fetchAllReferencingEntities @getAttribute("entity").id, (err) ->
                # fix to center the popover over the icon; currentTarget is never the span
                e.currentTarget = e.target

                $tbody.popover('toggle', e)

                # only register one() once -- better: provide a popover('hide', e)!
                $tr = $(e.target).parents('tr')
                if $.hasData($tr[0])
                    and (events = $._data( $tr[0], 'events' ))
                    and events.mouseout
                    and _.find(events.mouseout, (evt) -> evt.namespace == 'entity.popover')
                        $tr.off 'mouseout.entity.popover'
                else
                    $tr.one 'mouseout.entity.popover', -> $tbody.popover('toggle', e)


    keyActions: (e) ->
        return if not e

        switch e.keyCode
        | 13 =>
            # no form shown yet -> start new item
            if !@item.get()
                e.preventDefault!
                @add!

        | 27 => @deselect!



    # The following functions can be called from the view

    /** Create a new item. */
    add: !->
        id = @items.add {}
        @select id
        #@emit("added" + @getAttribute("entity").id, newItem)


    /* When called as "done(this)" from the view, "this", the argument, will be the object with the current model data,
     * which is the same as this.model.data
     */
    done: (entity) !->
        # entity == this.model.data
        @deselect!


    select: (id) ->
        if not id
            id = @item.get().id
        else if @item.get("id") == id    # if id is already selected, deselect
            @deselect!
            return
        else
            # otherwise @item points to the selected item and the first input is focused
            @item.ref(@items.at(id))
            @app.history.push(@app.pathFor(@getAttribute("entity").id, id), false)

        @dtApi.select(id)
        $(@form).find(':input[type!=hidden]').first().focus()
        @startValidation!


    deselect: (push = true) ->
        $tr = @dtApi.deselect!
        @stopValidation!
        @item.removeRef!

        # scroll back into view - TODO: use DataTables row().show() plugin and this to it? needed for paging tables
        $tr[0].scrollIntoView!
        if $tr.offset().top < $(window).scrollTop! + $(window).height() / 3
            $(window).scrollTop( $(window).scrollTop! - $(window).height() / 3 )

        # in case of done(): Wait for all model changes to go through before going to the next page, mainly because
        # in non-single-page-app mode (basically IE < 10) we want changes to save to the server before leaving the page
        @model.whenNothingPending ~>
            if push
                @app.history.push(@app.pathFor(@getAttribute("entity").id), false)
            else
                @app.history.replace(@app.pathFor(@getAttribute("entity").id), false)


    showDeleteModal: (item) ->
        @model.set "_page.itemToBeDeleted", item
        @deleteModal.show!

    closeDeleteModal: (action, closeCallback) ->
        if action == 'delete'
            @remove @model.get("_page.itemToBeDeleted.id")

        closeCallback!

    remove: (id) ->
        # check if the item to be deleted is still referenced
        if @repository.itemReferences id, @getAttribute("entity").id
            usages = "<ul>"
            loc = @model.get("$locale")
            for usage in that
                usages += "<li>" + @page.t(loc, usage.entity + '.one') + ": " + usage.item + "</li>"

            usages += "</ul>"

            @model.toast('error', @page.t(loc, 'messages.itemReferenced', { 'ENTITY': @page.t(loc, @getAttribute("entity").id + '.one') }) + usages)
            return

        # if id is already selected, deselect
        if @item.get("id") == id
            @deselect false

        # actually delete the item
        item = @items.del(id)

        @entityMessage item, 'messages.entityDeleted'


    getItemName: (item) ->
        @repository.getItemAttr item, 'name', @getAttribute("entity").id, @page.l(@model.get("$locale"))


    entityMessage: (item, message) ->
        loc = @model.get("$locale")

        @model.toast('success', @page.t(loc, message, {
            'ENTITY': @page.t(loc, @getAttribute("entity").id + '.one')
            'ITEM': @getItemName item
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
