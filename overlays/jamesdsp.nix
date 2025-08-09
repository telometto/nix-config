# Overlay exposing jamesdsp from stable set
self: super: {
  # Use pkgs-stable from specialArgs if desired; fallback to super if unavailable
  jamesdsp = (super.pkgs-stable or super).jamesdsp or super.jamesdsp;
}
