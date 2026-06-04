(defsystem "ningle-actions-test"
  :class :package-inferred-system
  :pathname "tests"
  :depends-on ("ningle-actions-test/app"
               "ningle-actions-test/action"
               "ningle-actions-test/main")
  :perform (test-op (o c) (symbol-call :rove :run c :style :dot)))
