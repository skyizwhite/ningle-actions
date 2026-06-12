(defsystem "ningle-actions"
  :version "0.5.0"
  :description "Server actions for Ningle"
  :long-description #.(uiop:read-file-string
                       (uiop:subpathname *load-pathname* "README.md"))
  :author "Akira Tempaku"
  :maintainer "Akira Tempaku <paku@skyizwhite.dev>"
  :license "MIT"
  :class :package-inferred-system
  :pathname "src"
  :depends-on ("ningle-actions/main")
  :in-order-to ((test-op (test-op "ningle-actions-test"))))
