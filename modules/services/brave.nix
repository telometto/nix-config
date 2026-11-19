import ../../lib/linuxserver-browser.nix {
  name = "brave";
  title = "Brave";
  image = (import ../../lib/oci-images.nix).brave;
}
