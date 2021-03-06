require! {
    derby: { Component }
}

export class Table extends Component

    table: -> 'datatables'

    init: (model) ->
        model.ref '_page.items', @items.filter(null)    # make items available in the local model as a list with a null-filter


    create: (model, dom) ->

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

        @on 'destroy', ~>
            @dtApi.destroy true



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


    select: (id) ->
        $tr = @dtApi.select(id)
        @dtApi.row($tr).show!

    deselect: ->
        $tr = @dtApi.deselect!
        @dtApi.row($tr).show!

        # scroll back into view
        $tr[0].scrollIntoView!
        if $tr.offset().top < $(window).scrollTop! + $(window).height() / 3
            $(window).scrollTop( $(window).scrollTop! - $(window).height() / 3 )


    /*** PUBLIC API ENDS HERE ***/


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
            language: @model.root.get("$lang.dict.strings." + @model.get("$locale.locale") + ".dataTables")
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
                            @entitiesApi.render(data, attr, api.cell(meta.row, col).node())
                        else
                            @entitiesApi.renderAsText(data, attr)

                *   targets: "actions"
                    className: "actions"
                    orderable: false
                    searchable: false
                    data: "id"
                    render: (data, type, full, meta) ->
                        return '<span class="action-references"><i class="fa fa-external-link"></i></span>&nbsp;' +
                               '<span class="action-remove"><i class="fa fa-remove"></i></span>'
            ]

        console.time("init table")
        # console.profile("init table")

        @dtApi = $(@table).DataTable(settings)

        console.timeEnd("init table")
        # console.profileEnd("init table")

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
        $tbody.on 'click', '> tr > td.actions .action-references', (e) !~>
            @showReferences e
