#!/usr/bin/env bash
# 新しい回の公開アーカイブ AICatchup/catchup-NNN を作り、既定の設定を適用する。
# 使い方: scripts/new-event.sh [--dry-run] <回番号3桁> <開催日>
# 詳細:   scripts/README.md
set -euo pipefail

ORG="AICatchup"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT/templates/event-repo"
SETTINGS="$ROOT/settings"
DOCS="README.md CONTRIBUTING.md AGENT_GUIDE.md"
DRY_RUN=0
WORK=""
WORKTREE=""

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
使い方: scripts/new-event.sh [--dry-run] <回番号3桁> <開催日>
例:     scripts/new-event.sh 004 "2027年3月10日（水）"

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

patch_docs() {
  local dir="$1"
  patch_doc "$dir" README.md \
    "| 第${EVENT_NO}回 | ${EVENT_DATE} / 時間・参加登録先は後日案内 | [catchup-$EVENT_ID]($URL) |"
  patch_doc "$dir" CONTRIBUTING.md \
    "| 第${EVENT_NO}回 | [共有フォーム]($URL/issues/new?template=share.yml) |"
  patch_doc "$dir" AGENT_GUIDE.md ""
}

main() {
  if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; shift; fi
  [ $# -eq 2 ] || usage
  EVENT_ID="$1"
  EVENT_DATE="$2"
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

  local cmd
  for cmd in gh git awk; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd が見つかりません。"
  done
  gh auth status >/dev/null 2>&1 || die "GitHub CLI にログインしていません。gh auth login を実行してください。"
  [ -d "$TEMPLATE" ] || die "ひな形が見つかりません: $TEMPLATE"

  WORK="$(mktemp -d)"
  trap cleanup EXIT

  local exists=0
  if gh repo view "$REPO" >/dev/null 2>&1; then exists=1; fi

  # ---- 1. リポジトリ作成とひな形の投入 ----
  step "1/3 $REPO の作成"
  render_template "$WORK/repo"
  if [ "$exists" = 1 ]; then
    echo "  すでに存在するため、作成とひな形の投入は行いません（設定だけ適用し直します）。"
  else
    if [ "$DRY_RUN" = 1 ]; then
      echo "  生成されるファイル:"
      (cd "$WORK/repo" && find . -type f | sort | sed 's|^\./|    |')
      echo "  README.md の冒頭:"
      sed -n '1,7p' "$WORK/repo/README.md" | sed 's/^/    | /'
    fi
    run git -C "$WORK/repo" init -q -b main
    run git -C "$WORK/repo" add -A
    run git -C "$WORK/repo" commit -q -m "第${EVENT_NO}回の公開アーカイブを用意"
    run gh repo create "$REPO" --public \
      --description "AI Catchup 第${EVENT_NO}回の発表・活用事例・学びを持ち寄る公開アーカイブ" \
      --source "$WORK/repo" --remote origin --push
  fi

  # ---- 2. 設定の適用（何度実行しても同じ結果になる） ----
  step "2/3 設定の適用"
  run gh api --silent -X PATCH "repos/$REPO" --input "$SETTINGS/repo-settings.json"
  run gh api --silent -X PUT "repos/$REPO/topics" --input "$SETTINGS/topics.json"
  run gh api --silent -X PUT "repos/$REPO/vulnerability-alerts"
  run gh api --silent -X PUT "repos/$REPO/automated-security-fixes"
  run gh api --silent -X PUT "repos/$REPO/branches/main/protection" --input "$SETTINGS/branch-protection.json"
  local name color desc
  while IFS=$'\t' read -r name color desc; do
    [ -n "$name" ] || continue
    run gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" --force
  done < "$SETTINGS/labels.tsv"

  # ---- 3. community の案内に新しい回を追加する PR ----
  step "3/3 community の案内を更新"
  local doc
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
    git -C "$ROOT" fetch -q origin main
    WORKTREE="$WORK/community"
    git -C "$ROOT" worktree add -q --detach "$WORKTREE" origin/main
    patch_docs "$WORKTREE"
    if git -C "$WORKTREE" diff --quiet; then
      echo "  変更がないため PR は作成しません。"
    elif git -C "$ROOT" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
      echo "  ブランチ $BRANCH がすでにあるため PR は作成しません。作成済みの PR を確認してください。"
    else
      # shellcheck disable=SC2086
      git -C "$WORKTREE" add $DOCS
      git -C "$WORKTREE" commit -q -m "第${EVENT_NO}回の投稿先を案内に追加"
      git -C "$WORKTREE" push -q origin "HEAD:refs/heads/$BRANCH"
      gh pr create --repo "$ORG/community" --base main --head "$BRANCH" \
        --title "第${EVENT_NO}回の投稿先を案内に追加" \
        --body "## 何を変えるか

README.md、CONTRIBUTING.md、AGENT_GUIDE.md の投稿先一覧に、第${EVENT_NO}回（${EVENT_DATE}）の [catchup-$EVENT_ID]($URL) を追加します。

## なぜ変えるか

第${EVENT_NO}回の公開アーカイブを用意したため、参加者と AI が投稿先をたどれるようにします。

\`scripts/new-event.sh\` が作成した PR です。開催案内のリンクや時間が決まったら追記してください。"
    fi
  fi

  if [ "$DRY_RUN" = 1 ]; then
    step "dry-run 完了（何も作成・変更していません）"
    return
  fi
  step "完了"
  echo "  リポジトリ: $URL"
  echo "  残りの手作業:"
  echo "    - 開始・終了時刻、参加登録先が決まったら $URL の README.md に追記"
  echo "    - 確認担当が変わる回は .github/CODEOWNERS を変更"
  echo "    - community の PR をレビューしてマージ"
}

main "$@"
