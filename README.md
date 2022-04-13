# jsfr's Spoons 🥄

Personal Hammerspoon Spoons Repository

To use this you are expected to be running [Hammerspoon](https://www.hammerspoon.org/) and it is recommended to set up [SpoonInstall](http://www.hammerspoon.org/Spoons/SpoonInstall.html) for easy use of Spoons. See e.g. [this guide](https://zzamboni.org/post/using-spoons-in-hammerspoon/) for easy setup.

## PullRequests

<img src="/images/PullRequests.png" width=400 />

A menubar item containg the Github Pull Requests the user is part of. The list is split into three parts:

1. Users own PRs
2. PRs with review requests to be done
3. PRs with review requests done

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
  "PullRequests", {
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

Once you have the token ready you can store it in the the keychain using the following command

```sh
security add-generic-password -a github_api_token -s github_api_token -w [INSERT API TOKEN]
```

## YabaiSpaces

<img src="/images/YabaiSpaces.png" width=150 />

A menubar item showing a list of spaces currently containing windows, as well as highlighting the currently active window.

The item comes with the expectation that you are using yabai as a window manager, and that you have between 1 and 10 spaces.

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

You will need to ensure that the `hs` IPC cli is installed on your system which can be done by using the [`hs.ipc.cliInstall`](https://www.hammerspoon.org/docs/hs.ipc.html#cliInstall)

You will also need to add the following triggers to your `.yabairc`

```sh
## update spaces menubar item when changing space or moving an application
yabai -m signal --add event=application_launched    action="hs -A -c 'spoon.YabaiSpaces.update()'"
yabai -m signal --add event=application_deactivated action="hs -A -c 'spoon.YabaiSpaces.update()'"
yabai -m signal --add event=application_terminated  action="hs -A -c 'spoon.YabaiSpaces.update()'"
yabai -m signal --add event=space_changed           action="hs -A -c 'spoon.YabaiSpaces.update()'"
```

Finally you need to install the font [CD Numbers](https://www.dafont.com/cd-numbers.font) on your system to be able to show the space numbers in the menubar.
