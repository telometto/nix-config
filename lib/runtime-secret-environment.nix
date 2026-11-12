{
  lib,
  pkgs,
  name,
  variable,
  source,
  group,
  requiredBy,
  jsonScalar ? false,
}:
let
  directory = "${name}-secret-environment";
  path = "/run/${directory}/environment";
in
{
  inherit path;
  service = {
    description = "Render ${name} runtime secret environment";
    inherit requiredBy;
    partOf = requiredBy;
    before = requiredBy;
    after = [ "sops-install-secrets.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
      Group = group;
      RuntimeDirectory = directory;
      RuntimeDirectoryMode = "0750";
      RuntimeDirectoryPreserve = true;
      UMask = "0077";
    };
    script = ''
      ${lib.getExe pkgs.python3} ${./runtime-secret-environment.py} ${lib.optionalString jsonScalar "--json-scalar"} ${
        lib.escapeShellArgs [
          variable
          (if source == null then "" else source)
          path
        ]
      }
    '';
  };
}
