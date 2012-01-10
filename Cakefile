{spawn, exec} = require 'child_process'

runCommand = (cmd) ->
  child = exec(cmd, (error, stdout, stderr) ->
    if error != null
      console.log "exec error: #{error}"
  )

test = (msg, name, args...) ->
  res = false
  proc = spawn name, args
  proc.stderr.on 'data', (buffer) -> console.log buffer.toString()
  
  proc.stdout.on 'data', (buffer) ->
    res = true if buffer.toString() != ""
  
  proc.on 'exit', (status) ->
    console.log msg unless res
    process.exit(1) if status isnt 0

# ====================================
#              TASKS
# ====================================    
task 'rebuild_js', 'Clean and Rebuild JS', (options) ->  
  invoke 'deps'
  invoke 'clean_js'
  invoke 'build_js'

task 'build_js', 'Generate JS from Coffeescript', (options) ->
  invoke 'deps'
  runCommand 'coffee -c -o lib src/*.coffee'
  console.log "JS Compiled to lib folder"

task 'clean_js', 'Remove js output', (options) ->
  runCommand 'rm -rf lib/*.js'
  console.log "compiled js in lib folder deleted"
  
task 'deps', 'Check dependencies', (options) ->
  test 'You need to have CoffeeScript in your PATH.\nPlease install it using `brew install coffee-script` or `npm install coffee-script`.', 'which' , 'coffee'  
  
task 'publish', 'Publish NPM Package', (options) ->
  invoke 'build_js'
  test 'You need npm to do npm publish... makes sense?', 'which', 'npm'
  runCommand 'sudo npm publish'
  invoke 'clean_js'
  console.log "Module published"

task 'link', 'Link ', (options) ->
  invoke 'build_js'
  test 'You need npm to do npm publish... makes sense?', 'which', 'npm'
  runCommand 'npm link'
  invoke 'clean_js'
  console.log "Module linked"