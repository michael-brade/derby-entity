require! {
    derby: { Component }
}

export class Table extends Component

    table: -> 'native'

    init: (model) ->
        # filter will need the additional input path _page.filter, which is the value
        # of the search field the user enters his stuff into

        #model.ref '_page.items', @items.filter(null)    # make items available in the local model as a list with a null-filter

        # default sorting: display attribute
        entity = @entitiesApi.entity @entity.id     # get the version of entity with indexed attributes
        @sortAttr = entity.attributes[entity.display.attribute]

        @sortFn = (itemA, itemB) ~>
            itemAtext = @entitiesApi.renderAsText(itemA, @sortAttr)
            itemBtext = @entitiesApi.renderAsText(itemB, @sortAttr)

            if (itemAtext < itemBtext)
                return -1;
            if (itemAtext > itemBtext)
                return 1;

            return 0;


        model.ref '_page.items', @items.sort(@sortFn)


    create: (model, dom) ->
        require('jquery-highlight/jquery.highlight')


    sortBy: (attr) ->
        @sortAttr = attr
        @model.ref '_page.items', @items.sort(@sortFn)


    select: (id) ->
        $('.animate-selection', @table).removeClass('animate-selection')   # don't animate deselect if we just change the selection
        $('tr.selected', @table).removeClass('selected')
        $('tr#' + id, @table).addClass('selected')


    deselect: ->
        $tr = $('tr#' + @item.get!.id, @table).addClass('animate-selection')

        # scroll back into view
        $tr[0].scrollIntoView!
        if $tr.offset().top < $(window).scrollTop! + $(window).height() / 3
            $(window).scrollTop( $(window).scrollTop! - $(window).height() / 3 )

        requestAnimationFrame -> $tr.removeClass('selected')
        setTimeout (-> $tr.removeClass('animate-selection')), 1000      # don't use transitionend because it can be prolonged with the mouse!
