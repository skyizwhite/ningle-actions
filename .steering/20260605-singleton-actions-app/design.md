# 設計: シングルトンのアクションアプリを直接提供する

## 1. 実装アプローチ

変更は「命名」と「シングルトンの確定方法」に閉じる。レジストリ・ディスパッチ・
`action-endpoint` のロジックには一切手を入れない。

要点は 3 つ。

1. `*app*` → `*actions-app*` にリネームし、**生成済みシングルトンを束ねた
   `defvar`** にする（ロード時に確定）。
2. `make-actions-app` を **副作用なしの純粋コンストラクタ** に変更し、
   **export から外す**（`ningle-actions/app` 内の内部関数として残す）。
3. `defaction` の暗黙の登録先を `*actions-app*` に切り替える。
4. `src/main.lisp` のロード時初期化ブロックは不要になるため削除する。

## 2. 変更するコンポーネント

### 2.1 `src/app.lisp`

#### パッケージ定義（`:export`）

`*app*` / `make-actions-app` を export から外し、`*actions-app*` を追加する。

変更前:
```lisp
(:export #:actions-app
         #:*app*
         #:make-actions-app)
```

変更後:
```lisp
(:export #:actions-app
         #:*actions-app*)
```

> `make-actions-app` は **定義は残すが export しない**（内部コンストラクタ）。
> `actions-app` クラスは引き続き公開（mount 対象の型情報・`typep` 用）。

#### `make-actions-app`（純粋コンストラクタ化）

`setf *app*` を削除し、生成したインスタンスを返すだけにする。`*actions-app*`
の定義より前（参照される前）に置く。

変更前:
```lisp
(defun make-actions-app ()
  "Create an actions app and register the single /:action_id route for all
standard methods. Sets *app* to the new instance and returns it."
  (let ((app (make-instance 'actions-app)))
    (setf (route app "/:action_id" :method '(:GET :POST :PUT :PATCH :DELETE))
          (lambda (params)
            (dispatch-action app params)))
    (setf *app* app)
    app))
```

変更後:
```lisp
(defun make-actions-app ()
  "Create a fresh actions-app with the single /:action_id route registered for
all standard methods, and return it. Internal constructor: the public entry
point is the *actions-app* singleton; tests use this to build isolated apps."
  (let ((app (make-instance 'actions-app)))
    (setf (route app "/:action_id" :method '(:GET :POST :PUT :PATCH :DELETE))
          (lambda (params)
            (dispatch-action app params)))
    app))
```

#### `*actions-app*`（旧 `*app*`・シングルトン化）

`nil` 初期値の `defvar` をやめ、`make-actions-app` の戻り値で初期化する
`defvar` にする。`make-actions-app` / `dispatch-action` の定義より後ろに置く
（前方参照を避けるため、ファイル末尾付近に移動する）。

変更前（ファイル中ほど）:
```lisp
(defvar *app* nil
  "The current actions app. Initialized by make-actions-app when main is loaded.
defaction registers into this variable implicitly.")
```

変更後（`make-actions-app` 定義より後ろ）:
```lisp
(defvar *actions-app* (make-actions-app)
  "The singleton actions app, created at load time with its dispatch route
registered. defaction registers into it implicitly, and you mount it into your
host app (:mount \"/actions\" *actions-app*). Tests may rebind it to an
isolated instance built with make-actions-app.")
```

> `defvar` を採用する理由: 再ロード（イメージ更新・再評価）時に既存の
> シングルトンと、そこに `defaction` で積まれた登録内容を保持するため。
> `defparameter` だと再評価で空のインスタンスに戻ってしまう。

#### ファイル内の定義順（前方参照の解消）

`*actions-app*` の初期化フォーム `(make-actions-app)` が **ロード時に評価される**
ため、`make-actions-app` と、それが参照する `dispatch-action` が先に定義済みで
ある必要がある。現状 `*app*` は `dispatch-action` より前にあるので、
`*actions-app*` の `defvar` を **`make-actions-app` 定義の直後（ファイル末尾）**
へ移動する。`find-action` / `register-action` 等は `*actions-app*` を参照しない
ため順序の影響を受けない。

### 2.2 `src/action.lisp`

`defaction` の暗黙の登録先を `*actions-app*` に切り替える。import も更新。

変更前:
```lisp
(:import-from #:ningle-actions/app
              #:*app*
              #:register-action
              #:action-endpoint)
...
(register-action *app* ',name ,method ...)
```

変更後:
```lisp
(:import-from #:ningle-actions/app
              #:*actions-app*
              #:register-action
              #:action-endpoint)
...
(register-action *actions-app* ',name ,method ...)
```

docstring 中の「Register an action on *app*」も `*actions-app*` に更新する。

### 2.3 `src/main.lisp`

ロード時初期化ブロックを削除する（`*actions-app*` は `app.lisp` の `defvar`
で確定するため不要）。`use-reexport` により `*actions-app*` は
`ningle-actions` パッケージから自動的に再エクスポートされる。

変更前:
```lisp
(in-package #:ningle-actions)

;; Initialize the global actions app on load.
(unless *app*
  (make-actions-app))
```

変更後:
```lisp
(in-package #:ningle-actions)
```

> `in-package` 後に本体がなくなるが、`uiop:define-package` + `in-package` の
> 構成は維持する（パッケージは存在し続け、再エクスポートが働く）。

## 3. テストの変更

`make-actions-app` を非公開化するため、テストの import 元を切り替える。
`*app*` 参照を `*actions-app*` に置換する。副作用テストを削除する。

### 3.1 `tests/app.lisp`

- import: `ningle-actions` から取っていた `make-actions-app` / `*app*` を、
  `*actions-app*` は `ningle-actions` から、`make-actions-app` は
  `ningle-actions/app`（内部）から取得する。
- `make-actions-app` deftest の `(ok (eq app *app*))` という **副作用検証を削除**
  （AC5 でグローバル書き換えをやめたため）。「`actions-app` 型を返す」検証だけ残す。
- それ以外（`register-and-find` / `action-id-reuse` / `action-endpoint*`）は
  ローカル変数 `app` を使っており影響なし。

### 3.2 `tests/action.lisp`

- import: `make-actions-app` を `ningle-actions/app` から、`*actions-app*` を
  追加（`ningle-actions` から）。`*app*` 参照を削除。
- 各テストの `(let ((*app* (make-actions-app))) ...)` を
  `(let ((*actions-app* (make-actions-app))) ...)` に置換。
- `find-action *app* ...` を `find-action *actions-app* ...` に置換。

### 3.3 `tests/main.lisp`

- import: 同上（`make-actions-app` は内部、`*actions-app*` は公開）。
- `with-mounted` マクロ内の `(:mount "/actions" *app*)` を `*actions-app*` に置換。
- 各テストの `(let ((*app* (make-actions-app))) ...)` を `*actions-app*` に置換。

## 4. データ構造の変更

なし。`action` 構造体・`actions-app` クラス（`registry` / `name-index`）・
ディスパッチは不変。変更はシンボル名と「シングルトンの確定方法」に閉じる。

## 5. 影響範囲の分析

### コード
- `src/app.lisp`: `:export` 変更、`make-actions-app` の副作用除去、`*app*` を
  `*actions-app*` にリネームしシングルトン初期化、定義順の移動。
- `src/action.lisp`: import・登録先・docstring を `*actions-app*` 化。
- `src/main.lisp`: 初期化ブロック削除。

### テスト
- import 切り替え、`*app*`→`*actions-app*` 置換、副作用検証テスト 1 件削除。
- 機能的な期待値（404/405/正常/URL）は不変、全てグリーン維持。

### 永続的ドキュメント（`docs/`）
命名と提供方法は基本設計に属するため、以下を更新する。
- `docs/functional-design.md`: §1 方針・構成図・§4（`*app*`/`make-actions-app`
  の説明）・§5 利用例・公開 API 表を `*actions-app*` 直接提供に書き換え。
- `docs/product-requirements.md`: F4 / AC1 / FR / NFR3 の `*app*` 記述を
  `*actions-app*` に更新。
- `docs/architecture.md`: パッケージ構成図・`*app*` 保持の記述・mount 例・
  テスト隔離（`make-actions-app` 内部化）の記述を更新。
- `docs/repository-structure.md`: `app.lisp` / `main.lisp` の責務・公開シンボル
  欄を更新（`make-actions-app` は内部、`*actions-app*` 公開、main の初期化記述削除）。
- `docs/development-guidelines.md`: 公開シンボル列挙・特殊変数の例・テスト隔離の
  記述を `*actions-app*` / 内部 `make-actions-app` に更新。
- `docs/glossary.md`: 「アクションアプリ」「グローバルアプリ」行を `*actions-app*`
  に更新。
- `README.md`: Usage（make-actions-app を呼ばずシングルトンを mount）・API 表を更新。

### バージョン
- `ningle-actions.asd`: `:version "0.2.0"` → `"0.3.0"`（破壊的変更）。

### 後方互換性
- 破壊的。`*app*` 参照・`make-actions-app` の公開利用は動かなくなる。
  pre-1.0 のため許容。移行は「`*app*` → `*actions-app*`、`make-actions-app`
  呼び出しの削除」で完了する。
