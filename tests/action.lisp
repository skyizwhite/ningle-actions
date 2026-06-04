(uiop:define-package #:ningle-actions-test/action
  (:use #:cl #:rove)
  (:import-from #:ningle-actions
                #:defaction
                #:make-action-app
                #:*app*)
  (:import-from #:ningle-actions/app
                #:find-action
                #:action-method
                #:action-handler))
(in-package #:ningle-actions-test/action)

(deftest defaction-defines-endpoint-function
  (testing "a function named NAME returns /actions/<id>"
    (let ((*app* (make-action-app)))
      (defaction act-a :post (params)
        (declare (ignore params))
        "A")
      (ok (stringp (act-a)))
      (ok (eql 0 (search "/actions/" (act-a)))))))

(deftest defaction-registers-handler
  (testing "defaction registers the handler in the registry"
    (let ((*app* (make-action-app)))
      (defaction act-b :put (params)
        (declare (ignore params))
        "B")
      (let* ((id (subseq (act-b) (length "/actions/")))
             (action (find-action *app* id)))
        (ok action)
        (ok (eq :put (action-method action)))
        (ok (string= "B" (funcall (action-handler action) nil)))))))

(deftest defaction-redefinition-keeps-url
  (testing "redefining the same action keeps the URL"
    (let ((*app* (make-action-app)))
      (defaction act-c :post (params) (declare (ignore params)) "v1")
      (let ((url1 (act-c)))
        (defaction act-c :post (params) (declare (ignore params)) "v2")
        (ok (string= url1 (act-c)))))))

(deftest defaction-passes-params
  (testing "the handler receives ningle's params (alist)"
    (let ((*app* (make-action-app)))
      (defaction act-d :post (params)
        (cdr (assoc "name" params :test #'string=)))
      (let* ((id (subseq (act-d) (length "/actions/")))
             (action (find-action *app* id)))
        (ok (string= "alice"
                     (funcall (action-handler action)
                              (list (cons "name" "alice")))))))))
