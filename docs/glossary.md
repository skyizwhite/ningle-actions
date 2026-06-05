# ユビキタス言語定義 (Glossary)

本書は `ningle-actions` のドメイン用語・ビジネス用語・UI/UX 用語を定義し、英語・日本語・コード上の命名を対応づける。
本書を用語の正典とし、ドキュメント・コード・コミットメッセージで一貫して用いる。

---

## 1. コア用語（ドメイン）

| 用語（日本語） | 用語（英語） | コード上の名称 | 定義 |
|----------------|--------------|----------------|------|
| アクション | Action | `action`（レコード/概念） | サーバー上で実行される処理の単位。HTTP メソッド・本体・`action_id` を持ち、レジストリに登録される。Next.js の Server Action に相当。 |
| アクション ID | Action ID | `action_id`（URL）/ `id` | 各アクションを一意に識別するランダムな不透明トークン。URL の 1 セグメントとして使われる。 |
| アクションアプリ | Actions App | `actions-app` / `*actions-app*` | アクションを登録・ディスパッチする `ningle:app` 派生インスタンス。レジストリと name-index を持つ。 |
| シングルトンアプリ | Singleton app | `*actions-app*` | ライブラリがロード時に提供するシングルトンのアクションアプリを指す特殊変数。`defaction` の暗黙の登録先であり、利用者はこれをそのまま mount する。 |
| レジストリ | Registry | `registry` | `action_id` → アクション のハッシュテーブル。 |
| ネームインデックス | Name index | `name-index` | アクション名（シンボル）→ `action_id` の対応表。再定義時に `action_id` を再利用するために用いる。 |
| エンドポイント | Endpoint | `endpoint` | アクションを呼び出すための URL。`/actions/<action_id>`。 |
| エンドポイント関数 | Endpoint function | （アクション名と同名の関数） | `defaction` が定義する、エンドポイント URL 文字列を返す関数。利用者はこれ経由で URL を参照する。キーワード引数を渡すと、そのキー・値がクエリパラメータとして URL に付加される。 |
| クエリパラメータ | Query parameter | （エンドポイント関数のキーワード引数） | エンドポイント関数に渡すキーワード引数。キーは小文字化した名前、値は文字列化され、URL エンコードして `?key=value` 形式で URL に付加される。 |
| ディスパッチ | Dispatch | `dispatch-action` | 単一ルート `/:action_id` に届いたリクエストを、`action_id` でレジストリを引いて対応ハンドラへ振り分ける処理。 |
| ハンドラ | Handler | `handler` | アクション本体を包む、`params` を受け取るクロージャ。 |
| 接頭辞 | Prefix | `+actions-prefix+` | アクションアプリのマウント位置。固定値 `"/actions"`。 |
| パラメータ | Params | `params` | ningle がハンドラに渡すリクエストパラメータの alist。本ライブラリは加工せずそのまま渡す。 |

---

## 2. フレームワーク・統合用語

| 用語（日本語） | 用語（英語） | コード上の名称 | 定義 |
|----------------|--------------|----------------|------|
| マウント | Mount | `:mount`（Lack builder） | アクションアプリを本体アプリの接頭辞配下に組み込む Lack ミドルウェア。配線は利用者責務（スコープ外）。 |
| 本体アプリ | Main app / Host app | （利用者の `ningle:app`） | アクションアプリをマウントする側の Web アプリケーション。 |
| ルート | Route | `(setf ningle:route)` | ningle のルーティング登録機構。アクションアプリは `/:action_id` の 1 本のみ登録する。 |
| パスパラメータ | Path parameter | `:action_id` | URL パス中の動的セグメント。`(cdr (assoc :action_id params))` で取得（キーワードキー）。 |
| コンテキスト | Context | `ningle:*context*` 他 | リクエスト処理中に束縛される ningle の特殊変数群（`*request*` / `*response*` / `*session*` / `*context*`）。 |
| プロセスレスポンス | process-response | `ningle:process-response` | ningle が controller の戻り値（文字列 / Clack リスト）をレスポンス化する処理。整形はこれに委譲する。 |

---

## 3. クライアント・UI/UX 用語

| 用語（日本語） | 用語（英語） | コード上の名称 | 定義 |
|----------------|--------------|----------------|------|
| ハイパーメディア駆動 | Hypermedia-driven | — | サーバーが返す HTML（とヘッダ）で UI 遷移・更新を駆動する設計。htmx が代表。 |
| htmx | htmx | — | `hx-get` / `hx-post` 等の属性でサーバーを呼び、返ってきた HTML フラグメントで DOM を更新するライブラリ。本ライブラリの想定呼び出しモデル。 |
| HTML フラグメント | HTML fragment | — | ページ全体ではなく、差し替え対象の部分 HTML。アクションの典型的な戻り値。 |
| HX-* ヘッダ | HX-* headers | （`*response*` 経由） | htmx がクライアント挙動を制御するために解釈するレスポンスヘッダ（`HX-Trigger` 等）。設定は利用者責務。 |
| 漸進的強化 | Progressive enhancement | — | JS なしのフォーム送信でも動作し、htmx 等で体験を上積みする考え方。 |

---

## 4. HTTP・メソッド用語

| 用語（日本語） | 用語（英語） | コード上の名称 | 定義 |
|----------------|--------------|----------------|------|
| HTTP メソッド | HTTP method | `method`（`:get` 等） | アクションが受け付けるメソッド。既定 `:post`。実リクエストと不一致なら 405。 |
| メソッド照合 | Method matching | `request-method` | 実リクエストのメソッド（`lack/request:request-method`）とアクションの宣言メソッドを照合する処理。 |
| 未登録 | Not found (404) | — | `action_id` がレジストリに無い状態。404 を返す。 |
| メソッド不許可 | Method not allowed (405) | — | `action_id` は存在するがメソッドが一致しない状態。405 を返す。 |

---

## 5. 開発・配布用語

| 用語（日本語） | 用語（英語） | コード上の名称 | 定義 |
|----------------|--------------|----------------|------|
| パッケージ推論システム | Package-inferred-system | `:package-inferred-system` | ファイルパスとパッケージ名を 1:1 対応させる ASDF のシステム種別。本プロジェクトの構成方式。 |
| ステアリング | Steering | `.steering/` | 作業単位の一時ドキュメント群（requirements / design / tasklist）。 |
| ロックファイル | Lockfile | `qlfile.lock` | qlot による依存バージョンの固定。 |

---

## 6. 命名対応の原則

- ドメイン用語はコードでも同じ語を使う（例: 「アクション」=`action`、「エンドポイント」=`endpoint`）。新しい同義語を増やさない。
- 利用者が `defaction` で付ける**アクション名 = エンドポイント関数名**であり、動詞句のケバブケースを推奨する（`like` / `add-todo` / `delete-comment`）。
- 「アクションアプリ」と「本体アプリ」を明確に区別する。前者は `ningle-actions` が提供する `actions-app`、後者は利用者の `ningle:app`。
- 「レスポンス整形」「型強制」「バリデーション」「htmx ヘルパ」は **本ライブラリのスコープ外/将来機能** を指す語であり、MVP の説明では「対象外」と明示する。
