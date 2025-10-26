{ lib, config, ... }:
let
  cfg = config.telometto.services.searx or { };
in
{
  options.telometto.services.searx = {
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

      cfTunnel = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable Cloudflare Tunnel ingress for this service.
            When enabled, automatically adds this service to the Cloudflare Tunnel ingress configuration.
            Requires reverseProxy.enable = true and reverseProxy.domain to be set.
          '';
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.searx = {
      enable = true;
      redisCreateLocally = true;

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
          ###################################
          ### SECURITY & PRIVACY SETTINGS ###
          ###################################

          # General instance settings
          general = {
            # Disable debug mode in production (prevents information leakage)
            debug = false;
            instance_name = "SearXNG";

            # Contact and policy URLs (configurable, required for public instances)
            contact_url = if cfg.publicInstance then cfg.contactUrl else false;
            privacypolicy_url = if cfg.privacyPolicyUrl != null then cfg.privacyPolicyUrl else false;

            # Donation URL disabled by default
            donation_url = false;

            # Enable metrics for public instances (transparency)
            # Disabled for private instances (prevents information disclosure)
            enable_metrics = cfg.publicInstance;
          };

          # Server configuration
          server = {
            # Use centralized secrets bridge; avoids direct SOPS references here
            secret_key = config.telometto.secrets.searxSecretKeyFile;
            inherit (cfg) port;
            bind_address = cfg.bind;

            # Enable rate limiter (requires redis/valkey)
            limiter = true;

            # Enable image proxy to prevent direct connections to image hosts
            # This protects user privacy by proxying all image requests through SearXNG
            image_proxy = true;

            # HTTP method for search requests (GET is standard)
            method = "GET";

            # Public instance flag - enables public instance features when true
            public_instance = cfg.publicInstance;

            # Base URL - configured via reverseProxy.domain if available
            base_url = if cfg.reverseProxy.domain != null then "https://${cfg.reverseProxy.domain}" else null;
          };

          # User Interface settings
          ui = {
            # Use hashed static files for cache busting (security best practice)
            static_use_hash = true;
            default_locale = "en";
            query_in_title = true;
            infinite_scroll = false;
            center_alignment = true;
            default_theme = "simple";
            theme_args.simple_style = "auto";
            search_on_category_select = false;
            hotkeys = "vim";
          };

          # Search behavior settings
          search = {
            # Safe search level: 0=off, 1=moderate, 2=strict
            safe_search = 0;

            # Autocomplete settings
            autocomplete_min = 2;
            autocomplete = "duckduckgo";

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

          # Redis/Valkey configuration for rate limiting and caching
          # Redis has been renamed to Valkey in NixOS settings, but the service path remains redis
          valkey.url = lib.mkIf config.services.searx.redisCreateLocally "unix://${config.services.redis.servers.searx.unixSocket}";

          # Response headers for security
          # NOTE: Security headers are now configured at the Traefik reverse proxy level
          # via the 'security-headers' middleware in blizzard.nix (see http.middlewares.security-headers)
          # This provides consistent security headers across all services.
          # If you need SearXNG-specific headers, uncomment and customize below:
          #
          # server.response_headers = {
          #   X-Content-Type-Options = "nosniff";
          #   X-Frame-Options = "SAMEORIGIN";
          #   X-XSS-Protection = "1; mode=block";
          #   Referrer-Policy = "no-referrer";
          #   Content-Security-Policy = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:;";
          # };
        }
        cfg.settings
      ];
    };

    # Configure Traefik reverse proxy if enabled
    services.traefik.dynamicConfigOptions =
      lib.mkIf
        (
          cfg.reverseProxy.enable
          && cfg.reverseProxy.domain != null
          && config.services.traefik.enable or false
        )
        {
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

    # Configure Cloudflare Tunnel ingress if enabled
    telometto.services.cloudflared.ingress =
      lib.mkIf
        (
          cfg.reverseProxy.cfTunnel.enable
          && cfg.reverseProxy.enable
          && cfg.reverseProxy.domain != null
          && config.telometto.services.cloudflared.enable or false
        )
        {
          "${cfg.reverseProxy.domain}" = "http://localhost:80";
        };

    # Validate configuration
    assertions = [
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "telometto.services.searx.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
      {
        assertion = !cfg.publicInstance || cfg.contactUrl != null;
        message = "telometto.services.searx.contactUrl must be set when publicInstance = true (required for abuse reports)";
      }
      {
        assertion = !cfg.publicInstance || (cfg.bind == "127.0.0.1" || cfg.bind == "::1");
        message = "telometto.services.searx.bind must be localhost (127.0.0.1 or ::1) when publicInstance = true (security requirement - only accessible via reverse proxy)";
      }
      {
        assertion = !cfg.publicInstance || cfg.reverseProxy.enable;
        message = "telometto.services.searx.reverseProxy.enable must be true when publicInstance = true (security requirement)";
      }
    ];
  };
}
