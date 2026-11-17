# 運営向け：新しい回のリポジトリを作る

`new-event.sh` は、新しい回の公開アーカイブ `AICatchup/catchup-NNN` を作り、これまでの回と同じ設定を適用します。

## 必要なもの

- [GitHub CLI](https://cli.github.com/)（`gh auth login` 済み）と Git、bash。Windows では Git Bash で実行します。
- AICatchup の Owner 権限。
- このリポジトリのクローン。

## 使い方

まず `--dry-run` で、生成されるファイルと実行内容を確認します。何も作成・変更されません。

```bash
scripts/new-event.sh --dry-run 004 "2027年3月10日（水）"
```

問題なければ実行します。

```bash
scripts/new-event.sh 004 "2027年3月10日（水）"
```

## 実行される内容

1. `templates/event-repo/` の回番号と開催日を置き換え、`AICatchup/catchup-NNN` を公開リポジトリとして作成します。
2. `settings/` の内容を適用します。
   - `repo-settings.json`：Wiki・Projects・Discussions はオフ、マージ後のブランチ削除、Secret scanning と Push protection。
   - `branch-protection.json`：`main` への変更は PR 必須、承認1件、CODEOWNERS のレビュー、会話の解決が必要。force push と削除は不可。
   - `topics.json`、`labels.tsv`：トピックと、投稿フォームが使う `submission`・`correction` ラベル。
   - Dependabot のアラートとセキュリティ更新。
3. このリポジトリの README.md、CONTRIBUTING.md、AGENT_GUIDE.md に新しい回を追記する PR を作成します。

Actions、マージ方式、Fork からの PR の実行承認は GitHub の既定値のままで、スクリプトでは変更しません。

## 実行後の手作業

- 開始・終了時刻や参加登録先が決まったら、その回の README.md に追記します。
- 確認担当が変わる回は、その回の `.github/CODEOWNERS` を変更します。
- このリポジトリに作成された PR をレビューしてマージします。

## 設定を変えたいとき

`settings/` や `templates/event-repo/` を変更する PR を出します。既存の回の番号を指定して再実行すると、リポジトリの作成は行わず、設定だけを適用し直します。ひな形のファイルは既存の回には反映されません。

ひな形で使えるプレースホルダーは次の3つです。

| プレースホルダー | 例 |
| --- | --- |
| `{{EVENT_ID}}` | `004` |
| `{{EVENT_NO}}` | `4` |
| `{{EVENT_DATE}}` | `2027年3月10日（水）` |
