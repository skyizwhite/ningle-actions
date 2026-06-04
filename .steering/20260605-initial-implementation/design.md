# 初回実装 設計 (Design)

要求: [requirements.md](./requirements.md)。永続設計: [docs/functional-design.md](../../docs/functional-design.md)。

---

## 1. 実装アプローチ

- `:package-inferred-system` で `src/app.lisp` → `src/action.lisp` → `src/main.lisp` の 3 ファイル。
- 副作用（登録・ルート設定・`*app*` 変更）は `app` の関数に閉じ込め、`defaction` マクロは薄い展開に留める。
- 公開シンボルは `main.lisp` の `:use-reexport` で集約（公開4点: `defaction` `make-action-app` `*app*` `actions-app`）。
- 内部シンボル（`register-action` / `action-endpoint` 等）は `app` から export せず、`action.lisp` が `:import-from` で直接取り込む（reexport で漏れない）。

---

## 2. `src/app.lisp`（`ningle-actions/app`）

### パッケージ
```lisp
(uiop:define-package #:ningle-actions/app
  (:use #:cl)
  (:import-from #:ningle #:app #:route #:*request*)
  (:import-from #:lack/request #:request-method)
  (:import-from #:lack/util #:generate-random-id)
  (:export #:actions-app #:*app* #:make-action-app))   ; 公開はこの3つのみ
```
> `register-action` / `find-action` / `dispatch-action` / `action-endpoint` / `+action-prefix+` / `action` 構造体は **非 export**（内部）。`action.lisp` は `:import-from` で内部シンボルを取り込める。

### 定数・構造体・クラス
```lisp
(defparameter +action-prefix+ "/actions")   ; 論理的には定数（文字列のため defparameter）

(defstruct (action (:constructor %make-action))
  id name method handler)

(defclass actions-app (app)
  ((registry   :initform (make-hash-table :test 'equal) :reader app-registry)   ; action_id(string) → action
   (name-index :initform (make-hash-table :test 'eq)    :reader app-name-index))) ; name(symbol) → action_id

(defvar *app* nil "現在のアクションアプリ。main のロード時に初期化される。")
```

### レジストリ操作
```lisp
(defun find-action (app id)
  (gethash id (app-registry app)))

(defun register-action (app name method handler)
  "name で既存 action_id を再利用（無ければ採番）し、action を登録。action_id を返す。"
  (let ((id (or (gethash name (app-name-index app))
                (setf (gethash name (app-name-index app)) (generate-random-id)))))
    (setf (gethash id (app-registry app))
          (%make-action :id id :name name :method method :handler handler))
    id))

(defun action-endpoint (id)
  (concatenate 'string +action-prefix+ "/" id))   ; "/actions/<id>"
```

### ディスパッチ
```lisp
(defun dispatch-action (app params)
  (let* ((id (cdr (assoc :action_id params)))     ; ningle のパスパラメータ（キーワードキー）
         (action (and id (find-action app id))))
    (cond
      ((null action) '(404 () ("Not Found")))
      ((not (eq (action-method action) (request-method *request*)))
       '(405 () ("Method Not Allowed")))
      (t (funcall (action-handler action) params)))))   ; 戻り値は加工せず ningle に委譲
```

### アプリ生成
```lisp
(defun make-action-app ()
  (let ((app (make-instance 'actions-app)))
    (setf (route app "/:action_id" :method '(:GET :POST :PUT :PATCH :DELETE))
          (lambda (params) (dispatch-action app params)))
    (setf *app* app)
    app))
```

---

## 3. `src/action.lisp`（`ningle-actions/action`）

```lisp
(uiop:define-package #:ningle-actions/action
  (:use #:cl)
  (:import-from #:ningle-actions/app #:*app* #:register-action #:action-endpoint)
  (:export #:defaction))
(in-package #:ningle-actions/action)

(defmacro defaction (name method (params) &body body)
  "アクションを *app* に登録し、エンドポイント URL を返す関数 NAME を定義する。"
  (let ((id (gensym "ID")))
    `(let ((,id (register-action *app* ',name ,method
                                 (lambda (,params)
                                   (declare (ignorable ,params))
                                   ,@body))))
       (defun ,name () (action-endpoint ,id)))))
```

### 展開例
```lisp
(defaction like :post (params)
  (render-like-button (cdr (assoc "id" params :test #'string=))))
;; ↓
(let ((#:id123 (register-action *app* 'like :post
                                (lambda (params)
                                  (declare (ignorable params))
                                  (render-like-button (cdr (assoc "id" params :test #'string=)))))))
  (defun like () (action-endpoint #:id123)))
```
- `defun` は `let` の lexical `id` を閉じ込める（クロージャ）。再評価時は `register-action` が同じ `action_id` を返すため `(like)` の戻り値は不変。

---

## 4. `src/main.lisp`（`ningle-actions` / `ningle-actions/main`）

```lisp
(uiop:define-package #:ningle-actions
  (:nicknames #:ningle-actions/main)
  (:use #:cl)
  (:use-reexport #:ningle-actions/app
                 #:ningle-actions/action))
(in-package #:ningle-actions)

;; ロード時にグローバルアクションアプリを初期化
(unless *app* (make-action-app))
```
- 既存スケルトン（`:use #:cl` のみ）を上記へ置き換える。
- 公開面: `defaction` `make-action-app` `*app*` `actions-app`。

---

## 5. 変更するコンポーネント / 影響範囲

| 対象 | 変更 |
|------|------|
| `src/main.lisp` | 既存内容を §4 で置換 |
| `src/app.lisp` | 新規作成 |
| `src/action.lisp` | 新規作成 |
| `ningle-actions.asd` | 変更なし（`:depends-on ("ningle-actions/main")` のまま、推移的に app/action を取り込む） |
| `qlfile` / `qlfile.lock` | 変更なし（`ningle` / `lack` / `rove` 済み） |
| `tests/*.lisp` | 新規作成（§7） |
| `ningle-actions-test.asd` | `:depends-on` にテスト対象を追加（`ningle-actions` と各 tests パッケージ） |
| `README.md` | 最小サンプル追記（別タスク） |

---

## 6. データフロー（再掲・実装視点）

```
defaction ─(load)→ register-action(*app*, name, method, handler) ─→ registry[id]=action, name-index[name]=id
                                                                          │
リクエスト POST /actions/<id> ─mount→ ningle dispatch "/:action_id"
   → (lambda (params) (dispatch-action *the-app* params))
   → id=(assoc :action_id params) → find-action → method 照合
   → (funcall handler params) → 戻り値 → ningle process-response
```

---

## 7. テスト設計（`tests/`）

### 方針
- **ユニット**: `app` の純関数（register/find/endpoint/id 再利用）を直接検証。
- **ディスパッチ**: `dispatch-action` を、`ningle:*request*` を擬似 request に束縛して検証（404/405/正常）。
  - 擬似 request: `(lack/request:make-request (list :request-method :POST :path-info "/x" :headers (make-hash-table)))`。
- **統合**: `(:mount "/actions" app)` を含む `lack:builder` を組み、`to-app` 済みアプリへ env を流して end-to-end（URL→アクション実行→戻り値）を検証。
  - リクエスト駆動は ningle-test と同様の手段（`clack/lack` のテストユーティリティ）を用いる。具体 API は実装時に ningle-test の依存を参照して確定する。

### ケース一覧（AC 対応）
| ファイル | ケース | AC |
|----------|--------|----|
| `tests/app.lisp` | `make-action-app` が `actions-app` を返し `*app*` を設定 | AC-1 |
| | `register-action` → `find-action` で取得できる | AC-1 |
| | 同名 `register-action` 2 回で同一 `action_id`（再利用） | AC-3 |
| | `action-endpoint` が `/actions/<id>` を返す | AC-2 |
| | `dispatch-action`: 未登録 id → 404 | AC-5 |
| | `dispatch-action`: メソッド不一致 → 405 | AC-6 |
| | `dispatch-action`: 正常 → handler 戻り値 | AC-4/AC-7 |
| `tests/action.lisp` | `defaction` 後、`(name)` が URL を返す | AC-2 |
| | `defaction` 後、`find-action` で登録を確認 | AC-1 |
| | 再 `defaction` で `(name)` の戻り値不変 | AC-3 |
| | handler が `params` を受け取り値を取得 | AC-7 |
| `tests/main.lisp` | `(:mount "/actions" *app*)` 統合の end-to-end | AC-4 |
| | 統合下で未登録/メソッド不一致 → 404/405 | AC-5/AC-6 |

### テスト隔離
- 各テストブロックの冒頭で `(let ((*app* (make-action-app))) ...)` により隔離（NFR3）。
- `defaction` はグローバル `*app*` を使うため、隔離時はその束縛下で評価する。

---

## 8. 未確定事項（実装時に確定）

1. ningle のパスパラメータキーが `:action_id`（大文字化 `:ACTION_ID`）で取得できることを実コードで確認（README 例から想定。テストで担保）。
2. 統合テストのリクエスト駆動ユーティリティの具体 API（`ningle-actions-test.asd` の依存に合わせる）。
3. `ningle-actions-test.asd` の `:depends-on` 構成（`ningle-actions` 本体 + tests パッケージ群）。
