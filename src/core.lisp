(uiop:define-package #:ningle-actions/core
  (:use #:cl)
  (:import-from #:ningle
                #:app
                #:route
                #:*request*
                #:*response*)
  (:import-from #:lack/request
                #:request-method)
  (:import-from #:lack/response
                #:response-status)
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
  slug      ; URL path segment, <name>-<id> (string)
  name      ; defaction name (symbol)
  method    ; HTTP method (keyword)
  handler)  ; closure taking the params alist

(defparameter +id-length+ 6
  "Length (in hex chars) of the id suffix in an action slug. At most 8, the
width of the 32-bit hash it is taken from.")

(defparameter +fnv-offset-basis+ 2166136261
  "Offset basis of the 32-bit FNV-1a hash.")

(defparameter +fnv-prime+ 16777619
  "Prime multiplier of the 32-bit FNV-1a hash.")

(defclass actions-app (app)
  ((registry :initform (make-hash-table :test 'equal)
             :reader app-registry
             :documentation "slug(string) -> action")
   (name-index :initform (make-hash-table :test 'eq)
               :reader app-name-index
               :documentation "name(symbol) -> slug(string)"))
  (:documentation "A ningle:app subclass that registers and dispatches actions."))

(defun find-action (app slug)
  "Look up an action by its URL slug. Returns nil if not found."
  (gethash slug (app-registry app)))

(defun fnv-1a (string)
  "32-bit FNV-1a hash of STRING. Each character is mixed in one octet at a time,
little-endian, at least one octet per character, so characters outside Latin-1
hash deterministically too. Plain integer math with no external state: the same
string always yields the same number, in every process and every image."
  (let ((hash +fnv-offset-basis+))
    (flet ((mix (octet)
             (setf hash (ldb (byte 32 0) (* (logxor hash octet) +fnv-prime+)))))
      (loop :for char :across string
            :do (loop :for code := (char-code char) :then (ash code -8)
                      :do (mix (ldb (byte 8 0) code))
                      :until (zerop (ash code -8)))))
    hash))

(defun make-action-slug (name &optional (attempt 0))
  "Build a URL path segment for NAME of the form <name>-<id>, where <name> is the
downcased symbol name and <id> is a short hex hash of the package-qualified
name. The name prefix aids log traceability; the hash keeps slugs unique across
packages. The id is *derived*, not random, so the same action keeps the same URL
in every process and across deploys. ATTEMPT is folded into the hashed key so a
colliding slug can be re-derived (see allocate-action-slug).

The flip side of deriving it: renaming an action, or moving it to another
package, changes its URL."
  (let* ((package (symbol-package name))
         (key (format nil "~A:~A~@[#~D~]"
                      (if package (package-name package) "#")
                      (symbol-name name)
                      (when (plusp attempt) attempt))))
    (format nil "~(~A-~V,'0X~)"
            (symbol-name name)
            +id-length+
            (ldb (byte (* 4 +id-length+) 0) (fnv-1a key)))))

(defun allocate-action-slug (app name)
  "Allocate a slug for NAME that is not already taken in APP's registry, bumping
the attempt counter on the (astronomically unlikely) chance the short id
collides with another action's. A collision needs two actions whose downcased
names AND hashes both match, and the retry is resolved by registration order,
which is fixed for a given build -- so the outcome is reproducible. Only reached
when NAME has no slug yet; redefining an existing name reuses its slug and never
enters this loop."
  (loop :for attempt :from 0
        :for slug := (make-action-slug name attempt)
        :unless (find-action app slug)
          :return slug))

(defun register-action (app name method handler)
  "Register an action, reusing the existing slug for NAME (allocating a new one
if absent). Returns the slug. Reusing it on redefinition keeps endpoint URLs
stable."
  (let ((slug (or (gethash name (app-name-index app))
                  (setf (gethash name (app-name-index app)) (allocate-action-slug app name)))))
    (setf (gethash slug (app-registry app))
          (%make-action :slug slug :name name :method method :handler handler))
    slug))

(defun query-params-alist (plist)
  "Convert a plist of keyword/value pairs into an alist suitable for
quri:make-uri's :query. Keys become lowercased keyword-name strings; values
are coerced with princ-to-string (quri's url-encode-params requires string
keys and string/number values). Order follows the plist."
  (mapcar (lambda (pair)
            (cons (string-downcase (symbol-name (car pair)))
                  (princ-to-string (cdr pair))))
          (plist-alist plist)))

(defun action-endpoint (slug &optional query)
  "Build the full endpoint URL string (/actions/<name>-<id>) from a slug,
assembled with quri:make-uri. If QUERY (a plist of keyword/value pairs) is
non-nil, it is appended as a URL-encoded query string; otherwise the bare
/actions/<name>-<id> is returned."
  (let ((path (concatenate 'string +actions-prefix+ "/" slug)))
    (if query
        (render-uri (make-uri :path path :query (query-params-alist query)))
        path)))

(defun dispatch-action (app params)
  "Handler for the single /:action_id route. Calls the action's handler when the
slug is known and the request method matches; otherwise sets a 404 on
*response* and returns nil (empty body)."
  (let* ((slug (cdr (assoc :action_id params)))
         (action (and slug (find-action app slug))))
    (if (and action (eq (action-method action) (request-method *request*)))
        (funcall (action-handler action) params)
        (progn
          (setf (response-status *response*) 404)
          nil))))

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
           returns /actions/<name>-<id>. Keyword arguments passed to it are
           appended to the URL as query parameters, e.g.
           (NAME :category \"foo\" :page 2)
           => /actions/<name>-<id>?category=foo&page=2.
  METHOD : accepted HTTP method keyword (:get :post :put :patch :delete).
  PARAMS : variable name bound in the body to ningle's params (an alist).
  BODY   : action body. May reference PARAMS and ningle:*request* etc."
  (let ((id (gensym "ID")))
    ;; Peel off any leading declarations so they stay at the head of the
    ;; lambda body; the BLOCK only wraps the executable forms.
    (loop :for tail :on body
          :while (and (consp (car tail)) (eq 'declare (caar tail)))
          :collect (car tail) :into decls
          :finally (return
                     `(let ((,id (register-action *actions-app* ',name ,method
                                                  (lambda (,params)
                                                    ,@decls
                                                    (block ,name
                                                      ,@tail)))))
                        (defun ,name (&rest query)
                          (action-endpoint ,id query)))))))
