module: web-ide-backend
Copyright:    Original Code is Copyright (c) 2011 Dylan Hackers
              All rights reserved.
License:      See License.txt in this distribution for details.


define generic object-type
    (object :: <object>)
 => (name :: <string>);

define method object-type
    (object :: <object>)
 => (name :: <string>);
  "other"
end method;

define method object-type
    (object :: <library-object>)
 => (name :: <string>);
 "library"
end;

define method object-type
    (object :: <module-object>)
 => (name :: <string>);
 "module"
end;

define method object-type
    (object :: <class-object>)
 => (name :: <string>);
  "class"
end;

define method object-type
    (object :: <function-object>)
 => (name :: <string>);
  "function"
end;

define method object-type
    (object :: <generic-function-object>)
 => (name :: <string>);
  "generic-function"
end;

define method object-type
    (object :: <method-object>)
 => (name :: <string>);
  "method"
end;

define method object-type
    (object :: <variable-object>)
 => (name :: <string>);
  "variable"
end;

define method object-type
    (object :: <global-variable-object>)
 => (name :: <string>);
  "global-variable"
end;

define method object-type
    (object :: <thread-variable-object>)
 => (name :: <string>);
  "thread-variable"
end;

define method object-type
    (object :: <constant-object>)
 => (name :: <string>);
  "constant"
end;

define method object-type
    (object :: <slot-object>)
 => (name :: <string>);
  "slot"
end;

define method object-type
    (object :: <macro-object>)
 => (name :: <string>);
  "macro"
end;

define method object-type
    (object :: <domain-object>)
 => (name :: <string>);
  "domain"
end;

define method object-type
    (object :: <complex-type-expression-object>)
 => (name :: <string>);
  "complex-type-expression"
end method;

define method object-type
    (object :: <parameter>)
 => (name :: <string>);
  "parameter"
end method;

define method object-type
    (object :: <warning-object>)
 => (name :: <string>);
  "warning"
end method;

define method object-type
    (object :: <serious-compiler-warning-object>)
 => (name :: <string>);
  "serious-warning"
end method;

define method object-type
    (object :: <compiler-error-object>)
 => (name :: <string>);
  "error"
end method;
