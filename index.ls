_ = require 'lodash'  # use prelude.ls ?

# Display one entity with a table listing all instances on the left and
# the attibutes of a selected entity on the right.
#
# view parameters:
#  * item - either a new item (empty Object), no item (null), or points to the currently selected item
#
#  * entity - the entity definition object
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
        @item = model.at('item')

        # the list of entity instances to be displayed
        @list = model.root.at(@getAttribute("entity").id)

        ## make entities available sorted in the local model as "_page.list"
        model.ref('_page.list', @list.sort(nameAscending))

        function nameAscending(a, b)
            aName = (a && a.name || '').toLowerCase()
            bName = (b && b.name || '').toLowerCase()
            if (aName < bName)
                return -1
            if (aName > bName)
                return 1
            return 0




    /* Only called on the client before rendering. It is possible to use jQuery in here.
     *
     *  "this" (Entity) has:
     *   - context (Context)
     *   - model (ChildModel, aka ViewModel)
     *   - model.root (Model, parent/global model)
     *   - dom (Dom) [on(), once(), addListener(), removeListener()]
     *   - app (App) [use for e.g. this.app.history.back()]
     *   - page, parent (AppPage) [e.g. page.redirect('/home')]
     *
     *  this.app.model is global model
     */
    create: (model, dom) ->
        console.log("Entity.create: ", @getAttribute("entity").id)

        # prefill the fields
        model.set('_page.comboBoxStringArrayData', <[Item1, Item2, Item3, Item4]>)

        #dom.on 'click', (e) ->
        #    @deselect unless @table.contains(e.target)


    /* Called when leaving the "page".
     *
     *   - release memory
     *   - stop reactive functions
     *   - remove client libraries
     */
    destroy: (model, dom) ->
        console.log("Entity.destroy: ", @getAttribute("entity").id)



    # The following functions can be called from the view

    items: (entityId) ->
        console.log "items for: ", entityId


    /* Add a new entity.
     *
     * When called as "add(this)" from the view, "entity" will be the object with the current model data,
     * which is the same as this.model.data
     */
    add: (entity) !->
        # entity == this.model.data
        #console.log("userid " + @model.root.get('_session.userId'))

        if !(newItem = @item.get!) || newItem.id  # add only if exists and not in db yet
            @deselect!
            return

        @item.del! # TODO: is this needed??

        @list.add(newItem)
        console.log("add: ", newItem.id)

        @emit("addedEntity", newItem)
        @emit("added" + @getAttribute("entity").id, newItem)

        # TODO: use t() with parameters for this string!
        @model.toast('success', 'New <Entity> ' + newItem.name + ' added.')

        # Wait for all model changes to go through before going to the next page, mainly because
        # in non-single-page-app mode (basically IE < 10) we want changes to save to the server before leaving the page
        @model.whenNothingPending ~>
            @app.history.push(@app.pathFor(@getAttribute("entity").id))

    select: (id) ->
        if @item.get("id") == id    # if id is already selected, deselect
            @deselect!
        else
            @item.ref(@list.at(id)) # otherwise @item points to the selected item

    deselect: ->
        @item.removeRef!

    remove: (id) ->
        console.log("remove: ", id)
        @list.del(id)

    cancel: ->
        @deselect!
        @app.history.back!
