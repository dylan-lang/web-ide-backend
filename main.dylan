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

define constant $parse-lock = make(<lock>);

define function open-project-database (project :: <project-object>)
  open-project-compiler-database(project,
                                 warning-callback: callback-handler,
                                 error-handler: callback-handler);
  with-lock ($parse-lock)
    parse-project-source(project);
  end;
end function;

define variable *projects* = #f;

define function all-projects ()
  unless (*projects*)
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
    *projects* := remove-duplicates!(names, test: \=);
  end unless;
  *projects*
end function;

define function library-names ()
  table(parents: => #(),
        objects: => all-projects());
end function;

define function find-library/module (library-name, module-name)
  let project = find-project(library-name);
  project.project-opened-by-user? := #t;
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

define function direct-methods
    (#key library-name, module-name, class-name)
 => (result :: <table>);
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let class = find-environment-object(project, class-name,
                                      library: library,
                                      module: module);
  let methods = make(<deque>);
  do-direct-methods(method (method*)
                      push(methods,
                           object-information(project, method*));
                    end method,
                    project, class);
  table(parents: => #f,
        objects: => methods);
end function;

define function all-methods
    (#key library-name, module-name, class-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let class = find-environment-object(project, class-name,
                                      library: library,
                                      module: module);
  let methods = make(<deque>);
  do-all-methods(method (method-class, method*)
                   push(methods,
                        object-information(project, method*));
                 end method,
                 project, class);
  table(parents: => #f,
        objects: => methods);
end function;

define function methods
    (#key library-name, module-name, generic-function-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let generic-function =
    find-environment-object(project, generic-function-name,
                            library: library,
                            module: module);
  if (generic-function)
    let methods = make(<deque>);
    do-generic-function-methods(method (method*)
                                  push(methods,
                                       object-information(project,
                                                          method*));
                                end method,
                                project, generic-function);
    table(parents: => #f,
          objects: => methods);
  end if;
end function;

define function find-object
    (project, library, module, identifier :: <string>)
 => (result :: false-or(<environment-object>));
  let id = element($ids, identifier, default: #f);
  find-environment-object(project, id | identifier,
                          library: library,
                          module: module);
end function;

define method find-special-object
    (type == #"warning", project, library, module, identifier :: <string>)
 => (result :: false-or(<environment-object>));
  let index = string-to-integer(split(identifier, ";")[2]);
  element(project-warnings(project), index, default: #f);
end method;

define function special-identifier?
    (identifier :: <string>)
 => (special? :: <boolean>);
  identifier[0] = ';'
end function;

define function identifier-type
    (identifier :: <string>)
 => (type :: <symbol>);
  as(<symbol>, split(identifier, ";")[1]);
end function;

define function find-project/object (identifiers)
  let library-name = identifiers[0];
  if (identifiers.size > 1)
    let (module-name, identifier) =
      if (identifiers.size = 3)
        values(identifiers[1], identifiers[2]);
      else
        values(#f, identifiers[1]);
      end if;
    let (project, library, module) =
      find-library/module(library-name, module-name);
    if (special-identifier?(identifier))
      let object =
        find-special-object(identifier-type(identifier), project,
                            library, module, identifier);
      values(project, object);
    else
      values(project, if (identifiers.size = 3)
                        find-object(project, library, module, identifier);
                      else
                        module
                      end if);
    end if;
  else
    // library
    find-library/module(library-name, #f);
  end if;
end function;

define function source (#key identifiers)
  let (project, object) = find-project/object(identifiers);
  let location =
    environment-object-source-location(project, object);
  let (start-line, end-line) =
    object-source-location-lines(location);
  let source-record = location.source-location-source-record;
  let offset = source-record.source-record-start-line;
  let start-line = offset +
    location.source-location-start-line;
  let end-line = offset +
    location.source-location-end-line;
  select (current-request().request-method)
    #"GET" =>
      table(filename: => locator-name(source-record.source-record-location),
            line: => start-line,
            column: => location.source-location-start-column,
            end-line: => end-line,
            source: => environment-object-source(project, object));
    #"POST" =>
      begin
        let path = as(<string>, source-record.source-record-location);
        let new-source = get-query-value("value");
        let old-source = with-open-file (file = path, direction: #"input")
                           stream-contents(file);
                         end;
        with-open-file (file = path, direction: #"output", if-exists: #"replace")
          let stream = make(<string-stream>, direction: #"input",
                            contents: old-source);
          // copy up to start of old source
          for (line from 1 below start-line)
            write-line(file, read-line(stream));
          end for;
          // skip old source
          for (line from start-line to end-line)
            read-line(stream);
          end for;
          // write new source
          write(file, new-source);
          new-line(file);
          // copy up to end of file
          until (stream-at-end?(stream))
            write-line(file, read-line(stream));
          end until;
        end with-open-file;
        #t;
      end begin;
    otherwise => #f;
  end select;
end function;


define variable *build-progress* = 0;

define variable *build-project* = #f;

define constant $build-lock = make(<lock>);

define function build (#key library-name)
  let (project, library) = find-library/module(library-name, #f);
  with-lock ($build-lock)
    *build-project* := project;
    let built? =
      build-project(project,
                    progress-callback:
                      method (numerator, denominator, #rest foo)
                        *build-progress* :=
                          as(<float>, numerator) / as(<float>, denominator);
                        log-debug("build progress: %s", *build-progress*);
                      end method,
                    error-handler:
                      method (#rest args)
                        // TODO: save and serve in build-progress
                        log-debug("build error: %=", args);
                      end method,
                    clean?: #f,
                    link?: #f,
                    save-databases?: #t,
                    copy-sources?: #f,
                    process-subprojects?: #t);
    let notes = map(curry(object-information, project),
                    project-warnings(project));
    table(built?: => built?,
          notes: => notes);
  end with-lock;
end function;

define function build-progress ()
  if (*build-project*)
    table(object: =>
            object-information(*build-project*,
                               *build-project*.project-library),
          progress: => *build-progress*);
  end if;
end function;

define function run (#key library-name)
  let (project, library) = find-library/module(library-name, #f);
  let startup-option = project.application-startup-option;
  let machine = project.project-debug-machine
    | environment-host-machine();
  let application =
    run-application(project, machine: machine,
                    startup-option: startup-option);
end function;

define variable *link-progress* = 0;

define variable *link-project* = #f;

define constant $link-lock = make(<lock>);

define function link (#key library-name)
  let (project, library) = find-library/module(library-name, #f);
  with-lock ($link-lock)
    *link-project* := project;
    link-project(project,
                 progress-callback:
                   method (numerator, denominator, #rest foo)
                     *link-progress* :=
                       as(<float>, numerator) / as(<float>, denominator);
                     log-debug("link progress: %s", *link-progress*);
                   end method,
                 error-handler:
                   method (#rest args)
                     // TODO: save and serve in link-progress
                     log-debug("link error: %=", args);
                   end method,
                 process-subprojects?: #t,
                 release?: #f);
  end with-lock;
end function;

define function link-progress ()
  if (*link-project*)
    table(object: =>
            object-information(*link-project*,
                               *link-project*.project-library),
          progress: => *link-progress*);
  end if;
end function;

/* TODO:
  from env/tools/proj-commands:

  update-application(project, progress-callback: progress) // ???

  stop-application(project) // PAUSE
  continue-application(project);
  close-application(project, wait-for-termination?: #t) // STOP

*/

define function used-definitions (#key library-name, module-name, identifier)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let object = find-object(project, library, module, identifier);
  table(parents: => #f,
        objects: =>
          map(curry(object-information, project),
              source-form-used-definitions(project, object)));
end function;

define function clients (#key library-name, module-name, identifier)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let object = find-object(project, library, module, identifier);
  table(parents: => #f,
        objects: =>
          map(curry(object-information, project),
              source-form-clients(project, object)));
end function;

define function info (#key identifiers)
  let (project, object) = find-project/object(identifiers);
  object-information(project, object);
end function;

define function macroexpansion (#key library-name, module-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let trace-stream = #f;
  let source = get-query-value("value");
  let stream = make(<string-stream>, direction: #"output");
  project-macroexpand-code(project, module, source,
                           expansion-stream: stream,
                           trace-stream: trace-stream);
  table("macroexpansion" => stream-contents(stream));
end function;

define function search (#key term)
  // find matching keys
  let symbol-names =
    choose(method (name)
             copy-sequence(name, end: min(size(name),
                                          size(term)))
               = term
           end method,
           key-sequence($symbols));
  // gather symbol entries
  let symbol-entries = make(<deque>);
  for (symbol-name in symbol-names)
    for (symbol-entry in element($symbols, symbol-name))
      symbol-entries := add-new!(symbol-entries, symbol-entry);
    end for;
  end for;
  // return result
  table(parents: => #f,
        objects: =>
          map(method (symbol-entry)
                let project = symbol-entry.symbol-entry-project;
                let name = symbol-entry.symbol-entry-name;
                object-information(project, name-value(project, name));
              end method,
              symbol-entries));
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

define class <symbol-entry> (<object>)
  constant slot symbol-entry-name,
    required-init-keyword: name:;
  constant slot symbol-entry-project,
    required-init-keyword: project:;
end class;

define constant $symbols = make(<string-table>);

define function add-symbol (project, name-object :: <binding-name-object>)
  if (name-exported?(project, name-object))
    let symbol-entry = make(<symbol-entry>,
                            name: name-object,
                            project: project);
    let symbol-name =
      get-environment-object-primitive-name(project, name-object);
    let symbol-entries = element($symbols, symbol-name,
                                 default: make(<stretchy-vector>));
    $symbols[symbol-name] := add!(symbol-entries, symbol-entry);
  end if;
end function;

define function populate-symbol-table ()
  let projects = all-projects();
  // TODO: include more
  for (project-name in #("dylan", "web-ide-backend"))
    block()
      let (project, library) = find-library/module(project-name, #f);
      do-namespace-names(method(module-name :: <module-name-object>)
                             if (name-exported?(project, module-name))
                               let name = name-value(project, module-name);
                               do-namespace-names(curry(add-symbol, project),
                                                  project, name);
                             end if
                         end method,
                         project, project.project-library);
    exception (e :: <condition>)
      log-debug("Received exception %= in project %s\n", e, project-name);
    end block;
  end for;
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

  add("/api/clients/{library-name}/{module-name}/{identifier}",
      clients, filtered?: #t);
  add("/api/used-definitions/{library-name}/{module-name}/{identifier}",
      used-definitions, filtered?: #t);

  add("/api/source/{identifiers+}",
      source);
  add("/api/info/{identifiers+}",
      info);
  add("/api/macroexpansion/{library-name}/{module-name}",
      macroexpansion);

  add("/api/search/{term}", search);

  add("/api/build/{library-name}", build);
  add("/api/build-progress", build-progress);

  add("/api/link/{library-name}", link);
  add("/api/link-progress", link-progress);

  // TODO:
  // add("/configuration", configuration);

  make(<thread>, function: populate-symbol-table);
  start-server(server);
end function;

start();
