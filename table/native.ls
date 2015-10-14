export class Table

    table: -> 'native'


    create: (model, dom) ->
        require('jquery.highlight')


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
