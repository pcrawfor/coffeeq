###

CoffeeQOverlord
============
Since there can be a lot happening in a queue system like CoffeeQ the overlord is responsible for monitoring and reporting on the status of the queue(s)

This includes failure rates, errors, number of active jobs and workers.
The overlord provides a web server that can be used to view the status of the system at any time and to modify settings such as througput rate on queues.

Queues are of the form ":queue:somename"

Per queue the information available will be:
  completed count
  failure count
  failure list
  run time (run start time - current time)

Overview info:
  how many queues there are
  what their current counts are
  throughput of each queue (perhaps controls to modify/limit throughput)


TODO:
  Add web interface
  Provide access to actions:
    Clear a given queue
    View failures/errors
    See current state of all queues
    See current throughput of queues

### 

redis = require 'redis'
helper = require './coffeeq_helpers'
Ctrl =  require '../vendor/ctrl/ctrl.js'

class CoffeeQOverlord    
  constructor: (options={}) ->
    @port = options.port || 6379
    @host = options.host || 'localhost'
    @queueClient = redis.createClient @port, @host            
  
  # The include call must come after the constructor
  helper.include(this)
    
  ###
    Load the current set of active workers and return the result
  ###   
  activeWorkers: (callback) ->
    workers = null
    queues = []
    starts = {}
    counts = {}
    errors = {}
    performedCounts = {}
    startTimes = {}
    runningFor = {}
    throughputVals = {}
    
    results = {}
    
    Ctrl.run(
      (ctrl) =>
        @queueClient.keys ":running:*", ctrl.collect()
      
      (ctrl) =>
        workers = ctrl.result[1]        
        for worker in workers
          do (worker) =>
            @queueClient.get worker, ctrl.collect("#{worker}_last_run")
          q = worker.replace(":running:", "")          
          @queueClient.get @performedKeyForQueue(q), ctrl.collect("#{worker}_performed_count")
          @queueClient.get @runningKeyForQueue(q), ctrl.collect("#{worker}_running")          
          @queueClient.llen @activeKeyForQueue(q), ctrl.collect("#{worker}_count")          
          @queueClient.llen @errorKeyForQueue(q), ctrl.collect("#{worker}_error_count")                      
      
      (ctrl) =>
        for worker in workers
          do (worker) =>
            queueName = worker.replace(":running:", ":queue:")            
            queues.push queueName
            starts[queueName] = ctrl.named_results["#{worker}_last_run"][1]   
            counts[queueName] = ctrl.named_results["#{worker}_count"][1]
            performedCounts[queueName] = ctrl.named_results["#{worker}_performed_count"][1]            
            performedCounts[queueName] = 0 if(performedCounts[queueName] == undefined || performedCounts[queueName] == null)            
            startTimes[queueName] = ctrl.named_results["#{worker}_running"][1]
            
            numMinutesRunning = ((Date.parse(Date()) - Date.parse(starts[queueName]))/1000)/60
            numMinutesRunning = Math.round(numMinutesRunning*10)/10
            runningFor[queueName] = numMinutesRunning
            
            # calc throughput
            # performedCount / numSecondsRunning
            throughput = performedCounts[queueName]/numMinutesRunning
            throughputVals[queueName] = Math.round(throughput*10)/10
            
            errCount = ctrl.named_results["#{worker}_error_count"][1]
            errors[queueName] = errCount
        
        results =
          queues: queues          
          counts: counts
          starts: starts
          errors: errors
          performedCounts: performedCounts
          startTimes: startTimes
          runningFor: runningFor
          throughputVals: throughputVals
        
        callback(results)              
    )          
  
  errorsForQueue: (queue, callback) ->
    Ctrl.run(
      (ctrl) =>
        @queueClient.llen @errorKeyForQueue(queue), ctrl.collect()
      
      (ctrl) =>
        errCount = ctrl.result[1]
        @queueClient.lrange @errorKeyForQueue(queue), 0, errCount, ctrl.collect()
      
      (ctrl) =>
        callback(ctrl.result[1])
    )          
  
  ###
    ACTION
    * TODO: Expose via web interface
    Clears all items from a queue - either an actual work queue or an error queue
  ###
  clearQueue: (queue, callback) ->
    console.log "Clear #{queue}"
    @queueClient.ltrim queue, 0, 0, (err, res) =>
      console.log("TRIM #{res}")
      @queueClient.lpop queue
      @queueClient.llen queue, (err, length) ->
          console.log("#{length} jobs in #{queue}")
          callback()

  ###
    ACTION
    * TODO: Expose via web interface
    Clears all erros from a queues error list
  ###
  clearErrorsForQueue: (queue, callback) ->
    console.log "Clear Error Queue for #{@errorKeyForQueue(queue)}"
    @clearQueue(@errorKeyForQueue(queue), callback)
    
module.exports = CoffeeQOverlord
