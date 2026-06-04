(uiop:define-package #:ningle-actions/app
  (:use #:cl)
  (:import-from #:ningle
                #:app
                #:route
                #:*request*)
  (:import-from #:lack/request
                #:request-method)
  (:import-from #:lack/util
                #:generate-random-id)
  (:export #:actions-app
           #:*app*
           #:make-action-app))
(in-package #:ningle-actions/app)

(defparameter +action-prefix+ "/actions"
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

(defvar *app* nil
  "The current actions app. Initialized by make-action-app when main is loaded.
defaction registers into this variable implicitly.")

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

(defun action-endpoint (id)
  "Build the full endpoint URL string (/actions/<id>) from an action_id."
  (concatenate 'string +action-prefix+ "/" id))

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

(defun make-action-app ()
  "Create an actions app and register the single /:action_id route for all
standard methods. Sets *app* to the new instance and returns it."
  (let ((app (make-instance 'actions-app)))
    (setf (route app "/:action_id" :method '(:GET :POST :PUT :PATCH :DELETE))
          (lambda (params)
            (dispatch-action app params)))
    (setf *app* app)
    app))
