# 設計: エンドポイント関数のクエリパラメータ対応

## 1. 実装アプローチ

変更は 2 箇所のみ。**URL を組み立てる側**に閉じ、ディスパッチや `params`
受け取りには手を入れない。

1. `src/app.lisp`
   - `action-endpoint` を拡張し、オプションのクエリ用 plist を受け取る。
   - クエリ文字列の組み立てヘルパ `build-query-string` を追加（`quri` に委譲）。
2. `src/action.lisp`
   - `defaction` が生成する関数を、`&rest` でキーワード引数（plist）を受け取り、
     それを `action-endpoint` に渡す形に変更する。

依存: `quri` / `alexandria`（いずれも `qlfile` / `qlfile.lock` に追加済み）。
`ningle-actions/app` パッケージで `:import-from #:quri #:make-uri #:render-uri`
と `:import-from #:alexandria #:plist-alist` を取り込む。

URL の組み立ては自前の文字列連結ではなく **`quri:make-uri` で URI を構築し、
`quri:render-uri` で文字列化する**。`make-uri` は `:query` に cons（alist）を
渡すと内部で `quri:url-encode-params` を呼び URL エンコードする。

ただし `url-encode-params` は **キーが文字列**であること、値が
`(or string number simple-byte-vector)` であることを要求する（quri 実装で
確認済み）。キーワードキー・任意の値をそのまま渡せないため、plist→alist
変換時にキーを小文字文字列へ、値を文字列へ正規化する。

## 2. 変更するコンポーネント

### 2.1 `src/app.lisp`

#### `query-params-alist`（新規・内部関数）

plist→alist の構造変換は `alexandria:plist-alist`（引数順を保持）に委ね、
その各ペアのキーをキーワード名の小文字文字列に、値を `princ-to-string` で
文字列に正規化する（`make-uri` / `url-encode-params` の要求を満たすため）。

```lisp
(defun query-params-alist (plist)
  "Convert a plist of keyword/value pairs into an alist suitable for
quri:make-uri's :query. Keys become lowercased keyword-name strings;
values are coerced with princ-to-string. Order follows the plist."
  (mapcar (lambda (pair)
            (cons (string-downcase (symbol-name (car pair)))
                  (princ-to-string (cdr pair))))
          (plist-alist plist)))
```

#### `action-endpoint`（変更）

オプション引数 `query`（plist）を受け取る。`quri:make-uri` で `:path` に
`/actions/<id>` を、クエリがあれば `:query` に alist を渡して URI を構築し、
`quri:render-uri` で文字列化する。クエリなし時は従来と同一の
`/actions/<id>` を返す（後方互換）。

```lisp
(defun action-endpoint (id &optional query)
  "Build the full endpoint URL string (/actions/<id>) from an action_id,
assembled with quri:make-uri. If QUERY (a plist of keyword/value pairs) is
non-nil, it is appended as a URL-encoded query string."
  (let ((path (concatenate 'string +action-prefix+ "/" id)))
    (if query
        (render-uri (make-uri :path path :query (query-params-alist query)))
        path)))
```

export 追加は不要（`action-endpoint` は引き続き内部ヘルパ、非公開）。

### 2.2 `src/action.lisp`

`defun` 生成部のみ変更。`&rest` で plist を受け取り `action-endpoint` へ渡す。

変更前:
```lisp
(defun ,name ()
  (action-endpoint ,id))
```

変更後:
```lisp
(defun ,name (&rest query)
  (action-endpoint ,id query))
```

docstring（マクロ）も「キーワード引数でクエリパラメータを付加できる」旨を追記。

## 3. 展開イメージ（変更後）

```lisp
(progn
  (let ((#1=#:id (register-action *app* 'list-items :get
                                  (lambda (params)
                                    (declare (ignorable params))
                                    ...))))
    (defun list-items (&rest query)
      (action-endpoint #1# query))))
```

呼び出し:
```lisp
(list-items)                          ;=> "/actions/xxxxxxxx"
(list-items :category "foo")          ;=> "/actions/xxxxxxxx?category=foo"
(list-items :category "foo" :page 2)  ;=> "/actions/xxxxxxxx?category=foo&page=2"
(list-items :q "a b&c")               ;=> "/actions/xxxxxxxx?q=a%20b%26c"
```

## 4. データ構造の変更

なし。`action` 構造体・レジストリ・ディスパッチは不変。クエリは
エンドポイント関数呼び出し時にのみ組み立てられ、サーバー側には ningle が
通常どおりパースした `params`（alist）として届く。

## 5. 影響範囲の分析

### コード
- `src/app.lisp`: `action-endpoint` シグネチャ変更（オプション引数追加のため
  既存の `(action-endpoint id)` 呼び出しは無変更で動作）、`query-params-alist`
  追加、`quri`（`make-uri` / `render-uri`）・`alexandria`（`plist-alist`）import。
- `src/action.lisp`: 生成関数のラムダリスト変更、docstring 追記。
- `src/main.lisp`: 変更なし。

### テスト
- 既存テストは後方互換のため全てグリーンのまま（引数なし呼び出し）。
- 追加テスト（`tests/app.lisp` または `tests/action.lisp`）:
  - クエリなし → `/actions/<id>`。
  - 単一クエリ → `?category=foo`。
  - 複数クエリ → `?category=foo&page=2`（順序保持）。
  - エンコード → スペース・記号・マルチバイトが正しくエンコードされる。
  - 数値など非文字列値の文字列化。

### 永続的ドキュメント（`docs/`）
基本設計（エンドポイント関数の役割）が拡張されるため、以下を更新:
- `docs/functional-design.md`: §4.2 / §5.1（`defaction` 展開・利用例・
  エンドポイント関数の説明）、§4.1 の `action-endpoint` 記述。
- `docs/product-requirements.md`: F3 / FR1（エンドポイント関数の説明に
  クエリ付加を追記）。
- `docs/glossary.md`: 「エンドポイント関数」の定義にクエリ付加を追記。
- `docs/architecture.md`: 依存に `quri` / `alexandria` を追記（必要に応じて）。
- `README.md`: エンドポイント関数のクエリ引数の使い方を追記。

### 後方互換性
- 完全互換。既存の `(action-name)` 呼び出し・既存テストは挙動不変。
