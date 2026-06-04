# 初回実装 要求内容 (Requirements)

作業ディレクトリ: `.steering/20260605-initial-implementation/`
対象: `ningle-actions` の MVP（コアアクション機構）初回実装。

---

## 1. 今回の作業の目的

永続的ドキュメント（`docs/`）で定義した設計に基づき、`ningle-actions` の **MVP（F1〜F5）** を実装し、`rove` テストでグリーンにする。

参照:
- スコープ・受け入れ条件: [docs/product-requirements.md](../../docs/product-requirements.md)
- 詳細設計・API: [docs/functional-design.md](../../docs/functional-design.md)
- 構成: [docs/repository-structure.md](../../docs/repository-structure.md)

---

## 2. 実装する機能（今回のスコープ）

| ID | 機能 | 内容 |
|----|------|------|
| F1 | `defaction` マクロ | `(defaction NAME METHOD (PARAMS) &body BODY)`。本体クロージャ生成 → 登録 → エンドポイント関数定義 |
| F2 | 登録・ディスパッチ | レジストリ登録、単一ルート `/:action_id`、`action_id` 検索、404/405 |
| F3 | エンドポイント関数生成 | `NAME` と同名関数が `"/actions/<id>"` を返す。再定義で `action_id` 再利用 |
| F4 | グローバルアプリ `*app*` | ライブラリ保持の現在アプリ。`make-action-app` が設定 |
| F5 | マウント可能インスタンス | `actions-app`（`ningle:app` 派生）。`(:mount "/actions" *app*)` で統合可能 |

### 提供する公開シンボル（`ningle-actions`）
- `defaction`（マクロ）
- `make-action-app`（関数, 引数なし）
- `*app*`（変数）
- `actions-app`（クラス）

> `action-endpoint`（`(id)` → URL）は **内部ヘルパ**とし公開しない。`action_id` は不透明な内部値で利用者は保持しないため、URL は `defaction` が定義する同名関数経由でのみ取得する。

---

## 3. スコープ外（今回やらないこと）

- レスポンス整形・content-type 付与（ningle の `process-response` に委譲）。
- 型強制・引数バリデーション（`params` をそのまま渡す）。
- htmx ヘルパ（`HX-*` は利用者が `*response*` で設定）。
- mount 配線（利用者が `lack:builder` で行う）。
- アクション一覧 API・クライアント呼び出し補助。

---

## 4. ユーザーストーリー（今回分）

- 開発者として `(defaction like :post (params) ...)` でアクションを定義したい。→ ハンドラ登録 + `(like)` で URL 取得。
- 開発者として、未知の URL やメソッド不一致に対して 404 / 405 が返ってほしい。
- 開発者として、アクションアプリを `(:mount "/actions" *app*)` で本体に組み込みたい。
- 開発者として、アクション本体で ningle と同じ `params` を扱いたい。

---

## 5. 受け入れ条件（テストで担保）

- **AC-1**: `defaction` を評価すると、(a) レジストリに登録され、(b) 同名のエンドポイント関数が定義される。
- **AC-2**: エンドポイント関数の戻り値は `"/actions/<action_id>"` 形式。`action_id` はランダム。
- **AC-3**: 同名アクションを再定義しても、エンドポイント関数の戻り値（`action_id`）が変わらない。
- **AC-4**: マウント済みアプリへ正しい URL・メソッドで POST すると、対応アクション本体が実行され、その戻り値が ningle 経由でレスポンスになる。
- **AC-5**: 未登録 `action_id` へのリクエストは 404。
- **AC-6**: 登録済みだがメソッド不一致のリクエストは 405。
- **AC-7**: アクション本体が `params`（ningle と同形の alist）を受け取り、値を取得できる。
- **AC-8**: `rove` のテストスイートがグリーン。

---

## 6. 制約事項

- 依存は **ningle / lack** のみ（[docs/architecture.md](../../docs/architecture.md)）。`request-method` は `lack/request` から、`action_id` 生成は `lack/util:generate-random-id` を用いる。
- ningle / lack の **公開 API** 越しにのみ統合する。
- `:package-inferred-system` 構成（`src/app.lisp` / `src/action.lisp` / `src/main.lisp`）。
- グローバル `*app*` はテストで隔離可能であること。
- SBCL でコンパイル警告を出さないこと。
