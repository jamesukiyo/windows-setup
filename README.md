# plumjam's Windows 11 Setup Script

This is a script I created and use on Windows machines to quickly configure the environment with NixOS-WSL and all the packages I need in Windows.

## Overview

- Installs packages in parallel from Scoop and Winget
- Automatic `gh auth login` (for private dotfile repos)
- Automatically fetch and apply dotfiles with `chezmoi`
- Downloads and installs NixOS-WSL
- Configures NixOS-WSL with `./configuration.nix`
- Applies and updates the WSL username based on `./configuration.nix`
- Applies a NixOS-WSL configuration from a GitHub repository
- Creates shortcuts/startup entries in Windows
- Minor registry tweaks
- Automatic cleanup in both Windows and WSL
- Logging for every step of the process

## Usage

If you want to use this script, you'll need to update the packages and variables for usernames etc.

- Fork this repo
- Update `configuration.nix`
- Update the lists of packages
- Change the script's variables to suit your setup
- Run as a normal user in a bash shell

Via curl directly after forking and updating:
```bash
curl -sSL https://raw.githubusercontent.com/{username}/windows-setup/master/setup.sh | bash
```
Copy/paste the script or clone the repo and run:
```bash
./setup.sh
```

## License
```
Copyright (C) 2025-present  James Plummer <git@plumj.am>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
```
