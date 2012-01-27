
/**
 * Module dependencies.
 */

var express = require('express');

var app = express.createServer();

var Overlord = require('../coffeeq_overlord');
var overlord = new Overlord();

var io = require('socket.io');

var shared_helpers = require('./public/javascripts/shared_helpers');

var activeSocket;
var socketInterval;
var realtimeOn = true;

// Configuration

app.configure(function(){
  app.set('views', __dirname + '/views');
  app.set('view engine', 'ejs');
  app.use(express.bodyParser());
  app.use(express.methodOverride());
  app.use(app.router);
  app.use(express.static(__dirname + '/public'));
});

// Environment handlers

app.configure('development', function(){
  app.use(express.errorHandler({ dumpExceptions: true, showStack: true })); 
});

app.configure('production', function(){
  app.use(express.errorHandler()); 
});

// Routes

app.get('/', function(req, res) {  
  console.log("GET /")
  
  overlord.activeWorkers(function(result) {
    res.render('index', {
      title: 'CoffeeQ Overlord',
      queues: result.queues,
      counts: result.counts,
      errors: result.errors,
      performedCounts: result.performedCounts,
      startTimes: result.startTimes,
      runningFor: result.runningFor,
      throughputVals: result.throughputVals,
      realtimeOn: realtimeOn
    });
  });    
  
});

app.get('/errors/:id', function(req, res){
  console.log("Errors for queue " + req.params.id);
  
  // load the errors for the queue and display the list
  overlord.errorsForQueue(req.params.id, function(errors) {
    console.log("error render " + req.params.id);
    res.render('errors', {
      queueName: req.params.id,
      errors: errors 
    });
  });  
});

app.get('/errors/:id/clear', function(req, res) {
  console.log("Clear errors for queue " + req.params.id);
  
  // load the errors for the queue and display the list
  overlord.clearErrorsForQueue(req.params.id, function() {
    console.log("Errors list cleared for queue");
    res.redirect('back');
  });
});

/*app.get('/realtime/:id', function(req, res) {
  console.log("Realtime: " + req.params.id);
  
  if(req.params.id == "on") {
    startRealtime(activeSocket);    
  } else {
    stopRealtime(socketInterval);
  }
  
  res.redirect('back');  
});*/

// Socket.io
var connectSocketio = function() {
  io.sockets.on('connection', function (socket) {
    activeSocket = socket;    
    startRealtime(activeSocket);
  });
}

// view helpers
app.helpers(shared_helpers);

// socket action
// =============
var startRealtime = function(socket) {
  console.log("Start Realtime");
  
  if(socketInterval == undefined) {
    socketInterval = setInterval(function() {
      overlord.activeWorkers(function(result) {
        console.log("UPDATE! + " + Date());
        socket.broadcast.emit('update', { 
          queues: result.queues, 
          counts: result.counts,  
          performedCounts: result.performedCounts,
          startTimes: result.startTimes,
          runningFor: result.runningFor,
          throughputVals: result.throughputVals
        });
      });
    }, 5000);    
  }  
  
  realtimeOn = true;
}

var stopRealtime = function(interval) {
  console.log("Stop Realtime");
  clearInterval(interval);
    
  realtimeOn = false;
}

// startup

var server = {
  app: app,
  start: function(port) {    
    app.listen(port);
    console.log("Express server listening on port %d in %s mode", app.address().port, app.settings.env);
    io.listen(app);
    connectSocketio();
    return app;
  }
}

//TODO: refactor to provide an interface and function for starting up the server outside of the require
module.exports = server;
