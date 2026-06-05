# リポジトリ構造定義書 (Repository Structure)

本書は `ningle-actions` のフォルダ・ファイル構成と配置ルールを定義する。
構成の根拠は [functional-design.md](./functional-design.md) §4 / [architecture.md](./architecture.md) §2。

---

## 1. ディレクトリ全体図

```
ningle-actions/
├── ningle-actions.asd          # メインシステム定義 (package-inferred-system)
├── ningle-actions-test.asd     # テストシステム定義
├── qlfile                      # 依存宣言 (ningle / lack / rove)
├── qlfile.lock                 # 依存ロック
├── README.md                   # 概要・インストール・最小サンプル
├── CLAUDE.md                   # プロジェクト標準ルール
├── .gitignore                  # /.qlot/ など
│
├── docs/                       # 永続的ドキュメント
│   ├── product-requirements.md
│   ├── functional-design.md
│   ├── architecture.md
│   ├── repository-structure.md
│   ├── development-guidelines.md
│   └── glossary.md
│
├── .steering/                  # 作業単位ドキュメント
│   └── [YYYYMMDD]-[開発タイトル]/
│       ├── requirements.md
│       ├── design.md
│       └── tasklist.md
│
├── src/                        # 実装 (1 ファイル = 1 パッケージ)
│   ├── main.lisp               # ningle-actions / ningle-actions/main
│   ├── app.lisp                # ningle-actions/app
│   └── action.lisp             # ningle-actions/action
│
└── tests/                      # テスト (rove)
    ├── main.lisp               # ningle-actions-test / ningle-actions-test/main
    ├── app.lisp                # ningle-actions-test/app
    └── action.lisp             # ningle-actions-test/action
```

---

## 2. `src/` の役割とファイル配置ルール

`:package-inferred-system` を採用するため、**ファイルパスとパッケージ名を 1:1 対応**させる。
ファイル `src/foo.lisp` のパッケージは `ningle-actions/foo`、依存は `define-package` の `:use` / `:import-from` で宣言する（ASDF が依存を推論する）。

| ファイル | パッケージ | 役割 | 主な公開シンボル |
|----------|-----------|------|------------------|
| `src/app.lisp` | `ningle-actions/app` | `actions-app` クラス（`ningle:app` 継承）、`registry` / `name-index`、`*app*`、`make-actions-app`、`register-action` / `find-action` / `dispatch-action` / `action-endpoint`（内部）、定数 `+actions-prefix+` | `actions-app` `*app*` `make-actions-app`（`action-endpoint` は内部） |
| `src/action.lisp` | `ningle-actions/action` | `defaction` マクロ。本体クロージャ生成 → `register-action` 登録 → エンドポイント関数 `defun` | `defaction` |
| `src/main.lisp` | `ningle-actions`（nick: `ningle-actions/main`） | 公開 API の集約・再エクスポート。ロード時の `*app*` 初期化 | （再エクスポートのみ） |

### 依存方向（循環禁止）
```
main ──▶ action ──▶ app
   └───────────────▶ app
```
- `app` は最下層（他の自モジュールに依存しない）。
- `action` は `app` のみに依存。
- `main` は両者を `use-reexport` で集約。

---

## 3. パッケージ命名規約

- 内部パッケージ: `ningle-actions/<file>`（パス対応・package-inferred-system 必須）。
- 公開窓口パッケージ: `ningle-actions`（`src/main.lisp` の primary、nickname に `ningle-actions/main`）。
- 利用者は `ningle-actions`（または短縮ニックを各自定義）から `defaction` / `make-actions-app` 等を参照する。

### main.lisp の集約方針
- `uiop:define-package` の `:use-reexport` で `ningle-actions/app` と `ningle-actions/action` の公開シンボルをまとめて再エクスポートする。
- 既存スケルトン（`:use #:cl` のみ）はこの方針に置き換える。

---

## 4. `tests/` の役割とファイル配置ルール

- `:package-inferred-system`。ファイル `tests/foo.lisp` のパッケージは `ningle-actions-test/foo`。
- テストは対象モジュールに対応させる（`tests/app.lisp` ↔ `src/app.lisp`）。
- HTTP レベルの検証は `lack/test`（`clack.test` 相当）やリクエスト生成ユーティリティ、または `ningle` の `to-app` + テスト用 env を用いる。
- `tests/main.lisp` をテスト集約点とし、`ningle-actions-test.asd` の `test-op` から `rove:run` する。

| ファイル | 検証対象 |
|----------|----------|
| `tests/app.lisp` | `make-actions-app` / レジストリ登録・検索 / `dispatch-action`（404・405・正常）/ `action-endpoint` / `action_id` 再利用 |
| `tests/action.lisp` | `defaction` 展開（登録 + エンドポイント関数定義）/ `params` 受領 / メソッド指定 |
| `tests/main.lisp` | 公開 API の統合的な動作・集約 |

---

## 5. ルート直下ファイルの役割

| ファイル | 役割 | 編集頻度 |
|----------|------|----------|
| `ningle-actions.asd` | メインシステム。`:depends-on ("ningle-actions/main")` | 低 |
| `ningle-actions-test.asd` | テストシステム。`rove` 依存、`test-op` | 低 |
| `qlfile` / `qlfile.lock` | 依存宣言・ロック | 依存変更時 |
| `README.md` | 概要・最小サンプル（htmx + mount）・API 早見 | 機能変更時 |

---

## 6. 配置ルール（まとめ）

1. **実装は `src/`、テストは `tests/`**。パッケージ名はファイルパスに一致させる（package-inferred-system）。
2. **新しい関心事は新ファイル＝新パッケージ**として追加し、`main.lisp` で再エクスポートする（巨大な単一ファイルを避ける）。
3. **依存は下位（`app`）へ一方向**。循環を作らない。
4. **将来機能（型強制・htmx ヘルパ等）は別ファイル／別システム**として切り出す前提で、コアを汚さない（例: `ningle-actions-htmx`）。
5. 図表・ダイアグラムは独立フォルダを作らず、関連ドキュメント内に Mermaid で記載する（CLAUDE.md 準拠）。
