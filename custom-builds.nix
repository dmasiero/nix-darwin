[
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
