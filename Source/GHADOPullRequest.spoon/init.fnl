;;; === GHADOPullRequest ===
;;;
;;; List of a users Github and Azure DevOps PRs in a menubar item
;;;
;;; Download: [https://github.com/jsfr/Spoons/raw/main/Spoons/GHADOPullRequest.spoon.zip](https://github.com/jsfr/Spoons/raw/main/Spoons/GHADOPullRequest.spoon.zip)

; Prepare object
(local obj {})
(set obj.__index obj)

; Metadata
(set obj.name :GHADOPullRequest)
(set obj.version :1.2)
(set obj.author "Jens Fredskov <jensfredskov@gmail.com>")
(set obj.license "MIT - https://opensource.org/licenses/MIT")

; Configuration - GitHub
(set obj.username nil)
(set obj.skateItem nil)
(set obj.skatePath :/opt/homebrew/bin/skate)

; Configuration - Azure
(set obj.organizationUrl nil)
(set obj.project nil)
(set obj.userEmail nil)
(set obj.azPath :/opt/homebrew/bin/az)
(set obj.ignoredRepos [])

; Configuration - shared
(set obj.menuItem nil)
(set obj.timer nil)
(set obj.logger nil)

(fn fetch-token [skatePath skateItem]
  "Fetch a token from skate synchronously using io.popen"
  (let [command (.. skatePath " get " skateItem)]
    (with-open [handle (io.popen command)]
      (let [output (handle:read "*a")]
        (output:gsub "^%s*(.-)%s*$" "%1")))))

; State
(local state {:github-user-prs []
              :github-review-prs []
              :github-involved-prs []
              :azure-creator-prs []
              :azure-reviewer-prs []
              :token nil
              :last-update nil})

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

(fn get-last-update-text []
  "Get formatted last update time"
  (if state.last-update
    (.. "Last update: " (os.date "%Y-%m-%d %H:%M:%S" state.last-update))
    "Last update: never"))

(fn get-icons [pr]
  "Get status icons for a PR"
  (let [blank "\u{3000} "]
    (if (?. pr :draft?) ""
        (let [ci-icon (case (?. pr :ci-status)
                        :success "✅ "
                        :failure "❌ "
                        :running "⏳ "
                        _ blank)
              review-icon (case (?. pr :review-status)
                            :approved "👍 "
                            :rejected "👎 "
                            _ blank)
              conflict-icon (if (?. pr :has-conflicts?) "⚔️ " blank)]
          (.. ci-icon review-icon conflict-icon)))))

(fn get-style [pr]
  "Get text style for a PR"
  (if (?. pr :draft?) {:color {:red 0.5 :green 0.5 :blue 0.5 :alpha 1.0}}
      {}))

(fn get-title [pull-request]
  "Get the title of a menu line describing the specific PR"
  (let [title (?. pull-request :title)
        icons (get-icons pull-request)
        text (if (?. pull-request :draft?) (.. "[Draft] " title) title)
        style (get-style pull-request)]
    (hs.styledtext.new (.. icons text) style)))

(fn get-menu-line [pull-request]
  "Get the full menu line for a specific PR to be inserted into the menu"
  {:title (get-title pull-request)
   :fn (fn [] (hs.urlevent.openURL (?. pull-request :url)))})

; Forward declaration for update-menu
(var update-menu nil)

(fn get-menu-table [list-of-pull-requests]
  "Build the menu table with PR sections, separator, and footer"
  (let [menu-table {}
        separator {:title :-}
        empty-style {:color {:red 0.5 :green 0.5 :blue 0.5 :alpha 1.0}}
        empty-block {:title (hs.styledtext.new :n/a empty-style)}
        reload-line {:title "🔄 Reload Hammerspoon"
                     :fn (fn [] (hs.reload))}
        last-update-line {:title (hs.styledtext.new (get-last-update-text) empty-style)
                          :disabled true}]
    (each [i pull-requests (ipairs list-of-pull-requests)]
      (when (> i 1)
        (table.insert menu-table separator))
      (if (> (length pull-requests) 0)
        (each [_ pull-request (ipairs pull-requests)]
          (table.insert menu-table (get-menu-line pull-request)))
        (table.insert menu-table empty-block)))
    ; Add footer
    (table.insert menu-table separator)
    (table.insert menu-table reload-line)
    (table.insert menu-table last-update-line)
    menu-table))

;;; ============================================================
;;; GitHub logic
;;; ============================================================

(fn review-requested? [node]
  "Check if a PR has been requested to be reviewed by the user"
  (hs.fnutils.some
    (?. node :reviewRequests :nodes)
    #(= (?. $1 :requestedReviewer :login) obj.username)))

(fn assignee? [node]
  "Check if the user is assigned to the PR"
  (hs.fnutils.some
    (?. node :assignees :nodes)
    #(= (?. $1 :login) obj.username)))

(fn normalize-github-pr [node]
  "Map a GraphQL PR node to the common normalized format"
  (let [review-decision (?. node :reviewDecision)
        ci-state (?. node :commits :nodes 1 :commit :statusCheckRollup :state)
        mergeable (?. node :mergeable)]
    {:title (?. node :title)
     :url (?. node :url)
     :draft? (?. node :isDraft)
     :source :github
     :review-status (case review-decision
                      :APPROVED :approved
                      :CHANGES_REQUESTED :rejected
                      _ :pending)
     :ci-status (case ci-state
                  :SUCCESS :success
                  :FAILURE :failure
                  :ERROR :failure
                  :PENDING :running
                  :EXPECTED :running
                  _ :none)
     :has-conflicts? (= mergeable :CONFLICTING)
     :review-requested? (review-requested? node)
     :author (?. node :author :login)
     :assignee? (assignee? node)}))

(fn split-github-pull-requests [pull-requests]
  "Split GitHub PRs into user, review, and involved categories"
  (let [review? #(?. $1 :review-requested?)
        user? #(or (= (?. $1 :author) obj.username) (and (?. $1 :assignee?) (not (review? $1))))
        user []
        reviews []
        involved []]
    (each [_ pull-request (ipairs pull-requests)]
      (if (user? pull-request)
        (table.insert user pull-request)
        (review? pull-request)
        (table.insert reviews pull-request)
        (table.insert involved pull-request)))
    (values user reviews involved)))

(fn github-callback [_ body _]
  "Handle the response from the GitHub GraphQL API"
  (let [pull-requests (or (-?> body
                            (hs.json.decode)
                            (?. :data :search :nodes)
                            (hs.fnutils.imap normalize-github-pr)) [])]
    (if (= (length pull-requests) 0)
      (do
        (obj.logger.i body)
        (when (-?> body (hs.json.decode) (?. :errors))
          (show-error "GraphQL query returned errors")))
      (let [(user reviews involved) (split-github-pull-requests pull-requests)]
        (set state.github-user-prs user)
        (set state.github-review-prs reviews)
        (set state.github-involved-prs involved)
        (update-menu)))))

(fn github-update []
  "Fetch GitHub PRs via GraphQL API"
  (let [headers {:Content-Type :application/json :Authorization (.. "bearer " state.token)}
        url "https://api.github.com/graphql"
        data (.. "{\"query\": \"query ActivePullRequests($query: String!) { search(query: $query, type: ISSUE, first: 100) { nodes { ... on PullRequest { author { login } url title isDraft mergeable reviewDecision reviewRequests(first: 100) { nodes { requestedReviewer { ... on User { login } } } } assignees(first: 100) { nodes { login } } commits(last: 1) { nodes { commit { statusCheckRollup { state } } } } } } } }\", \"variables\": { \"query\": \"sort:updated-desc type:pr state:open involves:" obj.username "\" } }")]
    (hs.http.asyncPost url data headers github-callback)))

;;; ============================================================
;;; Azure logic
;;; ============================================================

(fn get-pull-request-url [pr]
  "Generate the URL for an Azure DevOps pull request"
  (.. obj.organizationUrl obj.project "/_git/" (?. pr :repository) "/pullrequest/" (?. pr :id)))

(fn azure-get-review-status [pr]
  "Determine review status from Azure reviewer votes"
  (let [votes (or (?. pr :reviewerVotes) [])]
    (var has-approval false)
    (var has-rejection false)
    (each [_ vote (ipairs votes)]
      (when (or (= vote -10) (= vote -5))
        (set has-rejection true))
      (when (or (= vote 10) (= vote 5))
        (set has-approval true)))
    (if has-rejection :rejected
        has-approval :approved
        :pending)))

(fn normalize-azure-pr [pr]
  "Map an Azure CLI PR response to the common normalized format"
  {:title (?. pr :title)
   :url (get-pull-request-url pr)
   :draft? (?. pr :isDraft)
   :source :azure
   :review-status (azure-get-review-status pr)
   :ci-status :none
   :has-conflicts? (= (?. pr :mergeStatus) :conflicts)
   :id (?. pr :id)
   :mergeStatus (?. pr :mergeStatus)})

(fn filter-ignored-repos [prs]
  "Filter out PRs from ignored repositories"
  (if (= (length obj.ignoredRepos) 0)
    prs
    (let [ignored (collect [_ repo (ipairs obj.ignoredRepos)] repo true)]
      (icollect [_ pr (ipairs prs)]
        (when (not (. ignored (?. pr :repository)))
          pr)))))

(fn parse-pr-response [json-output]
  "Parse the JSON output from az repos pr list"
  (let [prs (or (hs.json.decode json-output) [])]
    prs))

(fn parse-ci-status [policies]
  "Determine CI status from policy evaluations.
   Returns :success, :failure, :running, or :none."
  (let [build-policies (icollect [_ p (ipairs policies)]
                         (when (= (?. p :configuration :type :displayName) "Build") p))]
    (if (= (length build-policies) 0)
      :none
      (do
        (var has-rejected false)
        (var all-approved true)
        (each [_ p (ipairs build-policies)]
          (let [status (?. p :status)]
            (when (= status "rejected")
              (set has-rejected true))
            (when (not= status "approved")
              (set all-approved false))))
        (if has-rejected :failure
            all-approved :success
            :running)))))

(fn make-policy-callback [pr-id]
  "Create a callback function for policy status fetch"
  (fn [exit-code std-out _std-err]
    (when (= exit-code 0)
      (let [policies (or (hs.json.decode std-out) [])
            ci-status (parse-ci-status policies)]
        (each [_ pr (ipairs state.azure-creator-prs)]
          (when (= (?. pr :id) pr-id)
            (tset pr :ci-status ci-status)))
        (each [_ pr (ipairs state.azure-reviewer-prs)]
          (when (= (?. pr :id) pr-id)
            (tset pr :ci-status ci-status)))
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

(fn azure-creator-callback [exit-code std-out std-err]
  "Handle the response from fetching creator PRs"
  (if (= exit-code 0)
    (let [raw-prs (filter-ignored-repos (parse-pr-response std-out))
          prs (hs.fnutils.imap raw-prs normalize-azure-pr)]
      (set state.azure-creator-prs prs)
      (update-menu)
      (fetch-policy-status-for-prs prs))
    (show-error (.. "Failed to fetch Azure creator PRs: " std-err))))

(fn azure-reviewer-callback [exit-code std-out std-err]
  "Handle the response from fetching reviewer PRs"
  (if (= exit-code 0)
    (let [raw-prs (filter-ignored-repos (parse-pr-response std-out))
          prs (hs.fnutils.imap raw-prs normalize-azure-pr)]
      (set state.azure-reviewer-prs prs)
      (update-menu)
      (fetch-policy-status-for-prs prs))
    (show-error (.. "Failed to fetch Azure reviewer PRs: " std-err))))

(fn fetch-creator-prs []
  "Fetch PRs created by the user from Azure DevOps"
  (let [query (.. "[].{"
                  "authorEmail: createdBy.uniqueName,"
                  "authorName: createdBy.displayName,"
                  "isDraft: isDraft,"
                  "title: title,"
                  "id: pullRequestId,"
                  "repository: repository.name,"
                  "mergeStatus: mergeStatus,"
                  "reviewerVotes: reviewers[].vote"
                  "}")
        args [:repos :pr :list
              :--organization obj.organizationUrl
              :--project obj.project
              :--query query
              :--creator obj.userEmail]
        task (hs.task.new obj.azPath azure-creator-callback args)]
    (task:start)))

(fn fetch-reviewer-prs []
  "Fetch PRs where the user is a reviewer from Azure DevOps"
  (let [query (.. "[].{"
                  "authorEmail: createdBy.uniqueName,"
                  "authorName: createdBy.displayName,"
                  "isDraft: isDraft,"
                  "title: title,"
                  "id: pullRequestId,"
                  "repository: repository.name,"
                  "mergeStatus: mergeStatus,"
                  "reviewerVotes: reviewers[].vote"
                  "}")
        args [:repos :pr :list
              :--organization obj.organizationUrl
              :--project obj.project
              :--query query
              :--reviewer obj.userEmail]
        task (hs.task.new obj.azPath azure-reviewer-callback args)]
    (task:start)))

(fn azure-update []
  "Fetch both creator and reviewer PRs from Azure DevOps"
  (fetch-creator-prs)
  (fetch-reviewer-prs))

;;; ============================================================
;;; Combined update logic
;;; ============================================================

(set update-menu (fn []
  "Update the menubar with merged PR data from both sources"
  (let [user-prs (let [combined []]
                   (each [_ pr (ipairs state.github-user-prs)]
                     (table.insert combined pr))
                   (each [_ pr (ipairs state.azure-creator-prs)]
                     (table.insert combined pr))
                   combined)
        review-prs (let [combined []]
                     (each [_ pr (ipairs state.github-review-prs)]
                       (table.insert combined pr))
                     (each [_ pr (ipairs state.azure-reviewer-prs)]
                       (table.insert combined pr))
                     combined)
        involved-prs state.github-involved-prs
        total-count (+ (length user-prs) (length review-prs) (length involved-prs))
        menu-title (get-menu-title total-count)
        menu-table (get-menu-table [user-prs review-prs involved-prs])]
    (obj.menuItem:setTitle menu-title)
    (obj.menuItem:setMenu menu-table))))

(fn update []
  "Fetch PRs from both GitHub and Azure DevOps"
  (set state.last-update (os.time))
  (github-update)
  (azure-update))

;;; ============================================================
;;; Lifecycle
;;; ============================================================

(fn obj.init [self]
  (set self.logger (hs.logger.new :GHADOPullRequest))
  (set self.menuItem (hs.menubar.new))
  (let [icon (make-icon)]
    (self.menuItem:setIcon icon true))
  (set self.timer (hs.timer.new 60 update))
  self)

(fn obj.start [self]
  (set state.token (fetch-token self.skatePath self.skateItem))
  (self.menuItem:setTitle "...")
  (self.timer:start)
  (self.timer:setNextTrigger 0)
  self)

(fn obj.stop [self]
  (self.timer:stop)
  (self.menuItem:setTitle "...")
  (self.menuItem:setMenu nil)
  ; Clear state
  (set state.github-user-prs [])
  (set state.github-review-prs [])
  (set state.github-involved-prs [])
  (set state.azure-creator-prs [])
  (set state.azure-reviewer-prs [])
  (set state.token nil)
  (set state.last-update nil)
  self)

obj
