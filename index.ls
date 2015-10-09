require! {
    lodash: _
    './table/datatables': { Table }
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
export class Entity extends Table

    # public instance members
    name: 'entity'
    view: __dirname
    style: __dirname

    components:
        require('d-comp-palette/modal/modal')

        require('derby-entities-lib/item/item')

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
        model.ref('$locale', model.root.at('$locale'))

        @entity = @getAttribute("entity")
        @item = model.ref('_page.item', 'item')         # the item being added or edited - parameter, thus not _page!
        @items = model.root.at(@entity.id)              # the list of entity instances to be displayed

        model.ref '_page.items', @items.filter(null)    # make items available in the local model as a list with a null-filter

        @entitiesApi = EntitiesApi.instance!


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
        #console.warn "Entity CREATE", @getAttribute("entity").id


        #dom.on 'keydown', (e) ~>   # this registers several dom listeners

        $(document).keydown (e) ~> @keyActions.call(@, e)

        @on 'destroy', ~>
            $(document).off 'keydown'



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

        super? id
        $(@page.item-form).find(':input[type!=hidden]').first().focus()
        @startValidation!


    deselect: (push = true) ->
        return if not @item.get!

        super? ...

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
