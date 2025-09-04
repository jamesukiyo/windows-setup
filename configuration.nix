# THIS FILE IS USED BY THE SCRIPT TO BOOTSTRAP AND IS NOT USED FOR ANYTHING ELSE
{ config, lib, pkgs, ... }:
{
	nix.settings.experimental-features = [ "nix-command" "flakes" "pipe-operators" ];
  imports = [
    <nixos-wsl/modules>
  ];
  wsl.enable = true;
  wsl.defaultUser = "james";
  system.stateVersion = "25.05";
}
