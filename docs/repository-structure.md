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
│   └── core.lisp               # ningle-actions/core
│
└── tests/                      # テスト (rove)
    ├── core.lisp               # ningle-actions-test/core (単体)
    └── integration.lisp        # ningle-actions-test/integration (統合)
```

---

## 2. `src/` の役割とファイル配置ルール

`:package-inferred-system` を採用するため、**ファイルパスとパッケージ名を 1:1 対応**させる。
ファイル `src/foo.lisp` のパッケージは `ningle-actions/foo`、依存は `define-package` の `:use` / `:import-from` で宣言する（ASDF が依存を推論する）。

| ファイル | パッケージ | 役割 | 主な公開シンボル |
|----------|-----------|------|------------------|
| `src/core.lisp` | `ningle-actions/core` | `actions-app` クラス（`ningle:app` 継承）、`registry` / `name-index`、`*actions-app*` シングルトン、`*actions-middleware*`、`make-actions-app`（内部・純粋コンストラクタ）、`register-action` / `find-action` / `dispatch-action` / `action-endpoint`（内部）、定数 `+actions-prefix+`、`defaction` マクロ | `defaction` `actions-app` `*actions-app*` `*actions-middleware*`（`make-actions-app` / `action-endpoint` は内部） |
| `src/main.lisp` | `ningle-actions`（nick: `ningle-actions/main`） | 公開 API の集約・再エクスポート | （再エクスポートのみ） |

### 依存方向（循環禁止）
```
main ──▶ core
```
- `core` は最下層（他の自モジュールに依存しない）。`actions-app`・dispatch・`defaction` を 1 パッケージにまとめる。
- `main` は `core` を `use-reexport` で集約。

---

## 3. パッケージ命名規約

- 内部パッケージ: `ningle-actions/<file>`（パス対応・package-inferred-system 必須）。
- 公開窓口パッケージ: `ningle-actions`（`src/main.lisp` の primary、nickname に `ningle-actions/main`）。
- 利用者は `ningle-actions`（または短縮ニックを各自定義）から `defaction` / `make-actions-app` 等を参照する。

### main.lisp の集約方針
- `uiop:define-package` の `:use-reexport` で `ningle-actions/core` の公開シンボルをまとめて再エクスポートする。
- 既存スケルトン（`:use #:cl` のみ）はこの方針に置き換える。

---

## 4. `tests/` の役割とファイル配置ルール

- `:package-inferred-system`。ファイル `tests/foo.lisp` のパッケージは `ningle-actions-test/foo`。
- 単体テストは対象モジュールに対応させる（`tests/core.lisp` ↔ `src/core.lisp`）。統合テストは `tests/integration.lisp` に独立して置く。
- HTTP レベルの検証は `lack/test`（`clack.test` 相当）やリクエスト生成ユーティリティ、または `ningle` の `to-app` + テスト用 env を用いる。
- `ningle-actions-test.asd` の `test-op` から `rove:run` する。

| ファイル | 検証対象 |
|----------|----------|
| `tests/core.lisp` | `make-actions-app` / レジストリ登録・検索 / `action-endpoint` / `action_id` 再利用 / `defaction` 展開（登録 + エンドポイント関数定義）/ `params` 受領 / メソッド指定 |
| `tests/integration.lisp` | `*actions-app*` を `lack:builder` でマウントした統合動作（正常・404・405・prefix 不一致時の passthrough） |

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
