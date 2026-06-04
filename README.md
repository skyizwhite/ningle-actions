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
  redefinitions.
- **Single endpoint**: the actions app exposes only one route, `/:action_id`,
  and dispatches by id.
- **Idiomatic ningle**: the action body receives ningle's `params` (an alist)
  as-is. No custom argument convention, no type coercion.
- **Thin**: response shaping is delegated to ningle; htmx header tweaks use
  `*response*` directly.
- **Integrate by mounting**: `actions-app` is a `ningle:app` subclass; mount it
  into your host app with `lack:builder`'s `:mount`.

## Installation

Depends on `ningle` and `lack`. Intended to be used with
[qlot](https://github.com/fukamachi/qlot).

```
qlot install
```

## Usage

```lisp
(defpackage #:my-app
  (:use #:cl)
  (:local-nicknames (#:na #:ningle-actions)))
(in-package #:my-app)

;; 1. Create an actions app (the prefix is fixed to /actions).
(defparameter *actions* (na:make-action-app))

;; 2. Define an action. A function `like` is defined at the same time;
;;    calling it returns the endpoint URL.
(defparameter *likes* (make-hash-table))

(na:defaction like :post (params)
  (let ((id (cdr (assoc "id" params :test #'string=))))
    (incf (gethash id *likes* 0))
    ;; Return an HTML fragment (any generation method works).
    (format nil "<button>&#9829; ~A</button>" (gethash id *likes*))))

;; 3. Mount into the host app (wiring the mount is the user's responsibility).
(defparameter *web* (make-instance 'ningle:app))
;; ... set up the host's normal routes ...

(defparameter *app*
  (lack:builder
    (:mount "/actions" *actions*)   ; match make-action-app's "/actions" prefix
    *web*))
```

On the view side (htmx), embed the return value of `(like)`
(e.g. `"/actions/3f9a...c2"`):

```html
<button hx-post="<%= (like) %>" hx-target="#like-42" hx-swap="outerHTML">like</button>
```

Run `*app*` with a Clack handler (Hunchentoot / Woo, etc.) and it works.

### HTTP methods

The second argument of `defaction` is the method (`:get` `:post` `:put`
`:patch` `:delete`). A request with a mismatched method returns `405`, and an
unknown id returns `404`.

### htmx response headers

`HX-*` headers are set via ningle's standard `*response*` (this library ships
no dedicated helpers):

```lisp
(na:defaction notify :post (params)
  (declare (ignore params))
  (setf (getf (lack/response:response-headers ningle:*response*) :|HX-Trigger|) "notified")
  "<div>done</div>")
```

## API

| Symbol | Kind | Description |
|--------|------|-------------|
| `defaction` | macro | `(defaction NAME METHOD (PARAMS) &body BODY)`. Registers an action and defines a same-named function returning the URL |
| `make-action-app` | function | Creates an actions app, sets `*app*`, and returns it (no arguments) |
| `*app*` | variable | The current actions app; the implicit target of `defaction` |
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

## Out of scope (future / user's responsibility)

- Response shaping / content-type — delegated to ningle's `process-response`
- Type coercion / input validation — the user handles it from `params`
- htmx helpers — use `*response*` directly (a separate package may add these)
- Mount wiring — the user does it with `lack:builder`

See [`docs/`](./docs/) for the detailed design (in Japanese).

## Tests

```
qlot exec sbcl --non-interactive --eval '(asdf:test-system :ningle-actions)'
```

## License

MIT
