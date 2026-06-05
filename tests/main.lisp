(uiop:define-package #:ningle-actions-test/main
  (:use #:cl #:rove)
  (:import-from #:ningle-actions
                #:defaction
                #:*actions-app*)
  (:import-from #:ningle-actions/app
                #:make-actions-app)
  (:import-from #:lack
                #:builder))
(in-package #:ningle-actions-test/main)

(defun %env (method path &optional query-string)
  "Build a minimal Clack environment for testing."
  (list :request-method method
        :path-info path
        :query-string query-string
        :headers (make-hash-table :test 'equal)
        :server-name "localhost"
        :server-port 80
        :url-scheme "http"))

(defmacro with-mounted ((call-var) &body body)
  "Build an integrated app with the actions app (*actions-app*) mounted at /actions,
and bind CALL-VAR to a function that issues a request as (method path &optional query)."
  (let ((app (gensym "APP")))
    `(let* ((,app (builder (:mount "/actions" *actions-app*)
                           (lambda (env) (declare (ignore env)) '(404 () ("MAIN-404")))))
            (,call-var (lambda (method path &optional query)
                         (funcall ,app (%env method path query)))))
       (declare (ignorable ,call-var))
       ,@body)))

(deftest integration-normal
  (testing "the action body runs for the right URL/method and its return value becomes the response"
    (let ((*actions-app* (make-actions-app)))
      (defaction greet :post (params)
        (format nil "hello ~A" (cdr (assoc "name" params :test #'string=))))
      (with-mounted (call)
        (let ((res (funcall call :post (greet) "name=bob")))
          (ok (eql 200 (first res)))
          (ok (equal '("hello bob") (third res))))))))

(deftest integration-not-found
  (testing "an unknown action_id returns 404"
    (let ((*actions-app* (make-actions-app)))
      (with-mounted (call)
        (let ((res (funcall call :post "/actions/does-not-exist")))
          (ok (eql 404 (first res))))))))

(deftest integration-method-not-allowed
  (testing "a method mismatch returns 405"
    (let ((*actions-app* (make-actions-app)))
      (defaction only-post :post (params) (declare (ignore params)) "ok")
      (with-mounted (call)
        (let ((res (funcall call :get (only-post))))
          (ok (eql 405 (first res))))))))

(deftest integration-passthrough
  (testing "a path not matching the prefix falls through to the main app"
    (let ((*actions-app* (make-actions-app)))
      (with-mounted (call)
        (let ((res (funcall call :get "/somewhere-else")))
          (ok (eql 404 (first res)))
          (ok (equal '("MAIN-404") (third res))))))))
