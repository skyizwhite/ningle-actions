# 初回実装 タスクリスト (Tasklist)

要求: [requirements.md](./requirements.md) / 設計: [design.md](./design.md)

進捗記号: `[ ]` 未着手 / `[~]` 進行中 / `[x]` 完了

---

## フェーズ 0: 準備
- [ ] T0-1 `qlot install` で依存（ningle / lack / rove）が解決できることを確認
- [ ] T0-2 既存 `src/main.lisp` の現状を確認（置き換え対象）

## フェーズ 1: コア実装（`src/`）
- [ ] T1-1 `src/app.lisp` を作成
  - [ ] パッケージ定義（import: ningle `app`/`route`/`*request*`、`lack/request:request-method`、`lack/util:generate-random-id`。export: `actions-app`/`*app*`/`make-action-app`）
  - [ ] `+action-prefix+` 定数、`action` 構造体、`actions-app` クラス、`*app*` 変数
  - [ ] `find-action` / `register-action`（name-index による id 再利用）/ `action-endpoint`
  - [ ] `dispatch-action`（404 / 405 / 正常）
  - [ ] `make-action-app`（単一ルート登録 + `*app*` 設定）
- [ ] T1-2 `src/action.lisp` を作成
  - [ ] パッケージ定義（import: `*app*`/`register-action`/`action-endpoint`。export: `defaction`）
  - [ ] `defaction` マクロ（gensym で id 捕捉回避、登録 + 同名関数 defun）
- [ ] T1-3 `src/main.lisp` を置換
  - [ ] `:use-reexport`（app/action）
  - [ ] ロード時 `(unless *app* (make-action-app))`
- [ ] T1-4 `(ql:quickload :ningle-actions)` 相当でロード成功・警告ゼロを確認

## フェーズ 2: テスト（`tests/`）
- [ ] T2-1 `ningle-actions-test.asd` の依存を更新（`ningle-actions` 本体 + tests パッケージ群）
- [ ] T2-2 `tests/app.lisp`
  - [ ] `make-action-app` 戻り値・`*app*` 設定（AC-1）
  - [ ] `register-action` → `find-action`（AC-1）
  - [ ] 同名再登録で `action_id` 不変（AC-3）
  - [ ] `action-endpoint` の URL 形式（AC-2）
  - [ ] `dispatch-action`: 未登録 → 404（AC-5）
  - [ ] `dispatch-action`: メソッド不一致 → 405（AC-6）
  - [ ] `dispatch-action`: 正常 → handler 戻り値（AC-4/AC-7）
- [ ] T2-3 `tests/action.lisp`
  - [ ] `defaction` 後 `(name)` が URL を返す（AC-2）
  - [ ] `defaction` 後 `find-action` で登録確認（AC-1）
  - [ ] 再 `defaction` で `(name)` 不変（AC-3）
  - [ ] handler が `params` を受領し値取得（AC-7）
- [ ] T2-4 `tests/main.lisp`
  - [ ] `(:mount "/actions" *app*)` 統合 end-to-end（AC-4）
  - [ ] 統合下で 404 / 405（AC-5/AC-6）
- [ ] T2-5 リクエスト駆動ユーティリティを確定（ningle-test の依存を参照）し、未確定事項を解消
- [ ] T2-6 `qlot exec rove ningle-actions-test.asd` がグリーン（AC-8）

## フェーズ 3: ドキュメント・仕上げ
- [ ] T3-1 `README.md` に最小サンプル（`defaction` + `make-action-app` + `(:mount ...)` + htmx）と API 早見を記載
- [ ] T3-2 SBCL コンパイル警告の最終確認
- [ ] T3-3 設計と差異が出た場合、該当 `docs/` を更新
- [ ] T3-4 コミット（英語・Conventional Commits）。例: `feat: implement core action mechanism (defaction, dispatch, mount)`

---

## 完了条件（Definition of Done）
1. `src/app.lisp` / `src/action.lisp` / `src/main.lisp` が実装され、警告なくロードできる。
2. requirements.md の AC-1〜AC-8 をテストで満たす。
3. `rove` がグリーン。
4. README に最小サンプルがある。
5. 設計から逸脱した点があれば `docs/` に反映済み。

## リスク・留意点
- ningle パスパラメータのキー型（`:action_id`）が想定と異なる場合、`dispatch-action` の取得方法を調整（T2-2 で早期検出）。
- 統合テストのリクエスト駆動 API がバージョン差で異なる可能性（T2-5 で吸収）。
- `defconstant` ではなく `defparameter` を用いる（文字列定数の再定義問題回避）。
