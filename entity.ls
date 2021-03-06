require! {
    path
    # './table/datatables': { Table }
    './table/native': { Table }
    'derby-entities-lib/api': EntitiesApi
    'derby-entities-lib/types': { supportedTypeComponents }
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
export class Entity extends Table

    # public static members

    @view =
        is: 'entity'
        file: path.join __dirname, 'entity'
        style: path.join __dirname, 'entity'
        dependencies: [
            ['entity:modal', require 'd-comp-palette/modal/modal']
            ['entity:item', require 'derby-entities-lib/item/item' .Item]
        ] ++ supportedTypeComponents.map (ctor) -> [ 'entity:' + ctor.view.is, ctor ]


    # public instance members

    entity: null
    entitiesApi: null


    # This is basically the CTOR. Called when the component is instantiated.
    init: (model) !->
        model.ref('$locale', model.root.at '$locale')

        @entity = model.get('entity')
        @item = model.ref('_page.item', 'item')         # the item being added or edited - parameter, thus not _page!
        @items = model.root.at(@entity.id)              # the list of entity instances to be displayed

        @entitiesApi = EntitiesApi.instance model

        super ...



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
        super ...
        
        require 'bootstrap-sass/assets/javascripts/bootstrap/tooltip.js'
        require 'bootstrap-sass/assets/javascripts/bootstrap/popover.js'

        #dom.on 'keydown', (e) ~>   # this registers several dom listeners

        $(document).keydown (e) ~> @keyActions.call(@, e)

        @on 'destroy', ~>
            $(document).off 'keydown'



        # REFERENCES POPOVER INITIALIZATION

        _this = this

        $(@table).popover(
            placement: 'top'
            selector: 'span.action-references i'
            container: '#' + _this.entity.id
            viewport:
                selector: '#' + _this.entity.id
                padding: 0

            trigger: 'manual'

            html: true
            title: ->
                itemId = $(this).parents('tr').attr('id')
                _this.page.t(_this.model.get("$locale"), 'dialogs.referencePopoverTitle', {
                    ITEM: _this.renderItemName _this.items.get(itemId)
                })

            content: ->
                itemId = $(this).parents('tr').attr('id')
                loc = _this.model.get("$locale")

                if _this.entitiesApi.itemReferences itemId, _this.entity.id
                    references = "<ul>"
                    for ref in that
                        references += "<li>" +
                            _this.page.t(loc, ref.entity.id + '.one') + ": " +
                            _this.entitiesApi.render(ref.item, ref.entity.attributes.name) +
                        "</li>"
                    return references + "</ul>"

                _this.page.t(loc, 'dialogs.referencePopoverUnused', {
                    ENTITY: _this.page.t(loc, _this.entity.id + '.one')
                })
        )



        # EVENT REGISTRATION

        #model.on "all", "**", -> console.log(arguments)

        model.on "remove", "_page.items", (rowindex, removed) ~>
            # TODO: fix Derby/Racer: removed is always empty :(
            # after that, update datatables "remove" event registration
            @entityMessage removed, 'messages.entityDeleted'



        if @item.get!
            @select!




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
        # TODO: try to use the view with get! here so that render can eventually be dropped from the API
        @entitiesApi.render(item, @entity.id)


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

            # if app.history.push() is called with render == true, the whole component gets
            # destroyed and recreated, so don't.
            @app.history.push(@app.pathFor(@entity.id, id), false)

        super id
        @itemForm.focus!
        @startValidation!


    deselect: (push = true) ->
        return if not @item.get!

        super ...

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


    showReferences: (event) ->
        # copy native event because currentTarget will be null after @model.fetch
        e = {}
        for k, v of event
             e[k] = v

        popover = $(e.target).data('bs.popover')
        $tr = $(e.target).parents('tr')

        if popover?.isInStateTrue!  # popover is currently being shown
            popover.hide!
            $tr.off 'mouseout.entity.popover'
            return

        refQueries = @entitiesApi.queryReferencingEntities @entity.id
        @model.fetch refQueries, (err) ~>
            $(@table).popover('toggle', e)

            @model.unfetch refQueries   # unfetch again to get a new result next time

            $tr.one 'mouseout.entity.popover', ~> $(@table).popover('toggle', e)


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
                        @entitiesApi.render(ref.item, ref.entity.attributes.name) +
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
