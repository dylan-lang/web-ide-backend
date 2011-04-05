module: web-ide-backend

define generic object-details
    (project :: <project-object>, object :: <object>)
 => (result :: false-or(<table>));

define method object-details
    (project :: <project-object>, object :: <object>)
 => (result :: false-or(<table>));
  #f;
end method;

define method object-details
    (project :: <project-object>, class :: <class-object>)
 => (result :: false-or(<table>));
  let superclasses = make(<deque>);
  do-direct-superclasses(method (superclass)
                           push(superclasses,
                                object-information(project, superclass,
                                                   details?: #f));
                         end,
                         project, class);
  table(direct-superclasses: => superclasses);
end method;

define method object-details
    (project :: <project-object>, method* :: <method-object>)
 => (result :: false-or(<table>));
  map-into(next-method(),
           identity,
           table(specializers: =>
                   map(curry(object-information, project),
                       method-specializers(project, method*))));
end method;

define method object-details
    (project :: <project-object>, parameter :: <parameter>)
 => (result :: false-or(<table>));
  table(type: => object-information(project, parameter-type(parameter)));
end method;

define method object-details
    (project :: <project-object>, parameter :: <optional-parameter>)
 => (result :: false-or(<table>));
  map-into(next-method(),
           identity,
           table(keyword: => parameter-keyword(parameter),
                 default: =>
                   format-to-string("%s", parameter-default-value(parameter))));
end method;

define method object-details
    (project :: <project-object>, function :: <dylan-function-object>)
 => (result :: false-or(<table>));
  let information = curry(object-information, project);
  let (required :: <parameters>,
       rest :: false-or(<parameter>),
       keys :: <optional-parameters>,
       all-keys? :: <boolean>,
       next :: false-or(<parameter>),
       values :: <parameters>,
       rest-value :: false-or(<parameter>))
    = function-parameters(project, function);
  table(required: => map(information, required),
        rest: => rest & information(rest),
        keys: => map(information, keys),
        all-keys?: => all-keys?,
        next: => next & information(next),
        values: => map(information, values),
        rest-value: => rest-value & information(rest-value));
end method;

define method object-details
    (project :: <project-object>, variable :: <variable-object>)
 => (result :: false-or(<table>));
  // TODO value: => format-to-string("%s", variable-value(project, variable))
  table(type: =>
          object-information(project, variable-type(project, variable)));
end method;

define method object-details
    (project :: <project-object>, slot :: <slot-object>)
 => (result :: false-or(<table>));
  table(type: => object-information(project, slot-type(project, slot)));
end method;