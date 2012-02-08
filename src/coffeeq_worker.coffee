redis = require 'redis'
EventEmitter = require('events').EventEmitter
helper = require './coffeeq_helpers'

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

process.on 'uncaughtException', (err) ->    
  console.log "Caught exception: #{err}"
  if err.match /ECONNREFUSED/
    console.log "Redis Connection Error"
  else
    process.exit(1)

class CoffeeQWorker extends EventEmitter    
  
  constructor: (queue, callbacks, options) ->    
    options = {} unless options
    @port = options.port || 6379
    @host = options.host || 'localhost'
    @queue = queue    
    @queue_key = @key('queue', queue)
    @callbacks = callbacks or {}
    @connection_attempts = 0    
    @queueNeedsRestart = false
    @pubsubNeedsRestart = false

    # init the queue clients and subscribe to the queue channel
    @queueClient = redis.createClient @port, @host
    @queueClient.on("error", @redisConnectionError)
    @queueClient.on("connect", @redisQueueConnect)
    
    @pubsubClient = redis.createClient @port, @host
    @pubsubClient.on("error", @redisConnectionError)    
    @pubsubClient.on("connect", @redisPubsubConnect)    
    
      
  # include call must come after the constructor
  helper.include(this)
  
  redisQueueConnect: () =>
    console.log "Connected queue"    
    @startRedisQueue() unless @queueStarted
    @resetConnectionAttempts()

  redisPubsubConnect: () =>
    console.log "Connected pubsub"    
    @registerMessageHandlers @queue_key  
    @startRedisPubsub() unless @pubsubStarted
    @resetConnectionAttempts()
    
  resetConnectionAttempts: () ->
    @connection_attempts = 0 if !@queueNeedsRestart && !@pubsubNeedsRestart      

  redisConnectionError: (error) =>
    # handle redis connection error and retry connection
    # try to reconnect, if the connection fails
    console.log "handler | #{@connection_attempts} attempts"
    console.log "CONN ERROR: #{JSON.stringify(error)}"

    @queueNeedsRestart = true
    @pubsubNeedsRestart = true
    
    # if it fails too many times bail out
    @connection_attempts = @connection_attempts + 1
    if @connection_attempts > 20
      console.log "Unable to connect to redis"      
      process.exit(1)


  start: ->
    console.log "start worker"
    if @pubsubActive && @queueActive      
      @startRedisPubsub()
      @startRedisQueue()
    else      
      console.log "Problem starting worker, redis connection not active yet - will auto start if a valid connection is made to redis"
  
  startRedisPubsub: ->
    @pubsubNeedsRestart = false
    @subscribeToQueueChannel(@queue_key)
  
  startRedisQueue: ->
    @queueNeedsRestart = false
    @clearQueue(@queue_key)      
    @registerAsRunning()
    
  stop: ->
    console.log "end worker"
    @disconnectFromQueueChannel(@queue_key)
    
  subscribeToQueueChannel: (channel) ->
    console.log "subscribe to #{channel}"    
    @pubsubClient.subscribe channel    
  
  disconnectFromQueueChannel: (channel) ->
    console.log "unsubscribe from #{channel}"
    @pubsubClient.end()
  
  registerAsRunning: ->
    @queueClient.set(@runningKeyForQueue(@queue), Date())    
    @currentCount = 0
    @queueClient.set(@performedKeyForQueue(@queue), @currentCount)
      
  incrementPerformedCount: ->
    performedKey = @performedKeyForQueue(@queue)
    console.log("GET PERFORMED COUNT #{performedKey}")
    @currentCount = @currentCount+1    
    @queueClient.set(performedKey, @currentCount)
            
  # Registers to handle messages for pubsub
  registerMessageHandlers: (channel) ->    
    @pubsubClient.on "message", (channel, message) =>      
      @emit 'message', @, channel, message
      @popAndRun channel if message == "queued"
    @pubsubClient.on "subscribe", (channel, count) ->
      console.log "subscribed to #{channel}"
    
  # Recursively pops and runs any items found on the queue at startup
  clearQueue: (queue) ->    
    @queueClient.llen queue, (err, resp) =>      
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
        job = JSON.parse(resp.toString())
        # TODO: perform task
        try
          @perform job
        catch e
          console.log("CATCHING EXCEPTION #{e}")
          @recordFailure(e, job)      
      
  ###
  Handles the actual running of the job.    
  job - The parsed Job object that is being run.    
  Returns nothing.
  ###
  perform: (job) ->
    old_title = process.title
    @emit 'job', @, @queue, job
    
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
    @incrementPerformedCount()
    @emit 'success', @, @queue, job, result

  ###
  Tracks stats for failed jobs, and tracks them in a Redis list.  
  err - The caught Exception.
  job - The parsed Job object that is being run.
  Returns nothing.
  ###
  fail: (err, job) ->
    @recordFailure(err, job)          
    @emit 'error', err, @, @queue, job    
  
  recordFailure: (err, job) ->
    key = @errorKeyForQueue(@queue)
    @queueClient.rpush key, "Error processing:#{JSON.stringify(job)} | #{err} | #{Date()}", (err, val) =>
      console.log "pushed error on queue #{@queue}"    
  
  # extend object
  Object.defineProperty @prototype, 'name',
    get: -> @_name
    set: (name) ->
      @_name = if @ready
        [name or 'node', process.pid, @queues].join(":")
      else
        name     
  
#end class

# export classes
module.exports = CoffeeQWorker
