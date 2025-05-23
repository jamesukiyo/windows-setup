# Windows 11 developer setup script
This is a script I created and use on Windows machines to quickly configure the
environment. It hasn't really been tested but it's worked 3 times for me so far.

## Notes
I mainly work with Go and Rust so it's tailored to that.

Dry run mode doesn't work well, I added it for testing but it's not very
consistent so I recommend not using it.

You will need to make quite a few changes to make it work for you (personal
packages, repos etc.) so feel free to fork this repo and use it as you wish or
open a PR if something can generally be improved. However, please do not change
the packages, buckets etc. if contributing - this is a personal script.

Uses scoop, winget, go, npm, chezmoi and git and relies on bash shell.

## Features:
- retries failed commands (see `RETRIES`)
- attempts to run installs in parallel although, I'm not sure it actually works
  (see `JOBS`)
- add scoop buckets and install packages
- install winget packages
- chezmoi initialisation with gh cli auth
- clone github repos or pull if they already exist to `~/documents/projects`
- clone github plugin repos to `~/documents/projects/plugins`
- install go tools
- install npm tools
- install proto (toolchain management I use for projects)
- setup rustup + Visual Studio BuildTools which are needed for rust on Windows
- add shortcuts to start-up folder
- makes a few useful registry edits (old context menu, )
- verbose, coloured logging
- many checks to avoid running commands unnecessarily
- script timing
- and more...

## Usage
I recommend adjusting/removing/adding what you need. Most of the functions will
be useful to anyone but a lot of it is specific to my needs so I won't provide a
comprehensive guide.

The headings in the script are a useful way to get started and understand what
each section of the script does.

You'll mostly be making use of the functions like: `run_command`,
`install_package`, `parallel_install`, `log`, `safe_cd`, `check_command` etc. to
perform most tasks.

Make sure the paths are updated to match your system/account.

Run in a user bash shell:
```
./setup.sh
```

## License MIT
