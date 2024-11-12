/**
 * This Nix configuration file sets default settings for Nix, including enabling experimental features,
 * optimizing the Nix store, and configuring garbage collection.
 *
 * - `nix.settings.experimental-features`: Enables the Nix command and flakes.
 * - `nix.settings.auto-optimise-store`: Automatically optimizes the Nix store.
 * - `nix.settings.download-buffer-size`: Sets the download buffer size to 512MB.
 * - `nix.gc.automatic`: Enables automatic garbage collection.
 * - `nix.gc.dates`: Configures garbage collection to run weekly.
 * - `nix.gc.options`: Deletes generations older than 7 days during garbage collection.
 */

{ config, lib, pkgs, ... }:

{
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ]; # Enable Nix command and flakes
      auto-optimise-store = true; # Automatically optimise the Nix store
      download-buffer-size = 536870912; # 512MB download buffer size
    };

    gc = {
      automatic = lib.mkDefault true; # Enable automatic garbage collection
      dates = lib.mkDefault "weekly"; # Run garbage collection weekly
      options = lib.mkDefault "--delete-older-than 7d"; # Delete generations older than 7 days
    };
  };
}
