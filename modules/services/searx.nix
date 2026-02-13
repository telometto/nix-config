{ lib, config, ... }:
let
  cfg = config.sys.services.searx or { };
in
{
  options.sys.services.searx = {
    enable = lib.mkEnableOption "Searx Meta Search";

    publicInstance = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether this is a public SearXNG instance.
        When enabled:
        - Sets server.public_instance = true
        - Enables metrics endpoint for transparency
        - Requires contact information for abuse reports
        - Enforces bind to localhost (security requirement)
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7777;
    };

    bind = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Bind address for the SearXNG service.
        Default is 127.0.0.1 (localhost only) for security.
        Should only be accessible via reverse proxy.
      '';
    };

    contactUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Contact URL or email for abuse reports (e.g., "mailto:abuse@example.com").
        Required when publicInstance = true.
      '';
      example = "mailto:admin@example.com";
    };

    privacyPolicyUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        URL to privacy policy. Recommended for public instances.
      '';
      example = "https://example.com/privacy";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Owner/extension point merged into services.searx.settings.";
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Traefik reverse proxy configuration for Searx.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional domain for hostname-based routing (e.g., "searx.example.com").
          If set, creates a separate router for this domain with pathPrefix = "/".
          This is useful for Cloudflare Tunnel with dedicated subdomains.
        '';
        example = "searx.example.com";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/searx";
        description = "URL path prefix for Searx.";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the path prefix before forwarding to Searx.";
      };

      extraMiddlewares = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional Traefik middlewares to apply.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.searx = {
      enable = lib.mkDefault true;
      redisCreateLocally = lib.mkDefault true;

      # Rate limiting configuration for bot detection and abuse prevention
      limiterSettings = {
        real_ip = {
          # Trust the first X-Forwarded-For header entry (behind reverse proxy)
          x_for = 1;
          # /32 = exact IP for IPv4 (strictest rate limiting per unique IP)
          ipv4_prefix = 32;
          # /56 = reasonable IPv6 subnet size (prevents single user bypass via IPv6 rotation)
          ipv6_prefix = 56;
        };

        botdetection = {
          ip_limit = {
            # Filter out link-local addresses (169.254.0.0/16, fe80::/10)
            filter_link_local = true;
            # Enable link_token for additional bot detection
            link_token = true;
          };
        };
      };

      settings = lib.mkMerge [
        {
          # General instance settings
          general = {
            # Disable debug mode in production (prevents information leakage)
            debug = false;
            instance_name = "SearXNG";

            # Enable metrics for public instances (transparency)
            # Disabled for private instances (prevents information disclosure)
            enable_metrics = cfg.publicInstance;
          };
        }
        # Contact and policy URLs (only set when needed to avoid conflicts)
        (lib.mkIf cfg.publicInstance {
          general.contact_url = cfg.contactUrl;
        })
        (lib.mkIf (cfg.privacyPolicyUrl != null) {
          general.privacypolicy_url = cfg.privacyPolicyUrl;
        })
        {
          # Server configuration
          server = {
            # Use centralized secrets bridge; avoids direct SOPS references here
            secret_key = config.sys.secrets.searxSecretKeyFile or "/run/secrets/searx-secret-key";
            inherit (cfg) port;
            bind_address = cfg.bind;

            # Enable rate limiter (requires redis/valkey)
            limiter = true;

            # Enable image proxy to prevent direct connections to image hosts
            # This protects user privacy by proxying all image requests through SearXNG
            image_proxy = true;

            # HTTP method for search requests (POST for privacy)
            method = "POST";

            # Public instance flag - enables public instance features when true
            public_instance = cfg.publicInstance;
          };
        }
        # Base URL - only set when domain is configured
        (lib.mkIf (cfg.reverseProxy.domain != null) {
          server.base_url = "https://${cfg.reverseProxy.domain}";
        })
        {
          # User Interface settings
          ui = {
            # Use hashed static files for cache busting (security best practice)
            static_use_hash = true;
            default_locale = "en";
            query_in_title = true;
            infinite_scroll = false;
            center_alignment = true;
            default_theme = "simple";
            theme_args = {
              simple_style = "auto";
            };
            search_on_category_select = false;
            hotkeys = "vim";
          };

          # Search behavior settings
          search = {
            # Safe search level: 0=off, 1=moderate, 2=strict
            safe_search = 0;

            # Autocomplete settings
            autocomplete_min = 2;
            autocomplete = "startpage";

            # Rate limiting for failed requests
            ban_time_on_fail = 5;
            max_ban_time_on_fail = 120;

            # Available output formats
            formats = [
              "html"
              "json"
            ];
          };

          # Outgoing request settings (security & performance)
          outgoing = {
            # Timeout settings prevent hanging requests
            request_timeout = 5.0;
            max_request_timeout = 15.0;

            # Connection pooling for performance
            pool_connections = 100;
            pool_maxsize = 15;

            # Enable HTTP/2 for better performance and security
            enable_http2 = true;

            # Uncomment to use a proxy for all outgoing requests (Tor, etc.)
            # proxies = {
            #   http = "socks5://127.0.0.1:9050";
            #   https = "socks5://127.0.0.1:9050";
            # };

            # Enable to verify SSL certificates (recommended for security)
            # verify = true;
          };

          # Security plugins
          enabled_plugins = [
            # Essential security & privacy plugins
            "Hash plugin" # Calculate hashes
            "Tor check plugin" # Check if using Tor
            "Tracker URL remover" # Remove tracking parameters from URLs
            "Hostname replace" # Replace hostnames (privacy frontends)
            "Hostnames plugin" # Privacy-friendly redirects (YouTube→Invidious, Twitter→Nitter, etc.)

            # Utility plugins
            "Basic Calculator" # In-page calculator
            "Unit converter plugin" # Unit conversions
            "Open Access DOI rewrite" # Redirect to open access versions
          ];

          # Default search engine configuration
          # Privacy-optimized engine selection with quality results
          # Can be overridden via cfg.settings.engines in host config
          engines = lib.mapAttrsToList (name: value: { inherit name; } // value) {
            # Disable privacy-invasive engines
            "duckduckgo".disabled = true; # Use other privacy-focused alternatives
            "brave".disabled = true; # Brave has tracking concerns
            "brave.images".disabled = true;
            "brave.videos".disabled = true;
            "brave.news".disabled = true;

            # Privacy-first search engines (prioritize these)
            "startpage".disabled = false; # Privacy proxy for Google results
            "startpage".weight = 2.0; # PRIMARY - best privacy + quality combo
            "mojeek".disabled = false; # Privacy-focused, independent index
            "mojeek".weight = 1.0;
            "qwant".disabled = false; # EU-based, privacy-focused
            "qwant".weight = 1.0;

            # Traditional engines (fallback only, lower weight)
            # Your SearXNG proxies these, but use sparingly for best privacy
            "bing".disabled = false;
            "bing".weight = 0.5; # Lower weight - use as supplement
            "google".disabled = false;
            "google".weight = 0.5; # Lower weight - use as supplement

            # Alternative search engines
            "mwmbl".disabled = false; # Non-profit, ad-free
            "mwmbl".weight = 0.4;

            # Knowledge & reference
            "ddg definitions".disabled = false;
            "ddg definitions".weight = 2;
            "wikidata".disabled = false;
            "wikibooks".disabled = false;
            "wikipedia".disabled = false;
            "wikipedia".weight = 1.5;

            # Images
            "bing images".disabled = false;
            "google images".disabled = false;
            "duckduckgo images".disabled = true;
            "unsplash".disabled = false;
            "openverse".disabled = false;
            "wikicommons.images".disabled = false;

            # Videos
            "bing videos".disabled = false;
            "google videos".disabled = false;
            "youtube".disabled = false;
            "peertube".disabled = false; # Federated video platform
            "sepiasearch".disabled = false; # PeerTube search

            # Disable problematic/unnecessary engines
            "yacy images".disabled = true; # Requires yacy instance
            "ahmia".disabled = true; # Tor search - not for public instance
            "torch".disabled = true; # Tor search - not for public instance
            "google news".disabled = true; # Prefer other news sources
          };
        }
        # Redis/Valkey configuration - only set when using local redis
        (lib.mkIf config.services.searx.redisCreateLocally {
          # Redis has been renamed to Valkey in NixOS settings, but the service path remains redis
          valkey.url = "unix://${config.services.redis.servers.searx.unixSocket}";
        })
        cfg.settings
      ];
    };

    # Configure Traefik reverse proxy if enabled
    services.traefik.dynamic.files.searx = lib.mkIf
      (
        cfg.reverseProxy.enable
        && cfg.reverseProxy.domain != null
        && config.services.traefik.enable or false
      )
      {
        settings = {
          http = {
            routers.searx = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "searx";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ] ++ cfg.reverseProxy.extraMiddlewares;
            };

            services.searx.loadBalancer = {
              servers = [ { url = "http://localhost:${toString cfg.port}"; } ];
              passHostHeader = true;
            };
          };
        };
      };

    # Validate configuration
    assertions = [
      {
        assertion = !cfg.publicInstance || cfg.contactUrl != null;
        message = "sys.services.searx.contactUrl must be set when publicInstance = true (required for abuse reports)";
      }
      {
        assertion = !cfg.publicInstance || (cfg.bind == "127.0.0.1" || cfg.bind == "::1");
        message = "sys.services.searx.bind must be localhost (127.0.0.1 or ::1) when publicInstance = true (security requirement - only accessible via reverse proxy)";
      }
      {
        assertion = !cfg.publicInstance || cfg.reverseProxy.enable;
        message = "sys.services.searx.reverseProxy.enable must be true when publicInstance = true (security requirement)";
      }
    ];
  };
}
