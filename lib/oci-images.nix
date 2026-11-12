# Public manifest identities resolved on 2026-11-12. These pins freeze bytes;
# availability, vulnerability review and runtime acceptance remain update gates.
{
  firefox = "docker.io/linuxserver/firefox@sha256:6ef86d7663acd7d2ea490f2ae999683bfe60d6877e34ad773b0b246828ab1449"; # latest
  brave = "docker.io/linuxserver/brave@sha256:1db540c99996519f259cda767c41a73ccc575bf324a58e93fb1d10b23c060ecc"; # latest
  lingarr = "docker.io/lingarr/lingarr@sha256:38592c3f6156d519a131aeeda3245f0a7765e7c541b801a7b527b7d731efdfce"; # latest
  libretranslate = "docker.io/libretranslate/libretranslate@sha256:d56832ff665712faaf95338732b6635ffd9b4d6b9377d9a02d029008126b12e5"; # latest
  ollama = {
    cpu = "docker.io/ollama/ollama@sha256:910d0d8107b538fb0894e63163eb195de0cc7aefcbc666dc62d3b18f71124592"; # latest
    rocm = "docker.io/ollama/ollama@sha256:85b3c895222b1ddc9d63c40b20fc74f37a37593dcbbdfbf28910a925e43ead00"; # rocm
  };
  subgen = {
    latest = "docker.io/mccloud/subgen@sha256:2841515a3b409677669f0a10d77d49160bffb8111db91640fb33a4db06b3396c";
    cpu = "docker.io/mccloud/subgen@sha256:d26f285ee7ab1f48d45a6b5aea7c1b1f999b16c3770b71eee10e8602ae374cc5";
    amd = "docker.io/mccloud/subgen@sha256:e8a209812ca92929d54a369ec794cce095d64046b84841444ad4a90dad3279b4";
  };
  immich = {
    "3.3.6" = {
      cpu = "ghcr.io/immich-app/immich-machine-learning@sha256:14367bfb374b8576ddf49abd67c5ca0190a4c7fcf6303cdad65d7f7bf1a50bc2";
      cuda = "ghcr.io/immich-app/immich-machine-learning@sha256:2c2721c54c5e245b095eea3eb0cda743d112a3f537555b39e2e9a112879a50c1";
    };
    "3.4.1" = {
      cpu = "ghcr.io/immich-app/immich-machine-learning@sha256:8adebf414256f6e4f837bfbb66fa94f14f4da7260e3a1d65cbba49e4e35d8764";
      cuda = "ghcr.io/immich-app/immich-machine-learning@sha256:aaa7eb0f47e3815a1c575790085474e01c129df7c47ffbbcbfd80947d4c41339";
    };
  };
}
