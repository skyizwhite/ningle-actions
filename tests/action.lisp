(uiop:define-package #:ningle-actions-test/action
  (:use #:cl #:rove)
  (:import-from #:ningle-actions
                #:defaction
                #:*actions-app*)
  (:import-from #:ningle-actions/app
                #:make-actions-app
                #:find-action
                #:action-method
                #:action-handler))
(in-package #:ningle-actions-test/action)

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
