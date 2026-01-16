# jsfr's Spoons 🥄

Personal Hammerspoon Spoons Repository

To use this you are expected to be running [Hammerspoon](https://www.hammerspoon.org/), and it is recommended to set up [SpoonInstall](http://www.hammerspoon.org/Spoons/SpoonInstall.html) for easy use of Spoons. See e.g. [this guide](https://zzamboni.org/post/using-spoons-in-hammerspoon/) for easy setup.

## PullRequestsGithub

<img src="/images/PullRequests.png" width=400 />

A menubar item contains the GitHub Pull Requests the user is part of. The list is split into three parts:

1. Users own PRs.
2. PRs with review requests to be done.
3. PRs with review requests done.

An entry is marked read when new activity has happened on it, and a checkmark on or dash indicates whether the PR is approved or has requests for change.

Clicking an entry opens the PR in the default browser.

The menubar item is simply a count of the number of PRs currently tracked.

### How to install

If you are using [SpoonInstall](http://www.hammerspoon.org/Spoons/SpoonInstall.html) you can simply add this repo and use the [`andUse`](http://www.hammerspoon.org/Spoons/SpoonInstall.html#andUse) function. A minimal setup example looks like this

```lua
hs.loadSpoon("SpoonInstall")

spoon.SpoonInstall.repos.jsfr = {
  url = "https://github.com/jsfr/Spoons",
  desc = "jsfr's Spoons,
  branch = "main"
}

spoon.SpoonInstall:andUse(
  "PullRequestsGithub", {
    config = {
      username = "[INSERT GITHUB USERNAME]",
      keychainItem = "github_api_token"
    },
    repo = "jsfr",
    start = true
  }
)
```

You will also need a [Personal Access Token](https://github.com/settings/tokens) stored in the Keychain under the name you chose in the setup. This token should have the `repo` scope

Once you have the token ready you can store it in the keychain using the following command

```sh
security add-generic-password -a github_api_token -s github_api_token -w [INSERT API TOKEN]
```

## PullRequestsAzure

<img src="/images/PullRequestsAzure.png" width=400 />

A menubar item showing Azure DevOps Pull Requests where the user is either the creator or a reviewer. The list is split into two parts:

1. PRs created by the user.
2. PRs where the user is a reviewer.

Each entry shows the PR status with emoji indicators (✅ succeeded, ❌ rejected, ⚔️ conflicts, ⏳ pending). CI build status is also displayed via text color.

Clicking an entry opens the PR in the default browser.

### How to install

If you are using [SpoonInstall](http://www.hammerspoon.org/Spoons/SpoonInstall.html) you can simply add this repo and use the [`andUse`](http://www.hammerspoon.org/Spoons/SpoonInstall.html#andUse) function. A minimal setup example looks like this

```lua
hs.loadSpoon("SpoonInstall")

spoon.SpoonInstall.repos.jsfr = {
  url = "https://github.com/jsfr/Spoons",
  desc = "jsfr's Spoons",
  branch = "main"
}

spoon.SpoonInstall:andUse(
  "PullRequestsAzure", {
    config = {
      organizationUrl = "https://dev.azure.com/[YOUR_ORG]/",
      project = "[YOUR_PROJECT]",
      userEmail = "[YOUR_EMAIL]"
    },
    repo = "jsfr",
    start = true
  }
)
```

You will need the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed (defaults to `/opt/homebrew/bin/az`) and authenticated with `az login`.

## YabaiSpaces

<img src="/images/YabaiSpaces.png" width=150 />

A menubar item showing a list of spaces currently containing windows, as well as highlighting the currently active window.

The item comes with the expectation that you are using Yabai as a window manager, and that you have between 1 and 10 spaces.

### How to install

If you are using [SpoonInstall](http://www.hammerspoon.org/Spoons/SpoonInstall.html) you can simply add this repo and use the [`andUse`](http://www.hammerspoon.org/Spoons/SpoonInstall.html#andUse) function. A minimal setup example looks like this

```lua
require("hs.ipc")

hs.loadSpoon("SpoonInstall")

spoon.SpoonInstall.repos.jsfr = {
  url = "https://github.com/jsfr/Spoons",
  desc = "jsfr's Spoons",
  branch = "main"
}

spoon.SpoonInstall:andUse("YabaiSpaces", {repo = "jsfr"})
```

You will need to ensure that the `hs` IPC CLI is installed on your system which can be done by using the [`hs.ipc.cliInstall`](https://www.hammerspoon.org/docs/hs.ipc.html#cliInstall)

To ensure that the signals which the spoon adds to Yabai are always present you may also want to add the following command to your `.yabairc`

```sh
## Add signals for Hammerspoon Yabai Widget
hs -c "spoon.YabaiSpaces:add_signals()"

# go through all spaces to pick up all windows
active_space=$(yabai -m query --spaces --space | jq -r ".index")
last_space=$(yabai -m query --spaces | jq -r "[.[] | .index] | max")
for i in $(seq 1 "$last_space"); do yabai -m space --focus "$i"; sleep 0.1; done
yabai -m space --focus "$active_space"
```
