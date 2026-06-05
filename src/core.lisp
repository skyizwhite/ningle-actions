(uiop:define-package #:ningle-actions/core
  (:use #:cl)
  (:import-from #:ningle
                #:app
                #:route
                #:*request*)
  (:import-from #:lack/request
                #:request-method)
  (:import-from #:lack/util
                #:generate-random-id)
  (:import-from #:lack/middleware/mount
                #:*lack-middleware-mount*)
  (:import-from #:quri
                #:make-uri
                #:render-uri)
  (:import-from #:alexandria
                #:plist-alist)
  (:export #:defaction
           #:actions-app
           #:*actions-app*
           #:*actions-middleware*))
(in-package #:ningle-actions/core)

(defparameter +actions-prefix+ "/actions"
  "Mount prefix of the actions app (fixed). Prepended to endpoint URLs.
Logically a constant, but defined with defparameter to avoid the string
constant redefinition problem.")

(defstruct (action (:constructor %make-action))
  "Internal record for a single registered action."
  id        ; action_id (string)
  name      ; defaction name (symbol)
  method    ; HTTP method (keyword)
  handler)  ; closure taking the params alist

(defclass actions-app (app)
  ((registry :initform (make-hash-table :test 'equal)
             :reader app-registry
             :documentation "action_id(string) -> action")
   (name-index :initform (make-hash-table :test 'eq)
               :reader app-name-index
               :documentation "name(symbol) -> action_id(string)"))
  (:documentation "A ningle:app subclass that registers and dispatches actions."))

(defun find-action (app id)
  "Look up an action by action_id. Returns nil if not found."
  (gethash id (app-registry app)))

(defun register-action (app name method handler)
  "Register an action, reusing the existing action_id for NAME (allocating a
new one if absent). Returns the action_id. Reusing the id on redefinition
keeps endpoint URLs stable."
  (let ((id (or (gethash name (app-name-index app))
                (setf (gethash name (app-name-index app)) (generate-random-id)))))
    (setf (gethash id (app-registry app))
          (%make-action :id id :name name :method method :handler handler))
    id))

(defun query-params-alist (plist)
  "Convert a plist of keyword/value pairs into an alist suitable for
quri:make-uri's :query. Keys become lowercased keyword-name strings; values
are coerced with princ-to-string (quri's url-encode-params requires string
keys and string/number values). Order follows the plist."
  (mapcar (lambda (pair)
            (cons (string-downcase (symbol-name (car pair)))
                  (princ-to-string (cdr pair))))
          (plist-alist plist)))

(defun action-endpoint (id &optional query)
  "Build the full endpoint URL string (/actions/<id>) from an action_id,
assembled with quri:make-uri. If QUERY (a plist of keyword/value pairs) is
non-nil, it is appended as a URL-encoded query string; otherwise the bare
/actions/<id> is returned."
  (let ((path (concatenate 'string +actions-prefix+ "/" id)))
    (if query
        (render-uri (make-uri :path path :query (query-params-alist query)))
        path)))

(defun dispatch-action (app params)
  "Handler for the single /:action_id route. Looks up the action by action_id,
checks the method, and calls the handler. The return value is passed through
unchanged and left to ningle to turn into a response."
  (let* ((id (cdr (assoc :action_id params)))
         (action (and id (find-action app id))))
    (cond
      ((null action)
       '(404 () ("Not Found")))
      ((not (eq (action-method action) (request-method *request*)))
       '(405 () ("Method Not Allowed")))
      (t
       (funcall (action-handler action) params)))))

(defun make-actions-app ()
  "Create a fresh actions-app with the single /:action_id route registered for
all standard methods, and return it. Internal constructor with no side effects:
the public entry point is the *actions-app* singleton; tests use this to build
isolated apps."
  (let ((app (make-instance 'actions-app)))
    (setf (route app "/:action_id" :method '(:GET :POST :PUT :PATCH :DELETE))
          (lambda (params)
            (dispatch-action app params)))
    app))

(defvar *actions-app* (make-actions-app)
  "The singleton actions app, created at load time with its dispatch route
registered. defaction registers into it implicitly, and you mount it into your
host app with *actions-middleware*. Tests may rebind it to an isolated instance
built with make-actions-app.")

(defvar *actions-middleware*
  (lambda (app)
    (funcall *lack-middleware-mount* app +actions-prefix+ *actions-app*))
  "A Lack middleware that mounts *actions-app* under the fixed /actions prefix.
Add it to your lack:builder chain to wire up the actions app.")

(defmacro defaction (name method (params) &body body)
  "Register an action on *actions-app* and define a function NAME that returns
its endpoint URL.

  NAME   : action name. A function of this name is defined that, when called,
           returns /actions/<id>. Keyword arguments passed to it are appended
           to the URL as query parameters, e.g.
           (NAME :category \"foo\" :page 2) => /actions/<id>?category=foo&page=2.
  METHOD : accepted HTTP method keyword (:get :post :put :patch :delete).
  PARAMS : variable name bound in the body to ningle's params (an alist).
  BODY   : action body. May reference PARAMS and ningle:*request* etc."
  (let ((id (gensym "ID")))
    `(let ((,id (register-action *actions-app* ',name ,method
                                 (lambda (,params)
                                   (declare (ignorable ,params))
                                   ,@body))))
       (defun ,name (&rest query)
         (action-endpoint ,id query)))))
