Module: web-ide-backend

// See dylan/fundev/sources/environment/protocols/

define table *type-mapping* = 
  { <library-object> => "library",
    <module-object> => "module",
    <class-object> => "class",
    <function-object> => "function",
    <generic-function-object> => "generic-function",
    <method-object> => "method",
    <variable-object> => "variable",
    <global-variable-object> => "global-variable",
    <thread-variable-object> => "thread-variable",   
    <constant-object> => "constant",
    <macro-object> => "macro", 
    <domain-object> => "domain" };

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
    remove-duplicates!(names, test: \=);
    *libraries* := names;
  end unless;
  table("parents" => #(),
        "objects" => *libraries*);
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
  let (project, library) = find-library/module(library-name, #f);
  table("parents" => vector(library-name),
        "objects" => map(curry(object-name, project),
                         library-modules(project, library)));
end function;

define function defined-modules (#key library-name)
  let (project, library) = find-library/module(library-name, #f);
  table("parents" => vector(library-name),
        "objects" => map(curry(object-name, project),
                         library-modules(project, library, 
                                         imported?: #f)));
end function;

define function used-libraries (#key library-name)
  let (project, library) = find-library/module(library-name, #f);
  table("parents" => #(),
        "objects" => map(curry(object-name, project),
                         source-form-used-definitions(project, library)));
end function;

define function used-modules (#key library-name, module-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  table("parents" => #f,
        "objects" => map(method (used-module)
                           let used-module-name = 
                             environment-object-home-name(project, used-module);
                           let used-module-library = 
                             name-namespace(project, used-module-name);
                           table("name" => object-name(project, used-module),
                                 "parents" => vector(object-name(project, used-module-library)))
                         end method,
                         source-form-used-definitions(project, module)));
end function;

define function definitions (#key library-name, module-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let definitions = module-definitions(project, module, 
                                       imported?: #f);
  let definitions = 
    map(method (definition)
          table("name" => object-name(project, definition),
                "type" => *type-mapping*[object-class(definition)]);
        end, definitions);
  table("parents" => vector(library-name, module-name),
        "objects" => definitions);
end function;

// TODO:
// define function symbol-information (#key library-name, module-name, symbol-name)
//   let (project, library, module) =
//     find-library/module(library-name, module-name);
//   find-environment-object(project, symbol-name,
//                           library: library,
//                           module: module);
//   // TODO:
// end function;

define function direct-slots (#key library-name, module-name, class-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let class = find-environment-object(project, class-name,
                                      library: library,
                                      module: module);
  let slots = make(<deque>);
  do-direct-slots(method (slot-object)
                    let getter = slot-getter(project, slot-object);
                    let name = object-name(project, getter);
                    push(slots, name);
                  end, 
                  project, class);
  table("parents" => vector(library-name, module-name, class-name),
        "objects" => slots);
end function;

define function object-parents (project, object)
  let parents = make(<deque>);
  let parent = #f;
  for (current = object then parent, while: current)
    let home-name = 
      environment-object-home-name(project, current);
    if (home-name)
      parent := name-namespace(project, home-name);
      parents := add!(parents, object-name(project, parent));
    else
      parent := #f;
    end if;
  finally
    parents;
  end for;
end function;

define function all-slots (#key library-name, module-name, class-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let class = find-environment-object(project, class-name,
                                      library: library,
                                      module: module);
  let slots = make(<deque>);
  do-all-slots(method (slot-object)
                 let getter = slot-getter(project, slot-object);
                 push(slots, table("name" => object-name(project, getter),
                                   "parents" => object-parents(project, getter)))
               end method, 
               project, class);
  table("parents" => #f,
        "objects" => slots);
end function;

define function direct-superclasses (#key library-name, module-name, class-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let class = find-environment-object(project, class-name,
                                      library: library,
                                      module: module);
  let superclasses = make(<deque>);
  do-direct-superclasses(method (superclass)
                           push(superclasses, object-name(project, superclass));
                         end, 
                         project, class);
  table("parents" => vector(library-name, module-name),
        "objects" => superclasses);
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
                             table("name" => object-name(project, superclass),
                                   "parents" => object-parents(project, superclass)));
                      end method, 
                      project, class);
  table("parents" => #f,
        "objects" => superclasses);
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
                              table("name" => object-name(project, subclass),
                                    "parents" => object-parents(project, subclass)));
                       end method, 
                       project, class);
  table("parents" => #f,
        "objects" => subclasses);
end function;

// TODO: not supported by environment API
// define function all-subclasses (#key library-name, module-name, class-name)
//   let (project, library, module) =
//     find-library/module(library-name, module-name);
//   let class = find-environment-object(project, class-name,
//                                       library: library,
//                                       module: module);
//   let subclasses = make(<deque>);
//   do-all-subclasses(method (subclass)
//                       push(subclasses,
//                            table("name" => object-name(project, subclass),
//                                  "parents" => object-parents(project, subclass)));
//                     end method, 
//                     project, class);
//   table("parents" => #f,
//         "objects" => subclasses);
// end function;

define function direct-methods (#key library-name, module-name, class-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let class = find-environment-object(project, class-name,
                                      library: library,
                                      module: module);
  let methods = make(<deque>);
  do-direct-methods(method (method*)
                      push(methods,
                           table("name" => object-name(project, method*),
                                 "parents" => object-parents(project, method*)));
                    end method, 
                    project, class);
  table("parents" => #f,
        "objects" => methods);
end function;

define function all-methods (#key library-name, module-name, class-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let class = find-environment-object(project, class-name,
                                      library: library,
                                      module: module);
  let methods = make(<deque>);
  do-all-methods(method (method-class, method*)
                   push(methods,
                        table("name" => object-name(project, method*),
                              "parents" => object-parents(project, method*)));
                 end method, 
                 project, class);
  table("parents" => #f,
        "objects" => methods);
end function;

define function method-details (project :: <project-object>, method* :: <method-object>)
 => (result :: <table>);
  table("specializers" => 
          map(curry(object-name, project), 
              method-specializers(project, method*)));
end function;

define function parameter-details (project :: <project-object>, parameter :: <parameter>) 
 => (result :: <table>);
  table("name" => parameter-name(parameter),
        "type" => object-name(project, parameter-type(parameter)));
end function;

define function function-details (project :: <project-object>, function :: <function-object>)
 => (result :: <table>);
  let details = curry(parameter-details, project);
  let (required :: <parameters>,
       rest :: false-or(<parameter>),
       keys :: <optional-parameters>,
       all-keys? :: <boolean>,
       next :: false-or(<parameter>),
       values :: <parameters>,
       rest-value :: false-or(<parameter>)) 
    = function-parameters(project, function);
  table("required" => map(details, required),
        "rest" => rest & details(rest),
        "keys" => map(method (parameter)
                        map-into(details(parameter), 
                                 identity,
                                 table("keyword" => parameter-keyword(parameter),
                                       "default" => 
                                         format-to-string("%=", 
                                                          parameter-default-value(parameter))));
                      end, keys),
        "all-keys?" => all-keys?,
        "next" => next & details(next),
        "values" => map(details, values),
        "rest-value" => rest-value & details(rest-value));
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
                                  push(methods,
                                       table("name" => object-name(project, method*),
                                             "parents" => object-parents(project, method*),
                                             "details" => map-into(function-details(project, method*),
                                                                   identity,
                                                                   method-details(project, method*))));
                                end method,
                                project, generic-function);
    table("parents" => #f,
          "objects" => methods);
  end if;
end function;

define function source (#key library-name, module-name, object-name)
  let (project, library, module) =
    find-library/module(library-name, module-name);
  let object = find-environment-object(project, object-name,
                                       library: library,
                                       module: module);
  environment-object-source(project, object);
end function;


// TODO:
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

  define function filtered (function)
    method (#rest arguments)
      let prefix = get-query-value("prefix");
      let result = apply(function, arguments);
      if (prefix)
        result["objects"] := choose(method (object)
                                      let name = if (instance?(object, <string>))
                                                   object
                                                 else
                                                   object["name"]
                                                 end if;
                                      copy-sequence(name, end: min(size(name), 
                                                                   size(prefix)))
                                        = prefix
                                    end method,
                                    sort(result["objects"],
                                         test: method (a, b)
                                                 if (instance?(a, <string>))
                                                   a < b
                                                 else
                                                   a["name"] < b["name"]
                                                 end if;
                                               end method));
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

  // TODO:
  add("/configuration", configuration);

  // add("/api/symbol/{library-name}/{module-name}/{symbol-name}",
  //     symbol-information);

  // /search/{types+}/{term} => [{module: 'common-dylan'}, ...]

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
