# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  services.scrutiny = {
  	enable = true;
  	openFirewall = true;

  	settings = {
  		web = {
	      listen = {
  		    port = 8072;
  	    };
  	  };
	  };
  };
}
