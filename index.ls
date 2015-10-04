require! {
    lodash: _
    'derby-entities-lib/api': EntitiesApi
}

# Display one entity with a table listing all instances and
# the details, i.e., attibutes of a selected entity for editing below.
#
# view parameters:
#  * item     - if not null/undefined then it points to the currently selected item
#  * entity   - the entity definition object of the current entity to be displayed and edited
#
#
# Parameters are accessible by
#   @getAttribute("entity") or @model.get("entity")
# In the view just "entity" is enough to access them.
export class Entity

    # public instance members
    name: 'entity'
    view: __dirname
    style: __dirname

    components:
        require('d-comp-palette/modal/modal')

        require('derby-entities-lib/types/text')
        require('derby-entities-lib/types/textarea')
        require('derby-entities-lib/types/number')
        require('derby-entities-lib/types/entity')
        require('derby-entities-lib/types/color')
        require('derby-entities-lib/types/image')

    entity: null
    entitiesApi: null

    # This is basically the CTOR. Called when the component is instantiated.
    init: (model) !->
        # console.warn "Entity INIT", @getAttribute("entity").id

        model.ref('$locale', model.root.at('$locale'))

        @entity = @getAttribute("entity")
        @item = model.ref('_page.item', 'item')         # the item being added or edited - parameter, thus not _page!
        @items = model.root.at(@entity.id)              # the list of entity instances to be displayed

        model.ref '_page.items', @items.filter(null)    # make items available in the local model as a list with a null-filter

        @entitiesApi = EntitiesApi.instance!

        # make all dependent entity items available as lists under "_page.<entity id>"
        @entity.attributes.forEach (attr) ->
            if (attr.type == 'entity')
                model.ref '_page.' + attr.entity, model.root.filter(attr.entity, null)


    /* Called after the view is rendered. It is possible to use jQuery in here.
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
        #console.warn "Entity CREATE", @getAttribute("entity").id

        require('datatables')
        require('datatables.bootstrap')
        require('datatables.responsive')
        require('datatables.colReorder')
        require('datatables.colResize')
        require('jquery.highlight')
        require('datatables.searchHighlight')


        @registerDataTablesPlugins!

        # init the table
        @createTable!

        #dom.on 'keydown', (e) ~>   # this registers several dom listeners

        $(document).keydown (e) ~> @keyActions.call(@, e)

        @on 'destroy', ~>
            @dtApi.destroy true
            $(document).off 'keydown'



        # EVENT REGISTRATION

        #model.on "all", "**", -> console.log(arguments)

        # data changes
        model.on "all", "_page.items.*.**", (rowindex, path, event) ~>
            # on "change" events, the path is:
            #   "" if a new item was added
            #   undefined if an item was deleted
            return if not path

            # no need to modify table data, we have the data getter in columnDefs that gets the current data
            row = @dtApi.row(rowindex).invalidate!
            requestAnimationFrame !~>
                row.draw false
                row.show! if @item.get("id") == row.id! # only if it is selected do we want to see it

            #@dtApi.state.save()

        # locale changes
        model.on "all", "$locale.**", ~>
            #@dtApi.rows().invalidate().draw()
            @dtApi.state.save()
            model.increment '_page.recreateTable'
            requestAnimationFrame !~> @createTable!



        # insert and remove item(s) -- first the captures, then the rest
        # items is an array
        model.on "insert", "_page.items", (rowindex, items) ~>
            for item in items
                row = @dtApi.row.add(item)
            # do not use requestAnimationFrame here, otherwise select(), because it is synchronous, will be
            #  called before the tr element is created, and it won't find it.
            row.draw false

        model.on "remove", "_page.items", (rowindex, removed) ~>
            # TODO: fix Derby/Racer: removed is always empty :(
            row = @dtApi.row(rowindex)
            @entityMessage row.data!, 'messages.entityDeleted'
            requestAnimationFrame !-> row.remove!.draw false    # false means: stay on current page




        # if app.history.push() is called with render == true, destroy() and create() are called,
        # but the old listener is never removed!

        if @item.get!
            @select!




    registerDataTablesPlugins: !->
        $.fn.dataTable.Api.register 'deselect()', ->
            $tr = this.$('tr.selected').addClass('animate-selection')
            requestAnimationFrame -> $tr.removeClass('selected')
            setTimeout (-> $tr.removeClass('animate-selection')), 1000      # don't use transitionend because it can be prolonged with the mouse!
            return $tr


        $.fn.dataTable.Api.register 'select()', (itemId) ->
            this.$('.animate-selection').removeClass('animate-selection')   # don't animate deselect if we just change the selection
            this.$('tr#' + itemId).addClass('selected')


        $.fn.dataTable.Api.register 'row().show()', ->
            page_info = @table().page.info!

            # account for the "display" all case - row is already displayed
            return @ if page_info.length == -1

            row_position = @table().rows()[0].indexOf @index!

            # already on right page
            return @ if row_position >= page_info.start && row_position < page_info.end

            # find page number and go there
            page_to_display = Math.floor(row_position/page_info.length)
            @table().page(page_to_display).draw('page')

            @ # return row object



    createTable: !->
        settings =
            language: @model.root.get("$lang.dict.strings." + @page.l(@model.get("$locale")) + ".dataTables")
            autowidth: true    # takes cpu, see also column.width
            #lenghthChange: false

            dom: "Z<'dt-control'lrf>tp" # Z for ColResize
            info: false

            paging: true
            lengthMenu: [[10, 20, 30, 50, -1], [10, 20, 30, 50, @page.t(@model.get("$locale"), 'dataTables.oPaginate.sAll')]]
            pageLength: -1

            fnDrawCallback: ->
                wrapper = this.parent()
                rowsPerPage = this.fnSettings()._iDisplayLength
                rowsToShow = this.fnSettings().fnRecordsDisplay()
                minRowsPerPage = this.fnSettings().aLengthMenu[0][0]

                if rowsToShow <= rowsPerPage || rowsPerPage == -1
                    $('.dataTables_paginate', wrapper).hide!
                else
                    $('.dataTables_paginate', wrapper).show!

                if rowsToShow <= minRowsPerPage
                    $('.dataTables_length', wrapper).hide!
                else
                    $('.dataTables_length', wrapper).show!

            searching: true
            searchHighlight: true

            processing: true

            colReorder:
                fixedColumnsLeft: 1

            #scrollY: 300
            #scrollCollapse: true

            stateSave: true
            stateDuration: 0
            fnStateSaveCallback: (settings, data) !~>
                try localStorage.setItem @app.name + "_entities_" + settings.sInstance, JSON.stringify(data)

            fnStateLoadCallback: (settings) ~>
                try JSON.parse(localStorage.getItem @app.name + "_entities_" + settings.sInstance)


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

            data: @entitiesApi.items @entity.id
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
                        col = meta.col
                        try col = api.colReorder.order()[meta.col]

                        attr = @entity.attributes[col - 1]
                        throw new Error("attribute #{col - 1} not found for #{@entity.id}!") if not attr

                        if type == 'display'
                            @entitiesApi.render(data, attr, @page.l(@model.get("$locale")), api.cell(meta.row, col).node())
                        else
                            @entitiesApi.renderAsText(data, attr, @page.l(@model.get("$locale")))

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
        _this = this
        $tbody.popover(
            placement: 'top'
            selector: 'span.action-references i'
            container: '#' + _this.entity.id
            viewport:
                selector: '#' + _this.entity.id
                padding: 0

            trigger: 'manual'

            html: true
            title: ->
                item = _this.dtApi.row( $(this).parents('tr') ).data!
                name = _this.renderItemName item
                _this.page.t(_this.model.get("$locale"), 'dialogs.referencePopoverTitle', { ITEM: name })

            content: ->
                itemId = _this.dtApi.row( $(this).parents('tr') ).id!
                loc = _this.model.get("$locale")

                if _this.entitiesApi.itemReferences itemId, _this.entity.id
                    references = "<ul>"
                    for ref in that
                        references += "<li>" +
                            _this.page.t(loc, ref.entity.id + '.one') + ": " +
                            _this.entitiesApi.render(ref.item, ref.entity.attributes.name, _this.page.l loc) +
                        "</li>"
                    return references + "</ul>"

                _this.page.t(loc, 'dialogs.referencePopoverUnused', {
                    ENTITY: _this.page.t(loc, _this.entity.id + '.one')
                })
        )

        $tbody.on 'click', '> tr > td.actions .action-references', (e) !~>
            popover = $(e.target).data('bs.popover')
            $tr = $(e.target).parents('tr')

            if popover?.isInStateTrue!  # popover is currently being shown
                popover.hide!
                $tr.off 'mouseout.entity.popover'
                return

            refQueries = @entitiesApi.queryReferencingEntities @entity.id
            @model.fetch refQueries, (err) ~>
                e.currentTarget = e.target  # fix to center the popover over the icon; currentTarget is never the span
                $tbody.popover('toggle', e)

                @model.unfetch refQueries   # unfetch again to get a new result next time

                $tr.one 'mouseout.entity.popover', -> $tbody.popover('toggle', e)


    keyActions: (e) ->
        return if not e

        switch e.keyCode
        | 13 =>
            # no form shown yet -> start new item
            if not @item.get!
                e.preventDefault!
                @add!

        | 27 => @deselect!



    # The following functions are meant to be called from the view

    ## Given an item, render its attribute and return the html
    #
    renderItemName: (item) ->
        return "" if not item
        @entitiesApi.render(item, @entity.id, @page.l(@model.get("$locale")))


    /** Create a new item. */
    add: !->
        id = @items.add {}
        @select id
        #@emit("added" + @entity.id, newItem)


    /* When called as "done(this)" from the view, "this", the argument, will be the object with the current model data,
     * which is the same as this.model.data
     */
    done: (entity) !->
        # entity == this.model.data
        @deselect!


    # Select the item with the given id. If no id is given, the current item (@item) will be selected.
    # If the item is already selected, deselet it.
    select: (id) ->
        if not id
            id = @item.get().id
        else if @item.get("id") == id    # if id is already selected, deselect
            @deselect!
            return
        else
            # otherwise @item points to the selected item and the first input is focused
            @item.ref(@items.at(id))
            @app.history.push(@app.pathFor(@entity.id, id), false)

        $tr = @dtApi.select(id)
        @dtApi.row($tr).show!
        $(@form).find(':input[type!=hidden]').first().focus()
        @startValidation!


    deselect: (push = true) ->
        return if not @item.get!

        $tr = @dtApi.deselect!
        @dtApi.row($tr).show!

        # scroll back into view
        $tr[0].scrollIntoView!
        if $tr.offset().top < $(window).scrollTop! + $(window).height() / 3
            $(window).scrollTop( $(window).scrollTop! - $(window).height() / 3 )

        @stopValidation!
        @item.removeRef!

        # pressing Esc to deselect after changing the item causes a strange effect in Chrome:
        #  "if _page.item" of the view is now false, so the input fields get removed with ConditionalBlock.update(),
        # which calls replaceRange. And in replaceRange parent.removeChild(node) is called to remove the form.
        # That causes Chrome to emit #document.change, calling documentChange and creating the item again.
        # (registered by doc.addEventListener('change', documentChange, true) in derby/lib/documentListeners.js)
        # Calling removeRef! a second time fixes this.
        @item.removeRef!

        # in case of done(): Wait for all model changes to go through before going to the next page, mainly because
        # in non-single-page-app mode (basically IE < 10) we want changes to save to the server before leaving the page
        @model.whenNothingPending ~>
            if push
                @app.history.push(@app.pathFor(@entity.id), false)
            else
                @app.history.replace(@app.pathFor(@entity.id), false)


    showDeleteModal: (item) ->
        @model.set "_page.itemToBeDeleted", item
        @deleteModal.show!

    closeDeleteModal: (action, closeCallback) ->
        if action == 'delete'
            @remove @model.get("_page.itemToBeDeleted.id")

        @model.set "_page.itemToBeDeleted", undefined
        closeCallback!

    remove: (id) ->
        refQueries = @entitiesApi.queryReferencingEntities @entity.id
        @model.fetch refQueries, (err) ~>
            itemRefs = @entitiesApi.itemReferences id, @entity.id
            @model.unfetch refQueries   # unfetch again to get a new result next time

            # check if the item to be deleted is still referenced
            if itemRefs
                references = "<ul>"
                loc = @model.get("$locale")

                for ref in itemRefs
                    references += "<li>" +
                        @page.t(loc, ref.entity.id + '.one') + ": " +
                        @entitiesApi.render(ref.item, ref.entity.attributes.name, @page.l loc) +
                    "</li>"
                references += "</ul>"

                @model.toast('error', @page.t(loc, 'messages.itemReferenced', { 'ENTITY': @page.t(loc, @entity.id + '.one') }) + references)
                return

            # if id is already selected, deselect
            if @item.get("id") == id
                @deselect false

            # actually delete the item
            @items.del(id)


    entityMessage: (item, message) ->
        loc = @model.get("$locale")

        @model.toast('success', @page.t(loc, message, {
            'ENTITY': @page.t(loc, @entity.id + '.one')
            'ITEM': @renderItemName item
        }))

    startValidation: ->
        # there should be one output root path (containing an object with field IDs) and always a fn "validate()"
        # input path is to the entity object (item? or item id?)

        # @entitiesApi.forEachAttr @entity.attributes, (attrId) ~>
        #     path = "$validation.form." + attrId
        #     fn = @entitiesApi.getValidator attr, @entity.id, loc
        #     @model.start(path, "_page.item." + attrId, fn)


        @entity.attributes.forEach (attr) ~>
            if attr.i18n
                for loc in @model.get("$locale.supported")
                    path = "$validation.form." + attr.id + "_" + loc
                    if fn = @entitiesApi.getValidator attr, @entity.id, loc
                        @model.start(path, "_page.item.id", "_page.item." + attr.id + "." + loc, fn)
            else
                path = "$validation.form." + attr.id
                if fn = @entitiesApi.getValidator attr, @entity.id
                    @model.start(path, "_page.item.id", "_page.item." + attr.id, fn)

    stopValidation: ->
        @model.stopAll("$validation.form")

        # now clear the validation paths
        @model.set("$validation.form", null)
