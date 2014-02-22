_ = require 'underscore'
async = require 'async'

cloneCallbacks = (oldCallbacks = {}) ->
  result = {}
  for key of oldCallbacks
    result = (oldCallbacks[key] ? []).slice()
  return result

class Controller
  @makeCallbacksLocal: ->
    unless @hasOwnProperty('_callbacks')
      @_callbacks = cloneCallbacks @_callbacks
    return

  @callback: (event, method, options = {}) ->
    @makeCallbacksLocal()
    @_callbacks[event] ?= []
    @_callbacks[event].push method: method, options: options
    return

  @callbacks: (event) ->
    @makeCallbacksLocal()
    (@_callbacks[event] ? []).slice()

  @before: -> @callback 'before', arguments...
  @after: -> @callback 'after', arguments...

  @handle: (params, req, res, next) ->
    {action} = params
    throw new req.HTTPError 404 unless @prototype[action]

    instance = new this params, req, res

    array = @callbacks('before')
    array = array.concat(action)
    array = array.concat('generateNav')
    array = array.concat('render')
    array = array.concat @callbacks('after')

    run = (entry, done) ->
      if typeof entry is 'string'
        entry = method: entry, options: {}
      fn = instance[entry.method]
      if fn.length > 0
        fn.call instance, done
      else
        fn.call instance
        process.nextTick done

    async.eachSeries array, run, (err) =>
      next err unless instance.rendered

  constructor: (@params, @req, @res) ->
    @templateParent ?= @params.controller
    @template ?= @params.action
    @data = @req.body ? {}

  render: (done) ->
    vars = {}
    vars[k] = v for own k, v of @ when typeof k isnt 'function'
    @res.render "#{@templateParent}/#{@template}", vars, (err, html) =>
      return done err if err
      @rendered = true
      @res.send html
      done()

  redirectTo: (url, {status} = {}) ->
    if status?
      @res.redirect status, url
    else
      @res.redirect url
    @rendered = true

  generateNav: (done) ->
    return done() unless @req.user
    # XXX: Get additional nav items from plugins
    @activeNavigationId ?= "#{@templateParent}-#{@template}"
    @navigation = [
      {
        title: @loggedInUser.fullname
        header: true
        id: 'user'
        items: [
          {
            title: 'Dashbard'
            href: '/dashboard'
            id: 'user-dashboard'
          }
          {
            title: 'Account'
            href: '/account'
            id: 'user-account'
          }
          {
            title: 'Subscription'
            href: '/subscription'
            id: 'user-subscription'
            className: 'pending warning'
          }
          {
            title: 'Member list'
            href: '/members'
            id: 'members-index'
          }
        ]
      }
      {
        title: 'Trustees'
        header: true
        id: 'trustees'
        items: [
          {
            title: 'Register of Members'
            href: '/admin/register'
            id: 'admin-register'
          }
          {
            title: 'Banking/Money'
            href: '/admin/money'
            id: 'admin-money'
          }
          {
            title: 'Reminders'
            href: '/admin/reminders'
            id: 'admin-reminders'
          }
          {
            title: 'Emails'
            href: '/admin/emails'
            id: 'admin-emails'
          }
        ]
      }
    ]
    for item in @navigation
      if item.id is @activeNavigationId
        item.active = true
        break
    done()

module.exports = Controller
