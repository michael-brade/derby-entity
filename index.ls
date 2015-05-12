_ = require 'lodash'  # use prelude.ls ?

# Display one entity with a table listing all instances on the left and
# the attibutes of a selected entity on the right.
#
export class Entity

    view: __dirname
    style: __dirname

    # called on the server and the client before rendering
    init: (model) !->
        console.log("Entity.init: ", @getAttribute("entity"))

        # @app.entities is access to all entity types, _page.entity is the currently displayed entity type
        model.set("_page.entity", _.find(@app.entities, (item) ~>
            item.id == @getAttribute("entity")))

        @newEntity = model.at('_page.newEntity')

        # the list of entity instances to be displayed
        @list = model.root.at(@getAttribute("entity"))

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




    /* Only called on the client before rendering.
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

        # prefill the fields
        model.set('_page.comboBoxStringArrayData', <[Item1, Item2, Item3, Item4]>)




    /* Called when leaving the "page".
     *
     *   - release memory
     *   - stop reactive functions
     *   - remove client libraries
     */
    destroy: (model, dom) ->
        console.log("Entity.destroy: ", @getAttribute("entity"))



    # The following functions can be called from the view


    /* Add a new Entity.
     *
     * When called as "addNewEntity(this)" from the view, "entity" will be the object with the current model data (values),
     * which is the same as this.model.data
     */
    addNewEntity: (entity) ->

        model = this.model
        # entity == model.data

        newEntity = @newEntity.del!

        #console.log("newEntity:", newEntity)
        #console.log("userid " + @model.root.get('_session.userId'))

        @list.add(newEntity) if newEntity

        @emit("addedEntity", newEntity)
        @emit("added" + @getAttribute("entity"), newEntity)
        model.toast('success', 'New <Entity> ' + newEntity.name + ' added.')
