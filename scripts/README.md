# 運営向け：新しい回のリポジトリを作る

`new-event.sh` は、新しい回の公開アーカイブ `AICatchup/catchup-NNN` を作り、これまでの回と同じ設定を適用します。

## 必要なもの

- [GitHub CLI](https://cli.github.com/)（`gh auth login` 済み）と Git、bash。Windows では Git Bash で実行します。
- AICatchup の Owner 権限。Owner 以外が実行すると、何も作成せずに止まります。`--dry-run` は誰でも実行できます。
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
   - `branch-protection.json`：`main` への変更は PR 必須、承認1件、CODEOWNERS のレビュー、会話の解決が必要。force push と削除は不可。管理者（Owner）はこの保護の対象外で、これは意図した設定です（`enforce_admins` は `false`）。
   - `topics.json`、`labels.tsv`：トピックと、投稿フォームが使う `submission`・`correction` ラベル。
   - Dependabot のアラートとセキュリティ更新。
   - 運営チーム `@AICatchup/maintainers` への書き込み権限。各回の CODEOWNERS はこのチームを指定しており、チームの誰か1人が承認すればマージできます。
3. このリポジトリの README.md、CONTRIBUTING.md、AGENT_GUIDE.md に新しい回を追記する PR を作成します。

案内の3つの文書に前の回の記載がない場合は、何も作成せずに止まります。回番号の指定を誤ったときや、前の回を追加する PR がまだマージされていないときに起こります。

Actions、マージ方式、Fork からの PR の実行承認は GitHub の既定値のままで、スクリプトでは変更しません。

開催日が決まっていない場合は、開催日を省略します。「未定」として作成されます。

```bash
scripts/new-event.sh 004
```

## 実行後の手作業

- 開催日を省略して作った場合は、決まった時点で次の3か所を更新します。
  - その回の README.md の「開催日：未定」
  - その回の AGENTS.md の「開催日は未定です」
  - このリポジトリの README.md にある各回の表

- 開始・終了時刻や参加登録先が決まったら、その回の README.md に追記します。
- このリポジトリに作成された PR をレビューしてマージします。

## 設定を変えたいとき

`settings/` と `templates/event-repo/` が、第3回以降の構成と設定の正本です（[POLICY.md](../POLICY.md)）。変えるときは、先にこれらを変更する PR を出します。

- 設定：既存の回の番号を指定して再実行すると、リポジトリの作成は行わず、設定だけを適用し直します。作成の途中で失敗してリポジトリが空のまま残った場合は、再実行でひな形を投入します。
- ひな形のファイル：既存の回には自動で反映されません。反映する場合は、同じ内容の PR をその回にも出します。

## 確認担当を変えたいとき

確認担当は、Org のチーム `@AICatchup/maintainers` のメンバーです。担当を増減するときは、ファイルではなくチームのメンバーを変更します。すべての回にまとめて反映されます。

## ひな形のプレースホルダー

ひな形で使えるプレースホルダーは次の3つです。

| プレースホルダー | 例 |
| --- | --- |
| `{{EVENT_ID}}` | `004` |
| `{{EVENT_NO}}` | `4` |
| `{{EVENT_DATE}}` | `2027年3月10日（水）` |
