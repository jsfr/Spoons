;;; === PullRequestGithub ===
;;;
;;; List of a users Github PRs in a menubar item
;;;
;;; Download: [https://github.com/jsfr/Spoons/raw/main/Spoons/PullRequestGithub.spoon.zip](https://github.com/jsfr/Spoons/raw/main/Spoons/PullRequestGithub.spoon.zip)

; Prepare object
(local obj {})
(set obj.__index obj)

; Metadata
(set obj.name :PullRequestGithub)
(set obj.version :2.0)
(set obj.author "Jens Fredskov <jensfredskov@gmail.com>")
(set obj.license "MIT - https://opensource.org/licenses/MIT")

; Configuration
(set obj.username nil)
(set obj.skateItem nil)
(set obj.skatePath :/opt/homebrew/bin/skate)
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
(local state {:user-prs [] :review-prs [] :involved-prs [] :token nil :last-update nil})

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

(fn get-status-emoji [pull-request]
  "Get emoji prefix based on review decision and mergeable status"
  (if (= (?. pull-request :mergeable) :CONFLICTING) "⚔️ "
      (case (?. pull-request :review-decision)
        :APPROVED "✅ "
        :CHANGES_REQUESTED "❌ "
        _ "⏳ ")))

(fn get-ci-status-style [pull-request]
  "Get text style based on CI/check status"
  (case (?. pull-request :ci-status)
    :SUCCESS {:color {:red 0 :green 0.6 :blue 0 :alpha 1.0}}
    :FAILURE {:color {:red 0.8 :green 0 :blue 0 :alpha 1.0}}
    :ERROR {:color {:red 0.8 :green 0 :blue 0 :alpha 1.0}}
    _ {}))

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

(fn get-title [pull-request]
  "Get the title of a menu line describing the specific PR"
  (let [title (?. pull-request :title)
        emoji (get-status-emoji pull-request)
        draft-style {:color {:red 0.5 :green 0.5 :blue 0.5 :alpha 1.0}}
        conflict-style {:color {:red 0.9 :green 0.7 :blue 0 :alpha 1.0}}
        ci-style (get-ci-status-style pull-request)
        text (if (?. pull-request :draft?) (.. "[Draft] " title) title)
        style (if (?. pull-request :draft?) draft-style
                  (= (?. pull-request :mergeable) :CONFLICTING) conflict-style
                  ci-style)]
    (hs.styledtext.new (.. emoji text) style)))

(fn get-menu-line [pull-request]
  "Get the full menu line for a specific PR to be inserted into the menu"
  {:title (get-title pull-request)
   :fn (fn [] (hs.urlevent.openURL (?. pull-request :url)))})

(fn get-last-update-text []
  "Get formatted last update time"
  (if state.last-update
    (.. "Last update: " (os.date "%Y-%m-%d %H:%M:%S" state.last-update))
    "Last update: never"))

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

(fn get-pull-request [node]
  "Map a GraphQL PR node to a table with various information"
  {:title (?. node :title)
   :url (?. node :url)
   :draft? (?. node :isDraft)
   :review-requested? (review-requested? node)
   :review-decision (?. node :reviewDecision)
   :mergeable (?. node :mergeable)
   :ci-status (?. node :commits :nodes 1 :commit :statusCheckRollup :state)
   :author (?. node :author :login)
   :assignee? (assignee? node)})

(fn split-pull-requests [pull-requests]
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
    [user reviews involved]))

(fn callback [_ body _]
  (let [pull-requests (or (-?> body
                            (hs.json.decode)
                            (?. :data :search :nodes)
                            (hs.fnutils.imap get-pull-request)) [])]
    (if (= (length pull-requests) 0)
      (do
        (obj.logger.i body)
        (when (-?> body (hs.json.decode) (?. :errors))
          (show-error "GraphQL query returned errors")))
      (let [total-count (length pull-requests)
            menu-title (get-menu-title total-count)
            pull-request-blocks (split-pull-requests pull-requests)
            menu-table (get-menu-table pull-request-blocks)]
        (obj.menuItem:setTitle menu-title)
        (obj.menuItem:setMenu menu-table)))))

(fn update []
  (set state.last-update (os.time))
  (let [headers {:Content-Type :application/json :Authorization (.. "bearer " state.token)}
        url "https://api.github.com/graphql"
        data (.. "{\"query\": \"query ActivePullRequests($query: String!) { search(query: $query, type: ISSUE, first: 100) { nodes { ... on PullRequest { author { login } url title isDraft mergeable reviewDecision reviewRequests(first: 100) { nodes { requestedReviewer { ... on User { login } } } } assignees(first: 100) { nodes { login } } commits(last: 1) { nodes { commit { statusCheckRollup { state } } } } } } } }\", \"variables\": { \"query\": \"sort:updated-desc type:pr state:open involves:" obj.username "\" } }")]
    (hs.http.asyncPost url data headers callback)))

(fn obj.init [self]
  (set self.logger (hs.logger.new :PullRequestGithub))
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
  (set state.user-prs [])
  (set state.review-prs [])
  (set state.involved-prs [])
  (set state.token nil)
  (set state.last-update nil)
  self)

obj
