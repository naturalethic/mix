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
Module = (require \module).Module

# -----------------------------------------------------------------------------
# Global assignments.  Please keep all global assignments within this area.
# -----------------------------------------------------------------------------

array-replace = (it, a, b) -> index = it.index-of(a); it.splice(index, 1, b) if index > -1; it

process <<< child_process
global  <<< console
global  <<< prelude-ls

global <<< do
  co:            co
  fs:            fs <<< { path: path }
  uuid:          node-uuid.v4
  glob:          glob
  extend:        deep-extend
  clone:         clone
  Promise:       bluebird
  promise:       bluebird
  promisify:     bluebird.promisify
  promisify-all: bluebird.promisify-all
  livescript:    livescript
  watcher:       chokidar

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

if fs.exists-sync (config-path = "#{process.cwd!}/mix.ls")
  extend mix.config, require config-path

if fs.exists-sync (host-path = "#{process.cwd!}/host.ls")
  extend mix.config, require host-path

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

# -----------------------------------------------------------------------------
# End global assignments.
# -----------------------------------------------------------------------------

# Load plugin and project tasks.  Project tasks will mask plugins of the same name.
task-modules = pairs-to-obj (((glob.sync "#{process.cwd!}/node_modules/mix*/task/*") ++ glob.sync("#{process.cwd!}/task/*")) |> map ->
  [ (camelize fs.path.basename(it).replace //#{fs.path.extname it}$//, ''), it ]
)

# Print list of tasks if none given, or task does not exist.
if !mix.task.0 or !task-modules[camelize mix.task.0]
  if !(keys task-modules).length
    info 'No tasks defined'
    process.exit!
  info 'Tasks:'
  keys task-modules |> each -> info "  #it"
  process.exit!

task-module = new Module
task-module.paths = [ "#{process.cwd!}/node_modules", "#{process.cwd!}/lib", "#__dirname/../lib" ]
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
co task
.catch ->
  error (it.stack or it)
