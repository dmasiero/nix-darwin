[
  {
    id = "pi-coding-agent";
    displayName = "pi-coding-agent";
    attrName = "pi-coding-agent";
    source = {
      type = "npm";
      package = "@mariozechner/pi-coding-agent";
      distTag = "latest";
    };
    update = {
      type = "npm-package";
      target = "pi-coding-agent.nix";
      derivationFile = "pi-coding-agent.nix";
      lockfile = "pi-coding-agent-package-lock.json";
    };
  }
  {
    id = "swo-cli";
    displayName = "swo-cli";
    attrName = "swo-cli";
    source = {
      type = "github-release";
      owner = "solarwinds";
      repo = "swo-cli";
      stripV = true;
    };
    update = {
      type = "manual";
      target = "swo-cli.nix";
    };
  }
]
