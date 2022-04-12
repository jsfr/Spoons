(fn get-command [name]
  (.. "/usr/bin/security find-generic-password -wa " name))

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
