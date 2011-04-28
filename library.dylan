module: dylan-user

define library web-ide-backend
  use common-dylan;
  use system;
  use io;
  use collections;
  use registry-projects;
  use environment-commands;
  use environment-protocols;
  use source-records;
  use http-common;
  use koala;
  use json;
end;

define module web-ide-backend
  use common-dylan, 
    exclude: { direct-superclasses, all-superclasses, direct-subclasses };
  use threads;
  use locators;
  use standard-io;
  use file-system;
  use print;
  use format;
  use streams;
  use table-extensions;
  use operating-system,
    rename: { load-library => os/load-library };
  use registry-projects;
  use environment-commands;
  use environment-protocols,
    exclude: { application-filename,
	       application-arguments,
	       run-application };
  use source-records;
  use source-records-implementation;
  use koala;
  use http-common;
  use json;
end;
