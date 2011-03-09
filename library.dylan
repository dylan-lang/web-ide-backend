module: dylan-user

define library web-ide-backend
  use common-dylan;
  use system;
  use io;
  use collections;
  use registry-projects;
  use environment-commands;
  use environment-protocols;
  use koala;
  use json;
end;

define module web-ide-backend
  use common-dylan;
  use standard-io;
  use file-system;
  use print;
  use format;
  use table-extensions;
  use operating-system,
    rename: { load-library => os/load-library };
  use registry-projects;
  use environment-commands;
  use environment-protocols,
    exclude: { application-filename,
	       application-arguments,
	       run-application };
  use koala;
  use json;
end;
