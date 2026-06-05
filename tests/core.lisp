(uiop:define-package #:ningle-actions-test/core
  (:use #:cl #:rove)
  (:import-from #:ningle-actions
                #:actions-app
                #:*actions-app*
                #:defaction)
  (:import-from #:ningle-actions/core
                #:make-actions-app
                #:register-action
                #:find-action
                #:action-endpoint
                #:action-method
                #:action-handler))
(in-package #:ningle-actions-test/core)

;;; --- actions-app / registry / endpoint -------------------------------------

(deftest make-actions-app
  (testing "returns a fresh actions-app"
    (let ((app (make-actions-app)))
      (ok (typep app 'actions-app)))))

(deftest register-and-find
  (testing "a registered action can be looked up by action_id"
    (let* ((app (make-actions-app))
           (id (register-action app 'foo :post (lambda (params)
                                                 (declare (ignore params))
                                                 "ok"))))
      (ok (stringp id))
      (let ((action (find-action app id)))
        (ok action)
        (ok (eq :post (action-method action)))
        (ok (string= "ok" (funcall (action-handler action) nil))))))
  (testing "an unknown id returns nil"
    (let ((app (make-actions-app)))
      (ok (null (find-action app "no-such-id"))))))

(deftest action-id-reuse
  (testing "re-registering the same name reuses the action_id"
    (let* ((app (make-actions-app))
           (id1 (register-action app 'bar :post (lambda (p) (declare (ignore p)) "v1")))
           (id2 (register-action app 'bar :post (lambda (p) (declare (ignore p)) "v2"))))
      (ok (string= id1 id2))
      (testing "the handler is replaced"
        (ok (string= "v2" (funcall (action-handler (find-action app id2)) nil)))))))

(deftest action-endpoint-format
  (testing "returns the /actions/<id> form"
    (ok (string= "/actions/abc123" (action-endpoint "abc123"))))
  (testing "an empty query is treated as no query"
    (ok (string= "/actions/abc123" (action-endpoint "abc123" nil)))))

(deftest action-endpoint-query
  (testing "a single keyword/value becomes ?key=value"
    (ok (string= "/actions/abc123?category=foo"
                 (action-endpoint "abc123" '(:category "foo")))))
  (testing "multiple pairs are joined with & in argument order"
    (ok (string= "/actions/abc123?category=foo&page=2"
                 (action-endpoint "abc123" '(:category "foo" :page 2)))))
  (testing "non-string values are coerced to their printed representation"
    (ok (string= "/actions/abc123?page=2"
                 (action-endpoint "abc123" '(:page 2)))))
  (testing "keys and values are URL-encoded"
    (ok (string= "/actions/abc123?q=a%20b%26c"
                 (action-endpoint "abc123" '(:q "a b&c"))))))

;;; --- defaction macro -------------------------------------------------------

(deftest defaction-defines-endpoint-function
  (testing "a function named NAME returns /actions/<id>"
    (let ((*actions-app* (make-actions-app)))
      (defaction act-a :post (params)
        (declare (ignore params))
        "A")
      (ok (stringp (act-a)))
      (ok (eql 0 (search "/actions/" (act-a)))))))

(deftest defaction-registers-handler
  (testing "defaction registers the handler in the registry"
    (let ((*actions-app* (make-actions-app)))
      (defaction act-b :put (params)
        (declare (ignore params))
        "B")
      (let* ((id (subseq (act-b) (length "/actions/")))
             (action (find-action *actions-app* id)))
        (ok action)
        (ok (eq :put (action-method action)))
        (ok (string= "B" (funcall (action-handler action) nil)))))))

(deftest defaction-redefinition-keeps-url
  (testing "redefining the same action keeps the URL"
    (let ((*actions-app* (make-actions-app)))
      (defaction act-c :post (params) (declare (ignore params)) "v1")
      (let ((url1 (act-c)))
        (defaction act-c :post (params) (declare (ignore params)) "v2")
        (ok (string= url1 (act-c)))))))

(deftest defaction-endpoint-function-query
  (testing "the endpoint function appends keyword args as query parameters"
    (let ((*actions-app* (make-actions-app)))
      (defaction list-items :get (params) (declare (ignore params)) "ok")
      (testing "no args keeps the bare /actions/<id> (backward compatible)"
        (ok (null (position #\? (list-items)))))
      (let ((base (list-items)))
        (testing "a single keyword arg yields ?key=value"
          (ok (string= (concatenate 'string base "?category=foo")
                       (list-items :category "foo"))))
        (testing "multiple keyword args are joined in order"
          (ok (string= (concatenate 'string base "?category=foo&page=2")
                       (list-items :category "foo" :page 2))))))))

(deftest defaction-passes-params
  (testing "the handler receives ningle's params (alist)"
    (let ((*actions-app* (make-actions-app)))
      (defaction act-d :post (params)
        (cdr (assoc "name" params :test #'string=)))
      (let* ((id (subseq (act-d) (length "/actions/")))
             (action (find-action *actions-app* id)))
        (ok (string= "alice"
                     (funcall (action-handler action)
                              (list (cons "name" "alice")))))))))
