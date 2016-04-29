#### mix

**mix** is a task runner, written in LiveScript.

#### purpose

The purpose of mix is to simplify bootstrapping scripted tasks in a project.  Over the years I have come to rely on some libraries often enough at the project scripting level that I have included those globally in the mix environment.

#### globals

Globally, mix provides the following names:

- **mix** - the mix object, containing `task`, `option`, `config`
- **co** - https://github.com/tj/co
- **fs** - standard lib
- **fs.path** - standard lib
- **uuid** - https://github.com/broofa/node-uuid (the version 4 function)
- **glob** - https://github.com/isaacs/node-glob
- **clone** - https://github.com/pvorb/node-clone
- **Promise** - https://github.com/petkaantonov/bluebird
- **promise** - alias to `new Promise`
- **livescript** - https://github.com/gkz/LiveScript
- **watcher** - https://github.com/paulmillr/chokidar
- **ex** wraps process.exec in a promise
- **exec** alias to process.exec-sync
- **spawn** wraps process.spawn in a promise
- **color** takes a number from 0-255 and a string and produces an xterm256 string
- **debounce** takes a time in milliseconds, and a function, and returns a debounced function
- **spin** takes a log line and a command that will be executed with a spinner until it is completed
- **pathify** add a path NODE_PATH

###### notes
`prelude-ls` is imported into global.
`Obj.compact` is redefined to reject only undefined properties.

#### usage
Mix looks in the current directory for a folder called `task`.  Tasks are written in LiveScript.  Each file in the task folder refers to a top level task.  Consider a file call `task/ip.ls` with the following code:
```
export encode = ->*
  info new Buffer(mix.task.2.split('.') |> map parse-int).to-string(\base64).substring 0, 6

export decode = ->*
  info (new Buffer(mix.task.2, 'base64')).join '.'
```
If you run
```
$ mix ip encode 127.0.0.1
```
mix will search for `task/ip.ls`, compile it into a module, and run the `encode` function, placing all arguments following `mix` in `mix.task`.  Thus `mix.task` in this case is `<[ ip encode 127.0.0.1 ]>`

Note that any functions defined in a task module will be yielded, thus they must be a generator or return a promise.

Options are also supported.  Thus adding `--myopt foo` will place the string value `"foo"` in the property `mix.option.myopt`.

Arguments that aren't options are passed to the called task function.

#### configuration

Mix will load any `mix.ls` file sitting in project folder and set it to `mix.config`.  If a file named `host.ls` is also present, it is loaded and then deep-merged over the top of `mix.config`.

#### libraries

Mix tasks will be compiled with a node path that includes `./lib`.  It also will search your standard node path heirarchy.

#### daemonization

If you want to daemonize your task, call it with `start`.

```
$ mix start <task>
$ mix stop <task>
```

