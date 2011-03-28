Module: web-ide-backend

define table *type-mapping* = 
  { <library-object> => "library",
    <module-object> => "module",
    <class-object> => "class",
    <function-object> => "function",
    <generic-function-object> => "generic-function",
    <method-object> => "method",
    <variable-object> => "variable",
    <constant-object> => "constant" };

define function callback-handler (#rest args)
  log-debug("%=\n", args);
end function;

define function open-project-database (project :: <project-object>)
  open-project-compiler-database(project,
                                 warning-callback: callback-handler,
                                 error-handler: callback-handler);
  parse-project-source(project);
end function;

define function all-library-names ()
  let names = make(<deque>);
  local method collect-project
            (dir :: <pathname>, name :: <string>, type :: <file-type>)
          if (type == #"file")
            push-last(names, name);
          end;
        end;
  let registries = find-registries($machine-name, $os-name);
  let paths = map(registry-location, registries);
  for (path in paths)
    if (file-exists?(path))
      do-directory(collect-project, path);
    end;
  end;
  remove-duplicates!(names, test: \=);
end function;

define function library-names ()
  let prefix = get-query-value("prefix");
  let names = sort!(all-library-names());
  if (prefix)
    choose(method (name)
             copy-sequence(name, end: min(size(name), size(prefix)))
               = prefix
           end,
           names);
  else
    names;
  end if;
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

define function library-modules-names (#key library-name)
  let (project, library) = find-library/module(library-name, #f);
  let modules = library-modules(project, library);
  map(method (module)
        environment-object-primitive-name(project, module);
      end, modules);
end function;

define function library-defined-modules-names (#key library-name)
  let (project, library) = find-library/module(library-name, #f);
  let modules = library-modules(project, library, imported?: #f);
  map(method (module)
        environment-object-primitive-name(project, module);
      end, modules);
end function;

define function library-used-libraries-names (#key library-name)
  let (project, library) = find-library/module(library-name, #f);
  let used-libraries = source-form-used-definitions(project, library);
  map(method (used-library)
        environment-object-primitive-name(project, used-library);
      end, used-libraries);
end function;

define function module-used-modules-names (#key library-name, module-name)
  let (project, library, module) = find-library/module(library-name, module-name);
  let used-modules = source-form-used-definitions(project, module);
  map(method (used-module)
        environment-object-primitive-name(project, used-module);
      end, used-modules);
end function;

define function module-definitions-handler (#key library-name, module-name)
  let (project, library, module) = find-library/module(library-name, module-name);
  let definitions = module-definitions(project, module, imported?: #f);
  map(method (definition)
        let home-name = environment-object-home-name(project, definition);
        table("name" => environment-object-primitive-name(project, home-name),
              "type" => *type-mapping*[object-class(definition)]);
      end, definitions);
end function;

define function symbol-information (#key library-name, module-name, symbol-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  find-environment-object(project, symbol-name,
                          library: library,
                          module: module);
  // TODO:
end function;


define function configuration ()
  table("" => "library",
        "library" => "module",
        "module" => "symbol")
end function;

define function json-handler (function)
  method (#rest arguments)
    encode-json(current-response(),
                apply(function, arguments));
  end method;
end function;

define function start ()
  // configure environment
  *check-source-record-date?* := #f;

  // configure and start server
  let server = make(<http-server>,
                    listeners: list("0.0.0.0:8080"));

  local method add (url, function)
          add-resource(server, url,
                       function-resource(json-handler(function)));
        end;

  add("/configuration", configuration);

  // human-readable name for environment object:
  // => environment-object-type-name

  add("/api/libraries", library-names);
  add("/api/modules/{library-name}",
      library-modules-names);
  add("/api/defined-modules/{library-name}",
      library-defined-modules-names);
  add("/api/used-libraries/{library-name}",
      library-used-libraries-names);

  add("/api/used-modules/{library-name}/{module-name}",
      module-used-modules-names);
  add("/api/module-definitions/{library-name}/{module-name}",
      module-definitions-handler);

  add("/api/symbol/{library-name}/{module-name}/{symbol-name}",
      symbol-information);

  // TODO: add("/api/methods/{library-name}/{module-name}/{function-name}",
  // generic-function-methods);
  //  => generic-function-object-methods(project, generic-function);


  // TODO: /search/{types+}/{term} => [{module: 'common-dylan'}, ...]


  //  dylan/fundev/sources/environment/protocols/:

  // <class-object>
  // => class-direct-subclasses
  // => class-direct-superclasses
  // => class-direct-methods
  // => class-slots

  // <dylan-function-object>
  // => function-parameters
  //    (server :: <server>, function :: <dylan-function-object>)
  //     => (required :: <parameters>,
  //         rest :: false-or(<parameter>),
  //         keys :: <optional-parameters>,
  //         all-keys? :: <boolean>,
  //         next :: false-or(<parameter>),
  //         values :: <parameters>,
  //         rest-value :: false-or(<parameter>));
  // <method-object>
  // => method-specializers

  // <variable-object>
  // => variable-type
  // => variable-value

  start-server(server);
end function;

start();
