{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "swo-cli";
  version = "1.3.6";

  src = fetchFromGitHub {
    owner = "solarwinds";
    repo = "swo-cli";
    rev = "v${version}";
    hash = "sha256-OeipY7pT6Z6D31zHEBbBwNSs4ecQEhxv0DKd6JWE3VQ=";
  };

  vendorHash = "sha256-Ei+kPeiic6T3txyh6ZmviIINXmGEFUuNxVNItdau26A=";

  subPackages = [ "cmd/swo" ];

  meta = with lib; {
    description = "CLI tool for SolarWinds Observability";
    homepage = "https://github.com/solarwinds/swo-cli";
    license = licenses.asl20;
  };
}
