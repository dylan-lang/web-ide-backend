module: web-ide-backend

define generic object-information
    (project :: <project-object>, object :: <object>, #key)
 => (result :: <table>);

define method object-information
    (project :: <project-object>, object :: <object>,
     #key details? = #t, parents? = #t)
 => (result :: <table>);
  let information =
    table(name: => object-name(project, object),
          type: => object-type(object));
  when (parents?)
    information[parents:] := object-parents(project, object);
  end;
  if (details?)
    information[details:] := object-details(project, object);
  else
    information[incomplete?:] := #t;
  end if;
  information;
end method;

define constant $id-separator = ";";

define constant $ids = make(<string-table>);

define method object-identifier
    (project :: <project-object>, id :: <id>)
 => (identifier :: <string>);
  let module-id = id.id-module;
  let library-id = module-id.id-library;
  concatenate-as(<string>,
                 id-name(id), $id-separator,
                 id-name(module-id), $id-separator,
                 id-name(library-id));
end method;

define method object-identifier
    (project :: <project-object>, object :: <environment-object>)
 => (identifier :: <string>);
  let object-id = environment-object-id(project, object);
  object-identifier(project, object-id);
end method;

define method object-identifier
    (project :: <project-object>, method* :: <method-object>)
 => (identifier :: <string>);
  let method-id = environment-object-id(project, method*);
  select (method-id by instance?)
    <method-id> =>
      let generic-function-id = method-id.id-generic-function;
      let identifier = object-identifier(project, generic-function-id);
      for (specializer-id in method-id.id-specializers)
        identifier := concatenate(identifier, $id-separator,
                                  object-identifier(project, specializer-id));
      end;
      identifier;
    <id> =>
      id-name(method-id);
    <integer> =>
      integer-to-string(method-id);
  end select;
end method;

define method object-information
    (project :: <project-object>, method* :: <method-object>, #key)
 => (result :: <table>);
  let information = next-method();
  let identifier = object-identifier(project, method*);
  unless (element($ids, identifier, default: #f))
    // save id for identifier
    $ids[identifier] := environment-object-id(project, method*);
  end;
  information[identifier:] := identifier;
  information;
end method;

// TODO: <integer> ids not working yet
// let (project, library, module) = find-library/module("uri", "uri");
// let gf = find-environment-object(project, "parse-uri-as", library: library, module: module);
// let methods = generic-function-object-methods(project, gf);
// environment-object-id(project, methods[0]) // = 10079
// parse-uri-as => 10014


define method object-information
    (project :: <project-object>, slot :: <slot-object>, #key)
 => (result :: <table>);
  let getter = slot-getter(project, slot);
  let information = next-method();
  information[name:] := object-name(project, getter);
  information[parents:] := object-parents(project, getter);
  information;
end method;

define method object-information
    (project :: <project-object>, object :: <parameter>, #key)
 => (result :: <table>);
  table(name: => parameter-name(object),
        type: => object-type(object),
        details: => object-details(project, object));
end method;
