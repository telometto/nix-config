{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.adguardhome;

  defaultSettings = {
    dns = {
      bind_hosts = [
        "0.0.0.0"
        "::"
      ];
      port = 53;

      upstream_dns = [
        "https://dns.quad9.net/dns-query"
        "tls://dns.quad9.net"
      ];

      bootstrap_dns = [
        "9.9.9.9"
        "149.112.112.112"
        "2620:fe::fe"
        "2620:fe::9"
      ];

      all_servers = true;
      fastest_addr = false;

      allowed_clients = [ ];
      disallowed_clients = [ ];
      blocked_hosts = [ ];

      trusted_proxies = [
        "127.0.0.0/8"
        "::1/128"
      ];

      cache_size = 4194304;
      cache_ttl_min = 0;
      cache_ttl_max = 0;
      cache_optimistic = false;

      enable_dnssec = true;

      edns_client_subnet = {
        custom_ip = "";
        enabled = false;
        use_custom = false;
      };

      filtering_enabled = true;
      filters_update_interval = 1;

      parental_enabled = false;
      safebrowsing_enabled = false;

      safesearch = {
        enabled = false;
        bing = true;
        duckduckgo = true;
        ecosia = true;
        google = true;
        pixabay = true;
        yandex = true;
        youtube = true;
      };

      protection_enabled = true;
      protection_disabled_until = null;

      blocking_mode = "default";
      blocking_ipv4 = "";
      blocking_ipv6 = "";
      blocked_response_ttl = 10;

      parental_block_host = "family-block.dns.adguard.com";
      safebrowsing_block_host = "standard-block.dns.adguard.com";

      ratelimit = 0;
      ratelimit_whitelist = [ ];
      refuse_any = true;

      upstream_timeout = "10s";

      private_networks = [ ];
      use_private_ptr_resolvers = true;
      local_ptr_upstreams = [ ];

      use_dns64 = false;
      dns64_prefixes = [ ];

      serve_http3 = false;
      use_http3_upstreams = false;
    };

    tls = {
      enabled = false;
      server_name = "";
      force_https = false;
      port_https = 443;
      port_dns_over_tls = 853;
      port_dns_over_quic = 853;
      port_dnscrypt = 0;
      dnscrypt_config_file = "";
      allow_unencrypted_doh = false;
      certificate_chain = "";
      private_key = "";
      certificate_path = "";
      private_key_path = "";
      strict_sni_check = false;
    };

    querylog = {
      ignored = [ ];
      interval = "1h";
      size_memory = 1000;
      enabled = true;
      file_enabled = true;
      anonymize_client_ip = true;
    };

    statistics = {
      ignored = [ ];
      interval = "1h";
      enabled = true;
    };

    filters = [
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
        name = "AdGuard DNS filter";
        id = 1;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_47.txt";
        name = "AdGuard DNS Popup Hosts filter";
        id = 2;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_27.txt";
        name = "OISD Blocklist Big";
        id = 3;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_24.txt";
        name = "AWAvenue Ads Rule";
        id = 4;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_33.txt";
        name = "Steven Black's List";
        id = 5;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_11.txt";
        name = "Dandelion Sprout's Anti Push Notifications";
        id = 6;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_7.txt";
        name = "Perflyst and Dandelion Sprout's Smart-TV Blocklist";
        id = 7;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_30.txt";
        name = "Phishing URL Blocklist (PhishTank and OpenPhish)";
        id = 8;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_12.txt";
        name = "Dandelion Sprout's Anti-Malware List";
        id = 9;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_31.txt";
        name = "Phishing Army";
        id = 10;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_10.txt";
        name = "Scam Blocklist by DurableNapkin";
        id = 11;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt";
        name = "The Big List of Hacked Malware Web Sites";
        id = 12;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_8.txt";
        name = "NoCoin Filter List";
        id = 13;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_18.txt";
        name = "WindowsSpyBlocker - Hosts spy rules";
        id = 14;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_38.txt";
        name = "HaGeZi's Threat Intelligence Feeds";
        id = 15;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_34.txt";
        name = "HaGeZi's Pro++ Blocklist";
        id = 16;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_48.txt";
        name = "HaGeZi's Badware Hoster Blocklist";
        id = 17;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_64.txt";
        name = "HaGeZi's DynDNS Blocklist";
        id = 18;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_49.txt";
        name = "HaGeZi's The World's Most Abused TLDs";
        id = 19;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_50.txt";
        name = "uBlock filters - Badware risks";
        id = 20;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_4.txt";
        name = "Dan Pollock's List";
        id = 21;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_3.txt";
        name = "Peter Lowe's Blocklist";
        id = 22;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_23.txt";
        name = "Dandelion Sprout's Game Console Adblock List";
        id = 23;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_32.txt";
        name = "Stalkerware Indicators List";
        id = 24;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_51.txt";
        name = "Malicious URL Blocklist (URLHaus)";
        id = 25;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_57.txt";
        name = "ShadowWhisperer's Malware List";
        id = 26;
      }
      {
        enabled = true;
        url = "https://v.firebog.net/hosts/Admiral.txt";
        name = "Admiral";
        id = 100;
      }
      {
        enabled = true;
        url = "https://raw.githubusercontent.com/jdlingyu/ad-wars/master/hosts";
        name = "Ad Wars";
        id = 101;
      }
      {
        enabled = true;
        url = "https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt";
        name = "anudeepND's Blacklist";
        id = 102;
      }
      {
        enabled = true;
        url = "https://badblock.celenity.dev/abp/badblock.txt";
        name = "My BadBlock";
        id = 103;
      }
      {
        enabled = true;
        url = "https://sysctl.org/cameleon/hosts";
        name = "CAMELEON";
        id = 104;
      }
      {
        enabled = true;
        url = "https://zerodot1.gitlab.io/CoinBlockerLists/hosts_browser";
        name = "CoinBlocker";
        id = 105;
      }
      {
        enabled = true;
        url = "https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt";
        name = "DeveloperDan Ads & Tracking";
        id = 106;
      }
      {
        enabled = true;
        url = "https://osint.digitalside.it/Threat-Intel/lists/latestdomains.txt";
        name = "Digital Side Threat Intel";
        id = 107;
      }
      {
        enabled = true;
        url = "https://divested.dev/hosts-domains-wildcards";
        name = "Divested Combined Blocklist";
        id = 108;
      }
      {
        enabled = true;
        url = "https://v.firebog.net/hosts/Easylist.txt";
        name = "EasyList";
        id = 109;
      }
      {
        enabled = true;
        url = "https://v.firebog.net/hosts/Easyprivacy.txt";
        name = "EasyPrivacy";
        id = 110;
      }
      {
        enabled = true;
        url = "https://feodotracker.abuse.ch/downloads/ipblocklist.txt";
        name = "Feudo Tracker Abuse";
        id = 111;
      }
      {
        enabled = true;
        url = "https://raw.githubusercontent.com/fmhy/FMHYFilterlist/main/filterlist.txt";
        name = "FMHY Unsafe sites filterlist - Plus";
        id = 112;
      }
      {
        enabled = true;
        url = "https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt";
        name = "FrogEye First Party Trackers";
        id = 113;
      }
      {
        enabled = true;
        url = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/doh.txt";
        name = "HaGeZi's Encrypted DNS Servers";
        id = 114;
      }
      {
        enabled = true;
        url = "https://raw.githubusercontent.com/xRuffKez/NRD/main/lists/14-day/adblock/nrd-14day_adblock.txt";
        name = "HaGeZi/xRuffKez's Newly Registered Domains (14 days)";
        id = 115;
      }
      {
        enabled = true;
        url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif-ips.txt";
        name = "HaGeZi's Threat Intelligence Feeds - IPs";
        id = 116;
      }
      {
        enabled = true;
        url = "https://hblock.molinero.dev/hosts_adblock.txt";
        name = "hBlock";
        id = 117;
      }
      {
        enabled = true;
        url = "https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts";
        name = "hostsVN";
        id = 118;
      }
      {
        enabled = true;
        url = "https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt";
        name = "KADhosts";
        id = 119;
      }
      {
        enabled = true;
        url = "https://raw.githubusercontent.com/stamparm/aux/master/maltrail-malware-domains.txt";
        name = "Maltrail Malware Domains";
        id = 120;
      }
      {
        enabled = true;
        url = "https://v.firebog.net/hosts/Prigent-Ads.txt";
        name = "Prigent-Ads";
        id = 121;
      }
      {
        enabled = true;
        url = "https://v.firebog.net/hosts/Prigent-Crypto.txt";
        name = "Prigent-Crypto";
        id = 122;
      }
      {
        enabled = true;
        url = "https://v.firebog.net/hosts/Prigent-Malware.txt";
        name = "Prigent-Malware";
        id = 123;
      }
      {
        enabled = true;
        url = "https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt";
        name = "Quidsup NoTrack Malware Blocklist";
        id = 124;
      }
      {
        enabled = true;
        url = "https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-blocklist.txt";
        name = "Quidsup NoTrack Tracker Blocklist";
        id = 125;
      }
      {
        enabled = true;
        url = "https://v.firebog.net/hosts/RPiList-Malware.txt";
        name = "RPiList-Malware";
        id = 126;
      }
      {
        enabled = true;
        url = "https://v.firebog.net/hosts/RPiList-Phishing.txt";
        name = "RPiList-Phishing";
        id = 127;
      }
      {
        enabled = true;
        url = "https://raw.githubusercontent.com/Spam404/lists/master/adblock-list.txt";
        name = "Spam404";
        id = 128;
      }
      {
        enabled = true;
        url = "https://raw.githubusercontent.com/olbat/ut1-blacklists/master/blacklists/cryptojacking/domains";
        name = "Ut1 Cryptojacking Domains";
        id = 129;
      }
      {
        enabled = true;
        url = "https://raw.githubusercontent.com/olbat/ut1-blacklists/master/blacklists/malware/domains";
        name = "Ut1 Malware Domains";
        id = 130;
      }
      {
        enabled = true;
        url = "https://raw.githubusercontent.com/olbat/ut1-blacklists/master/blacklists/phishing/domains";
        name = "Ut1 Phishing Domains";
        id = 131;
      }
      {
        enabled = true;
        url = "https://v.firebog.net/hosts/static/w3kbl.txt";
        name = "WaLLy3K's Personal Blocklist";
        id = 132;
      }
    ];

    whitelist_filters = [
      {
        enabled = true;
        url = "https://badblock.celenity.dev/abp/whitelist.txt";
        name = "BadBlock Whitelist";
        id = 1;
      }
      {
        enabled = true;
        url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/whitelist-urlshortener.txt";
        name = "HaGeZi's URL Shorteners";
        id = 2;
      }
      {
        enabled = true;
        url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_54.txt";
        name = "HaGeZi's Allowlist Referral";
        id = 3;
      }
    ];

    user_rules = [
      "||adservice.google.*^$important"
      "||adsterra.com^$important"
      "||amplitude.com^$important"
      "||analytics.edgekey.net^$important"
      "||analytics.twitter.com^$important"
      "||app.adjust.*^$important"
      "||app.*.adjust.com^$important"
      "||app.appsflyer.com^$important"
      "||doubleclick.net^$important"
      "||googleadservices.com^$important"
      "||guce.advertising.com^$important"
      "||metric.gstatic.com^$important"
      "||mmstat.com^$important"
      "||statcounter.com^$important"
    ];

    dhcp = {
      enabled = false;
      interface_name = "";
      local_domain_name = "lan";

      dhcpv4 = {
        gateway_ip = "";
        subnet_mask = "";
        range_start = "";
        range_end = "";
        lease_duration = 86400;
        icmp_timeout_msec = 1000;
        options = [ ];
      };

      dhcpv6 = {
        range_start = "";
        lease_duration = 86400;
        ra_slaac_only = false;
        ra_allow_slaac = false;
      };
    };

    filtering = {
      blocking_ipv4 = "";
      blocking_ipv6 = "";
      blocked_services = {
        schedule = {
          time_zone = "Local";
        };
        ids = [ ];
      };
      protection_disabled_until = null;
      safe_search = {
        enabled = false;
        bing = true;
        duckduckgo = true;
        google = true;
        pixabay = true;
        yandex = true;
        youtube = true;
      };
      blocking_mode = "default";
      parental_block_host = "family-block.dns.adguard.com";
      safebrowsing_block_host = "standard-block.dns.adguard.com";
      rewrites = [ ];
      safebrowsing_cache_size = 1048576;
      safesearch_cache_size = 1048576;
      parental_cache_size = 1048576;
      cache_time = 30;
      filters_update_interval = 1;
      blocked_response_ttl = 10;
      filtering_enabled = true;
      parental_enabled = false;
      safebrowsing_enabled = false;
      protection_enabled = true;
    };

    clients = {
      runtime_sources = {
        whois = true;
        arp = true;
        rdns = true;
        dhcp = true;
        hosts = true;
      };
      persistent = [ ];
    };

    log = {
      file = "";
      max_backups = 0;
      max_size = 100;
      max_age = 3;
      compress = false;
      local_time = false;
      verbose = false;
    };

    os = {
      group = "";
      user = "";
      rlimit_nofile = 0;
    };

    schema_version = 28;
  };
in
{
  options.sys.services.adguardhome = {
    enable = lib.mkEnableOption "AdGuard Home DNS filter and ad blocker";

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "IP address for the web interface to listen on";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port for the AdGuard Home web interface";
    };

    dnsPort = lib.mkOption {
      type = lib.types.port;
      default = 53;
      description = "Port for DNS service";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for AdGuard Home web interface and DNS ports";
    };

    mutableSettings = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow changes made in the web UI to persist between restarts";
    };

    disableSystemdResolved = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Automatically disable systemd-resolved's stub listener and DNSSEC validation
        to prevent conflicts with AdGuard Home. AdGuard Home will handle DNSSEC instead.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = defaultSettings;
      description = "AdGuard Home configuration settings. Merged with defaults.";
      example = lib.literalExpression ''
        {
          dns.upstream_dns = [ "1.1.1.1" "9.9.9.9" ];
          filtering.protection_enabled = true;
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.adguardhome = {
      enable = true;
      inherit (cfg)
        host
        port
        openFirewall
        mutableSettings
        ;
      settings = lib.mkMerge [
        defaultSettings
        { dns.port = cfg.dnsPort; }
        cfg.settings
      ];
    };

    sys.services.resolved = lib.mkIf cfg.disableSystemdResolved {
      enable = lib.mkForce false;
    };

    services.resolved = lib.mkIf cfg.disableSystemdResolved {
      enable = true;

      dnssec = "false";
      llmnr = "true";

      extraConfig = ''
        DNSStubListener=no
      '';
    };

    networking.nameservers = lib.mkIf cfg.disableSystemdResolved [ "127.0.0.1" ];
  };
}
