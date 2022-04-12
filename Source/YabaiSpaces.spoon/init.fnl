;;; === YabaiSpaces ===
;;;
;;; Shows a list of current spaces with windows on them as well as current active space.
;;;
;;; Download: [https://github.com/jsfr/Spoons/raw/main/Spoons/YabaiSpaces.spoon.zip](https://github.com/jsfr/Spoons/raw/main/Spoons/YabaiSpaces.spoon.zip)

; Prepare object
(local obj {})
(set obj.__index obj)

; Metadata
(set obj.name "YabaiSpaces")
(set obj.version "1.0")
(set obj.author "Jens Fredskov <jensfredskov@gmail.com>")
(set obj.license "MIT - https://opensource.org/licenses/MIT")

; Configuration
(set obj.menuItem nil)
(set obj.yabaiPath "/opt/homebrew/bin/yabai")
(set obj.jqPath "/opt/homebrew/bin/jq")
(set obj.task nil)
(set obj.logger nil)

(fn space-text [space active-space]
  "Returns the styled number block of a given space"
  (let [space-font {:name "CD Numbers" :size 12}
        inactive-color {:red 0.34 :green 0.37 :blue 0.39 :alpha 1.0}
        active-style {:font space-font :baselineOffset -5.0}
        inactive-style {:font space-font :baselineOffset -5.0 :color inactive-color}
        space-icons {1 :e 2 :f 3 :g 4 :i 5 :j 6 :k 7 :l 8 :m 9 :n 10 :o :f :a}
        space-icon-unknown :h]
    (hs.styledtext.new
      (or (?. space-icons space) space-icon-unknown)
      (if (= space active-space) active-style inactive-style)))
  )

(fn callback [exit-code std-out _]
  "Updates the menubar item given a set of spaces and an active space"
  (if (= exit-code 0)
    (let [result (hs.json.decode std-out)]
      (when (~= result nil)
        (let [visible-spaces (. result :spaces)
              active-space (. result :focused)]
          (var title (hs.styledtext.new " "))
          (each [_ space (pairs visible-spaces)]
            (set title (.. title (space-text space active-space))))
          (obj.menuItem:setTitle title))))))

(fn terminate-task []
  "Terminates the task if it is currently running"
  (when (and (~= obj.task nil) (obj.task:isRunning))
    (obj.task:terminate)
    (set obj.task nil)))

(fn run-task []
  "Run the task to update the menubar item"
  (let [command (hs.fs.pathToAbsolute "./spaces.sh")]
    (set obj.task (-> (hs.task.new command callback)
                      (: :setEnvironment {:JQ_PATH obj.jqPath
                                          :YABAI_PATH obj.yabaiPath})
                      (: :start)))))

(fn obj.update [self]
  "Asynchronously update the menubar item"
  (terminate-task)
  (run-task))

(fn obj.init [self]
  (set self.logger (hs.logger.new :YabaiSpaces))
  (set self.menuItem (hs.menubar.new))
  (self.menuItem:setTitle "[Updating...]")
  (self:update))

obj
