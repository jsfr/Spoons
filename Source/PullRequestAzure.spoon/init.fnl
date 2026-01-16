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
(set obj.version :1.6)
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
(local state {:creator-prs [] :reviewer-prs [] :ci-status {} :last-update nil})

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
  "Get text style based on CI status"
  (let [pr-id (?. pull-request :id)
        ci-status (. state.ci-status pr-id)]
    (case ci-status
      :passed {:color {:red 0 :green 0.6 :blue 0 :alpha 1.0}}
      :failed {:color {:red 0.8 :green 0 :blue 0 :alpha 1.0}}
      _ {})))

(fn has-merge-conflicts [pull-request]
  "Check if the PR has merge conflicts"
  (= (?. pull-request :mergeStatus) :conflicts))

(fn get-title [pull-request]
  "Get the title of a menu line describing the specific PR"
  (let [title (?. pull-request :title)
        draft-style {:color {:red 0.5 :green 0.5 :blue 0.5 :alpha 1.0}}
        conflict-style {:color {:red 0.9 :green 0.7 :blue 0 :alpha 1.0}}
        ci-style (get-ci-status-style pull-request)
        text (if (?. pull-request :isDraft) (.. "[Draft] " title) title)
        style (if (?. pull-request :isDraft) draft-style
                  (has-merge-conflicts pull-request) conflict-style
                  ci-style)]
    (hs.styledtext.new text style)))

(fn get-menu-line [pull-request]
  "Get the full menu line for a specific PR to be inserted into the menu"
  {:title (get-title pull-request)
   :fn (fn [] (hs.urlevent.openURL (get-pull-request-url pull-request)))
   :state (get-ready-icon pull-request)})

(fn get-last-update-text []
  "Get formatted last update time"
  (if state.last-update
    (.. "Last update: " (os.date "%Y-%m-%d %H:%M:%S" state.last-update))
    "Last update: never"))

(fn get-menu-table [creator-prs reviewer-prs]
  "Build the menu table with creator PRs, separator, reviewer PRs, and footer"
  (let [menu-table {}
        separator {:title :-}
        empty-style {:color {:red 0.5 :green 0.5 :blue 0.5 :alpha 1.0}}
        empty-block {:title (hs.styledtext.new :n/a empty-style)}
        reload-line {:title "⟳ Reload Hammerspoon"
                     :fn (fn [] (hs.reload))}
        last-update-line {:title (hs.styledtext.new (get-last-update-text) empty-style)
                          :disabled true}]
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
    ; Add footer
    (table.insert menu-table separator)
    (table.insert menu-table reload-line)
    (table.insert menu-table last-update-line)
    menu-table))

(fn parse-pr-response [json-output]
  "Parse the JSON output from az repos pr list"
  (let [prs (or (hs.json.decode json-output) [])]
    prs))

(fn parse-ci-status [policies]
  "Determine CI status from policy evaluations.
   Returns :passed if all build policies approved, :failed if any rejected, nil otherwise."
  (let [build-policies (icollect [_ p (ipairs policies)]
                         (when (= (?. p :configuration :type :displayName) "Build") p))]
    (if (= (length build-policies) 0)
      nil
      (do
        (var has-rejected false)
        (var all-approved true)
        (each [_ p (ipairs build-policies)]
          (let [status (?. p :status)]
            (when (= status "rejected")
              (set has-rejected true))
            (when (not= status "approved")
              (set all-approved false))))
        (if has-rejected :failed
            all-approved :passed
            nil)))))

; Forward declaration for update-menu
(var update-menu nil)

(fn make-policy-callback [pr-id]
  "Create a callback function for policy status fetch"
  (fn [exit-code std-out _std-err]
    (when (= exit-code 0)
      (let [policies (or (hs.json.decode std-out) [])
            ci-status (parse-ci-status policies)]
        (tset state.ci-status pr-id ci-status)
        (update-menu)))))

(fn fetch-policy-status [pr-id]
  "Fetch policy evaluations for a specific PR"
  (let [args [:repos :pr :policy :list
              :--id (tostring pr-id)
              :--organization obj.organizationUrl]
        callback (make-policy-callback pr-id)
        task (hs.task.new obj.azPath callback args)]
    (task:start)))

(fn fetch-policy-status-for-prs [prs]
  "Fetch policy status for a list of PRs"
  (each [_ pr (ipairs prs)]
    (let [pr-id (?. pr :id)]
      (when pr-id
        (fetch-policy-status pr-id)))))

(set update-menu (fn []
  "Update the menubar with current PR data"
  (let [creator-prs state.creator-prs
        reviewer-prs state.reviewer-prs
        total-count (+ (length creator-prs) (length reviewer-prs))
        menu-title (get-menu-title total-count)
        menu-table (get-menu-table creator-prs reviewer-prs)]
    (obj.menuItem:setTitle menu-title)
    (obj.menuItem:setMenu menu-table))))

(fn creator-callback [exit-code std-out std-err]
  "Handle the response from fetching creator PRs"
  (if (= exit-code 0)
    (let [prs (parse-pr-response std-out)]
      (set state.creator-prs prs)
      (update-menu)
      (fetch-policy-status-for-prs prs))
    (show-error (.. "Failed to fetch creator PRs: " std-err))))

(fn reviewer-callback [exit-code std-out std-err]
  "Handle the response from fetching reviewer PRs"
  (if (= exit-code 0)
    (let [prs (parse-pr-response std-out)]
      (set state.reviewer-prs prs)
      (update-menu)
      (fetch-policy-status-for-prs prs))
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
  (set state.last-update (os.time))
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
  ; Clear state
  (set state.creator-prs [])
  (set state.reviewer-prs [])
  (set state.ci-status {})
  (set state.last-update nil)
  self)

obj
