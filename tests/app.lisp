(uiop:define-package #:ningle-actions-test/app
  (:use #:cl #:rove)
  (:import-from #:ningle-actions
                #:make-action-app
                #:actions-app
                #:*app*)
  (:import-from #:ningle-actions/app
                #:register-action
                #:find-action
                #:action-endpoint
                #:action-method
                #:action-handler))
(in-package #:ningle-actions-test/app)

(deftest make-action-app
  (testing "returns an actions-app and sets *app*"
    (let ((app (make-action-app)))
      (ok (typep app 'actions-app))
      (ok (eq app *app*)))))

(deftest register-and-find
  (testing "a registered action can be looked up by action_id"
    (let* ((app (make-action-app))
           (id (register-action app 'foo :post (lambda (params)
                                                 (declare (ignore params))
                                                 "ok"))))
      (ok (stringp id))
      (let ((action (find-action app id)))
        (ok action)
        (ok (eq :post (action-method action)))
        (ok (string= "ok" (funcall (action-handler action) nil))))))
  (testing "an unknown id returns nil"
    (let ((app (make-action-app)))
      (ok (null (find-action app "no-such-id"))))))

(deftest action-id-reuse
  (testing "re-registering the same name reuses the action_id"
    (let* ((app (make-action-app))
           (id1 (register-action app 'bar :post (lambda (p) (declare (ignore p)) "v1")))
           (id2 (register-action app 'bar :post (lambda (p) (declare (ignore p)) "v2"))))
      (ok (string= id1 id2))
      (testing "the handler is replaced"
        (ok (string= "v2" (funcall (action-handler (find-action app id2)) nil)))))))

(deftest action-endpoint-format
  (testing "returns the /actions/<id> form"
    (ok (string= "/actions/abc123" (action-endpoint "abc123")))))
