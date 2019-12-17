module.exports.apply = (app) !->

    ### i18n

    lang = require('derby-lang').app
    locale = require('derby-locale').app.locale


    app.on 'model', (model) ->
        model.fn('locale', locale)

    ## subscribe to current user and his locale strategy in each route
    app.module 'useri18n',
        load: ->
            userId = @model.get('_session.user.id')   # or any other way to determine the user
            @user = @model.at('users.' + userId)
            @addSubscriptions(@user)

        setup: ->
            @model.ref('_page.user', @user);
            @model.ref('$locale.strategies.user.locales', @user.at('local.locales'))

            @model.start '$locale.locale', '$locale', 'locale'




    ## set the locale
    # TODO:
    #   if no user logged in, use _session
    #   otherwise use _page.user.local.locales
    app.proto.setLocale = (locale) ->
        # locales is an array with preferences - just replace it with the correct locale
        @model.set('_page.user.local.locales', [locale])


    ## instead of just defining app.proto.t = lang.translate() and having to pass $lang.dict and the locale
    #  all the time, set the default parameters already here.
    app.proto.t = ($locale, path, params) ->
        if (typeof path == 'string')
            path .= split('.')

        lang.translate().call(@, @model.get('$lang.dict'), locale($locale), path, params)
