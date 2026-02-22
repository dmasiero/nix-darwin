{ lib, buildNpmPackage, fetchurl, nodejs }:

buildNpmPackage rec {
  pname = "pi-coding-agent";
  version = "0.54.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-Lgw1/cpNdZjP4qdgiRMM1ZS4ePV/6WR5CRh63BRIuaI=";
  };

  sourceRoot = "package";

  # The published npm tarball doesn't include a lockfile (monorepo).
  # We vendor one generated from the package's dependencies.
  postPatch = ''
    cp ${./pi-coding-agent-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-1Peo0+g4IIq29dJVkXGYjJavqE9OMzHG+c4HtXm9+7Y=";

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
