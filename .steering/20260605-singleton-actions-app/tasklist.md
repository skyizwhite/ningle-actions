# タスクリスト: シングルトンのアクションアプリを直接提供する

## 実装

- [x] T1. `src/app.lisp`: パッケージ定義の `:export` を更新
  - `*app*` / `make-actions-app` を除外し、`*actions-app*` を追加
  - `actions-app` は公開のまま維持
- [x] T2. `src/app.lisp`: `make-actions-app` を純粋コンストラクタ化
  - `setf *app*`（グローバル書き換え）を削除し、生成インスタンスを返すだけにする
  - docstring を「内部コンストラクタ／公開は *actions-app*」に更新
- [x] T3. `src/app.lisp`: `*app*` を `*actions-app*` にリネーム＆シングルトン化
  - `(defvar *actions-app* (make-actions-app) "...")` に変更
  - 定義位置を `make-actions-app` 定義の後ろ（ファイル末尾）へ移動（前方参照解消）
- [x] T4. `src/action.lisp`: 登録先を `*actions-app*` に切替
  - `:import-from #:ningle-actions/app` を `*app*` → `*actions-app*` に
  - `register-action *actions-app* ...` に変更
  - マクロ docstring の `*app*` 記述を `*actions-app*` に更新
- [x] T5. `src/main.lisp`: ロード時初期化ブロックを削除

## テスト

- [x] T6. `tests/app.lisp`: import 切替＋副作用検証削除
  - `make-actions-app` を `ningle-actions/app` から import、`*actions-app*` を公開から
  - `make-actions-app` deftest の `(ok (eq app *app*))` を削除（型検証のみ残す）
- [x] T7. `tests/action.lisp`: `*app*` → `*actions-app*` 置換
  - import 切替、`(let ((*actions-app* (make-actions-app))) ...)`、`find-action *actions-app*`
- [x] T8. `tests/main.lisp`: `*app*` → `*actions-app*` 置換
  - import 切替、`with-mounted` の `(:mount "/actions" *actions-app*)`、各 `let` 束縛

## ドキュメント更新（永続的ドキュメント）

- [x] T9. `docs/functional-design.md`: 方針・構成図・§4/§5・公開 API 表を `*actions-app*` 直接提供へ
- [x] T10. `docs/product-requirements.md`: F4 / AC1 / FR / NFR3 の `*app*` 記述を更新
- [x] T11. `docs/architecture.md`: パッケージ構成図・保持記述・mount 例・テスト隔離を更新
- [x] T12. `docs/repository-structure.md`: `app.lisp`/`main.lisp` の責務・公開シンボル欄を更新
- [x] T13. `docs/development-guidelines.md`: 公開シンボル列挙・特殊変数例・テスト隔離記述を更新
- [x] T14. `docs/glossary.md`: 「アクションアプリ」「グローバルアプリ」行を `*actions-app*` に更新
- [x] T15. `README.md`: Usage（シングルトンを mount）・API 表を更新

## バージョン

- [x] T16. `ningle-actions.asd`: `:version "0.2.0"` → `"0.3.0"`

## 品質チェック

- [x] T17. `qlot exec rove ningle-actions-test.asd` がグリーン
- [x] T18. コンパイル警告（未使用・未定義・未エクスポート参照）の解消
- [x] T19. 公開シンボル（`defaction` / `actions-app` / `*actions-app*` / `action-endpoint`）の docstring 確認
- [x] T20. `*app*` / 公開 `make-actions-app` への残存参照がないこと（grep 確認）

## 完了条件

- 受け入れ条件 AC1〜AC7（`requirements.md`）をすべて満たす。
- 既存テストを含め全テストがグリーン。
- 関連する永続的ドキュメントと README が更新済み。
- リポジトリ全体に `*app*` への参照が残っていない。
