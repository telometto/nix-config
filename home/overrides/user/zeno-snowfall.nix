# User-specific configuration for zeno on snowfall host
# This file is automatically imported only for zeno on snowfall
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # TODO: temporary until Codex declares all required system-library build inputs.
  codex = pkgs.codex.overrideAttrs {
    dontCargoUseSystemLibs = true;
  };
in
{
  imports = [ ./zeno-desktop-ssh.nix ];

  # User-specific packages for admin on snowfall
  home.packages = [
    pkgs.polychromatic # Razer configuration tool
    pkgs.tuxguitar # Guitar tablature editor and player
    pkgs.pgadmin4-desktopmode # PostgreSQL administration tool
    pkgs.vorta # Borg backup GUI
    pkgs.hugo # static website engine
    pkgs.signal-desktop
    # pkgs.logseq # Issues with Electron
    # pkgs.kdePackages.krdc
    pkgs.teams-for-linux
    pkgs.meld
    # pkgs.rustdesk-flutter
    pkgs.lmstudio
    pkgs.podman-desktop
    pkgs.zola
    pkgs.rendercv
    pkgs.uv
    pkgs.filen-desktop
    pkgs.filen-cli
    pkgs.nodejs
    pkgs.annotation-mono
    pkgs.jellyfin-desktop
    pkgs.bubblewrap
    # TODO: temporary: use stable Tectonic until the unstable AWS-LC build is fixed.
    (pkgs.chatgpt.override {
      inherit codex;
      tectonic-unwrapped = pkgs.tectonic-unwrapped;
    })
  ]
  ++ (with pkgs.sweethome3d; [
    application
    furniture-editor
    textures-editor
  ]);

  hm = {
    programs = {
      codex = {
        enable = true;
        package = codex;
        preferXdgDirectories = false;
        mutableSettings = true;

        context = ''
          Keep development tools from creating new visible directories directly
          in $HOME. Check unfamiliar tools' storage defaults and use documented
          environment variables or configuration to redirect generated files:

          - Caches: $XDG_CACHE_HOME/codex/<tool>
          - Temporary scratch work: directories created with mktemp -d
          - Persistent configuration, data, and state: appropriate XDG directories

          Preserve existing user data and project-required paths.
        '';

        # Merge these preferences into ~/.codex/config.toml while preserving
        # local MCP credentials, project trust, and plugin/skill state.
        settings = {
          model = "gpt-6.1-sol";
          model_reasoning_effort = "max";
          plan_mode_reasoning_effort = "max";
          personality = "pragmatic";
          approvals_reviewer = "auto_review";
          service_tier = "default";

          shell_environment_policy.set = {
            GOPATH = "${config.xdg.cacheHome}/codex/go";
            GOMODCACHE = "${config.xdg.cacheHome}/codex/go/pkg/mod";
            GOCACHE = "${config.xdg.cacheHome}/codex/go/build";
          };

          features = {
            terminal_resize_reflow = true;
            memories = true;
            network_proxy = true;
            mentions_v2 = true;
            prevent_idle_sleep = true;
            worktrees = true;
            analytics_plan_history = true;
            daemon_auto_start = true;
            login_shell_package_path = true;
          };

          tui = {
            theme = "gruvbox-dark";
            status_line = [
              "model-with-reasoning"
              "context-used"
              "five-hour-limit"
              "weekly-limit"
            ];
            status_line_use_colors = true;
            session_picker_view = "comfortable";
          };
        };
      };

      development = {
        extraPackages = [
          pkgs.vscode
          # pkgs.jetbrains.idea-oss # disabled due to vulnerable package
        ];

        git.lfs = true;
      };

      gitea.enable = true;
    };

    files.sshAllowedSigners = lib.mkAfter [
      ''telometto@gitea namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINpFgTwAXaVs3LSoVuQsQoylu2G80QzkqFA751naKNUQ''
    ];

    services = {
      autotidy = {
        enable = true;
        settings.rules =
          let
            directories = config.xdg.userDirs;
            locations = [
              directories.documents
              directories.pictures
              directories.videos
              directories.download
              directories.music
            ];
            categories = [
              {
                name = "Documents";
                directory = directories.documents;
                extensions = [
                  "pdf"
                  "doc"
                  "docx"
                  "docm"
                  "dot"
                  "dotx"
                  "dotm"
                  "xls"
                  "xlsx"
                  "xlsm"
                  "xlsb"
                  "xlt"
                  "xltx"
                  "xltm"
                  "ppt"
                  "pptx"
                  "pptm"
                  "pot"
                  "potx"
                  "potm"
                  "pps"
                  "ppsx"
                  "ppsm"
                  "odt"
                  "ods"
                  "odp"
                  "odg"
                  "ott"
                  "ots"
                  "otp"
                  "rtf"
                  "txt"
                  "md"
                  "markdown"
                  "rst"
                  "csv"
                  "tsv"
                  "tex"
                  "epub"
                  "mobi"
                  "azw"
                  "azw3"
                  "djvu"
                  "djv"
                  "pages"
                  "numbers"
                ];
                mimeTypes = [
                  "application/pdf"
                  "application/rtf"
                  "text/rtf"
                  "text/markdown"
                  "text/csv"
                  "text/tab-separated-values"
                  "application/msword"
                  "application/vnd.ms-word*"
                  "application/vnd.ms-excel*"
                  "application/vnd.ms-powerpoint*"
                  "application/vnd.openxmlformats-officedocument.*"
                  "application/vnd.oasis.opendocument.*"
                  "application/vnd.apple.pages"
                  "application/vnd.apple.numbers"
                  "application/vnd.apple.keynote"
                  "application/epub+zip"
                  "application/x-mobipocket-ebook"
                ];
              }
              {
                name = "Pictures";
                directory = directories.pictures;
                extensions = [
                  "jpg"
                  "jpeg"
                  "jpe"
                  "jfif"
                  "png"
                  "apng"
                  "gif"
                  "webp"
                  "avif"
                  "heic"
                  "heif"
                  "bmp"
                  "dib"
                  "tif"
                  "tiff"
                  "svg"
                  "svgz"
                  "ico"
                  "icns"
                  "jxl"
                  "jp2"
                  "j2k"
                  "jpf"
                  "jpx"
                  "psd"
                  "psb"
                  "xcf"
                  "kra"
                  "ora"
                  "dds"
                  "exr"
                  "hdr"
                  "raw"
                  "arw"
                  "cr2"
                  "cr3"
                  "dng"
                  "nef"
                  "nrw"
                  "orf"
                  "raf"
                  "rw2"
                  "pef"
                  "srw"
                ];
                mimeTypes = [ "image/*" ];
              }
              {
                name = "Videos";
                directory = directories.videos;
                extensions = [
                  "mp4"
                  "m4v"
                  "mkv"
                  "avi"
                  "mov"
                  "qt"
                  "webm"
                  "wmv"
                  "asf"
                  "flv"
                  "f4v"
                  "mpeg"
                  "mpg"
                  "mpe"
                  "m1v"
                  "m2v"
                  "m2ts"
                  "mts"
                  "mxf"
                  "vob"
                  "ogv"
                  "ogm"
                  "3gp"
                  "3g2"
                  "rm"
                  "rmvb"
                ];
                mimeTypes = [ "video/*" ];
              }
              {
                name = "Music";
                directory = directories.music;
                extensions = [
                  "mp3"
                  "mp2"
                  "flac"
                  "wav"
                  "wave"
                  "ogg"
                  "oga"
                  "opus"
                  "aac"
                  "m4a"
                  "m4b"
                  "m4p"
                  "m4r"
                  "alac"
                  "aif"
                  "aiff"
                  "aifc"
                  "wma"
                  "ape"
                  "wv"
                  "mka"
                  "amr"
                  "au"
                  "caf"
                  "mid"
                  "midi"
                  "dsf"
                  "dff"
                  "tta"
                  "tak"
                  "ac3"
                  "eac3"
                  "dts"
                ];
                mimeTypes = [ "audio/*" ];
              }
            ];
            extensionPattern = extensions: "(?i)\\.(${lib.concatStringsSep "|" extensions})$";
            mkRule = category: {
              name = "Organize ${category.name}";
              inherit locations;
              recursive = false;
              filters = [
                { file_type = "file"; }
                {
                  not = [
                    # Leave download fragments, editor backups, and Office lock files alone.
                    {
                      name.regex = "(?i)(^~\\$|\\.(part|partial|crdownload|download|tmp|temp|aria2|filepart|!qb|bak|backup|swp|swo)$|~$)";
                    }
                  ];
                }
                {
                  # A known extension takes precedence over conflicting content detection.
                  not = [
                    {
                      name.regex = extensionPattern (
                        lib.concatMap (other: lib.optionals (other.name != category.name) other.extensions) categories
                      );
                    }
                  ];
                }
                {
                  any = [
                    { name.regex = extensionPattern category.extensions; }
                    { mime_type = category.mimeTypes; }
                  ];
                }
              ];
              actions = [
                {
                  move = {
                    # Upstream's extension template includes the dot, e.g. ext.jpg.
                    dest = "${category.directory}/ext\${ext}";
                    on_conflict = "rename_with_suffix";
                  };
                }
              ];
            };
          in
          map mkRule categories;
      };
      sshAgent.enable = true;
      gpgAgent = {
        enable = true;
        enableSsh = false;
      };
    };
  };
}
