{
  pkgs,
  beetsPackage ? pkgs.beets,
}:
let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.beets ]);
  command = pkgs.writeShellApplication {
    name = "beets-import";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      exec ${pythonEnv}/bin/python3 -B ${../home/programs/beets-import}/cli.py \
        --beet ${beetsPackage}/bin/beet \
        --ffmpeg ${pkgs.ffmpeg}/bin/ffmpeg \
        --ffprobe ${pkgs.ffmpeg}/bin/ffprobe "$@"
    '';
  };
in
command.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    inherit pythonEnv;
  };
})
