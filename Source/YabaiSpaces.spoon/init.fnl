;;; === YabaiSpaces ===
;;;
;;; Shows a list of current spaces with windows on them as well as current active space.
;;;
;;; Download: [https://github.com/jsfr/Spoons/raw/main/Spoons/YabaiSpaces.spoon.zip](https://github.com/jsfr/Spoons/raw/main/Spoons/YabaiSpaces.spoon.zip)

; Prepare object
(local obj {})
(set obj.__index obj)

; Metadata
(set obj.name :YabaiSpaces)
(set obj.version :1.1)
(set obj.author "Jens Fredskov <jensfredskov@gmail.com>")
(set obj.license "MIT - https://opensource.org/licenses/MIT")

; Configuration
(set obj.menuItem nil)
(set obj.yabaiPath :/opt/homebrew/bin/yabai)
(set obj.jqPath :/opt/homebrew/bin/jq)
(set obj.task nil)
(set obj.logger nil)

(fn space-text [space active-space]
  "Returns the styled number block of a given space"
  (let [space-font {:name "CD Numbers" :size 12}
        inactive-color {:red 0.54 :green 0.56 :blue 0.59 :alpha 1.0}
        active-color {:red 0 :green 0 :blue 0 :alpha 1.0}
        active-style {:font space-font :baselineOffset -5.0 :color active-color}
        inactive-style {:font space-font :baselineOffset -5.0 :color inactive-color}
        space-icons {1 :e 2 :f 3 :g 4 :i 5 :j 6 :k 7 :l 8 :m 9 :n 10 :o 11 :r :f :a}
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

(fn set-environment [task]
  (let [environment (task:environment)]
    (set environment.JQ_PATH obj.jqPath)
    (set environment.YABAI_PATH obj.yabaiPath)
    (task:setEnvironment environment)))

(fn run-task []
  "Run the task to update the menubar item"
  (set obj.task (-> (hs.spoons.resourcePath :spaces.sh)
                    (hs.task.new callback)
                    (set-environment)
                    (: :start))))

(fn obj.add_signals [self]
  (-> :signals.sh
      (hs.spoons.resourcePath)
      (hs.task.new nil)
      (set-environment)
      (: :start)))

(fn obj.update [self]
  (terminate-task)
  (run-task))

(fn obj.init [self]
  (set self.logger (hs.logger.new :YabaiSpaces))
  (set self.menuItem (hs.menubar.new))
  (self:add_signals)
  (hs.styledtext.loadFont (hs.spoons.resourcePath :cdnumbers.ttf))
  (self.menuItem:setTitle "[Updating...]")
  (self:update))

obj
