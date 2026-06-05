(uiop:define-package #:ningle-actions/action
  (:use #:cl)
  (:import-from #:ningle-actions/app
                #:*actions-app*
                #:register-action
                #:action-endpoint)
  (:export #:defaction))
(in-package #:ningle-actions/action)

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
