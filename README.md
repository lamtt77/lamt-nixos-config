# LamT NixOS System Configurations
This repository is my NixOS system configuration. I have slowly but fully migrated my existing dotfiles configuration to Nix.
Moving forward my dotfiles repo will only be using for Arch Linux (its wiki is just unbeatable) and FreeBSD/non-Linux.
All Linux, WSL and MacOS stuffs will be managed by Nix, no-going-back :).

## TODO
+ Migrate to my own vim/nvim configuration stored in dotfiles, not-in-hurry as the existing nvim config is working fine
+ bootstrap: migrate Makefile/scripts to 'disko' and 'btrfs' with [optional] luks encrypted
+ homelab and backup: migrate my custom scripts to nix
+ services: add tailscale/headscale, caddy...
+ github: build/workflows
+ security hardened
+ cloud: migrate my Digital Ocean hosting to nix
+ nixos-generators: iso/proxmox/esxi/docker images
+ impermanence support
+ [optional] secure boot: lanzaboote

## Features
+ One (or two) command(s) Full System Deployment
+ Unified Config for MacOS (apple silicon & intel), Linux and Windows WSL2
+ Modules/Services can easily enable/disable on demand
+ home-manager can act as a stanalone system or as a nixos module
+ Remote & Cross Platforms Deployment (TODO)
+ Secrets Management

## Quickstart:
+ Boot with 'EFI' Bios, use NixOS Minimal ISO Boot CD from https://nixos.org/download/
+ Must ensure hardware-configuration fileSystems correct, best is to use /by-label/

### Non-secrets Host Deployment
Format and build a brand new Host. One-time/liner headless installation!

*WARNING*: This will ERASE all data of the machine's hard disk! Use at your OWN RISK!!!

+ Method 1: Directly from github: TODO will be ready after migrated to 'disko'
```
$ sudo su
$ nix-shell -p git --command "nixos-install --no-root-passwd --flake github:lamtt77/lamt-nixconfig#gaming"
$ reboot
```
Optional:
```
$ passwd <set-temp-root-psw>, then connect & setup the above in a remote ssh terminal (for copy & paste)
Remove --no-root-passwd option to set a password for root when setup completed. This can be use if you have an issue with connecting to the host using pubkey.
```
+ Method 2: Locally:
From the target host:
```
$ sudo su
$ passwd <set-temp-root-psw>
$ ip addr -> note the IP address of this host, example: 192.168.1.100
```
From the main deployment machine:
```
$ git clone https://github.com/lamtt77/lamt-nixconfig && cd lamt-nixconfig
$ NIXADDR=192.168.1.100 NIXHOST=gaming NIXUSER=vivi make remote/bootstrap
```

### Secrets Host Deployment: TODO improve to a more automatic way
#### Follow non-secrets host deployment above, and have some extra-steps:
+ From the main deployment machine: go to 'lamt-secrets' repo:
```
$ ssh-keyscan -H 192.168.1.101 -> note the ssh-ed25519 pubkey
Change 'lamt-secrets/agenix/secrets.nix' to add that ssh-ed25519 pubkey, then rekey:
$ agenix -r
Commit & push 'lamt-secrets'
```
+ Go back to 'lamt-nixconfig' repo:
```
$ NIXADDR=192.168.1.101 NIXHOST=avon NIXUSER=nixos make remote/copy
$ NIXADDR=192.168.1.101 NIXHOST=avon NIXUSER=nixos make remote/switch/secrets
Note: from 2nd switch onwards, if secrets not changed, use:
$ NIXADDR=192.168.1.101 NIXHOST=avon NIXUSER=nixos make remote/switch
```

### MacOS / Darwin
* Installer: https://determinate.systems/posts/determinate-nix-installer/
```
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```
After completed, verify with 'nix --version', we are now ready to switch to our config:
+ Standalone home-manager: I used this option on darwin
```
$ NIXHOST=macair15-m2 make switch
$ NIXHOST=macair15-m2 make switch/hm
```
+ Combined home-manager as a nixos module: I used this option for the rest (linux & wsl)
```
$ NIXHOST=macair15-m2-combined make switch
```
+ Note: alternatively, you can use official installer https://nixos.org/download/, I use the installer from determinate systems because it supports unninstall easily.
```
$ sh <(curl -L https://nixos.org/nix/install)
```

### WSL
#### Method 1: https://github.com/nix-community/NixOS-WSL
* Download the pre-built at https://github.com/nix-community/NixOS-WSL/releases/latest
```
$ wsl --import NixOS $env:USERPROFILE\NixOS\ nixos-wsl.tar.gz
$ wsl -d NixOS
$ git clone https://github.com/lamtt77/lamt-nixconfig && cd lamt-nixconfig
$ sudo nixos-rebuild switch --flake ".#wsl"
```
#### Method 2: build your own reuseable tarball: recommended
```
$ wsl --import NixOS $env:USERPROFILE\NixOS\ nixos-wsl.tar.gz
$ wsl -d NixOS
$ git clone https://github.com/lamtt77/lamt-nixconfig && cd lamt-nixconfig
$ nix build .#nixosConfigurations.wsl.config.system.build.tarballBuilder
```
Copy/rename the generated tarball to C:\Downloads\nixos-wsl-custom.tar.gz, and then
```
$ wsl --import NixOS $env:USERPROFILE\NixOS\ nixos-wsl-custom.tar.gz
$ wsl -d NixOS
```
* The first time wsl may start as root, switch to your username to initialize:
```
$ su lamt
```
* Note: method 2 can be built by 'nix build' from other wsl distro such as Ubuntu...

## Credits
+ [Virtual Machine as MacOS terminal workflow] https://github.com/mitchellh/nixos-config
+ [handsome libs, doomemacs and modules/services structure] https://github.com/hlissner/dotfiles
+ Lots of others' nix configuration around the internet
