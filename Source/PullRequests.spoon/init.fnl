;;; === PullRequests ===
;;;
;;; List of a users Github PRs in a menubar item
;;;
;;; Download: [https://github.com/jsfr/Spoons/raw/main/Spoons/PullRequests.spoon.zip](https://github.com/jsfr/Spoons/raw/main/Spoons/PullRequests.spoon.zip)

; Prepare object
(local obj {})
(set obj.__index obj)

; Metadata
(set obj.name :PullRequests)
(set obj.version :1.0)
(set obj.author "Jens Fredskov <jensfredskov@gmail.com>")
(set obj.license "MIT - https://opensource.org/licenses/MIT")

; Configuration
(set obj.username nil)
(set obj.keychainItem nil)
(set obj.unreadStyle {:color {:red 1.0 :green 0.0 :blue 0.0 :alpha 1.0}})
(set obj.menuItem nil)
(set obj.timer nil)
(set obj.logger nil)

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
   :unread? (not (?. node :isReadByViewer))
   :draft? (?. node :isDraft)
   :review-requested? (review-requested? node)
   :review-decision (?. node :reviewDecision)
   :author (?. node :author :login)
   :assignee? (assignee? node)})

(fn get-menu-title [total-count unread?]
  "Get the text of the menu item describing number of current PRs"
  (let [style (if unread? obj.unreadStyle {})]
    (hs.styledtext.new (.. "[PRs: " total-count "]") style)))

(fn get-title [pull-request]
  "Get the title of a menu line describing the specific PR"
  (let [title (?. pull-request :title)
        text (if (?. pull-request :draft?) (.. "[Draft] " title) title)
        style (if (?. pull-request :unread?) obj.unreadStyle {})]
    (hs.styledtext.new text style)))

(fn get-menu-line [pull-request]
  "Get the full menu line for a specific PR to be inserted into the menu"
  {:title (get-title pull-request)
   :fn (fn [] (hs.urlevent.openURL (?. pull-request :url)))
   :state (match (?. pull-request :review-decision)
            :CHANGES_REQUESTED :mixed
            :APPROVED :on
            _ :off)})

(fn get-menu-table [list-of-pull-requests]
  (let [menu-table {}
        separator {:title :-}
        empty-style {:color {:red 0.5 :green 0.5 :blue 0.5 :alpha 1.0}}
        empty-block {:title (hs.styledtext.new :n/a empty-style)}]
    (each [i pull-requests (ipairs list-of-pull-requests)]
      (when (> i 1)
        (table.insert menu-table separator))
      (if (> (length pull-requests) 0)
        (each [_ pull-request (ipairs pull-requests)]
          (table.insert menu-table (get-menu-line pull-request)))
        (table.insert menu-table empty-block)))
    menu-table))

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
                            (hs.fnutils.imap get-pull-request)) [])
        total-count (length pull-requests)
        unread? (hs.fnutils.some pull-requests #(?. $1 :unread?))
        menu-title (get-menu-title total-count unread?)
        pull-request-blocks (split-pull-requests pull-requests)
        menu-table (get-menu-table pull-request-blocks)]
    (when (= (length pull-requests) 0)
      (obj.logger.i body))
    (obj.menuItem:setTitle menu-title)
    (obj.menuItem:setMenu menu-table)))

(fn update []
  (let [
        keychain (require :keychain)
        token (keychain.password-from-keychain obj.keychainItem)
        headers {:Content-Type :application/json :Authorization (.. "bearer " token)}
        url "https://api.github.com/graphql"
        data (.. "{\"query\": \"query ActivePullRequests($query: String!) { search(query: $query, type: ISSUE, first: 100) { nodes { ... on PullRequest { author { login } url title isReadByViewer isDraft reviewDecision reviewRequests(first: 100) { nodes { requestedReviewer { ... on User { login } } } } assignees(first: 100) { nodes { login } } } } } }\", \"variables\": { \"query\": \"sort:updated-desc type:pr state:open involves:" obj.username "\" } }")]
    (hs.http.asyncPost url data headers callback)))

(fn obj.init [self]
  (set self.logger (hs.logger.new :PullRequests))
  (set self.menuItem (hs.menubar.new))
  (set self.timer (hs.timer.new 60 update))
  self)

(fn obj.start [self]
  (self.menuItem:setTitle "[PRs: ...]")
  (self.timer:setNextTrigger 0)
  self)

(fn obj.stop [self]
  (self.timer:stop)
  (self.menuItem:setTitle "[PRs: ...]")
  (self.menuItem:setMenu nil)
  self)

obj
