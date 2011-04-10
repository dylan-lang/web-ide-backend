module: web-ide-backend

// See dylan/fundev/sources/environment/protocols/

define function object-name (project, object)
  let name = environment-object-home-name(project, object);
  if (name)
    environment-object-primitive-name(project, name)
  else
    environment-object-display-name(project, object, #f,
                                    qualify-names?: #f)
  end if;
end function;

define function callback-handler (#rest args)
  log-debug("%=\n", args);
end function;

define function open-project-database (project :: <project-object>)
  open-project-compiler-database(project,
                                 warning-callback: callback-handler,
                                 error-handler: callback-handler);
  parse-project-source(project);
end function;

define variable *libraries* = #f;

define function library-names ()
  unless (*libraries*)
    let names = make(<deque>);
    local method collect-project
              (dir :: <pathname>, name :: <string>, type :: <file-type>)
            if (type == #"file")
              push-last(names, name);
            end;
          end method;
    let registries = find-registries($machine-name, $os-name);
    let paths = map(registry-location, registries);
    for (path in paths)
      if (file-exists?(path))
        do-directory(collect-project, path);
      end;
    end for;
    *libraries* := remove-duplicates!(names, test: \=);
  end unless;
  table(parents: => #(),
        objects: => *libraries*);
end function;

define function find-library/module (library-name, module-name)
  let project = find-project(library-name);
  open-project-database(project);
  let library = project.project-library;
  let module = if (module-name)
                 find-module(project, module-name,
                             library: library);
               else
                 #f;
               end;
  values(project, library, module);
end function;

define function modules (#key library-name)
  let (project, library) =
    find-library/module(library-name, #f);
  let information = curry(object-information, project);
  table(parents: => vector(information(library, details?: #f)),
        objects: => map(rcurry(information, parents?: #f),
                        library-modules(project, library)));
end function;

define function defined-modules (#key library-name)
  let (project, library) =
    find-library/module(library-name, #f);
  let information = curry(object-information, project);
  table(parents: => vector(information(library, details?: #f)),
        objects: => map(rcurry(information, parents?: #f),
                        library-modules(project, library,
                                        imported?: #f)));
end function;

define function used-libraries (#key library-name)
  let (project, library) =
    find-library/module(library-name, #f);
  table(parents: => #(),
        objects: =>
          map(curry(object-information, project),
              source-form-used-definitions(project, library)));
end function;

define function used-modules (#key library-name, module-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  table(parents: => #f,
        objects: =>
          map(curry(object-information, project),
              source-form-used-definitions(project, module)));
end function;

define function definitions (#key library-name, module-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let definitions = module-definitions(project, module,
                                       imported?: #f);
  let information = curry(object-information, project);
  table(parents: =>
          map(rcurry(information, details?: #f),
              vector(library, module)),
        objects: =>
          map(rcurry(information, parents?: #f),
              definitions));
end function;

define function direct-slots (#key library-name, module-name, class-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let class = find-environment-object(project, class-name,
                                      library: library,
                                      module: module);
  let information = curry(object-information, project);
  let slots = make(<deque>);
  do-direct-slots(method (slot)
                    push(slots, information(slot, parents?: #f));
                  end,
                  project, class);
  table(parents: =>
          map(method (parent)
                information(parent, details?: #f)
              end,
              vector(library, module)),
        objects: => slots);
end function;

define function all-slots (#key library-name, module-name, class-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let class = find-environment-object(project, class-name,
                                      library: library,
                                      module: module);
  let slots = make(<deque>);
  do-all-slots(method (slot)
                 push(slots, object-information(project, slot));
               end,
               project, class);
  table(parents: => #f,
        objects: => slots);
end function;

define function object-parents (project, object)
  let parents = make(<deque>);
  let parent = #f;
  for (current = object then parent, while: current)
    let home-name =
      environment-object-home-name(project, current);
    if (home-name)
      parent := name-namespace(project, home-name);
      parents :=
        add!(parents, object-information(project, parent,
                                         details?: #f));
    else
      parent := #f;
    end if;
  finally
    parents;
  end for;
end function;

define function direct-superclasses (#key library-name, module-name, class-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let class = find-environment-object(project, class-name,
                                      library: library,
                                      module: module);
  let superclasses = make(<deque>);
  do-direct-superclasses(method (superclass)
                           push(superclasses,
                                object-information(project, superclass));
                         end,
                         project, class);
  table(parents: => #f,
        objects: => superclasses);
end function;

define function all-superclasses (#key library-name, module-name, class-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let class = find-environment-object(project, class-name,
                                      library: library,
                                      module: module);
  let superclasses = make(<deque>);
  do-all-superclasses(method (superclass)
                        push(superclasses,
                             object-information(project, superclass));
                      end method,
                      project, class);
  table(parents: => #f,
        objects: => superclasses);
end function;

define function direct-subclasses (#key library-name, module-name, class-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let class = find-environment-object(project, class-name,
                                      library: library,
                                      module: module);
  let subclasses = make(<deque>);
  do-direct-subclasses(method (subclass)
                         push(subclasses,
                              object-information(project, subclass));
                       end method,
                       project, class);
  table(parents: => #f,
        objects: => subclasses);
end function;

// TODO: not supported by environment API
// define function all-subclasses (#key library-name, module-name, class-name)

define function direct-methods (#key library-name, module-name, class-name)
 => (result :: <table>);
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let class = find-environment-object(project, class-name,
                                      library: library,
                                      module: module);
  let methods = make(<deque>);
  do-direct-methods(method (method*)
                      push(methods, object-information(project, method*));
                    end method,
                    project, class);
  table(parents: => #f,
        objects: => methods);
end function;

define function all-methods (#key library-name, module-name, class-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let class = find-environment-object(project, class-name,
                                      library: library,
                                      module: module);
  let methods = make(<deque>);
  do-all-methods(method (method-class, method*)
                   push(methods, object-information(project, method*));
                 end method,
                 project, class);
  table(parents: => #f,
        objects: => methods);
end function;

define function methods (#key library-name, module-name, generic-function-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let generic-function = find-environment-object(project, generic-function-name,
                                                 library: library,
                                                 module: module);
  if (generic-function)
    let methods = make(<deque>);
    do-generic-function-methods(method (method*)
                                  push(methods, object-information(project, method*));
                                end method,
                                project, generic-function);
    table(parents: => #f,
          objects: => methods);
  end if;
end function;

define function source (#key library-name, module-name, object-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let object = find-environment-object(project, object-name,
                                       library: library,
                                       module: module);
  let location =
    environment-object-source-location(project, object);
  let (filename, line)
    = source-line-location(location.source-location-source-record,
                           location.source-location-start-line);
  table(filename: => filename,
        line: => line,
        column: => location.source-location-start-column,
        end-line: => line + location.source-location-end-line,
        source: => environment-object-source(project, object));
end function;

// TODO: identifier!
define function info (#key library-name, module-name, symbol-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  object-information(project,
                     find-environment-object(project, symbol-name,
                                             library: library,
                                             module: module));
end function;


// TODO:
// define function configuration ()
//   table("" => "library",
//         "library" => "module",
//         "module" => "symbol")
// end function;

define function json-handler (function)
  method (#rest arguments)
    encode-json(current-response(),
                apply(function, arguments));
  end method;
end function;

define function filtered (function)
  local method compare (a, b)
          if (instance?(a, <string>))
            a < b
          else
            a[name:] < b[name:]
          end if;
        end method;

  method (#rest arguments)
    let prefix = get-query-value("prefix");
    let result = apply(function, arguments);
    result[objects:] := sort(result[objects:], test: compare);
    if (prefix)
      result[objects:] := choose(method (object)
                                    let name = if (instance?(object, <string>))
                                                 object
                                               else
                                                 object[name:]
                                               end if;
                                    copy-sequence(name, end: min(size(name),
                                                                 size(prefix)))
                                      = prefix
                                  end method,
                                  result[objects:]);
    end if;
    result;
  end method;
end function;

define function start ()
  // configure environment
  *check-source-record-date?* := #f;

  // configure and start server
  let server = make(<http-server>,
                    listeners: list("0.0.0.0:8080"),
                    debug: #t);

  local method add (url, function, #key filtered?)
          let function = if (filtered?)
                           filtered(function)
                         else
                           function
                         end if;
          add-resource(server, url,
                       function-resource(json-handler(function)));
        end;

  add("/api/libraries",
      library-names, filtered?: #t);
  add("/api/modules/{library-name}",
      modules, filtered?: #t);
  add("/api/defined-modules/{library-name}",
      defined-modules, filtered?: #t);
  add("/api/used-libraries/{library-name}",
      used-libraries, filtered?: #t);

  add("/api/used-modules/{library-name}/{module-name}",
      used-modules, filtered?: #t);
  add("/api/definitions/{library-name}/{module-name}",
      definitions, filtered?: #t);

  add("/api/direct-subclasses/{library-name}/{module-name}/{class-name}",
      direct-subclasses, filtered?: #t);
// TODO: not supported by environment API
//  add("/api/all-subclasses/{library-name}/{module-name}/{class-name}",
//      all-subclasses, filtered?: #t);
  add("/api/direct-superclasses/{library-name}/{module-name}/{class-name}",
      direct-superclasses, filtered?: #t);
  add("/api/all-superclasses/{library-name}/{module-name}/{class-name}",
      all-superclasses, filtered?: #t);
  add("/api/direct-methods/{library-name}/{module-name}/{class-name}",
      direct-methods, filtered?: #t);
  add("/api/all-methods/{library-name}/{module-name}/{class-name}",
      all-methods, filtered?: #t);
  add("/api/direct-slots/{library-name}/{module-name}/{class-name}",
      direct-slots, filtered?: #t);
  add("/api/all-slots/{library-name}/{module-name}/{class-name}",
      all-slots, filtered?: #t);

  add("/api/methods/{library-name}/{module-name}/{generic-function-name}",
      methods, filtered?: #t);

  add("/api/source/{library-name}/{module-name}/{object-name}",
      source);

  add("/api/info/{library-name}/{module-name}/{symbol-name}",
      info);

  // TODO:
  // add("/configuration", configuration);
  // /search/{types+}/{term} => [{module: 'common-dylan'}, ...]

  start-server(server);
end function;

start();
