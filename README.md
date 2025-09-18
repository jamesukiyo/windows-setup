# PlumJam's Windows 11 Setup Script

This is a script I created and use on Windows machines to quickly configure the
environment with NixOS-WSL and all the packages I need in Windows.

This script has changed quite a few times so it isn't very clean but it gets the
job done.

## Overview

- Installs packages in parallel from Scoop and Winget
- Automatic `gh auth login` (for private dotfile repos)
- Automatically fetch and apply dotfiles with `chezmoi`
- Uses a backed-up pre-built NixOS-WSL to prepare WSL
- Creates shortcuts/startup entries in Windows
- Minor registry tweaks
- Automatic cleanup in both Windows and WSL

## Usage

I doubt this script will be of use to anyone unless you somehow have the exact
same setup with automatic backups, chezmoi, etc. You can see my NixOS
configurations here if you are interested:
[https://github.com/jamesukiyo/nixos](https://github.com/jamesukiyo/nixos)

To run via curl:

```bash
curl -sSL https://raw.githubusercontent.com/{username}/windows-setup/master/setup.sh | bash
```

Copy/paste the script or clone the repo and run:

```bash
./setup.sh
```

## License

```
Copyright (C) 2025-present PlumJam <git@plumj.am>

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
