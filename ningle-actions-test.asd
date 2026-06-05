(defsystem "ningle-actions-test"
  :class :package-inferred-system
  :pathname "tests"
  :depends-on ("ningle-actions-test/core"
               "ningle-actions-test/integration")
  :perform (test-op (o c) (symbol-call :rove :run c :style :dot)))
