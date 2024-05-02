# Connectivity info for Linux Remote Machine
NIXADDR ?= unset
NIXPORT ?= 22
NIXUSER ?= lamt
# The hostname of the nixosConfiguration in the flake
NIXHOST ?= avon
NIXCFG ?= lamt-nixconfig

GH_REPO ?= github:lamtt77/$(NIXCFG)
TEA_REPO ?= git+ssh://git@tea.lamhub.com/lamtt77/$(NIXCFG)
LOCAL_REPO ?= path:///root/$(NIXCFG)
ifeq ($(NIXREPO), tea)
	NIXREPO = $(TEA_REPO)
else ifeq ($(NIXREPO), local)
	NIXREPO = $(LOCAL_REPO)
else
	NIXREPO = $(GH_REPO)
endif

# Get the path to this Makefile and Flake directory
FLAKE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

SSH_OPTIONS=-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no

# We need to do some OS switching below.
UNAME := $(shell uname)

switch:
ifeq ($(UNAME), Darwin)
	nix build --extra-experimental-features "nix-command flakes" ".#darwinConfigurations.${NIXHOST}.system"
	./result/sw/bin/darwin-rebuild switch --flake "$$(pwd)#${NIXHOST}"
else
	sudo nixos-rebuild switch --flake ".#${NIXHOST}"
endif

# should only run with home-manager standalone config
switch/hm:
	home-manager switch --flake ".#${NIXUSER}_${NIXHOST}"

test:
ifeq ($(UNAME), Darwin)
	nix build ".#darwinConfigurations.${NIXHOST}.system"
	./result/sw/bin/darwin-rebuild check --flake "$$(pwd)#${NIXHOST}"
else
	sudo nixos-rebuild test --flake ".#$(NIXHOST)"
endif

# This will ERASE all data of the REMOTE machine's hard disk! Use at your OWN RISK!!!
#
# Format and setup a brand new Remote Host. One-time/liner installation from github :)
# NixOS Minimum ISO required to be on the CD drive.
# Set a temp password for the root user before bootstrap for ssh connectivity,
# the password is only valid during installation session.
#
# Remove 'ssh-keyscan' if you do not want/have secrets deployment, it's OK to keep as-is
# Forwarding ssh-agent '-A' is only required for my secrets private repo deployment,
# this deployment machine should already have the private-key installed.
#
# git+ssh also requires git pre-installed
#
# Low performance system may have out of memory (OOM) issue during Stage1, if so,
# simly do one more time 'remote/switch' with NIXUSER=root
#
# After Stage1 completed, optionally reboot then 'remote/switch' with NIXUSER=<youruser>
remote/bootstrap:
	echo "====>Stage0: Staging..."
	ssh -A $(SSH_OPTIONS) -p$(NIXPORT) root@$(NIXADDR) " \
		test -f ./.ssh/known_hosts || (mkdir -p ./.ssh && \
		  ssh-keyscan -H tea.lamhub.com > ./.ssh/known_hosts); \
        nix-shell -p gitMinimal --run 'nix run \
          --extra-experimental-features \"nix-command flakes\" \
          \"${NIXREPO}#installer-staging\" ${NIXHOST}' && reboot; \
    "
	echo "====>Stage1: Rebooting for Host Swiching/Activating... Ctrl-C to terminate"
	sleep 10
	ssh -A $(SSH_OPTIONS) -p$(NIXPORT) root@$(NIXADDR) " \
		cd ${NIXCFG} && nix flake lock; \
		nixos-rebuild switch --flake .#${NIXHOST}; \
	"
	until !!; do sleep 5; done
	echo "DONE! It's recommended to reboot at first use and rebuild switch to your user"

# NixOS Minimal ISO Boot CD does not have git, which is required for nixos-install
remote/bootstrap/initlocal:
	ssh $(SSH_OPTIONS) -p$(NIXPORT) root@$(NIXADDR) " \
        nix profile --verbose --extra-experimental-features \"nix-command flakes\" \
          install nixpkgs#rsync; \
	"
	NIXUSER=root $(MAKE) remote/copy

# staging still works best for all configurations, especially for low performance system
remote/bootstrap0:
	echo "====>Stage0: Staging..."
	ssh -A $(SSH_OPTIONS) -p$(NIXPORT) root@$(NIXADDR) " \
		test -f ./.ssh/known_hosts || (mkdir -p ./.ssh && \
		  ssh-keyscan -H tea.lamhub.com > ./.ssh/known_hosts); \
        nix-shell -p gitMinimal --run 'nix run \
          --extra-experimental-features \"nix-command flakes\" \
          \"${NIXREPO}#installer-staging\" ${NIXHOST}' && reboot; \
    "

remote/bootstrap1:
	echo "====>Stage1: Host Swiching/Activating..."
	ssh -A $(SSH_OPTIONS) -p$(NIXPORT) root@$(NIXADDR) " \
		cd ${NIXCFG} && nix flake lock; \
		nixos-rebuild switch --flake .#${NIXHOST}; \
	"

# experimenting: only one stage required, reboot is not needed!
# TODO: figure out how to forward ssh agent to 'chroot' for secrets deployment
remote/bootstrap/chroot:
	ssh -A $(SSH_OPTIONS) -p$(NIXPORT) root@$(NIXADDR) " \
        nix-shell -p gitMinimal --run 'nix run \
          --extra-experimental-features \"nix-command flakes\" \
          \"${NIXREPO}#installer-nixos-enter\" ${NIXHOST}' && reboot; \
    "

# not-in-used, need to disable disko & set fileSystems manually for each host if used
# it's actually faster than disko because the later needs to build derivation
# it's however a lot more manual & less flexible than disko
# mkdir -p /mnt/tmp && export TMPDIR=/mnt/tmp; \
# READ: https://stackoverflow.com/questions/76591674/nix-gives-no-space-left-on-device-even-though-nix-has-lots
remote/bootstrap/legacy:
	NIXUSER=root $(MAKE) remote/copy
	ssh -A $(SSH_OPTIONS) -p$(NIXPORT) root@$(NIXADDR) " \
		parted /dev/sda -- mklabel gpt; \
		parted /dev/sda -- mkpart primary 512MB 100\%; \
		parted /dev/sda -- mkpart ESP fat32 1MB 512MB; \
		parted /dev/sda -- set 2 esp on; \
		sleep 1; \
		mkfs.ext4 -L nixos /dev/sda1; \
		mkfs.fat -F 32 -n boot /dev/sda2; \
		sleep 1; \
		mount /dev/disk/by-label/nixos /mnt; \
		mkdir -p /mnt/boot; \
		mount /dev/disk/by-label/boot /mnt/boot; \
		nixos-generate-config --root /mnt; \
		test -f ./.ssh/known_hosts || (mkdir -p ./.ssh && \
          ssh-keyscan -H tea.lamhub.com > ./.ssh/known_hosts); \
        mkdir -p /mnt/tmp && export TMPDIR=/mnt/tmp; \
        nixos-install --no-root-passwd --flake path:/root/${NIXCFG}#${NIXHOST} && reboot; \
	"

# copy the Nix configurations into the Remote Machine. For local setup without github
remote/copy:
	rsync -av -e 'ssh $(SSH_OPTIONS) -p$(NIXPORT)' \
		--exclude='.git/' \
		--exclude='result' \
        --delete \
		$(FLAKE_DIR)/ $(NIXUSER)@$(NIXADDR):./$(NIXCFG)

# This does NOT copy files so you have to run remote/copy before.
remote/switch:
	ssh $(SSH_OPTIONS) -p$(NIXPORT) $(NIXUSER)@$(NIXADDR) " \
	sudo nixos-rebuild switch --flake \"./$(NIXCFG)#${NIXHOST}\" \
	"

# This only requires for 1st time secrets deployment or when secrets changed
remote/switch/secrets:
	ssh -A $(SSH_OPTIONS) -p$(NIXPORT) $(NIXUSER)@$(NIXADDR) " \
		test -f ./.ssh/known_hosts || (mkdir -p ./.ssh && \
		  ssh-keyscan -H tea.lamhub.com > ./.ssh/known_hosts); \
		cd ${NIXCFG} && nix flake lock; \
		sudo nixos-rebuild switch --flake \".#${NIXHOST}\" \
	"

# copy our GPG keyring and SSH keys secrets into the Remote Machine
remote/secrets:
	rsync -av -e 'ssh $(SSH_OPTIONS)' \
		--exclude='.#*' \
		--exclude='S.*' \
		--exclude='*.conf' \
		$(GNUPGHOME)/ $(NIXUSER)@$(NIXADDR):~/.config/gnupg
	rsync -av -e 'ssh $(SSH_OPTIONS)' \
		--exclude='environment' \
		$(HOME)/.ssh/ $(NIXUSER)@$(NIXADDR):~/.ssh

# Build a WSL installer
.PHONY: wsl
wsl:
	 sudo nix run ".#nixosConfigurations.wsl.config.system.build.tarballBuilder"
