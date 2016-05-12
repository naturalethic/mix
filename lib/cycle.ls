require! \object-path

export function decycle object, replacer
  objects = new WeakMap
  (function derez value, path
    value = replacer value if replacer
    if typeof! value in <[ Object Array ]>
      if p = objects.get value
        return $ref: p
      objects.set value, path
      if typeof! value is \Array
        nu = []
        for element, i in value
          nu[i] = derez element, "#{path}.#{i}"
      else
        nu = {}
        for name, item of value
          nu[name] = derez item, "#{path}.#{name}"
      return nu
    return value
  ) object, \$

export function recycle $
  (function rez value
    if typeof! value in <[ Object Array ]>
      if typeof! value is \Array
        for element, i in value
          if typeof! element is \Object
            if (typeof!(path = element.$ref) is \String)
              value[i] = object-path.get $, path
            else
              rez element
      else
        for name, item of value
          if typeof! item is \Object
            if (typeof!(path = item.$ref) is \String)
              value[name] = object-path.get $, /\$\.(.*)/.exec(path).1
            else
              rez item
  ) $
  $
