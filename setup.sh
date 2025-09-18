#!/bin/bash
# ────────────────────────────────────────────────
# Description: Windows 11 + NixOS-WSL setup script
# Author: https://github.com/jamesukiyo
# Source: https://github.com/jamesukiyo/windows-setup
# License: GNU General Public License v3.0
# Last modified: 2025-09-18
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
dotfiles_repo="dotfiles"

# ────────────────────────────────────────────────
# LOGGING
# ────────────────────────────────────────────────
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${RESET} $*" }
success() { echo -e "${GREEN}✓${RESET} $*" }
warn() { echo -e "${YELLOW}⚠${RESET} $*" }
error() { echo -e "${RED}✗${RESET} $*" >&2 }

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
		"f.lux\\current\\flux.exe"
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
scoop_packages=(alacritty bat bruno bun chezmoi fd fzf gh git helix hyperfine IosevkaTerm-NF-Mono komorebi mingw nircmd ripgrep starship tableplus vial whkd winget winrar)
winget_packages=(Adobe.Acrobat.Reader.64-bit Blizzard.BattleNet Docker.DockerDesktop pCloudAG.pCloudDrive PrivateInternetAccess.PrivateInternetAccess Valve.Steam)

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

enable_on_startup

run_command "wsl --install --no-distribution" "Installing WSL"
run_command "wsl --update" "Updating WSL"
run_command "wsl --install --no-launch --from-file 'C:/Users/$windows_username/nixos-wsl-backup/nixos.wsl' --name $wsl_name" "Installing NixOS-WSL"
run_command "wsl --set-default $wsl_name" "Setting default WSL distro to $wsl_name"
success "NixOS-WSL base installation finished"
run_command "wsl -d $wsl_name sudo tailscale up" "Configuring Tailscale"
run_command "wsl -d $wsl_name gh auth login" "Configuring GitHub authentication"
success "NixOS-WSL services authenticated"
run_command "wsl -d $wsl_name mkdir ~/projects" "Creating empty projects directory"
run_command "wsl -d $wsl_name touch ~/.ssh/id ~/.ssh/id.pub" "Creating empty user ssh files"
run_command "wsl -d $wsl_name chmod 0600 ~/.ssh/id ~/.ssh/id.pub" "chmod user ssh files"
run_command "wsl -d $wsl_name --user root touch /root/.ssh/id /root/.ssh/id.pub" "Creating empty root ssh files"
run_command "wsl -d $wsl_name --user root chmod 0600 /root/.ssh/id /root/.ssh/id.pub" "chmod root ssh files"
success "NixOS-WSL files/directories created"

log "============================================================"
log "Manual steps needed to complete setup:"
log "- set keys for user in ~/.ssh/id and ~/.ssh/id.pub"
log "- set keys for root in /root/.ssh/id and /root/.ssh/id.pub"
log "============================================================"

end_time=$(date +%s)
elapsed=$(( end_time - start_time ))

log "Setup complete in $elapsed seconds!"
log "============================================================"

exec nu
