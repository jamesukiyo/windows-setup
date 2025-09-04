# THIS FILE IS USED BY THE SCRIPT TO BOOTSTRAP AND IS NOT USED FOR ANYTHING ELSE
{ config, lib, pkgs, ... }:
{
	nix.settings.experimental-features = [ "cgroups" "nix-command" "flakes" "pipe-operators" ];
	nix.settings.max-jobs = "auto";
	nix.settings.http-connections = 0;
	nix.settings.flake-registry = "";
	nix.settings.show-trace = true;
	nix.settings.use-cgroups = true;
	nix.channel.enable = false;
  imports = [
    <nixos-wsl/modules>
  ];
  wsl.enable = true;
  wsl.defaultUser = "james";
  system.stateVersion = "25.05";
}
