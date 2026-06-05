# 開発ガイドライン (Development Guidelines)

本書は `ningle-actions` のコーディング規約・命名規則・テスト規約・Git 規約を定義する。
対象は Common Lisp（主に SBCL）。前提構成は [repository-structure.md](./repository-structure.md)。

---

## 1. コーディング規約

### 1.1 基本方針
- **薄さを最優先**（NFR1）。マクロは展開結果が読めるシンプルさを保ち、賢さより明快さを採る。
- ningle / lack の **公開 API のみ**を使う。内部シンボルへの依存を避ける（やむを得ない場合はコメントで明記）。
- 副作用のある処理（ルート登録など）は関数として切り出し、マクロ本体は薄く保つ。シングルトン `*actions-app*` の生成（`make-actions-app`）は副作用を持たない純粋コンストラクタとする。

### 1.2 整形・スタイル
- インデントは標準の Lisp インデント（SLIME/Sly 既定）に従う。タブは使わずスペース。
- 1 行は概ね 100 桁以内を目安にする。
- 閉じ括弧は最終行末にまとめる（行頭に単独で置かない）。
- トップレベルフォーム間は 1 行空ける。

### 1.3 パッケージ定義
- `uiop:define-package` を用いる（package-inferred-system 前提）。
- `:use` は最小限（`#:cl` と必要なもの）。外部シンボルは原則 `:import-from` で個別に取り込む。
- 再エクスポートは `:use-reexport` / `:export` を `main.lisp` に集約する。
- パッケージ名はファイルパスに一致させる（`src/core.lisp` → `ningle-actions/core`）。

### 1.4 マクロ
- `defaction` 等のマクロは、生成コードを別関数（`register-action` 等）へ委譲し、展開を小さく保つ。
- マクロ引数は分割代入時に `&body` を本体に使い、エディタのインデントが効くようにする。
- 変数捕捉を避けるため、展開内で導入する一時変数は `gensym`（または `with-gensyms` 相当）で作る。
- マクロは必ず「期待する展開形」をテストするか、振る舞いテストで間接的に保証する。

### 1.5 エラーハンドリング
- ライブラリが定義・送出する状況（未登録 id・メソッド不一致＝404）は `*response*` に status を設定し空 body を返す。例外を濫用しない。
- アクション本体内のアプリ固有エラーは握りつぶさず上位（ningle / Lack）へ伝播させる（[functional-design.md](./functional-design.md) §6）。
- 入力検証は利用者責務。ライブラリ側で暗黙の検証・変換を行わない。

### 1.6 ドキュメンテーション
- 公開シンボル（`defaction` / `actions-app` / `*actions-app*`）と主要な内部関数（`make-actions-app` / `action-endpoint` / `dispatch-action`）には docstring を付ける。
- docstring は「何をするか・引数・戻り値・副作用」を簡潔に。日本語可（プロジェクト言語に合わせる）。
- 非自明な実装判断にはインラインコメントで「なぜ」を残す（「何を」はコードで表現）。

---

## 2. 命名規則

CL の慣習に従う。詳細な用語対応は [glossary.md](./glossary.md) を正とする。

| 種別 | 規約 | 例 |
|------|------|----|
| 関数・変数 | ケバブケース（小文字 + `-`） | `make-actions-app` `dispatch-action` |
| 特殊変数 | `*earmuffs*` | `*actions-app*` |
| 定数 | `+plus-signs+` | `+actions-prefix+` |
| クラス | 通常はケバブケース | `actions-app` |
| 述語 | `-p` / `?` は付けず CL 慣習の `-p` | `action-exists-p` |
| マクロ | 関数と同様。定義系は `def-` 接頭辞可 | `defaction` |
| パッケージ | `ningle-actions/<file>` | `ningle-actions/core` |

- 真偽値を返す述語は `-p` を付ける（例 `method-allowed-p`）。
- アクセサは対象名をそのまま（`action-handler` `action-method`）。
- 利用者が `defaction` で付ける**アクション名は、そのまま関数名になる**ため、関数命名規約に従う（ケバブケース、動詞句推奨: `like` `add-todo` `delete-comment`）。

---

## 3. スタイリング規約（ビュー）

- 本ライブラリは HTML を生成しない（ビュー層非依存）。アクションが返す HTML 文字列の生成手段（文字列・Spinneret・cl-who 等）は利用者の自由。
- README / サンプルでは特定ライブラリに固定しないが、例示時は最小限の文字列または Spinneret を用い、依存を増やさない。
- 共通デザインシステム（Tailwind 等）の話題はサンプル内に限定し、ライブラリ本体には持ち込まない。

---

## 4. テスト規約

### 4.1 フレームワーク・実行
- `rove` を使用。`tests/` 配下に対象モジュール対応で配置（[repository-structure.md](./repository-structure.md) §4）。
- 実行: `qlot exec rove ningle-actions-test.asd` または `(asdf:test-system :ningle-actions)`。
- コミット前にローカルでグリーンを確認する。

### 4.2 カバレッジ方針
- コア機構（F1〜F5）の主要パスを必ずカバーする:
  - `defaction` がレジストリ登録とエンドポイント関数定義の両方を行う。
  - `dispatch-action`: 正常呼び出し / 未登録 id → 404 / メソッド不一致 → 404。
  - `action-endpoint` が `/actions/<id>` を返す。再定義で `action_id` が再利用され URL が安定する。
  - `params` が ningle と同じ形でアクション本体へ渡る。
- HTTP レベル検証（`tests/integration.lisp`）は `*actions-middleware*` を `lack:builder` に組み込んだ統合アプリへテスト用 env を流して行う（正常・404（未登録 id・メソッド不一致）・prefix 不一致時の passthrough）。

### 4.3 テストの隔離
- シングルトン `*actions-app*` に依存するテストは、内部 `make-actions-app`（`ningle-actions/core` から参照）で生成した隔離インスタンスへ `let` 再束縛してテストごとに隔離する（NFR3）。副作用がテスト間に漏れないこと。

### 4.4 テストの書き方
- 1 テストは 1 つの振る舞いを検証する。`testing` でグルーピングし、`ok` / `is` で表明する。
- ランダム `action_id` に依存した固定値アサートは避け、「エンドポイント関数の戻り値」を介して検証する。

---

## 5. Git 規約

### 5.1 ブランチ
- `main` を保護ブランチとする。作業は `feature/<topic>` `fix/<topic>` `docs/<topic>` 等から派生。
- 1 ブランチ 1 関心事。ステアリングディレクトリ（`.steering/[YYYYMMDD]-...`）と対応させると追跡しやすい。

### 5.2 コミットメッセージ
- 形式は Conventional Commits を推奨:
  - `feat:` 機能追加 / `fix:` バグ修正 / `docs:` ドキュメント / `test:` テスト / `refactor:` 整理 / `chore:` 雑務
  - 例: `feat(action): add defaction macro and endpoint function generation`
- 件名は命令形・72 桁以内。本文に「なぜ」を書く。

### 5.3 PR / レビュー
- PR には目的・変更点・テスト結果を記載。関連するステアリングや docs の更新を含める。
- マージ前に `rove` グリーン・リント/型警告の解消を確認する。

### 5.4 品質チェック（コミット前チェックリスト）
1. `qlot exec rove ...` がグリーン。
2. コンパイル警告（未使用変数・未定義関数等）を解消。
3. 公開 API に docstring がある。
4. 設計変更がある場合、該当する `docs/` を更新済み。
5. 依存追加時は `qlfile` / `qlfile.lock` を更新済み。

---

## 6. セキュリティ・品質の原則（再掲）

- `action_id` は推測困難なランダムトークンとする（列挙攻撃対策）。
- 入力検証・出力エスケープ（XSS 対策）は利用者責務だが、README で注意喚起する。
- ningle 公開 API 越しにのみ統合し、内部実装への依存を避ける（後方互換・移植性）。
