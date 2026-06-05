# タスクリスト: エンドポイント関数のクエリパラメータ対応

## 実装

- [x] T1. `src/app.lisp`: パッケージ定義に依存 import を追加
  - `:import-from #:quri #:make-uri #:render-uri`
  - `:import-from #:alexandria #:plist-alist`
- [x] T2. `src/app.lisp`: `query-params-alist` 内部関数を追加
  - `plist-alist` で構造変換し、キー＝小文字文字列・値＝`princ-to-string` に正規化
- [x] T3. `src/app.lisp`: `action-endpoint` を `(id &optional query)` に変更
  - クエリありは `make-uri`+`render-uri`、なしは従来の `/actions/<id>`
- [x] T4. `src/action.lisp`: `defaction` 生成関数を `(&rest query)` 化し
  `(action-endpoint ,id query)` を呼ぶ。マクロ docstring にクエリ付加を追記

## テスト

- [x] T5. `tests/app.lisp`: `action-endpoint` のクエリ対応テストを追加
  - クエリなし → `/actions/<id>`
  - 単一クエリ → `?category=foo`
  - 複数クエリ → `?category=foo&page=2`（順序保持）
  - エンコード → スペース・記号・マルチバイトが正しくエンコードされる
  - 非文字列値（数値など）の文字列化
- [x] T6. `tests/action.lisp`: 生成関数がキーワード引数でクエリ付き URL を
  返すことの振る舞いテストを追加（引数なしの後方互換も確認）

## ドキュメント更新（永続的ドキュメント）

- [x] T7. `docs/functional-design.md`: §4.1（`action-endpoint`）・§4.2・§5.1
  （`defaction` 展開・利用例・エンドポイント関数の説明）を更新
- [x] T8. `docs/product-requirements.md`: F3 / FR1 にクエリ付加を追記
- [x] T9. `docs/glossary.md`: 「エンドポイント関数」定義にクエリ付加を追記
- [x] T10. `docs/architecture.md`: 依存に `quri` / `alexandria` を追記
- [x] T11. `README.md`: エンドポイント関数のクエリ引数の使い方を追記

## 品質チェック

- [x] T12. `qlot exec rove ningle-actions-test.asd` がグリーン
- [x] T13. コンパイル警告（未使用変数・未定義関数等）の解消
- [x] T14. 公開シンボルの docstring 確認
- [x] T15. `qlfile` / `qlfile.lock` 更新済みの確認（quri / alexandria）

## 完了条件

- 受け入れ条件 AC1〜AC5（`requirements.md`）をすべて満たす。
- 既存テストを含め全テストがグリーン。
- 関連する永続的ドキュメントと README が更新済み。
