# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Repository Overview

This is a Hammerspoon Spoons repository containing custom menubar extensions. Spoons are Lua-based plugins for [Hammerspoon](https://www.hammerspoon.org/), a macOS automation tool. The codebase is written in **Fennel** (a Lisp that compiles to Lua) and compiled to Lua for distribution.

## Build System

### Building Spoons

```bash
# Build all Spoons (compile Fennel to Lua, create zips, generate docs)
make

# Clean build artifacts and rebuild
make clean && make
```

The Makefile orchestrates the build process:
1. Compiles `.fnl` files to `.lua` using `fennel --require-as-include --compile`
2. Creates `.spoon.zip` packages in `Spoons/` directory
3. Generates HTML documentation using Python (via `uv`)

**IMPORTANT:** It's only necessary to run `make clean` when you specifically want to rebuild all zip files or have messed something up in the build artifacts. Generally you only need to run `make` as it will rebuild any artifact where the source changed.

### Build Output Directories

- `Source/*.spoon/` - Source code in Fennel
- `.spoons_tmp/*.spoon/` - Temporary compiled Lua (intermediate build artifacts)
- `Spoons/*.spoon.zip` - Final distributable packages
- `docs/` - Generated HTML documentation

### Documentation Generation

Documentation is built using the Hammerspoon documentation tooling with dependencies managed by `uv`:

```bash
# Dependencies are automatically installed via uv
uv run --with-requirements hammerspoon/requirements.txt hammerspoon/scripts/docs/bin/build_docs.py [...]
```

Required Python packages (from `hammerspoon/requirements.txt`):
- jinja2 ~= 3.0.3
- mistune ~= 2.0.0
- pygments ~= 2.11.2

## Codebase Architecture

### Fennel to Lua Compilation

All Spoons are written in Fennel and compiled to Lua. The compilation happens automatically during `make` and uses `--require-as-include` to inline module dependencies.

### Spoon Structure

Each Spoon follows this pattern:

```fennel
; Metadata and configuration
(local obj {})
(set obj.__index obj)
(set obj.name "SpoonName")
(set obj.version "1.0")

; Configuration properties
(set obj.someConfig nil)

; Implementation functions
(fn some-function [] ...)

; Required lifecycle methods
(fn obj.init [self] ...)
(fn obj.start [self] ...)
(fn obj.stop [self] ...)

obj  ; Return the object
```

### Keychain Integration Pattern

Spoons that need API tokens use macOS Keychain for secure storage. See `Source/PullRequests.spoon/keychain.fnl` for the reusable module pattern:

```fennel
(fn password-from-keychain [name]
  (-> name
      (get-command)
      (run-command)
      (extract-password)))
```

This module is inlined during compilation via `--require-as-include`.

### Async Task Execution

Spoons use `hs.task.new()` for running external commands asynchronously:

```fennel
(let [task (hs.task.new executable-path args-array callback-fn)]
  (task:start))
```

**Important**: The args array should NOT include the executable path - that's passed as the first parameter to `hs.task.new()`.

### Menubar Item Pattern

All Spoons create menubar items with this pattern:

```fennel
; In obj.init
(set self.menuItem (hs.menubar.new))

; Update menu
(obj.menuItem:setTitle (hs.styledtext.new "Title"))
(obj.menuItem:setMenu menu-table)
```

Menu items can have states (`:on`, `:off`, `:mixed`) for checkbox display.

## Current Spoons

### PullRequests
GitHub PR tracker using GraphQL API. Requires GitHub Personal Access Token stored in macOS Keychain.

### PullRequestAzure
Azure DevOps PR tracker using Azure CLI (`az`). Fetches PRs where user is creator or reviewer. Requires:
- Azure CLI installed at `/opt/homebrew/bin/az`
- Configured Azure DevOps organization and project

### YabaiSpaces
Menubar display of yabai window manager spaces. Uses:
- Shell scripts (`spaces.sh`, `signals.sh`) to query yabai
- Custom font (`cdnumbers.ttf`) for space indicators
- Yabai signals to trigger updates via Hammerspoon IPC

## Development Workflow

### Adding a New Spoon

1. Create directory: `Source/NewSpoon.spoon/`
2. Write Fennel source: `Source/NewSpoon.spoon/init.fnl`
3. Follow the standard Spoon object pattern (see "Spoon Structure" above)
4. Build: `make clean && make`
5. Test by loading in Hammerspoon

### Modifying Existing Spoons

1. Edit `.fnl` files in `Source/*.spoon/`
2. Rebuild: `make clean && make`
3. Reload Spoon in Hammerspoon: `hs.reload()` or restart Hammerspoon

### Shell Script Resources

Spoons can include shell scripts (e.g., YabaiSpaces). Access them via:

```fennel
(hs.spoons.resourcePath "script.sh")
```

Environment variables can be set on tasks:

```fennel
(fn set-environment [task]
  (let [environment (task:environment)]
    (set environment.CUSTOM_VAR value)
    (task:setEnvironment environment)))
```

## Git Workflow

The repository uses git with the following branch structure:
- `main` - Main branch for releases and distribution

## Installation and Usage

Users install Spoons via SpoonInstall in their Hammerspoon config:

```lua
spoon.SpoonInstall.repos.jsfr = {
  url = "https://github.com/jsfr/Spoons",
  desc = "jsfr's Spoons",
  branch = "main"
}

spoon.SpoonInstall:andUse("SpoonName", {
  config = { ... },
  repo = "jsfr",
  start = true
})
```
