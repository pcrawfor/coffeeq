# CoffeeQ - Simple queuing library implemented on redis

CoffeeQ is a simple queueing library for node.js implemented on top of redis and inspired by resque.  It was inspired by Coffee-Resque and implemented to satisfy the needs of a specific development project for a fast backend queueing library.  The use of redis build in pub/sub functionality makes the processing of new queue items very fast and eliminates the need to poll redis for changes.

CoffeeQ uses redis built in pub/sub functionality and lists to provide a reliable and fast queueing mechanism.  A client can enqueue and job which will add the job to a queue and publish a change message to the queue's pub/sub channel, any workers set to work on that queue will try to pickup the job from the queue - only one worker is able to take any given item from a queue.  

Workers listen to the pub/sub channel for a given queue and whenever a new job is queued will attempt to dequeue the job to be processed, if successful they will perform the action defined by the job.

## Installation

CoffeeQ is available via npm

`npm install coffeeq`

It's only dependency is redis which will be installed by npm along with the module.

## Usage

CoffeeQ allows you to define workers dedicated to processing tasks for a given queue, a job can be any arbitrary coffeescript/javascript function.  You can use the node client to enqueue items on a queue for processing by passing in the name of the job and the parameters for the job in an array.

### Defining tasks to be performed
  
You can define the tasks to be performed as functions, in the simplest case you can 

    jobs = 
      multiply: (a, b, callback) ->
        console.log "callback add #{a} + #{b}"
        callback(a * b)        
      succeed: (callback) ->
        console.log "callback succeed"
        callback()
      fail: (callback) ->
        console.log "callback fail"
        callback()

### Adding items to a Queue

To add an job to a queue you create a CoffeeQ client and enqueue the task for the given queue.

    CoffeeQ = require 'coffeeq'
    client = new CoffeeQ
    client.enqueue "test_queue", "add", [1,4]


### Implementing Workers

Workers are 

      Worker = require('coffeeq').Worker

      jobs = 
        multiply: (a, b, callback) ->
          console.log "callback add #{a} + #{b}"
          callback(a * b)        
        succeed: (callback) ->
          console.log "callback succeed"
          callback()
        fail: (callback) ->
          console.log "callback fail"
          callback()

      worker = new Worker("test_queue", jobs)

      worker.on 'message', (worker, queue) ->
        console.log("message fired")
      worker.on 'job', (worker, queue) ->
        console.log("job fired")
      worker.on 'error', (worker, queue) ->
        console.log("error fired")
      worker.on 'success', (worker, queue, job, result) ->
        console.log("success fired with result #{result}")

      worker.start()

