# ningle-actions

A server-action extension for [ningle](https://github.com/fukamachi/ningle),
inspired by Next.js Server Actions.

Define a server function once with `defaction` and you get:

- an auto-generated, auto-registered endpoint with a random opaque id, and
- a **function of the same name** that returns that URL (you never write or
  remember concrete URLs).

Clients (e.g. htmx) just embed the return value of that function into
attributes like `hx-post`.

## Features

- **URL-free**: `(like)` returns the endpoint URL. The URL stays stable across
  redefinitions. Pass keyword arguments to append them as query parameters
  (`(like :id 42)` → `/actions/…?id=42`).
- **Single endpoint**: the actions app exposes only one route, `/:action_id`,
  and dispatches by id.
- **Idiomatic ningle**: the action body receives ningle's `params` (an alist)
  as-is. No custom argument convention, no type coercion.
- **Thin**: response shaping is delegated to ningle; htmx header tweaks use
  `*response*` directly.
- **Integrate in one line**: drop the ready-made `*actions-middleware*` into
  your `lack:builder` chain and the actions app is mounted for you.

## Usage

```lisp
(defpackage #:my-app
  (:use #:cl)
  (:local-nicknames (#:na #:ningle-actions)))
(in-package #:my-app)

;; 1. Define an action. The library provides a singleton actions app,
;;    na:*actions-app*, and defaction registers into it implicitly — you do
;;    not create or hold an instance yourself. A function `like` is defined at
;;    the same time; calling it returns the endpoint URL.
(defparameter *likes* (make-hash-table))

(na:defaction like :post (params)
  (let ((id (cdr (assoc "id" params :test #'string=))))
    (incf (gethash id *likes* 0))
    ;; Return an HTML fragment (any generation method works).
    (format nil "<button>&#9829; ~A</button>" (gethash id *likes*))))

;; 2. Add the actions middleware to your host app. It mounts the singleton
;;    actions app under the fixed /actions prefix for you — no manual wiring.
(defparameter *web* (make-instance 'ningle:app))
;; ... set up the host's normal routes ...

(defparameter *web-app*
  (lack:builder
    na:*actions-middleware*
    *web*))
```

On the view side (htmx), embed the return value of `(like)`
(e.g. `"/actions/3f9a...c2"`):

```html
<button hx-post="<%= (like) %>" hx-target="#like-42" hx-swap="outerHTML">like</button>
```

Run `*web-app*` with a Clack handler (Hunchentoot / Woo, etc.) and it works.

### Query parameters

The generated function accepts keyword arguments and appends them to the URL
as URL-encoded query parameters (handy for `:get` actions that take filters
or paging). Keys become lowercased names, values are stringified, and order is
preserved:

```lisp
(na:defaction list-items :get (params)
  (let ((category (cdr (assoc "category" params :test #'string=))))
    ...))

(list-items)                          ;=> "/actions/3f9a…c2"
(list-items :category "foo")          ;=> "/actions/3f9a…c2?category=foo"
(list-items :category "foo" :page 2)  ;=> "/actions/3f9a…c2?category=foo&page=2"
```

On the server side these arrive in ningle's `params` exactly like any other
query string — no special handling.

### HTTP methods

The second argument of `defaction` is the method (`:get` `:post` `:put`
`:patch` `:delete`). An unknown id and a mismatched method both return `404`.

## API

| Symbol | Kind | Description |
|--------|------|-------------|
| `defaction` | macro | `(defaction NAME METHOD (PARAMS) &body BODY)`. Registers an action on `*actions-app*` and defines a same-named function returning the URL; keyword arguments to that function become query parameters |
| `*actions-middleware*` | variable | A Lack middleware that mounts `*actions-app*` under the fixed `/actions` prefix. Add it to your `lack:builder` chain to wire up the actions app |
| `*actions-app*` | variable | The singleton actions app, created at load time. The implicit target of `defaction` |
| `actions-app` | class | The actions app type (a `ningle:app` subclass) |

## Security

An action defined with `defaction` is just a normal HTTP request handler
reachable from the network. It carries the **same web security risks as any
other endpoint**, and you must guard against them yourself — this library does
not, and the random `action_id` is *not* a secret (it is embedded in the HTML
sent to every client, so it is visible in the DOM, network logs, and `Referer`
headers; it only prevents enumeration, never authorization).

In particular:

- **CSRF** — actions are typically triggered by browser-native form/`hx-post`
  submissions, which can be sent cross-origin. Validate a CSRF token or check
  the `Origin`/`Referer` header (e.g. in your action body or a mount-level
  middleware).
- **Authentication / authorization** — check the session/user inside the
  action (`ningle:*request*` / `*session*` are available) before performing any
  privileged work. Do not rely on the opaque URL as an access control.
- **Input validation & injection** — `params` reaches the body as raw strings.
  Validate and coerce them, and use parameterized queries (SQLi), path
  normalization (path traversal), and output escaping (XSS) as you would in any
  handler.

The convenience of `defaction` can make it easy to forget that each action is a
publicly reachable endpoint, so apply the same scrutiny you would to a
hand-written route.

## License

MIT
