{ config, lib, ... }:

with lib;
let
  cfg = config.modules.hm.base.direnv;
in {
  options.modules.hm.base.direnv = with types; {
    enable = mkEnableOption "Direnv";
  };

  config = mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;

      enableZshIntegration = true;
      enableBashIntegration = true;

      config = {
        whitelist = {
          exact = ["$HOME/.envrc"];
        };
      };
    };
  };
}
