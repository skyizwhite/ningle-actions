# ningle-actions

Server actions for [ningle](https://github.com/fukamachi/ningle). They make
partial HTML updates easier to handle with hypermedia libraries such as
[htmx](https://four.htmx.org/).

`defaction` defines a partial-update endpoint and, under the same name, a
function that returns that endpoint's URL. Your views call the function
instead of writing a URL, so you never have to design, name, or keep in sync
the URLs that your buttons and forms request fragments from.

```lisp
(na:defaction like :post (params)
  (render-to-string (hsx (span "♥ " (add-like params)))))

(like)  ;=> "/actions/like-5713aa"
```

## Concept

A hypermedia app has two kinds of URLs:

- **Page URLs**, such as `/posts/42` or `/settings`. These are resources that
  people bookmark and share, and you design them on purpose.
- **Action URLs**: whatever a button or form requests, through htmx or a
  similar library, to get back an HTML fragment. Nobody visits these. They exist only so a button or form can work.

Plain ningle puts both kinds in one route table. Your page routes get mixed up
with a growing pile of fragment routes, and you have to name each fragment
route and repeat its URL by hand in the view that calls it.

ningle-actions separates the two:

- Page URLs stay in your ningle app, and you design them as usual.
- Action URLs live under their own `/actions/` namespace. The library generates
  them, so you never write one.

Each action is a Lisp function on the server, and the view gets its URL by
calling that function. Rename an action and every reference to its URL is a
function call that your compiler and editor know about, not a string you have
to search for. The idea is close to Next.js Server Actions, adapted to
server-rendered HTML and hypermedia libraries.

## Installation

With [qlot](https://github.com/fukamachi/qlot), add this to your `qlfile`:

```
git ningle-actions https://github.com/skyizwhite/ningle-actions.git
```

Then depend on `"ningle-actions"` in your system definition.

ningle-actions doesn't depend on any client library or HTML generator. The
examples below use [htmx](https://four.htmx.org/) on the client and
[hsx](https://github.com/skyizwhite/hsx) for HTML, but any client that sends
HTTP requests to a URL works the same way.

## Usage

### 1. Mount the actions app

Add `na:*actions-middleware*` to your Lack chain. It serves every action under
`/actions` and passes all other requests to your app.

```lisp
(defpackage #:my-app
  (:use #:cl #:hsx)
  (:local-nicknames (#:na #:ningle-actions)))
(in-package #:my-app)

(defvar *app* (make-instance 'ningle:app))

(defvar *web*
  (lack:builder
   na:*actions-middleware*
   *app*))

;; (clack:clackup *web*)
```

### 2. Define actions

```lisp
(defvar *likes* (make-hash-table :test 'equal))

(defun param (params name)
  (cdr (assoc name params :test #'string=)))

(defcomp ~like-button (&key id)
  (hsx
    (button :hx-post (like :id id) :hx-swap "outerHTML"
      "♥ " (gethash id *likes* 0))))

;; POST /actions/like-5713aa?id=...
(na:defaction like :post (params)
  (let ((id (param params "id")))
    (incf (gethash id *likes* 0))
    (render-to-string (hsx (~like-button :id id)))))

;; GET /actions/search-items-bf2b6c?q=...
(na:defaction search-items :get (params)
  (render-to-string
   (hsx
     (<>
       (loop :for item :in (find-items (param params "q"))
             :collect (hsx (li item)))))))
```

(`find-items`, and later `add-like`, `save-title`, and `remove-item`, stand in
for your own code.)

`defaction` takes a name, an HTTP method (`:get`, `:post`, `:put`, `:patch`, or
`:delete`), a variable for ningle's params, and a body. Requests with any other
method get `404`. The body works like a
ningle route handler. `params` is ningle's alist of query and form parameters.
It also contains `(:action_id . "<slug>")` from the dispatch route. Whatever the
body returns becomes the response, exactly as it would from a normal ningle
route.

The body is wrapped in `(block NAME ...)`, so you can exit early with
`return-from`:

```lisp
(na:defaction rename :post (params)
  (let ((title (param params "title")))
    (when (zerop (length title))
      (setf (lack/response:response-status ningle:*response*) 422)
      (return-from rename
        (render-to-string (hsx (p :class "error" "Title is required.")))))
    (save-title title)
    (render-to-string (hsx (h1 title)))))
```

### 3. Call them from views

Put the result of calling the action's function wherever the client library expects a URL:

```lisp
(setf (ningle:route *app* "/")
      (lambda (params)
        (declare (ignore params))
        (render-to-string
         (hsx
           (html
             (head
               (script :src "https://cdn.jsdelivr.net/npm/htmx.org@4.0.0"))
             (body
               (~like-button :id "42")
               (input :type "search" :name "q"
                      :hx-get (search-items)
                      :hx-trigger "input changed delay:300ms"
                      :hx-target "#results")
               (ul :id "results")))))))
```

### Passing parameters

Whatever the client sends as form fields or a query string arrives in `params`.
You can also pass keyword arguments to the action function to bake values into
the URL as a query string:

```lisp
(search-items)                          ;=> "/actions/search-items-bf2b6c"
(search-items :q "lisp")                ;=> "/actions/search-items-bf2b6c?q=lisp"
(search-items :q "a b" :page 2)         ;=> "/actions/search-items-bf2b6c?q=a%20b&page=2"
(delete-item :id 7)                     ;=> "/actions/delete-item-554732?id=7"
```

Keys become lowercase strings (`:page-size` becomes `page-size`). Values are
printed with `princ-to-string`, URL-encoded, and kept in argument order. A `nil`
value is sent as the string `"NIL"`, so leave the key out instead. On the server
these values appear in `params` like any other query parameter.

This lets each button in a list carry its own ID in the URL, with no extra
client-side configuration.

### Setting status and response headers

The library doesn't wrap any client library's protocol. To set a status code or
send response headers such as htmx's `HX-Trigger`, set them on ningle's
`*response*` directly:

```lisp
(na:defaction delete-item :delete (params)
  (remove-item (param params "id"))
  (setf (getf (lack/response:response-headers ningle:*response*) :hx-trigger)
        "item-deleted")
  "")
```

## How it works

```
browser ── POST /actions/like-5713aa?id=42 ──▶ *actions-middleware*
                                                 │ path starts with /actions?
                                   no ◀──────────┤
                                   │             │ yes: strip prefix
                                   ▼             ▼
                              your app      *actions-app*
                                             route /:action_id
                                               │ look up "like-5713aa"
                                               │ check method is POST
                                               ▼
                                             like's body → HTML fragment
```

- **One registry, one route.** `na:*actions-app*` is a single `ningle:app`
  created at load time. It has exactly one route, `/:action_id`, which accepts
  every standard method. Evaluating `defaction` stores the body as a closure in
  the registry and doesn't add any routes.
- **Mounting.** `*actions-middleware*` is Lack's mount middleware, fixed to the
  `/actions` prefix. Requests under that prefix go to `*actions-app*`, and
  everything else passes through to the next app in the chain.
- **Dispatch.** The route looks up the slug in the registry. If the slug is
  registered and the request method matches, the action's closure is called
  with ningle's params. Otherwise the response is `404` with an empty body.
- **The slug.** Each action is addressed by `<name>-<id>`. The name part is the
  downcased symbol name, which makes access logs readable. The id is six hex
  digits of a 32-bit FNV-1a hash of the package-qualified symbol name, such as
  `MY-APP:LIKE`. The id is computed from the name rather than generated
  randomly, so an action keeps the same URL across redefinitions, processes,
  machines, and deploys. Two actions with the same name in different packages
  get different ids. If a slug is already taken by a different action, which is
  extremely unlikely, a salted hash is tried instead.
- **The function.** `defaction` also runs `(defun NAME (&rest query) ...)`,
  which returns `/actions/<slug>`, adding `query` as a query string when you
  pass one. The function only builds the URL. It never calls the action.
- **Redefinition.** Re-evaluating a `defaction` replaces the closure but reuses
  the slug, so interactive REPL work never changes a URL.

## Caveats

### Every action is a public HTTP endpoint

Hiding the URL behind a function makes an action feel like a local function
call, but it's a network endpoint, and anyone can send it any request. The
slug is not a secret. It's derived from the name, and it appears in the HTML
you send to every visitor. The library doesn't do any of the following for
you:

- **CSRF protection.** Check a CSRF token or validate the `Origin` header,
  either in each action or in a middleware placed in front of
  `*actions-middleware*`.
- **Authentication and authorization.** Check the session and user inside the
  action before doing privileged work. `ningle:*request*` and
  `ningle:*session*` are available. A URL that is hard to guess doesn't count as
  access control.
- **Input validation and output escaping.** `params` values are raw strings
  sent by the client. Validate them, and escape them before putting them into
  HTML.

### URLs follow the symbol name

- Renaming an action or moving it to another package changes its URL. After a
  deploy, pages already open in users' browsers still point at the old URL,
  which now returns `404`. Keep that in mind when renaming actions in a live
  app.
- Choose action names that are safe in a URL path. The downcased symbol name
  goes into the path as it is, so a name like `save/draft` would produce a
  slug that can't be routed.
- `defaction` defines a global function with the action's name, which replaces
  any function already named that in the package.

### The registry only grows

Deleting or renaming a `defaction` in your source doesn't unregister the old
action from a running image. The endpoint stays live until the process restarts. Restart the process
before relying on an action being gone, for example after removing one for
security reasons.

### Load order

An action's function exists only after its `defaction` has been loaded. If a
view calls `(like)` at load time, for example in a top-level form that renders
HTML, the file that defines `like` must be loaded first. Calls made inside
request handlers don't have this issue.

### Fixed `/actions` prefix

The prefix can't be configured. Your own routes under `/actions/` are
unreachable because the middleware handles that path first.

### Unknown actions return an empty `404`

An unknown slug and a method mismatch both return `404` with an empty body,
never `405`. If your client swaps error responses into the page (htmx v4 does
this by default), an empty `404`, for example from a page left open across a
deploy, clears the target element. Configure this on the client side.

## API

| Symbol | Kind | Description |
|--------|------|-------------|
| `defaction` | macro | `(defaction NAME METHOD (PARAMS) &body BODY)` registers an action on `*actions-app*` and defines the function `NAME`, which returns the action's URL. Keyword arguments to `NAME` become query parameters. |
| `*actions-middleware*` | variable | A Lack middleware that mounts `*actions-app*` at `/actions`. |
| `*actions-app*` | variable | The single actions app that `defaction` registers into. |
| `actions-app` | class | The class of `*actions-app*`, a subclass of `ningle:app`. |

A production site using this library:
[skyizwhite/website](https://github.com/skyizwhite/website).

## License

MIT
