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
