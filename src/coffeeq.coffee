redis = require 'redis'
Worker = require './coffeeq_worker'

###
  CoffeeQ
  Uses two redis client instances so that it can handle pubsub and normal events simultaneously (redis connections have a pubsub mode that prevents one from doing both pubsub and normal events simultaneously)
  @queueClient, @pubsubClient
###
class CoffeeQ    
  constructor: (options) ->
    console.log "Init CoffeeQ"
    options = {} unless options
    @port = options.port || 6379
    @host = options.host || 'localhost'
    @queueClient = redis.createClient @port, @host
    @pubsubClient = redis.createClient @port, @host

  ###
  Public: Queues a job in a given queue to be run.
  
   queue - String queue name.
   func  - String name of the function to run.
   args  - Optional Array of arguments to pass.
  
   Returns nothing.      
  ### 
  enqueue: (queue, func, args) ->
    console.log "enqueue"
    val = JSON.stringify class: func, args: args    
    key = @key('queue', queue)
    console.log("key #{key}")
    @queueClient.rpush key, val, (err, val) =>
      console.log "pushed #{val}" 
      @pubsubClient.publish( key, "queued", -> 
        console.log "published on #{queue}"
      ) if !err  
  
  ###
    Builds a namespaced Redis key with the given arguments.
    args - Array of Strings.  
    Returns an assembled String key
  ###
  key: (args...) ->
    args.unshift @namespace
    args.join ":"
  
# end class

  
# export classes
CoffeeQ.Worker = Worker  
CoffeeQ.version = "0.0.3"
module.exports = CoffeeQ
