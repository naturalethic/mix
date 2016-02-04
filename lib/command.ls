require! \child_process
require! \prelude-ls
require! \fs
require! \path
require! \optimist
require! \chokidar
require! \glob
require! \co
require! \livescript

# -----------------------------------------------------------------------------
# Global assignments.  Please keep all global assignments within this area.
# -----------------------------------------------------------------------------

process <<< child_process
global  <<< console
global  <<< prelude-ls

global <<< do
  co:            co
  fs:            fs <<< { path: path }
  glob:          glob
  livescript:    livescript
  watcher:       chokidar

global.exec = (command) ->
  process.exec-sync command .to-string!

global.spawn = ->
  words = it.match(/[^"'\s]+|"[^"]+"|'[^'']+'/g)
  process.spawn-sync (head words), (tail words), stdio: \inherit

global.mix =
  task: [last((delete optimist.argv.$0).split ' ')] ++ delete optimist.argv._
  option: pairs-to-obj(obj-to-pairs(optimist.argv) |> map -> [camelize(it[0]), it[1]])

# -----------------------------------------------------------------------------
# End global assignments.
# -----------------------------------------------------------------------------

# Load plugin and project tasks.  Project tasks will mask plugins of the same name.
task-modules = pairs-to-obj (((glob.sync "#{process.cwd!}/node_modules/mix*/task/*") ++ glob.sync("#{process.cwd!}/task/*")) |> map ->
  [ (camelize fs.path.basename(it).replace //#{fs.path.extname it}$//, ''), it ]
)

# Print list of tasks if none given, or task does not exist.
if !mix.task.0 or !task-modules[camelize mix.task.0]
  exit 'No tasks defined' if !(keys task-modules).length
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
else
  co task
