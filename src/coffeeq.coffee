redis = require 'redis'
helper = require './coffeeq_helpers'
Worker = require './coffeeq_worker'

###
  CoffeeQ
  Uses two redis client instances so that it can handle pubsub and normal events simultaneously (redis connections have a pubsub mode that prevents one from doing both pubsub and normal events simultaneously)
  @queueClient, @pubsubClient
###

class CoffeeQ
  constructor: (options) ->    
    options = {} unless options
    @port = options.port || 6379
    @host = options.host || 'localhost'
    @queueClient = redis.createClient @port, @host
    @pubsubClient = redis.createClient @port, @host

  # include call must come after the constructor
  helper.include(this)

  ###
  Public: Queues a job in a given queue to be run.
  
   queue - String queue name.
   func  - String name of the function to run.
   args  - Optional Array of arguments to pass.
  
   Returns nothing.      
  ### 
  enqueue: (queue, func, args) ->    
    val = JSON.stringify class: func, args: args    
    key = @activeKeyForQueue(queue)
    @queueClient.rpush key, val, (err, val) =>      
      @pubsubClient.publish(key, "queued", -> 
        console.log "published on #{queue}"
      ) if !err 

# end class
  
# export classes
CoffeeQ.Worker = Worker
CoffeeQ.version = "0.0.7"
CoffeeQ.app = require('./http')
module.exports = CoffeeQ
