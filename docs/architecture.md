# 技術仕様書 (Architecture)

本書は `ningle-actions` のテクノロジースタック・開発ツール・技術的制約・パフォーマンス要件を定義する。
機能面の出典は [functional-design.md](./functional-design.md)、要求の出典は [product-requirements.md](./product-requirements.md)。

---

## 1. テクノロジースタック

### 1.1 言語・処理系
| 項目 | 採用 | 備考 |
|------|------|------|
| 言語 | Common Lisp | ANSI CL |
| 主対象処理系 | SBCL 2.6.5+ | 開発・CI の主対象 |
| 移植性方針 | 処理系非依存を志向 | 処理系固有拡張に依存しない（NFR6） |

### 1.2 ランタイム依存ライブラリ
| ライブラリ | 用途 | バージョン基準（qlfile.lock） |
|------------|------|-------------------------------|
| **ningle** | ベース Web フレームワーク。`app` クラス継承、`route` によるルート登録、`*request*` / `*response*` / `*session*` / `*context*` の参照 | `ql-2024-10-12` |
| **lack** | `lack/request:request-method`（メソッド照合）、`lack/util:generate-random-id`（`action_id` のランダム生成。内部で ironclad を使用） | `ql-2026-01-01` |
| **quri** | エンドポイント関数のクエリパラメータ付き URL 組み立て（`make-uri` / `render-uri`）と URL エンコード | `ql-2026-01-01` |
| **alexandria** | plist→alist 変換（`plist-alist`）。クエリパラメータの正規化に使用 | `ql-2026-01-01` |

- `quri` と `alexandria` は ningle / lack の推移的依存でもあるが、本ライブラリが直接 import するため `qlfile` に明示する。
- `ironclad`・`cl-ppcre`・`myway`・`bordeaux-threads` 等は ningle / lack の推移的依存として導入される（直接依存に加えない）。
- 直接依存は **ningle / lack / quri / alexandria** に限定し、導入障壁を最小化する（ビジネス要件・NFR1）。

### 1.3 開発・テスト依存
| ライブラリ/ツール | 用途 |
|-------------------|------|
| **rove** | 単体テストフレームワーク（`ql-2026-01-01`） |
| **qlot** | プロジェクトローカルな依存解決・ロック（1.8.3） |
| **ASDF** | システム定義。`:package-inferred-system` を使用 |

### 1.4 想定する利用側スタック（参考・本ライブラリ非依存）
- **htmx**: クライアント側のハイパーメディア駆動（呼び出しモデル）。
- **Lack builder の `:mount`**: アクションアプリを本体へ統合（mount 配線は利用者責務）。
- **HTML 生成**: 文字列・Spinneret・cl-who など任意（ビュー層非依存）。

---

## 2. システム定義（ASDF / パッケージ構成）

- システム名 `ningle-actions`、クラス `:package-inferred-system`、`:pathname "src"`。
- 1 ファイル = 1 パッケージ（`ningle-actions/<name>`）。`ningle-actions/main` を集約点とし、`ningle-actions.asd` の `:depends-on` は `("ningle-actions/main")`。
- テストシステム `ningle-actions-test`（`:pathname "tests"`、`rove` 依存、`test-op` で `rove:run`）。

```
ningle-actions          (ASDF system)
└── ningle-actions/main         ← 公開 API 再エクスポート
    ├── ningle-actions/action   ← defaction / endpoint 関数
    └── ningle-actions/app      ← actions-app / registry / dispatch / *actions-app* シングルトン / (内部) make-actions-app
```

> 詳細なファイル配置は [repository-structure.md](./repository-structure.md) で確定する。

---

## 3. 技術的制約と要件

### 3.1 ningle / lack の公開境界
- ningle は **公開 API のみ**に依存する（`ningle:app` 継承、`(setf ningle:route)`、`ningle:*request*` 等）。内部実装（`ningle/route` のクラス詳細など）には踏み込まない（NFR2・後方互換）。
- `request-method` は ningle から再エクスポートされないため、`lack/request:request-method` を直接用いる。
- 単一ルート `/:action_id` は `(setf (ningle:route app "/:action_id" :method '(:GET :POST :PUT :PATCH :DELETE)) #'dispatch)` で登録する。`action_id` は `(cdr (assoc :action_id params))` で取得（ningle のパスパラメータ規約に準拠）。

### 3.2 グローバル状態
- ライブラリは特殊変数 `*actions-app*`（シングルトンのアクションアプリ）を提供する。ロード時に `(make-actions-app)` の戻り値で初期化する `defvar` であり、`defaction` は暗黙に参照する。利用者はインスタンスを生成・保持しない。
- 内部コンストラクタ `make-actions-app`（非公開）は**副作用を持たない純粋関数**。グローバル変数は書き換えず、シングルトンの初期化フォームとテストの隔離インスタンス生成にのみ用いる。
- テスト時は `*actions-app*` を `let` で再束縛し、内部 `make-actions-app`（`ningle-actions/app` から参照）で生成した隔離インスタンスに差し替える（NFR3）。

### 3.3 `action_id` とセキュリティ
- `action_id` は推測困難なランダムトークン（`generate-random-id` = ironclad の乱数 40 桁 hex）。列挙攻撃を避ける（NFR4）。
- 入力検証・出力エスケープ（XSS 対策）は利用者責務。ドキュメントで注意喚起する。

### 3.4 マウントとの整合
- 接頭辞は `/actions` 固定（定数 `+actions-prefix+`）。エンドポイント関数はこの定数を前置する。
- mount ミドルウェアは `path-info` のみ書き換え `script-name` を更新しない（実装確認済み）ため、接頭辞は実行時取得せず固定値で扱う。利用者は `(:mount "/actions" *actions-app*)` で一致させる。

### 3.5 スコープ外（技術的に持ち込まないもの）
- レスポンス整形・content-type 付与（ningle の `process-response` に委譲）。
- 型強制・引数バリデーション（利用者責務、将来機能）。
- htmx ヘルパ（`*response*` 操作で代替、将来は別パッケージ候補）。
- mount 配線・クライアント JS ランタイム。

---

## 4. パフォーマンス要件

- **登録時処理**: arg 解析は無し（`params` をそのまま渡すため）。本体クロージャの生成と `action_id` 採番はマクロ展開／ロード時に行い、リクエスト毎のオーバーヘッドを排除する（NFR5）。
- **ディスパッチ計算量**: レジストリはハッシュテーブル（`action_id` → アクション）で、検索は平均 O(1)。
- **ルート数**: アクションアプリのルートは `/:action_id` の 1 本のみ。アクション数が増えても ningle のルートマッチング対象は増えない（mapper 探索コストが一定）。
- **メモリ**: アクション 1 件あたり、レジストリ 1 エントリ + `name-index` 1 エントリ + クロージャ 1 個。

---

## 5. ビルド・テスト・CI

### 5.1 ローカル
```bash
qlot install          # 依存解決
qlot exec rove ningle-actions-test.asd   # テスト実行
```
- REPL では `(asdf:test-system :ningle-actions)`（`test-op` 経由）でも実行可能。

### 5.2 CI（方針）
- SBCL + qlot で依存を固定（`qlfile.lock`）し、`rove` をグリーンに保つ。
- 将来的に複数処理系（CCL 等）でのスモークテストを検討（移植性確認）。

---

## 6. バージョニング・配布

- セマンティックバージョニング。初期は `0.x`（API 安定化まで）。
- ライセンス MIT。Quicklisp / Ultralisp 配布を想定し、単一システム構成を維持する。
