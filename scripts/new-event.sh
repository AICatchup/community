#!/usr/bin/env bash
# 新しい回の公開アーカイブ AICatchup/catchup-NNN を作り、既定の設定を適用する。
# 使い方: scripts/new-event.sh [--dry-run] <回番号3桁> [開催日]
# 詳細:   scripts/README.md
set -euo pipefail

ORG="AICatchup"
# 各回の CODEOWNERS（templates/event-repo/.github/CODEOWNERS）に書かれている運営チーム。
TEAM="maintainers"
# 案内の更新は、このクローンのリモート設定（origin の名前や向き先）に頼らず、正規の URL に対して行う。
COMMUNITY_URL="https://github.com/$ORG/community.git"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT/templates/event-repo"
SETTINGS="$ROOT/settings"
DOCS="README.md CONTRIBUTING.md AGENT_GUIDE.md"
DRY_RUN=0
DATE_KNOWN=1
WORK=""
WORKTREE=""
COMMUNITY_HEAD=""
GIT_NAME=""
GIT_EMAIL=""

die() { printf 'エラー: %s\n' "$*" >&2; exit 1; }
warn() { printf '注意: %s\n' "$*" >&2; }
step() { printf '\n== %s\n' "$*"; }

# 書き込みを伴うコマンドはすべてここを通す。--dry-run では表示だけ行う。
run() {
  if [ "$DRY_RUN" = 1 ]; then
    printf '  [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

usage() {
  cat >&2 <<'EOF'
使い方: scripts/new-event.sh [--dry-run] <回番号3桁> [開催日]
例:     scripts/new-event.sh 004 "2027年3月10日（水）"
        scripts/new-event.sh 004          （開催日が未定の場合）

  --dry-run  何も作成・変更せず、生成されるファイルと実行内容だけを表示します。
EOF
  exit 2
}

cleanup() {
  if [ -n "$WORKTREE" ] && [ -d "$WORKTREE" ]; then
    git -C "$ROOT" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
  fi
  if [ -n "$WORK" ]; then rm -rf "$WORK"; fi
}

# 実行者が Org の Owner であることを確認する。Owner でない Org メンバーは、
# リポジトリの作成だけ成功して設定の適用に失敗し、保護のないリポジトリを残すおそれがある。
require_org_owner() {
  local login role
  login="$(gh api user --jq .login)"
  role="$(gh api "orgs/$ORG/memberships/$login" --jq .role 2>/dev/null || true)"
  if [ "$role" != "admin" ]; then
    die "このスクリプトを実行できるのは $ORG の Owner だけです（現在のアカウント: $login）。内容の確認だけなら --dry-run を付けてください。"
  fi
}

# コミットに使う作者情報を、このクローンの設定（なければグローバル設定）から取得する。
# 一時リポジトリはこのクローンのローカル設定を引き継がないため、明示的に渡す。
require_git_identity() {
  GIT_NAME="$(git -C "$ROOT" config user.name || true)"
  GIT_EMAIL="$(git -C "$ROOT" config user.email || true)"
  if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
    die "Git の作者情報が未設定です。git config --global user.name と user.email を設定してから再実行してください。"
  fi
}

# ひな形・設定・スクリプトは手元のファイルを使う。取得した main と違っていると、
# 古いクローンや未マージの変更から新しい回を作ってしまうため、何かを作成する前に止める。
require_current_sources() {
  local paths="templates/event-repo settings scripts"
  # shellcheck disable=SC2086
  if [ -n "$(git -C "$ROOT" status --porcelain -- $paths)" ] \
    || ! git -C "$ROOT" diff --quiet "$COMMUNITY_HEAD" -- $paths; then
    die "手元のひな形・設定・スクリプトが $ORG/community の main と一致しません。main を最新にして、未コミットの変更がない状態で再実行してください。内容の確認だけなら --dry-run を付けてください。"
  fi
}

# リモートにブランチが1つもなければ空とみなす。
remote_is_empty() {
  local refs
  refs="$(git ls-remote --heads "$URL.git")" || die "$REPO の状態を確認できませんでした。"
  [ -z "$refs" ]
}

# $WORK/repo に生成済みのひな形を最初のコミットにして、リモートの main へ push する。
push_template() {
  run git -C "$WORK/repo" init -q -b main
  if [ "$DRY_RUN" = 0 ]; then
    git -C "$WORK/repo" config user.name "$GIT_NAME"
    git -C "$WORK/repo" config user.email "$GIT_EMAIL"
  fi
  run git -C "$WORK/repo" add -A
  run git -C "$WORK/repo" commit -q -m "第${EVENT_NO}回の公開アーカイブを用意"
  # 認証は gh のログイン情報を使う（git 側の資格情報設定に依存しない）。
  run git -C "$WORK/repo" -c credential.helper= -c 'credential.helper=!gh auth git-credential' \
    push -q "$URL.git" main
}

# ひな形のプレースホルダーを置換して $1 に書き出す。
render_template() {
  local out="$1" src rel
  while IFS= read -r src; do
    rel="${src#"$TEMPLATE"/}"
    mkdir -p "$out/$(dirname "$rel")"
    awk -v id="$EVENT_ID" -v no="$EVENT_NO" -v date="$EVENT_DATE" '
      {
        gsub(/[{][{]EVENT_ID[}][}]/, id)
        gsub(/[{][{]EVENT_NO[}][}]/, no)
        gsub(/[{][{]EVENT_DATE[}][}]/, date)
        print
      }' "$src" > "$out/$rel"
  done < <(find "$TEMPLATE" -type f | sort)
}

# community の案内文書に新しい回を追記する。
#   $1 = 文書のあるディレクトリ  $2 = ファイル名  $3 = 前回の行の下に足す表の行（不要なら空）
patch_doc() {
  local file="$1/$2" row="$3"
  local prev_link="[第${PREV_NO}回](https://github.com/$ORG/catchup-$PREV_ID)"
  local new_link="、[第${EVENT_NO}回]($URL)"
  if grep -q "catchup-$EVENT_ID" "$file"; then
    echo "  $2: 記載済みのため変更しません。"
    return
  fi
  awk -v needle="$prev_link" -v add="$new_link" -v prefix="| 第${PREV_NO}回 |" -v row="$row" '
    {
      i = index($0, needle)
      if (i) $0 = substr($0, 1, i + length(needle) - 1) add substr($0, i + length(needle))
      print
      if (row != "" && index($0, prefix) == 1) print row
    }' "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
  if grep -q "catchup-$EVENT_ID" "$file"; then
    echo "  $2: 第${EVENT_NO}回を追記しました。"
  else
    warn "$2 に第${PREV_NO}回の記載が見つからず、追記できませんでした。手で追加してください。"
  fi
}

# $1 にある案内文書へ今回の回を追記できるかを、何かを作成する前に確かめる。
# 回番号の指定ミス（連番を飛ばすなど）や文書の書式の変更に気づかないまま、
# リポジトリだけが作られて案内の一覧がそろわなくなるのを防ぐ。
check_docs() {
  local dir="$1" doc file need ok missing=""
  local prev_link="[第${PREV_NO}回](https://github.com/$ORG/catchup-$PREV_ID)"
  for doc in $DOCS; do
    file="$dir/$doc"
    if grep -qF "catchup-$EVENT_ID" "$file"; then continue; fi
    # 文書ごとの追記位置。patch_docs が足す内容（前回へのリンクの後ろ、表の前回の行の下）に対応する。
    case "$doc" in
      README.md) need="row" ;;
      CONTRIBUTING.md) need="link row" ;;
      *) need="link" ;;
    esac
    ok=1
    case "$need" in *link*) grep -qF "$prev_link" "$file" || ok=0 ;; esac
    case "$need" in *row*) grep -q "^| 第${PREV_NO}回 |" "$file" || ok=0 ;; esac
    [ "$ok" = 1 ] || missing="$missing $doc"
  done
  if [ -n "$missing" ]; then
    die "community の案内（${missing# }）に第${PREV_NO}回の記載が見つからず、第${EVENT_NO}回を追記できません。何も作成していません。回番号が正しいか確認してください。第${PREV_NO}回を追加する PR が未マージの場合は、先にマージしてください。"
  fi
}

patch_docs() {
  local dir="$1" schedule
  if [ "$DATE_KNOWN" = 1 ]; then
    schedule="${EVENT_DATE} / 時間・参加登録先は後日案内"
  else
    schedule="開催日・時間・参加登録先は後日案内"
  fi
  patch_doc "$dir" README.md \
    "| 第${EVENT_NO}回 | ${schedule} | [catchup-$EVENT_ID]($URL) |"
  patch_doc "$dir" CONTRIBUTING.md \
    "| 第${EVENT_NO}回 | [共有フォーム]($URL/issues/new?template=share.yml) |"
  patch_doc "$dir" AGENT_GUIDE.md ""
}

main() {
  if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; shift; fi
  [ $# -ge 1 ] && [ $# -le 2 ] || usage
  EVENT_ID="$1"
  # 開催日は省略できる。省略時は「未定」として作り、決まってから各文書を更新する。
  EVENT_DATE="${2:-}"
  DATE_KNOWN=1
  if [ -z "$EVENT_DATE" ]; then EVENT_DATE="未定"; DATE_KNOWN=0; fi
  [[ "$EVENT_ID" =~ ^[0-9]{3}$ ]] || die "回番号は 004 のように3桁の数字で指定してください。"
  case "$EVENT_DATE" in
    *[\&\\\|]*) die "開催日に & \\ | は使えません。" ;;
  esac
  EVENT_NO=$((10#$EVENT_ID))
  [ "$EVENT_NO" -ge 1 ] || die "回番号は 001 以上で指定してください。"
  PREV_NO=$((EVENT_NO - 1))
  PREV_ID="$(printf '%03d' "$PREV_NO")"
  REPO="$ORG/catchup-$EVENT_ID"
  URL="https://github.com/$REPO"
  BRANCH="add-catchup-$EVENT_ID"

  local cmd doc
  for cmd in gh git awk; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd が見つかりません。"
  done
  gh auth status >/dev/null 2>&1 || die "GitHub CLI にログインしていません。gh auth login を実行してください。"
  [ -d "$TEMPLATE" ] || die "ひな形が見つかりません: $TEMPLATE"
  # 何かを作成する前に確認し、権限や設定が足りない環境で途中まで進まないようにする。
  # --dry-run は何も変更しないので、Owner でなくても実行できる。
  WORK="$(mktemp -d)"
  trap cleanup EXIT
  if [ "$DRY_RUN" = 0 ]; then
    require_org_owner
    require_git_identity
    gh api "orgs/$ORG/teams/$TEAM" --silent 2>/dev/null \
      || die "運営チーム @$ORG/$TEAM が見つかりません。先にチームを作成してください。"
    # 案内は community の最新の main を元に更新する。追記できるかもその内容で確かめる。
    git -C "$ROOT" fetch -q "$COMMUNITY_URL" main \
      || die "$ORG/community の main を取得できませんでした。"
    COMMUNITY_HEAD="$(git -C "$ROOT" rev-parse FETCH_HEAD)"
    require_current_sources
    mkdir -p "$WORK/main-docs"
    for doc in $DOCS; do
      git -C "$ROOT" show "$COMMUNITY_HEAD:$doc" > "$WORK/main-docs/$doc"
    done
    check_docs "$WORK/main-docs"
  else
    check_docs "$ROOT"
  fi

  local exists=0
  if gh repo view "$REPO" >/dev/null 2>&1; then exists=1; fi

  # ---- 1. リポジトリ作成とひな形の投入 ----
  step "1/3 $REPO の作成"
  render_template "$WORK/repo"
  # 作成と push を別々に行う。作成だけ成功して push に失敗した場合も、
  # 再実行時に空のリポジトリを検出してひな形を投入できる。
  local need_push=1
  if [ "$exists" = 1 ]; then
    if remote_is_empty; then
      echo "  リポジトリはありますが空のため、ひな形を投入します。"
    else
      need_push=0
      echo "  すでに存在するため、作成とひな形の投入は行いません（設定だけ適用し直します）。"
    fi
  fi
  if [ "$need_push" = 1 ]; then
    if [ "$DRY_RUN" = 1 ]; then
      echo "  生成されるファイル:"
      (cd "$WORK/repo" && find . -type f | sort | sed 's|^\./|    |')
      echo "  README.md の冒頭:"
      sed -n '1,7p' "$WORK/repo/README.md" | sed 's/^/    | /'
    fi
    if [ "$exists" = 0 ]; then
      run gh repo create "$REPO" --public \
        --description "AI Catchup 第${EVENT_NO}回の発表・活用事例・学びを持ち寄る公開アーカイブ"
    fi
    push_template
  fi

  # ---- 2. 設定の適用（何度実行しても同じ結果になる） ----
  step "2/3 設定の適用"
  run gh api --silent -X PATCH "repos/$REPO" --input "$SETTINGS/repo-settings.json"
  run gh api --silent -X PUT "repos/$REPO/topics" --input "$SETTINGS/topics.json"
  run gh api --silent -X PUT "repos/$REPO/vulnerability-alerts"
  run gh api --silent -X PUT "repos/$REPO/automated-security-fixes"
  # CODEOWNERS のチーム指定は、チームにそのリポジトリの書き込み権限がないと無効になる。
  run gh api --silent -X PUT "orgs/$ORG/teams/$TEAM/repos/$REPO" -f permission=push
  run gh api --silent -X PUT "repos/$REPO/branches/main/protection" --input "$SETTINGS/branch-protection.json"
  local name color desc
  while IFS=$'\t' read -r name color desc; do
    [ -n "$name" ] || continue
    run gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" --force
  done < "$SETTINGS/labels.tsv"

  # ---- 3. community の案内に新しい回を追加する PR ----
  step "3/3 community の案内を更新"
  if [ "$DRY_RUN" = 1 ]; then
    mkdir -p "$WORK/community"
    for doc in $DOCS; do cp "$ROOT/$doc" "$WORK/community/$doc"; done
    patch_docs "$WORK/community"
    local changed=0
    for doc in $DOCS; do
      if ! cmp -s "$ROOT/$doc" "$WORK/community/$doc"; then
        changed=1
        diff -u "$ROOT/$doc" "$WORK/community/$doc" | sed -e '1,2d' -e 's/^/    /' || true
      fi
    done
    if [ "$changed" = 1 ]; then
      echo "  [dry-run] 上の差分を $BRANCH ブランチにコミットし、$ORG/community へ PR を作成"
    else
      echo "  変更がないため PR は作成しません。"
    fi
  else
    # ローカルにブランチを残さないよう、切り離した作業ツリーで編集して直接 push する。
    WORKTREE="$WORK/community"
    git -C "$ROOT" worktree add -q --detach "$WORKTREE" "$COMMUNITY_HEAD"
    patch_docs "$WORKTREE"
    if git -C "$WORKTREE" diff --quiet; then
      echo "  変更がないため PR は作成しません。"
    else
      # push は済んだが PR 作成だけ失敗した場合に再実行で続きから進められるよう、
      # ブランチの有無と PR の有無を別々に確認する。
      if git ls-remote --exit-code --heads "$COMMUNITY_URL" "$BRANCH" >/dev/null 2>&1; then
        echo "  ブランチ $BRANCH はすでにあるため、push は行いません。"
      else
        # shellcheck disable=SC2086
        git -C "$WORKTREE" add $DOCS
        git -C "$WORKTREE" commit -q -m "第${EVENT_NO}回の投稿先を案内に追加"
        git -C "$WORKTREE" -c credential.helper= -c 'credential.helper=!gh auth git-credential' \
          push -q "$COMMUNITY_URL" "HEAD:refs/heads/$BRANCH"
      fi
      local pr_url
      pr_url="$(gh pr list --repo "$ORG/community" --head "$BRANCH" --state open --json url --jq '.[0].url // empty')"
      if [ -n "$pr_url" ]; then
        echo "  PR は作成済みです: $pr_url"
      else
        gh pr create --repo "$ORG/community" --base main --head "$BRANCH" \
          --title "第${EVENT_NO}回の投稿先を案内に追加" \
          --body "## 何を変えるか

README.md、CONTRIBUTING.md、AGENT_GUIDE.md の投稿先一覧に、第${EVENT_NO}回（開催日：${EVENT_DATE}）の [catchup-$EVENT_ID]($URL) を追加します。

## なぜ変えるか

第${EVENT_NO}回の公開アーカイブを用意したため、参加者と AI が投稿先をたどれるようにします。

\`scripts/new-event.sh\` が作成した PR です。開催案内のリンクや時間が決まったら追記してください。"
      fi
    fi
  fi

  if [ "$DRY_RUN" = 1 ]; then
    step "dry-run 完了（何も作成・変更していません）"
    return
  fi
  step "完了"
  echo "  リポジトリ: $URL"
  echo "  残りの手作業:"
  if [ "$DATE_KNOWN" = 0 ]; then
    echo "    - 開催日が決まったら、$URL の README.md と AGENTS.md、community の README.md の表を更新"
  fi
  echo "    - 開始・終了時刻、参加登録先が決まったら $URL の README.md に追記"
  echo "    - community の PR をレビューしてマージ"
}

main "$@"
