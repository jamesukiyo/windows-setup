#!/bin/bash
# ────────────────────────────────────────────────
# Description: Windows 11 + NixOS-WSL setup script
# Author: https://github.com/jamesukiyo
# Source: https://github.com/jamesukiyo/windows-setup
# License: GNU General Public License v3.0
# Last modified: 2025-09-13
# ────────────────────────────────────────────────

set -euo pipefail

# ────────────────────────────────────────────────
# CONFIG
# ────────────────────────────────────────────────
JOBS=8
RETRIES=3

start_time=$(date +%s)

windows_username="james"
wsl_name="nixos"
github_username="jamesukiyo"
nixos_config_repo="nixos"
dotfiles_repo="dotfiles"
flake_name="pear"
script_repo="windows-setup"

# ────────────────────────────────────────────────
# LOGGING
# ────────────────────────────────────────────────
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)

log() {
	echo -e "${BLUE}[$(date +'%H:%M:%S')]${RESET} $*"
}

success() {
	echo -e "${GREEN}✓${RESET} $*"
}

warn() {
	echo -e "${YELLOW}⚠${RESET} $*"
}

error() {
	echo -e "${RED}✗${RESET} $*" >&2
}

# ────────────────────────────────────────────────
# CORE FUNCTIONS
# ────────────────────────────────────────────────
run_command() {
	local cmd="$1"
	local description="$2"
	local attempts=0

	log "→ $description..."

	until eval "$cmd"; do
		((attempts++))
		if ((attempts >= RETRIES)); then
			error "Failed after $RETRIES attempts: $description"
			return 1
		fi
		warn "Retrying ($attempts/$RETRIES)..."
		sleep 1
	done
	success "Done: $description"
}

confirm() {
	read -p "⚙️  $1 [y/N]: " -r
	[[ "$REPLY" =~ ^[Yy]$ ]]
}

check_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		error "Missing required tool: $1"
		exit 1
	fi
}

install_package() {
	local manager="$1"
	local flags="$2"
	local package="$3"

	log "→ Installing $package via $manager..."

	if "$manager" list | grep -q "$package"; then
		success "$package already installed"
	else
		if "$manager" install $flags "$package"; then
			success "Installed $package"
		else
			error "Failed to install $package"
		fi
	fi
}

parallel_install() {
	local manager="$1"
	shift
	local -a packages=("$@")
	local -a pids=()
	local -i count=0

	for pkg in "${packages[@]}"; do
		install_package "$manager" "" "$pkg" &
		pids+=($!)
		((++count))

		if ((count % JOBS == 0)); then
			wait -n
		fi
	done
	wait
}

safe_cd() {
	local target="$1"
	cd "$target" 2>/dev/null || { error "Failed to change directory to $target"; exit 1; }
}

enable_on_startup() {
	log "→ Enabling apps on startup"
	run_command "mkdir -p \"$HOME/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup\"" "Ensure startup folder exists"

	local STARTUP_DIR="C:\\Users\\$windows_username\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs\\Startup"
	local SHORTCUTS=(
		"qutebrowser\\current\\qutebrowser.exe"
		"f.lux\\current\\flux.exe"
		"flow-launcher\\current\\Flow.Launcher.exe"
		"obs-studio\\current\\bin\\64bit\\obs64.exe"
	)

	for shortcut in "${SHORTCUTS[@]}"; do
		app_name=$(basename "$shortcut")
		run_command "~/scoop/apps/nircmd/current/nircmd.exe shortcut \"C:\\Users\\$windows_username\\scoop\\apps\\$shortcut\" \"$STARTUP_DIR\" \"$app_name\"" "Create startup shortcut for $app_name"
	done

	run_command "komorebic enable-autostart --whkd" "Enable komorebi on startup"
	run_command "yasbc enable-autostart" "Enable yasb on startup"
}

# ────────────────────────────────────────────────
# VALIDATE ENVIRONMENT
# ────────────────────────────────────────────────
for cmd in git powershell.exe curl; do
	check_command "$cmd"
done

# ────────────────────────────────────────────────
# BOOTSTRAP POWERSHELL
# ────────────────────────────────────────────────
run_command 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {
	try { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force} catch {};
	iwr -useb https://get.scoop.sh | iex;
}"' "Running PowerShell setup for Scoop"

# ────────────────────────────────────────────────
# INSTALL PACKAGES
# ────────────────────────────────────────────────
scoop_buckets=(extras games nerd-fonts versions)
scoop_packages=(act alacritty bat bruno bun chezmoi docker exercism fd fzf gh git helix hyperfine IosevkaTerm-NF-Mono komorebi mingw nircmd ripgrep starship tableplus vial vim whkd winget winrar)
winget_packages=(Adobe.Acrobat.Reader.64-bit Blizzard.BattleNet Docker.DockerDesktop pCloudAG.pCloudDrive PrivateInternetAccess.PrivateInternetAccess TheBrowserCompany.Arc Valve.Steam)

log "→ Adding Scoop Buckets..."
for bucket in "${scoop_buckets[@]}"; do
	run_command "scoop bucket add $bucket" "Adding bucket: $bucket"
done

install_package "scoop" "" "aria2"
run_command "scoop config aria2-warning-enabled false" "Disable aria2 warnings"
install_package "scoop" "" "sudo"

log "→ Installing Scoop packages in parallel..."
parallel_install "scoop" "${scoop_packages[@]}"

log "→ Installing Winget packages..."
for pkg in "${winget_packages[@]}"; do
	install_package "winget" "" "$pkg"
done

# ────────────────────────────────────────────────
# SYSTEM TWEAKS
# ────────────────────────────────────────────────
run_command 'sudo powershell.exe -Command "Set-ItemProperty -Path '\''HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'\'' -Name '\''LongPathsEnabled'\'' -Value 1"' "Enable long paths"
run_command 'reg add "HKEY_CURRENT_USER\SOFTWARE\CLASSES\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -ve -f' "Fix context menu registry"
run_command 'sudo powershell.exe -Command "Stop-Process -Name explorer -Force"' "Stop Windows Explorer (Windows will restart it automatically)"
# ────────────────────────────────────────────────
# FINAL SETUP
# ────────────────────────────────────────────────
run_command "scoop cleanup --all" "Cleaning up Scoop"

log "→ Checking GitHub CLI authentication status..."
if gh auth status 2>&1 | grep -q "Logged in to github.com"; then
	success "Already logged in to GitHub CLI"
else
	run_command "gh auth login" "GitHub CLI authentication"
fi

run_command "chezmoi init --apply https://github.com/$github_username/$dotfiles_repo.git" "Applying dotfiles"

safe_cd ~

run_command "[ ! -d '~/appdata/roaming/qutebrowser/config/catpuccin' ] && git clone https://github.com/catppuccin/qutebrowser.git ~/appdata/roaming/qutebrowser/config/catppuccin || echo ''" "Clone catppuccin theme for Qutebrowser"

enable_on_startup

run_command "wsl --install --no-distribution" "Installing WSL"
run_command "wsl --update" "Updating WSL"
run_command "curl -L https://github.com/nix-community/NixOS-WSL/releases/latest/download/nixos.wsl -o ./nixos.wsl" "Download NixOS-WSL"
run_command "wsl --install --no-launch --from-file ./nixos.wsl --name $wsl_name" "Installing NixOS-WSL"
run_command "wsl --set-default $wsl_name" "Setting default WSL distro to NixOS"
run_command "wsl --unregister ubuntu" "Unregistering Default Ubuntu WSL distro"
success "NixOS-WSL base installation finished"
run_command "wsl -d $wsl_name --user root --cd /etc/nixos curl -L https://raw.githubusercontent.com/$github_username/$script_repo/master/configuration.nix -o /etc/nixos/configuration.nix" "Bootstrapping NixOS configuration"
run_command "wsl -d $wsl_name sudo nixos-rebuild boot" "[1/4] Fixing user name"
run_command "wsl -t $wsl_name" "[2/4] Fixing user name"
run_command "wsl -d $wsl_name --user root exit" "[3/4] Fixing user name"
run_command "wsl -d $wsl_name sudo nixos-rebuild switch" "[4/4] Fixing user name"
success "NixOS-WSL username updated"
run_command "wsl -d $wsl_name sudo nixos-rebuild switch --accept-flake-config --flake github:$github_username/$nixos_config_repo#$flake_name" "Installing NixOS config from github/$github_username/$nixos_config_repo"
success "NixOS-WSL rebuilt with flake from github:$github_username/$nixos_config_repo#$flake_name"
run_command "wsl -d $wsl_name sudo rm -rf /root/.nix-defexpr/channels" "[1/2] cleaning channel directories"
run_command "wsl -d $wsl_name sudo rm -rf /nix/var/nix/profiles/per-user/root/channels" "[2/2] cleaning channel directories"
run_command "rm ./nixos.wsl" "Removing nixos.wsl installer"
success "NixOS-WSL cleanup complete"
run_command "wsl -d $wsl_name sudo tailscale up" "Configuring Tailscale"
run_command "wsl -d $wsl_name gh auth login" "Configuring GitHub authentication"
success "NixOS-WSL services authenticated"
run_command "wsl -d $wsl_name mkdir ~/projects" "Creating empty projects directory"
run_command "wsl -d $wsl_name touch ~/private.key" "Creating empty gpg key file"
run_command "wsl -d $wsl_name touch ~/.ssh/id" "Creating empty ssh id file"
run_command "wsl -d $wsl_name touch ~/.ssh/id.pub" "Creating empty ssh id.pub file"
success "NixOS-WSL files/directories created"

log "============================================================"
log "Manual steps needed to complete setup:"
log "- set ssh keys for normal user in ~/.ssh/id and ~/.ssh/id.pub"
log "- add gpg key to ~/private.key"
log "- gpg --import ~/private.key"
log "============================================================"

end_time=$(date +%s)
elapsed=$(( end_time - start_time ))

log "Setup complete in $elapsed seconds!"
log "============================================================"

exec nu
