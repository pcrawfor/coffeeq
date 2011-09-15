HelperMixin = () ->
  
HelperMixin.prototype =
  errorKeyForQueue: (queue) ->    
    @key('errors', queue)

  runningKeyForQueue: (queue) ->
    @key('running', queue)

  activeKeyForQueue: (queue) ->
    @key('queue', queue)
  
  #  Builds a namespaced Redis key with the given arguments
  key: (args...) ->
    args.unshift @namespace
    args.join ":"  

###
  The include function will add any functions defined on the HelperMixin to the recvClass
  
  This provides a mechanism to mixin some functions that may be useful across all classes regardless of whether those classes would inherit from the same base
  It works effectively like a Ruby mixin or an Objective-C extension
  
  Inspired by js mixins described here http://chamnapchhorn.blogspot.com/2009/05/javascript-mixins.html
###
CoffeeQHelpers =
  include: (recvClass) ->
    for methodName, func of HelperMixin.prototype when typeof func is 'function'    
      if(!recvClass.prototype[methodName])        
        recvClass.prototype[methodName] = HelperMixin.prototype[methodName]
    

module.exports = CoffeeQHelpers