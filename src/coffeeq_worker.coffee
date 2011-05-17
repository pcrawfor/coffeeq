redis = require 'redis'
EventEmitter = require('events').EventEmitter

###
CoffeeQWorker
============
Uses two redis client instances so that it can handle pubsub and normal events simultaneously (redis connections have a pubsub mode that prevents one from doing both pubsub and normal events simultaneously)
@queueClient, @pubsubClient


Events:
=======
Emits 'message' each time a pubsub message from Redis is received.
  err    - The caught exception.
  channel - The pubsub channel that the message is received on
  message  - The message data

Emits 'job' before attempting to run any job.
  worker - This Worker instance.
  queue  - The String queue that is being checked.
  job    - The parsed Job object that was being run.

Emits 'success' after a successful job completion.
  worker - This Worker instance.
  queue  - The String queue that is being checked.
  job    - The parsed Job object that was being run.
  result - The result produced by the job.

Emits 'error' if there is an error fetching or running the job.
  err    - The caught exception.
  worker - This Worker instance.
  queue  - The String queue that is being checked.
  job    - The parsed Job object that was being run.
###
class CoffeeQWorker extends EventEmitter
  constructor: (queue, callbacks, options) ->
    options = {} unless options
    @port = options.port || 6379
    @host = options.host || 'localhost'
    @queue = queue    
    @queue_key = @key('queue', queue)
    @callbacks = callbacks or {}
    # init the queue clients and subscribe to the queue channel
    @queueClient = redis.createClient @port, @host
    @pubsubClient = redis.createClient @port, @host
    @registerMessageHandlers @queue_key
    
  start: ->
    console.log "start worker"
    @clearQueue(@queue_key)
    @subscribeToQueueChannel(@queue_key)
    
  stop: ->
    console.log "end worker"
    @disconnectFromQueueChannel(@queue_key)
    
  subscribeToQueueChannel: (channel) ->
    console.log "subscribe to #{channel}"
    @pubsubClient.subscribe channel
  
  disconnectFromQueueChannel: (channel) ->
    console.log "unsubscribe from #{channel}"
    @pubsubClient.end()
  
  # Registers to handle messages for pubsub
  registerMessageHandlers: (channel) ->    
    @pubsubClient.on "message", (channel, message) =>
      console.log "client 1 channel:#{channel} message:#{message}"      
      @emit 'message', @, channel, message
      @popAndRun channel if message == "queued"
    @pubsubClient.on "subscribe", (channel, count) ->
      console.log "subscribed to #{channel}"
    
  # Recursively pops and runs any items found on the queue at startup
  clearQueue: (queue) ->
    @queueClient.llen queue, (err, resp) =>
      console.log "CLEAR QUEUE resp: #{resp}"
      if resp > 0
        @popAndRun queue
        @clearQueue(queue)
    
  #Private functions
    
  ###
  Pulls the job off the queue and executes it  
  returns nothing
  ###
  popAndRun: (queue) ->
    @queueClient.lpop queue, (err, resp) => 
      if !err && resp
        console.log "resp #{resp}"
        # TODO: perform task
        @perform JSON.parse(resp.toString())
      else
        console.log "Error popping #{err}"
      
  ###
  Handles the actual running of the job.    
  job - The parsed Job object that is being run.    
  Returns nothing.
  ###
  perform: (job) ->
    old_title = process.title
    @emit 'job', @, @queue, job
    @procline "#{@queue} job since #{(new Date).toString()}"
    if cb = @callbacks[job.class]
      cb job.args..., (result) =>
        try
          if result instanceof Error
            @fail result, job
          else
            @succeed result, job
        finally
          console.log "done performing"
    else
      @fail new Error("Missing Job: #{job.class}"), job      
  
  ###
  Tracks stats for successfully completed jobs.    
  result - The result produced by the job. 
  job    - The parsed Job object that is being run.    
  Returns nothing.
  ###
  succeed: (result, job) ->    
    @emit 'success', @, @queue, job, result

  ###
  Tracks stats for failed jobs, and tracks them in a Redis list.  
  err - The caught Exception.
  job - The parsed Job object that is being run.
  Returns nothing.
  ###
  fail: (err, job) ->
    @emit 'error', err, @, @queue, job    
  
  
  ###
  Sets the process title.    
  msg - The String message for the title.    
  Returns nothing.
  ###
  procline: (msg) ->
    process.title = "resque-#{exports.version}: #{msg}"
  
  # extend object
  Object.defineProperty @prototype, 'name',
    get: -> @_name
    set: (name) ->
      @_name = if @ready
        [name or 'node', process.pid, @queues].join(":")
      else
        name
  
  ###
  Builds a namespaced Redis key with the given arguments.    
  args - Array of Strings.    
  Returns an assembled String key.
  ###
  key: (args...) ->
    args.unshift @namespace
    args.join ":"
#end class

# export classes
module.exports = CoffeeQWorker
