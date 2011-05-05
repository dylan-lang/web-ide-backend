module: web-ide-backend

define generic object-information
    (project :: <project-object>, object :: <object>, #key)
 => (result :: <table>);

define method object-information
    (project :: <project-object>, object :: <object>,
     #key name? = #t, details? = #t, parents? = #t)
 => (result :: <table>);
  let information =
    table(type: => object-type(object));
  when (name?)
    information[name:] := object-name(project, object);
  end;
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
    (project :: <project-object>, id :: <integer>)
 => (identifier :: <string>);
  integer-to-string(id);
end method;

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
    (project :: <project-object>, warning :: <warning-object>)
 => (identifier :: <string>);
  // TODO: <warning-object>s don't have proper IDs :/
  concatenate(";warning;",
              integer-to-string(find-key(project-warnings(project),
                                         curry(\=, warning))));
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
    (project :: <project-object>,
     object :: type-union(<method-object>,
                          <domain-object>),
     #key)
 => (result :: <table>);
  let information = next-method();
  let identifier = object-identifier(project, object);
  unless (element($ids, identifier, default: #f))
    // save id for identifier
    $ids[identifier] :=
      environment-object-id(project, object);
  end;
  information[identifier:] := identifier;
  information;
end method;

define method object-information
    (project :: <project-object>,
     warning :: <warning-object>, #key)
 => (result :: <table>);
  let information = next-method();
  information[identifier:] :=
    object-identifier(project, warning);
  let library-information =
    object-information(project, project.project-library);
  let owner = warning-owner(project, warning);
  information[parents:] :=
    if (owner)
      object-parents(project, owner);
    else
      vector(library-information);
    end if;
  information[has-source?:] :=
    environment-object-source-location(project, warning) & #t;
  information;
end method;

define method object-information
    (project :: <project-object>, slot :: <slot-object>, #key)
 => (result :: <table>);
  let getter = slot-getter(project, slot);
  let information = next-method();
  // overwrite with getter's info
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
