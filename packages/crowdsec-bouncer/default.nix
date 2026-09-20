{ pkgs }:
pkgs.stdenvNoCC.mkDerivation {
  pname = "crowdsec-bouncer-attribution";
  version = "1.4.5-attribution.1";
  src = pkgs.fetchurl {
    url = "https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin/archive/refs/tags/v1.4.5.tar.gz";
    hash = "sha256-K+3xv7djPq1S8t+9B+aq00GvJUMvpktDS3lW7vD2zQ4=";
  };
  patches = [ ./attribution.patch ];
  postPatch = ''
    cp ${./telemetry.go} telemetry.go
    cp ${./telemetry_test.go} telemetry_test.go
  '';
  dontBuild = true;
  nativeCheckInputs = [ pkgs.go ];
  doCheck = true;
  checkPhase = ''
    export CGO_ENABLED=0 GOCACHE=$TMPDIR/go-cache
    go test -mod=vendor -run TestTelemetryPure ./...
  '';
  installPhase = ''
    mkdir -p $out
    cp -r . $out/
  '';
}
