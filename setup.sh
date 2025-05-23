#!/bin/bash
# ────────────────────────────────────────────────
# WINDOWS 11 SETUP SCRIPT BY github.com/jamesukiyo
# ────────────────────────────────────────────────

set -euo pipefail

# ────────────────────────────────────────────────
# CONFIG
# ────────────────────────────────────────────────
DRY_RUN=${DRY_RUN:-false}
JOBS=8
RETRIES=3

start_time=$(date +%s)

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

	if [ "$DRY_RUN" = true ]; then
		echo "(dry-run) $cmd"
		return
	fi

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

	if [ "$DRY_RUN" = true ]; then
		echo "(dry-run) $manager install $flags $package"
		return
	fi

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

clone_repo() {
	local repo_url="$1"
	local repo_name
	repo_name=$(basename "$repo_url" .git)

	if [ -d "$repo_name/.git" ]; then
		log "✓ Repo $repo_name exists, pulling updates"
		(cd "$repo_name" && git pull --rebase)
	else
		run_command "git clone $repo_url" "Cloning $repo_name"
	fi
}

safe_cd() {
	local target="$1"
	cd "$target" 2>/dev/null || { error "Failed to change directory to $target"; exit 1; }
}

enable_on_startup() {
	log "→ Enabling apps on startup"
	run_command "mkdir -p \"$HOME/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup\"" "Ensure startup folder exists"

	local STARTUP_DIR="C:\\Users\\<USERNAME>\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs\\Startup"
	local SHORTCUTS=(
		"wezterm-nightly\\current\\wezterm-gui.exe"
		"qutebrowser\\current\\qutebrowser.exe"
		"f.lux\\current\\flux.exe"
		"flow-launcher\\current\\Flow.Launcher.exe"
		"obs-studio\\current\\bin\\64bit\\obs64.exe"
	)

	for shortcut in "${SHORTCUTS[@]}"; do
		app_name=$(basename "$shortcut")
		run_command "~/scoop/apps/nircmd/current/nircmd.exe shortcut \"C:\\Users\\<USERNAME>\\scoop\\apps\\$shortcut\" \"$STARTUP_DIR\" \"$app_name\"" "Create startup shortcut for $app_name"
	done

	run_command "komorebic enable-autostart --whkd" "Enable komorebi on startup"
	run_command "yasbc enable-autostart" "Enable yasb on startup"
}

rustup_config() {
	log "→ Configuring rustup..."
	run_command "~/scoop/apps/rustup-msvc/current/rustup-init.exe -y --default-toolchain=nightly --profile=default --component=rust-analyzer" "Initialise rustup"
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
	irm https://moonrepo.dev/install/proto.ps1 | iex;
}"' "Running PowerShell setup for Scoop and Proto"

run_command "~/.proto/bin/proto.exe setup" "Setting up Proto"

# ────────────────────────────────────────────────
# INSTALL PACKAGES
# ────────────────────────────────────────────────
scoop_buckets=(extras games java nerd-fonts versions)
scoop_packages=(act bat bruno bun chezmoi docker dprint exercism fd flow-launcher fzf gh git github go@1.24.3 hyperfine IosevkaTerm-NF-Mono komorebi make migrate mingw neovim nircmd nodejs@22.14.0 ProggyClean-NF-Mono qutebrowser ripgrep ruff rustup-msvc ShareTechMono-NF-Mono starship stylua tableplus temurin21-jdk vial vim wezterm-nightly whkd winget winrar)
winget_packages=(Adobe.Acrobat.Reader.64-bit Blizzard.BattleNet Docker.DockerDesktop Microsoft.VisualStudio.2022.BuildTools pCloudAG.pCloudDrive PrivateInternetAccess.PrivateInternetAccess TheBrowserCompany.Arc Valve.Steam)
go_tools=(github.com/air-verse/air@latest github.com/swaggo/swag/cmd/swag@latest golang.org/x/tools/gopls@latest mvdan.cc/gofumpt@latest)
npm_tools=(sql-formatter)

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

log "→ Installing Go tools..."
for tool in "${go_tools[@]}"; do
	run_command "go install $tool" "Installing Go tool: $tool"
done

log "→ Installing npm tools..."
for tool in "${npm_tools[@]}"; do
	install_package "bun" "-g" "$tool"
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

run_command "chezmoi init --apply https://github.com/username/dotfiles.git" "Applying dotfiles"

mkdir -p ~/documents/projects
safe_cd ~/documents/projects
main_repos=(https://github.com/username/repo, https://github.com/username/repo2)
for repo in "${main_repos[@]}"; do
	clone_repo "$repo"
done

mkdir -p plugins && safe_cd plugins
plugin_repos=(https://github.com/jamesukiyo/jimbo.vim https://github.com/jamesukiyo/quicksnip.vim https://github.com/jamesukiyo/search-this.nvim)
for repo in "${plugin_repos[@]}"; do
	clone_repo "$repo"
done

safe_cd ~

run_command "[ ! -d '~/appdata/roaming/qutebrowser/config/catpuccin' ] && git clone https://github.com/catppuccin/qutebrowser.git ~/appdata/roaming/qutebrowser/config/catppuccin || echo ''" "Clone catppuccin theme for Qutebrowser"

rustup_config

enable_on_startup

log "============================================================"
log "Manual intervention needed:"
log "Install the latest MSVC and Windows SDK via VS BuildTools"
log "Visual Studio installer will open automatically in 3 seconds"
log "Once you are done, exit VS BuildTools to finish this setup"
log "============================================================"

sleep 3
"C:/Program Files (x86)/Microsoft Visual Studio/Installer/setup.exe"

end_time=$(date +%s)
elapsed=$(( end_time - start_time ))

log "Setup complete in $elapsed seconds!"
log "============================================================"

exec bash
