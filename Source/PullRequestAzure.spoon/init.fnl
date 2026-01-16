;;; === PullRequestAzure ===
;;;
;;; List of Azure DevOps PRs in a menubar item
;;;
;;; Download: [https://github.com/jsfr/Spoons/raw/main/Spoons/PullRequestAzure.spoon.zip](https://github.com/jsfr/Spoons/raw/main/Spoons/PullRequestAzure.spoon.zip)

; Prepare object
(local obj {})
(set obj.__index obj)

; Metadata
(set obj.name :PullRequestAzure)
(set obj.version :1.3)
(set obj.author "Jens Fredskov <jensfredskov@gmail.com>")
(set obj.license "MIT - https://opensource.org/licenses/MIT")

; Configuration
(set obj.organizationUrl nil)
(set obj.project nil)
(set obj.userEmail nil)
(set obj.azPath :/opt/homebrew/bin/az)
(set obj.menuItem nil)
(set obj.timer nil)
(set obj.logger nil)

; State
(local state {:creator-prs [] :reviewer-prs []})

(fn make-icon []
  "Create a branch icon using ASCII art"
  (let [ascii "ASCII:
. . . . . . . . . . . . . . . . .
. . . . 1 . . . . . . . 8 . . . .
. . . . . . . . . . . . . . . . .
. . 1 . . . 1 . . . 8 . . . 8 . .
. . . . . . . . . . . . . . . . .
. . . . 1 . . . . . . . 8 . . . .
. . . . 2 . . . . . . . 7 . . . .
. . . . . . . . . . . . . . . . .
. . . . 4 . . 5 . . . 6 . . . . .
. . . . 2 . . . . . . . . . . . .
. . . . 3 . . . . . . . . . . . .
. . . . . . . . . . . . . . . . .
. . 3 . . . 3 . . . . . . . . . .
. . . . . . . . . . . . . . . . .
. . . . 3 . . . . . . . . . . . .
. . . . . . . . . . . . . . . . ."
        context [{:strokeColor {:red 1 :green 1 :blue 1 :alpha 1}
                  :fillColor {:alpha 0}
                  :shouldClose false
                  :lineWidth 1.2}]]
    (hs.image.imageFromASCII ascii context)))

(fn get-pull-request-url [pr]
  "Generate the URL for a pull request"
  (.. obj.organizationUrl obj.project "/_git/" (?. pr :repository) "/pullrequest/" (?. pr :id)))

(fn get-ready-icon [pr]
  "Get the checkbox state based on merge status"
  (case (?. pr :mergeStatus)
    :succeeded :on
    :rejectedByPolicy :mixed
    _ :off))

(fn get-menu-title [total-count]
  "Get the text of the menu item describing number of current PRs"
  (hs.styledtext.new (tostring total-count)))

(fn get-error-title []
  "Get a red error title for the menu item"
  (let [error-style {:color {:red 1.0 :green 0 :blue 0 :alpha 1.0}}]
    (hs.styledtext.new "error" error-style)))

(fn show-error [error-message]
  "Update the menubar to show an error state"
  (obj.logger.e error-message)
  (obj.menuItem:setTitle (get-error-title))
  (obj.menuItem:setMenu nil))

(fn get-ci-status-style [pull-request]
  "Get text style based on CI/merge status"
  (case (?. pull-request :mergeStatus)
    :succeeded {:color {:red 0 :green 0.6 :blue 0 :alpha 1.0}}
    :rejectedByPolicy {:color {:red 0.8 :green 0 :blue 0 :alpha 1.0}}
    _ {}))

(fn get-title [pull-request]
  "Get the title of a menu line describing the specific PR"
  (let [title (?. pull-request :title)
        draft-style {:color {:red 0.5 :green 0.5 :blue 0.5 :alpha 1.0}}
        ci-style (get-ci-status-style pull-request)
        text (if (?. pull-request :isDraft) (.. "[Draft] " title) title)
        style (if (?. pull-request :isDraft) draft-style ci-style)]
    (hs.styledtext.new text style)))

(fn get-menu-line [pull-request]
  "Get the full menu line for a specific PR to be inserted into the menu"
  {:title (get-title pull-request)
   :fn (fn [] (hs.urlevent.openURL (get-pull-request-url pull-request)))
   :state (get-ready-icon pull-request)})

(fn get-menu-table [creator-prs reviewer-prs]
  "Build the menu table with creator PRs, separator, and reviewer PRs"
  (let [menu-table {}
        separator {:title :-}
        empty-style {:color {:red 0.5 :green 0.5 :blue 0.5 :alpha 1.0}}
        empty-block {:title (hs.styledtext.new :n/a empty-style)}]
    ; Add creator PRs
    (if (> (length creator-prs) 0)
      (each [_ pr (ipairs creator-prs)]
        (table.insert menu-table (get-menu-line pr)))
      (table.insert menu-table empty-block))
    ; Add separator
    (table.insert menu-table separator)
    ; Add reviewer PRs
    (if (> (length reviewer-prs) 0)
      (each [_ pr (ipairs reviewer-prs)]
        (table.insert menu-table (get-menu-line pr)))
      (table.insert menu-table empty-block))
    menu-table))

(fn parse-pr-response [json-output]
  "Parse the JSON output from az repos pr list"
  (let [prs (or (hs.json.decode json-output) [])]
    prs))

(fn update-menu []
  "Update the menubar with current PR data"
  (let [creator-prs state.creator-prs
        reviewer-prs state.reviewer-prs
        total-count (+ (length creator-prs) (length reviewer-prs))
        menu-title (get-menu-title total-count)
        menu-table (get-menu-table creator-prs reviewer-prs)]
    (obj.menuItem:setTitle menu-title)
    (obj.menuItem:setMenu menu-table)))

(fn creator-callback [exit-code std-out std-err]
  "Handle the response from fetching creator PRs"
  (if (= exit-code 0)
    (do
      (set state.creator-prs (parse-pr-response std-out))
      (update-menu))
    (show-error (.. "Failed to fetch creator PRs: " std-err))))

(fn reviewer-callback [exit-code std-out std-err]
  "Handle the response from fetching reviewer PRs"
  (if (= exit-code 0)
    (do
      (set state.reviewer-prs (parse-pr-response std-out))
      (update-menu))
    (show-error (.. "Failed to fetch reviewer PRs: " std-err))))

(fn fetch-creator-prs []
  "Fetch PRs created by the user"
  (let [query (.. "[].{"
                  "authorEmail: createdBy.uniqueName,"
                  "authorName: createdBy.displayName,"
                  "isDraft: isDraft,"
                  "title: title,"
                  "id: pullRequestId,"
                  "repository: repository.name,"
                  "mergeStatus: mergeStatus"
                  "}")
        args [:repos :pr :list
              :--organization obj.organizationUrl
              :--project obj.project
              :--query query
              :--creator obj.userEmail]
        task (hs.task.new obj.azPath creator-callback args)]
    (task:start)))

(fn fetch-reviewer-prs []
  "Fetch PRs where the user is a reviewer"
  (let [query (.. "[].{"
                  "authorEmail: createdBy.uniqueName,"
                  "authorName: createdBy.displayName,"
                  "isDraft: isDraft,"
                  "title: title,"
                  "id: pullRequestId,"
                  "repository: repository.name,"
                  "mergeStatus: mergeStatus"
                  "}")
        args [:repos :pr :list
              :--organization obj.organizationUrl
              :--project obj.project
              :--query query
              :--reviewer obj.userEmail]
        task (hs.task.new obj.azPath reviewer-callback args)]
    (task:start)))

(fn update []
  "Fetch both creator and reviewer PRs"
  (fetch-creator-prs)
  (fetch-reviewer-prs))

(fn obj.init [self]
  (set self.logger (hs.logger.new :PullRequestAzure))
  (set self.menuItem (hs.menubar.new))
  (let [icon (make-icon)]
    (self.menuItem:setIcon icon true))
  (set self.timer (hs.timer.new 60 update))
  self)

(fn obj.start [self]
  (self.menuItem:setTitle "...")
  (self.timer:start)
  (self.timer:setNextTrigger 0)
  self)

(fn obj.stop [self]
  (self.timer:stop)
  (self.menuItem:setTitle "...")
  (self.menuItem:setMenu nil)
  self)

obj
