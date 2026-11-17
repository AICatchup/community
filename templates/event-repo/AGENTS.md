# AI Catchup 第{{EVENT_NO}}回で作業するエージェントへ

ここは `AICatchup/catchup-{{EVENT_ID}}`、第{{EVENT_NO}}回の公開アーカイブです。開催日は{{EVENT_DATE}}です。参加者本人が共有したい知見・資料の投稿を手伝います。

## 先に読む正本

- [共通のエージェント向け投稿手順](https://github.com/AICatchup/community/blob/main/AGENT_GUIDE.md)
- [参加者向けの投稿方法](https://github.com/AICatchup/community/blob/main/CONTRIBUTING.md)
- [ビジョン](https://github.com/AICatchup/community/blob/main/VISION.md) / [公開・判断の方針](https://github.com/AICatchup/community/blob/main/POLICY.md)

共通ルールをこのリポジトリへ複製せず、上の正本を参照してください。

## この回の入口

| 用途 | 場所 |
| --- | --- |
| 標準の共有Issue | [share.yml の投稿フォーム](https://github.com/AICatchup/catchup-{{EVENT_ID}}/issues/new?template=share.yml) |
| 既存投稿・重複の確認 | [すべてのIssue一覧](https://github.com/AICatchup/catchup-{{EVENT_ID}}/issues?q=is%3Aissue) / [記録](contributions/) |
| PRで追加する記録 | `contributions/<GitHub名>-<短い題名>.md` |
| PRの宛先 | `AICatchup/catchup-{{EVENT_ID}}` の `main` |
| 訂正 | [correction.yml の投稿フォーム](https://github.com/AICatchup/catchup-{{EVENT_ID}}/issues/new?template=correction.yml) |

## どの作業にも共通すること

- Issue、PR、コミットメッセージ、レビューの指摘は日本語で書きます。
- 参加者の作業は、通常は共有Issueを1件作るか、本人が希望した場合にForkと作業ブランチからPRを出すところまでです。
- 参加者のPRで変更できるのは、`contributions/` にある本人の記録と、その記録に添える資料だけです（[投稿PRのルール](https://github.com/AICatchup/community/blob/main/CONTRIBUTING.md#第3回以降の投稿prのルール)）。
- `main` へ直接書き込んだり、参加者の依頼を運営によるマージ承認とみなしたりしません。運営としての編集・統合を依頼されている場合は、その権限と依頼範囲に従ってください。
- 公開リポジトリで、IssueとPRは送信時点から公開されます。個人情報や認証情報を含めず、公開範囲が曖昧な点は本人に確認します。

## レビューするとき（Review guidelines）

- 指摘は日本語で書きます。初めてPRを出す参加者にも伝わるよう、必要な点だけを具体的に伝えます。
- 確認する観点は、[投稿方法の「運営が確認すること」](https://github.com/AICatchup/community/blob/main/CONTRIBUTING.md#運営が確認すること)です。作者と原典、公開する権利と範囲、実際に試したことと未確認の区別、重複を見ます。
- 個人情報や認証情報（APIキー、トークン、`.env` の内容など）が含まれていたら、ほかの指摘より先に伝えます。
- 文章の巧拙、資料の完成度、内容の新しさは指摘しません。完璧な資料であることは求めていません。
- 参加者の投稿PRに、`contributions/` にある本人の記録とその資料以外への変更が含まれていたら、上の投稿PRのルールを示して伝えます。
- レビューは運営の判断を助けるものです。承認とマージは運営が行います。
