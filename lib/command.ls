require! \child_process
require! \prelude-ls
require! \fs
require! \path
require! \optimist
require! \chokidar
require! \glob
require! \co
require! \clone
require! \deep-extend
require! \node-uuid
require! \livescript
require! \cli-spinner
require! \bluebird
require! \module : Module
require! \daemonize2
require! './cycle'

daemon-action = null

# -----------------------------------------------------------------------------
# Initialization and setting of all globals
# -----------------------------------------------------------------------------
export init = ->
  process <<< child_process
  global  <<< prelude-ls
  if (process.argv.index-of '--daemon') >= 0
    log = fs.open-sync 'mix.log', 'a+'
    <[ log info warn error ]> |> each (key) -> global[key] = -> fs.write log, (& * ' '); fs.write log, '\n'
  else if window?
    if console.log.apply
      <[ log info warn error ]> |> each (key) -> window[key] = -> console[key] ...&
    else
      <[ log info warn error ]> |> each (key) -> window[key] = console[key]
  else
    global <<< console{log, info, warn, error}

  bluebird.config { +long-stack-traces }

  global <<< do
    co:            co
    fs:            fs <<< { path: path }
    uuid:          node-uuid.v4
    glob:          glob
    extend:        deep-extend
    clone:         clone
    Promise:       bluebird
    promise:       -> new Promise ...&
    promisify:     bluebird.promisify
    promisify-all: bluebird.promisify-all
    livescript:    livescript
    watcher:       chokidar
    pathify:       -> Module.global-paths.push it

  global <<< cycle

  Obj.compact = -> pairs-to-obj((obj-to-pairs it) |> filter -> it[1] is not undefined)

  global.spin = (line, command) ->*
    spinner = new cli-spinner.Spinner "#line %s"
    spinner.start!
    if command
      yield ex command
      spinner.stop true
      info line if line
    spinner.done = ->
      spinner.stop true
      info line if line
    spinner

  global.ex = (command, options) ->
    new Promise (resolve, reject) ->
      process.exec command, (error, result) ->
        return reject error if error
        resolve result.to-string!

  global.exec = (command, options) ->
    process.exec-sync command .to-string!

  global.spawn = (command, options = {}) ->
    options.stdio ?= \inherit
    new Promise (resolve, reject) ->
      words = command.match(/[^"'\s]+|"[^"]+"|'[^'']+'/g)
      process.spawn (head words), (tail words), options
      .on \close, resolve

  global.mix =
    config:
      color: true
    task:   [last((delete optimist.argv.$0).split ' ')] ++ delete optimist.argv._
    option: pairs-to-obj(obj-to-pairs(optimist.argv) |> map -> [camelize(it[0]), it[1]])

  global.project-root = it or mix.option.project-root or process.cwd!

  pathify fs.realpath-sync "#project-root/lib" if fs.exists-sync "#project-root/lib"
  pathify fs.realpath-sync "#project-root/node_modules"

  if mix.task.0 in <[ start stop ]>
    daemon-action := mix.task.shift!

  if fs.exists-sync (config-path = "#{project-root}/mix.ls")
    extend mix.config, require config-path

  if fs.exists-sync (host-path = "#{project-root}/host.ls")
    extend mix.config, require host-path

  mix.config = recycle mix.config

  global.color = (c, v) -> (mix.config.color and "\x1b[38;5;#{c}m#{v}\x1b[0m") or v

  global.debounce = ->
    return if &.length < 1
    wait = 1
    if is-type \Function &0
      func = &0
    else
      wait = &0
    if &.length > 1
      if is-type \Function &1
        func = &1
      else
        wait = &1
    timeout = null
    ->
      args = arguments
      clear-timeout timeout
      timeout := set-timeout (~>
        timeout := null
        func.apply this, args
      ), wait
  this <<< mix
  this

# -----------------------------------------------------------------------------
# End global assignments.
# -----------------------------------------------------------------------------

array-replace = (it, a, b) -> index = it.index-of(a); it.splice(index, 1, b) if index > -1; it

export run = ->
  # Load plugin and project tasks.  Project tasks will mask plugins of the same name.
  task-modules = pairs-to-obj (((glob.sync "#{project-root}/node_modules/mix*/task/*") ++ glob.sync("#{project-root}/task/*")) |> map ->
    [ (camelize fs.path.basename(it).replace //#{fs.path.extname it}$//, ''), it ]
  )

  if (process.argv.index-of '--daemon') >= 0
    mix.task.shift!

  # Print list of tasks if none given, or task does not exist.
  if !mix.task.0 or !task-modules[camelize mix.task.0]
    if !(keys task-modules).length
      info 'No tasks defined'
      process.exit!
    info 'Tasks:'
    keys task-modules |> each -> info "  #it"
    process.exit!

  task-module = new Module.Module
  task-module.paths = [ "#{project-root}/node_modules", "#{project-root}/lib", "#__dirname/../lib" ]
  task-module.paths.push "#__dirname/../node_modules" if fs.exists-sync "#__dirname/../node_modules"
  task-module._compile (livescript.compile ([
    (fs.read-file-sync task-modules[camelize mix.task.0] .to-string!)
  ].join '\n'), { +bare }), task-modules[camelize mix.task.0]
  task-module = task-module.exports

  # Print list of subtasks if one is acceptable and none given, or subtask does not exist.
  if !(mix.task.1 and task = task-module[camelize mix.task.1.to-string!]) and !(task = task-module[camelize mix.task.0])
    info 'Subtasks:'
    keys task-module
    |> filter -> it != camelize mix.task.0
    |> each -> info "  #{dasherize it}"
    process.exit!

  if daemon-action
    daemon = daemonize2.setup do
      main:    "#__dirname/../run.js"
      name:    "MIX: #{project-root} [#{mix.task.0}]"
      pidfile: "/tmp/mix-#{fs.path.basename project-root}-#{mix.task.0}.pid"
      argv:    process.argv.slice(2) ++ [ '--daemon' ]
      cwd:     project-root
    daemon.on \error, ->
      info ...&
    daemon[daemon-action]!
    process.exit!

  # Provide watch capability to all tasks.
  if mix.option.watch and task-module.watch
      process.argv.shift!
      process.argv.shift!
      argv = mix.task ++ process.argv
      array-replace argv, '--watch', '--supervised'
      while true
        child = process.spawn-sync fs.path.resolve('node_modules/.bin/mix'), argv, { stdio: 'inherit' }
        if child.error
          info child.error
          process.exit!
  else if mix.option.supervised
    watcher.watch (task-module.watch or []), persistent: true, ignore-initial: true .on 'all', (event, path) ->
      info "Change detected in '#path'..."
      process.exit!

  co task ...(mix.task.1 and mix.task[((task-module[camelize mix.task.1.to-string!] and 2) or 1) til mix.task.length] or [])
  .catch ->
    error (it.stack or it)
