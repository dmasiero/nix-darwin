{ lib, buildNpmPackage, fetchurl, nodejs }:

buildNpmPackage rec {
  pname = "pi-coding-agent";
  version = "0.55.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-+gUj3BPFAmxqkeNcYLg1J1iXAjEdWpByqX4Ixyc4NmE=";
  };

  sourceRoot = "package";

  # The published npm tarball doesn't include a lockfile (monorepo).
  # We vendor one generated from the package's dependencies.
  postPatch = ''
    cp ${./pi-coding-agent-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-qfXL8XMq6rHPgYo+6x6hpdlWzMCEq1flCyhn4PLk9rc=";

  # The npm tarball ships pre-built JS in dist/, no build step needed
  dontNpmBuild = true;

  meta = with lib; {
    description = "Interactive coding agent CLI with read, bash, edit, write tools";
    homepage = "https://github.com/badlogic/pi-mono";
    license = licenses.mit;
    mainProgram = "pi";
    platforms = platforms.unix;
  };
}
