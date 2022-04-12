# Spoons 🥄

Personal Hammerspoon Spoons Repository

To use this you are expected to be running [Hammerspoon](https://www.hammerspoon.org/) and it is recommended to set up [SpoonInstall](http://www.hammerspoon.org/Spoons/SpoonInstall.html) for easy use of Spoons. See e.g. [this guide](https://zzamboni.org/post/using-spoons-in-hammerspoon/) for easy setup.

## PullRequests

A menubar item containg the Github Pull Requests the user is part of. The list is split into three parts:

1. Users own PRs
2. PRs with review requests to be done
3. PRs with review requests done

An entry is marked read when new activity has happened on it, and a checkmark on or dash indicates whether the PR is approved or has requests for change.

Clicking an entry opens the PR in the default browser.

The menu bar item is simply a count of the number of PRs currently tracked.

### How to install

If you are using [SpoonInstall](http://www.hammerspoon.org/Spoons/SpoonInstall.html) you can simply add this repo and use the [`andUse`](http://www.hammerspoon.org/Spoons/SpoonInstall.html#andUse) function. A minimal setup example looks like this

```lua
hs.loadSpoon("SpoonInstall")

spoon.SpoonInstall.repos.jsfr = {
  url = "https://github.com/jsfr/Spoons",
  desc = "Personal Spoon repository of Jens Fredskov",
  branch = "main"
}

spoon.SpoonInstall:andUse(
  "PullRequests", {
    config = {
      username = "[YOUR GH USERNAME]",
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
security add-generic-password -a github_api_token -s github_api_token -w [YOUR GH API TOKEN HERE]
```

## YabaiSpace

WIP
