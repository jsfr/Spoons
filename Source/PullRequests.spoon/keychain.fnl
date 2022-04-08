(fn get-command [name]
  (.. "/usr/bin/security 2>&1 >/dev/null find-generic-password -ga "
      name
      " | sed -En '/^password: / s,^password: \"(.*)\"$,\\1,p'"))

(fn run-command [command]
  (with-open [handle (io.popen command)]
    (handle:read "*a")))

(fn extract-password [text]
  (text:gsub "^%s*(.-)%s*$" "%1"))

(fn password-from-keychain [name]
  (-> name
      (get-command)
      (run-command)
      (extract-password)))

{: password-from-keychain}
