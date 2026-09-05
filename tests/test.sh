#!/usr/bin/env bash
set -Eeuo pipefail

trap 'status=$?; printf "test failure at line %s: %s (status %s)\n" "$LINENO" "$BASH_COMMAND" "$status" >&2; exit "$status"' ERR

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
root=/tmp/dotfiles-test
rm -rf "$root"
mkdir -p "$root"

safety_pattern='(/'"Users/|1628"'1580|Opa'"rah|8f84"'64|sk-[A-Za-z0-9]{16,})'
if grep -R -E \
  --exclude-dir=.git \
  --exclude=.git \
  --exclude-dir=.idea \
  --exclude='*.iml' \
  "$safety_pattern" \
  "$source_dir" >/dev/null; then
  printf 'public-safety scan found a personal path, identifier, or credential-like value.\n' >&2
  exit 1
fi

source_files() {
  if git -C "$source_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$source_dir" ls-files --cached --others --exclude-standard -- \
      'dot_*' 'private_*' 'encrypted_*' 'executable_*' 'symlink_*' 'run_*'
  else
    while IFS= read -r -d '' source; do
      printf '%s\n' "${source#"$source_dir"/}"
    done < <(find "$source_dir" -type f \( \
      -path "$source_dir/dot_*" -o -path "$source_dir/private_*" -o \
      -path "$source_dir/encrypted_*" -o -path "$source_dir/executable_*" -o \
      -path "$source_dir/symlink_*" -o -path "$source_dir/run_*" \
    \) -print0)
  fi
}

template_suffix_error=false
while IFS= read -r source; do
  test -f "$source_dir/$source" || continue
  case "$source" in
    *.tmpl) continue ;;
  esac
  if grep -Fq '{{' "$source_dir/$source"; then
    printf 'managed source contains template directives without a .tmpl suffix: %s\n' "$source" >&2
    template_suffix_error=true
  fi
done < <(source_files)
if $template_suffix_error; then
  exit 1
fi

render_scripts() {
  local name=$1
  local config="$source_dir/tests/fixtures/$name.toml"
  local rendered="$root/$name/rendered"
  mkdir -p "$rendered"
  for template in "$source_dir"/run_*.tmpl; do
    output="$rendered/${template##*/}"
    chezmoi execute-template --source "$source_dir" --config "$config" <"$template" >"$output"
    sh -n "$output"
  done
  chezmoi execute-template --source "$source_dir" --config "$config" \
    <"$source_dir/.chezmoiexternal.toml.tmpl" >"$rendered/externals.toml"
  python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1], "rb"))' "$rendered/externals.toml"
  chezmoi execute-template --source "$source_dir" --config "$config" \
    <"$source_dir/.chezmoitemplates/Brewfile.tmpl" >"$rendered/Brewfile"
}

apply_fixture() {
  local name=$1
  local home="$root/$name/home"
  local config="$source_dir/tests/fixtures/$name.toml"
  mkdir -p "$home"
  chezmoi apply \
    --source "$source_dir" \
    --destination "$home" \
    --config "$config" \
    --cache "$root/$name/cache" \
    --persistent-state "$root/$name/chezmoistate.boltdb" \
    --exclude scripts,externals \
    --force
}

assert_contains() {
  local file=$1
  local text=$2
  grep -Fq "$text" "$file" || {
    printf 'expected %s to contain: %s\n' "$file" "$text" >&2
    exit 1
  }
}

assert_not_contains() {
  local file=$1
  local text=$2
  if grep -Fq "$text" "$file"; then
    printf 'expected %s not to contain: %s\n' "$file" "$text" >&2
    exit 1
  fi
}

assert_orchestration_reuse_contract() {
  local file=$1
  assert_contains "$file" 'Prefer and reuse existing suitable delegates for corrections and closely related same-scope follow-ups, including workers, investigators, architects, and planners.'
  assert_contains "$file" 'Create a new delegate only for distinct ownership, required isolation, or unavailable or unsuitable context.'
  assert_contains "$file" 'at most one integration subagent session per orchestration run and reuse it for relevant reruns and same-scope follow-ups.'
  assert_contains "$file" 'Start a second integration session only when genuinely necessary because the existing session'
  assert_contains "$file" 'Send accepted findings to the worker; return corrected work to that same reviewer session.'
}

assert_reference_branch_contract() {
  local file=$1
  assert_contains "$file" 'Reference-branch protection is unconditional by default: never implement, stage, commit, or push on a recorded reference branch.'
  assert_contains "$file" 'Before launching any implementation worker, create or use a distinct delivery branch or dedicated worktree derived from the recorded reference branch; never launch a worker in or allow a worker to edit the reference checkout.'
  assert_contains "$file" 'Before staging or pushing, verify that delivery remains on that distinct branch or worktree.'
  assert_contains "$file" 'This applies whether the reference is main, an integration branch, a release branch, or another named base.'
  assert_contains "$file" 'Explicit authorization to create or manage a PR does not authorize work, commit, or push on a reference branch; only an explicit user instruction to work or deliver on that specific reference branch waives protection.'
}

assert_delivery_contract() {
  local file=$1
  assert_contains "$file" 'without routine confirmation'
  assert_contains "$file" 'status/diff inspection, staging, commit, push, and final status reporting'
  assert_contains "$file" 'does not ask for or wait on manual confirmation'
  assert_contains "$file" 'gh pr create'
  assert_contains "$file" 'monitor PR checks'
  assert_contains "$file" 'user explicitly requests PR handling'
  assert_contains "$file" 'do not ask whether to create a PR'
  assert_not_contains "$file" 'PR creation from the orchestrator'
  assert_not_contains "$file" 'owns delivery through passing PR checks'
}

assert_beads_viewer_externals() {
  local file=$1
  python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); ref=sys.argv[2]; base="https://raw.githubusercontent.com/Angel-O/beads_viewer/" + ref + "/skills/"; assert data[".config/opencode/skills/beads-hub/SKILL.md"] == {"type": "file", "url": base + "beads-hub/SKILL.md"}; assert data[".config/opencode/skills/beads-hub-closeout/SKILL.md"] == {"type": "file", "url": base + "beads-hub-closeout/SKILL.md"}; assert data[".config/opencode/skills/beads-hub-closeout/validate.sh"] == {"type": "file", "url": base + "beads-hub-closeout/validate.sh", "executable": True}; assert data[".config/opencode/skills/beads-hub-closeout/closeout.sh"] == {"type": "file", "url": base + "beads-hub-closeout/closeout.sh", "executable": True}' "$file" "$beads_viewer_ref"
}

assert_ponytail_external() {
  local file=$1
  python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); ref=sys.argv[2]; assert data[".config/opencode/skills/ponytail/SKILL.md"] == {"type": "file", "url": "https://raw.githubusercontent.com/dietrichgebert/ponytail/" + ref + "/skills/ponytail/SKILL.md"}' "$file" "$ponytail_ref"
}

assert_agent_contracts() {
  local directory=$1
  python3 - "$directory" <<'PY'
import re
import sys
from pathlib import Path

directory = Path(sys.argv[1])
contracts = {
    "orchestrator": ("primary", "openai/gpt-5.6-terra", "high", {"external_directory", "question", "bash", "read", "glob", "grep", "task", "webfetch", "todowrite", "skill", "lsp", "quota_status", "handoff_session", "read_session", "history-search"}),
    "integration": ("subagent", "openai/gpt-5.6-luna", "medium", {"bash", "external_directory", "read", "glob", "grep", "skill"}),
    "investigator": ("subagent", "openai/gpt-5.6-sol", "medium", {"bash", "external_directory", "read", "glob", "grep", "webfetch", "skill"}),
    "reviewer": ("subagent", "openai/gpt-6-astra", "medium", {"bash", "external_directory", "read", "glob", "grep", "lsp", "skill"}),
    "worker": ("primary", "openai/gpt-5.6-luna", "high", {"bash", "read", "glob", "grep", "webfetch", "todowrite", "skill", "edit", "lsp"}),
    "architect": ("primary", "openai/gpt-5.6-sol", "high", {"question", "external_directory", "read", "glob", "grep", "webfetch", "lsp", "skill", "task"}),
    "planner": ("subagent", "openai/gpt-5.6-terra", "medium", {"read", "glob", "grep", "lsp", "skill"}),
}

for name, (mode, model, effort, allowed) in contracts.items():
    text = (directory / f"{name}.md").read_text()
    frontmatter = text.split("---", 2)[1]
    assert f"mode: {mode}" in frontmatter
    assert f"model: {model}" in frontmatter
    assert f"reasoningEffort: {effort}" in frontmatter
    assert '  "*": deny' in frontmatter
    permission = frontmatter.split("permission:", 1)[1]
    assert "apply_patch" not in permission
    keys = set()
    for line in permission.splitlines():
        match = re.match(r'^  (?:"([^"]+)"|([A-Za-z_-]+)):', line)
        if match:
            keys.add(match.group(1) or match.group(2))
    assert keys == allowed | {"*"}, (name, keys)
    for tool in allowed - {"bash", "task", "skill"}:
        action = "ask" if name in {"investigator", "architect"} and tool == "external_directory" else "allow"
        assert re.search(rf'^  {re.escape(tool)}: {action}$', permission, re.MULTILINE)
    if name in {"integration", "reviewer"}:
        assert '  skill:\n    "*": allow\n    terminal-mermaid: deny' in permission
        assert "create or include diagrams" in text
    else:
        assert re.search(r'^  skill: allow$', permission, re.MULTILINE)

for name, forbidden in {
    "integration": {"orchestrator", "reviewer", "worker", "planner", "architect", "orchestration", "routing", "delegate"},
    "investigator": {"orchestrator", "reviewer", "worker", "planner", "architect", "orchestration", "routing", "delegate"},
    "reviewer": {"orchestrator", "worker", "planner", "architect", "orchestration", "routing", "delegate"},
    "worker": {"orchestrator", "reviewer", "planner", "architect", "orchestration", "routing", "delegate"},
    "architect": {"orchestrator", "reviewer", "worker", "orchestration", "routing", "delegate"},
    "planner": {"orchestrator", "reviewer", "worker", "architect", "orchestration", "routing", "delegate"},
}.items():
    identity = (directory / f"{name}.md").read_text().split("---", 2)[2].lower()
    assert not forbidden.intersection(identity), (name, forbidden.intersection(identity))

read_only_git = r'    "git diff": allow\n    "git diff \*": allow\n    "git status": allow\n    "git status \*": allow\n    "git log": allow\n    "git log \*": allow\n    "git show": allow\n    "git show \*": allow'
worker = (directory / "worker.md").read_text()
assert re.search(r'^  bash:\n    "\*": allow\n    git: deny\n    "git \*": deny\n' + read_only_git, worker, re.MULTILINE)
orchestrator = (directory / "orchestrator.md").read_text()
assert '  task:\n    "*": deny\n    integration: allow\n    investigator: allow\n    reviewer: allow' in orchestrator
assert 'Every primary Architect launch must use `~/.local/bin/herdr-agent-launch architect sibling <architect-name>` from the current Herdr pane.' in orchestrator
assert "Do not use Herdr's raw agent-start command or a manual split-start recipe for primary Architect creation." in orchestrator
architect = (directory / "architect.md").read_text()
assert '  task:\n    "*": deny\n    planner: allow' in architect
assert 'architect: allow' not in orchestrator
assert 'worker: allow' not in orchestrator
for name in ("worker", "architect", "reviewer"):
    identity = (directory / f"{name}.md").read_text().split("---", 2)[2].lower()
    assert "`ponytail` skill" in identity, name
PY
  for built_in in build plan general explore scout; do
    test ! -e "$directory/$built_in.md"
  done
}

assert_herdr_agent_launcher() {
  local launcher="$source_dir/dot_local/bin/executable_herdr-agent-launch"
  local test_dir="$root/herdr-agent-launch"
  local fake_bin="$test_dir/bin"
  local canned="$test_dir/canned"
  local log="$test_dir/herdr.log"
  local worktree="$test_dir/worktree"
  local process_repo="$test_dir/process-repo"
  local pane_repo="$test_dir/pane-repo"
  mkdir -p "$fake_bin" "$canned"
  mkdir -p "$process_repo" "$pane_repo"
  git -C "$process_repo" init --quiet
  git -C "$pane_repo" init --quiet
  process_repo=$(git -C "$process_repo" rev-parse --show-toplevel)

  cat >"$canned/caller.json" <<EOF
{"result":{"type":"pane_current","pane":{"pane_id":"w1:p1","terminal_id":"term1","workspace_id":"w1","tab_id":"w1:t1","focused":true,"cwd":"$pane_repo","agent_status":"working","revision":1}}}
EOF
  cat >"$canned/split.json" <<EOF
{"result":{"type":"pane_info","pane":{"pane_id":"w1:p2","terminal_id":"term2","workspace_id":"w1","tab_id":"w1:t1","focused":false,"cwd":"$pane_repo","agent_status":"idle","revision":2}}}
EOF
  cat >"$canned/rename.json" <<'EOF'
{"result":{"type":"pane_info"}}
EOF
  cat >"$canned/tab.json" <<EOF
{"result":{"type":"tab_created","tab":{"tab_id":"w1:t2","workspace_id":"w1","number":2,"label":"worker","focused":false,"pane_count":1,"agent_status":"idle"},"root_pane":{"pane_id":"w1:p3","terminal_id":"term3","workspace_id":"w1","tab_id":"w1:t2","focused":false,"cwd":"$pane_repo","agent_status":"idle","revision":3}}}
EOF
  cat >"$canned/worktree.json" <<EOF
{"result":{"type":"worktree_created","workspace":{"workspace_id":"w2","number":2,"label":"worker-agent","focused":false,"pane_count":1,"tab_count":1,"active_tab_id":"w2:t1","agent_status":"idle","worktree":{"repo_key":"process-repo","repo_name":"process-repo","repo_root":"$process_repo","checkout_path":"$worktree","is_linked_worktree":true}},"tab":{"tab_id":"w2:t1","workspace_id":"w2","number":1,"label":"worker","focused":false,"pane_count":1,"agent_status":"idle"},"root_pane":{"pane_id":"w2:p1","terminal_id":"term4","workspace_id":"w2","tab_id":"w2:t1","focused":false,"cwd":"$worktree","agent_status":"idle","revision":4},"worktree":{"path":"$worktree","branch":"worker","is_bare":false,"is_detached":false,"is_prunable":false,"is_linked_worktree":true,"open_workspace_id":"w2","label":"worker"}}}
EOF
  cat >"$canned/start.json" <<EOF
{"result":{"type":"agent_started","agent":{"terminal_id":"term-agent","name":"worker-agent","agent":"opencode","agent_status":"idle","workspace_id":"w1","tab_id":"w1:t2","pane_id":"w1:p3","focused":false,"launch_pending":false,"interactive_ready":true,"cwd":"$pane_repo","revision":5},"argv":["opencode","--agent","ROLE"]}}
EOF
  cat >"$canned/get.json" <<EOF
{"result":{"type":"agent_info","agent":{"terminal_id":"term-agent","name":"worker-agent","agent":"opencode","agent_status":"idle","workspace_id":"w1","tab_id":"w1:t2","pane_id":"w1:p3","focused":false,"interactive_ready":true,"cwd":"$pane_repo","revision":6}}}
EOF
  cat >"$fake_bin/herdr" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >>"$FAKE_HERDR_LOG"
case "$1 $2" in
  "pane current") file=caller.json ;;
  "pane split") file=split.json ;;
  "pane rename") file=rename.json ;;
  "tab create") file=tab.json ;;
  "worktree create"|"worktree open") file=worktree.json ;;
  "agent start") file=start.json ;;
  "agent get") file=get.json ;;
  *) printf '{"error":{"code":"unexpected","message":"unexpected command"}}\n'; exit 1 ;;
esac
case "${FAKE_HERDR_FAILURE:-}:$1 $2" in
  malformed:"pane current") printf 'not json\n'; exit 0 ;;
  wrong-type:"pane current") jq '.result.type = "wrong"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  missing:"pane split") jq 'del(.result.pane.cwd)' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-placement:"pane split") jq '.result.pane.workspace_id = "w9"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-focus:"tab create") jq '.result.root_pane.focused = true' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-worktree:"worktree create") jq '.result.worktree.path = "/wrong"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-worktree:"worktree open") jq '.result.type = "worktree_opened" | .result.worktree.path = "/wrong"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-repository:"worktree create") jq '.result.workspace.worktree.repo_root = "/wrong-repository"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-repository:"worktree open") jq '.result.type = "worktree_opened" | .result.workspace.worktree.repo_root = "/wrong-repository"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-label:"worktree create") jq '.result.workspace.label = "other-agent"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-label:"worktree open") jq '.result.type = "worktree_opened" | .result.workspace.label = "other-agent"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-argv:"agent start") jq '.result.argv = ["opencode", "--agent", "investigator"]' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-identity:"agent get") jq '.result.agent.name = "other-agent"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
esac
if [[ "$1 $2" == "worktree open" ]]; then
  output=$(jq '.result.type = "worktree_opened"' "$FAKE_HERDR_CANNED/$file")
else
  output=$(<"$FAKE_HERDR_CANNED/$file")
fi
if [[ "$1 $2" == "worktree create" || "$1 $2" == "worktree open" ]]; then
  # The caller workspace represents a different repository in this fixture.
  test "$3 $4" = "--cwd $FAKE_HERDR_SOURCE_REPO" || { printf 'worktree repository selector mismatch\n' >&2; exit 1; }
  test "$7 $8" = "--label worker-agent" || { printf 'worktree label argument mismatch\n' >&2; exit 1; }
fi
if [[ "$1 $2" == "agent start" || "$1 $2" == "agent get" ]]; then
  output=$(printf '%s\n' "$output" | jq \
    --arg name "$FAKE_HERDR_NAME" --arg workspace "$FAKE_HERDR_WORKSPACE" \
    --arg tab "$FAKE_HERDR_TAB" --arg pane "$FAKE_HERDR_PANE" --arg cwd "$FAKE_HERDR_CWD" \
    '.result.agent.name = $name | .result.agent.workspace_id = $workspace |
     .result.agent.tab_id = $tab | .result.agent.pane_id = $pane |
     .result.agent.cwd = $cwd')
fi
printf '%s\n' "$output" | sed "s/ROLE/$FAKE_HERDR_ROLE/g"
EOF
  chmod +x "$fake_bin/herdr"

  run_launcher() {
    local role=$1 topology=$2 name=$3
    shift 3
    local launcher_path=${1:-}
    local -a launcher_args=("$role" "$topology" "$name")
    [[ -n "$launcher_path" ]] && launcher_args+=("$launcher_path")
    local fake_workspace=w1 fake_tab=w1:t2 fake_pane=w1:p3 fake_cwd=$pane_repo
    case "$topology" in
      sibling) fake_tab=w1:t1; fake_pane=w1:p2 ;;
      worktree) fake_workspace=w2; fake_tab=w2:t1; fake_pane=w2:p1; fake_cwd=$worktree ;;
    esac
    : >"$log"
    (
      CDPATH= cd -- "$process_repo"
      PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t1 HERDR_PANE_ID=w1:p1 \
        FAKE_HERDR_FAILURE="${FAKE_HERDR_FAILURE:-}" \
        FAKE_HERDR_LOG="$log" FAKE_HERDR_CANNED="$canned" FAKE_HERDR_ROLE="$role" \
        FAKE_HERDR_SOURCE_REPO="$process_repo" \
        FAKE_HERDR_NAME="$name" FAKE_HERDR_WORKSPACE="$fake_workspace" \
        FAKE_HERDR_TAB="$fake_tab" FAKE_HERDR_PANE="$fake_pane" FAKE_HERDR_CWD="$fake_cwd" \
        bash "$launcher" "${launcher_args[@]}"
    )
  }

  metadata=$(run_launcher architect sibling architect-agent)
  jq -e --arg cwd "$pane_repo" ' . == {role:"architect",topology:"sibling",agent_name:"architect-agent",agent_kind:"opencode",workspace_id:"w1",tab_id:"w1:t1",pane_id:"w1:p2",cwd:$cwd}' <<<"$metadata" >/dev/null
  assert_contains "$log" "pane split --current --direction right --cwd $pane_repo --no-focus"
  test "$(grep -Fc 'pane rename ' "$log")" -eq 2
  grep -Fxq 'pane rename w1:p1 orchestrator' "$log"
  grep -Fxq 'pane rename w1:p2 architect' "$log"
  assert_contains "$log" 'agent start architect-agent --kind opencode --pane w1:p2 -- --agent architect'

  metadata=$(run_launcher worker tab worker-agent)
  jq -e --arg cwd "$pane_repo" ' . == {role:"worker",topology:"tab",agent_name:"worker-agent",agent_kind:"opencode",workspace_id:"w1",tab_id:"w1:t2",pane_id:"w1:p3",cwd:$cwd}' <<<"$metadata" >/dev/null
  assert_contains "$log" "tab create --workspace w1 --cwd $pane_repo --no-focus"
  assert_contains "$log" 'agent start worker-agent --kind opencode --pane w1:p3 -- --agent worker'

  metadata=$(run_launcher worker worktree worker-agent "$worktree")
  jq -e --arg path "$worktree" ' . == {role:"worker",topology:"worktree",agent_name:"worker-agent",agent_kind:"opencode",workspace_id:"w2",tab_id:"w2:t1",pane_id:"w2:p1",cwd:$path,worktree_path:$path}' <<<"$metadata" >/dev/null
  assert_contains "$log" "worktree create --cwd $process_repo --path $worktree --label worker-agent --no-focus"
  assert_contains "$log" 'agent start worker-agent --kind opencode --pane w2:p1 -- --agent worker'

  : >"$log"
  if FAKE_HERDR_FAILURE=wrong-label run_launcher worker worktree worker-agent "$worktree" >/dev/null 2>&1; then exit 1; fi
  assert_not_contains "$log" 'agent start '

  mkdir -p "$worktree"
  metadata=$(run_launcher worker worktree worker-agent "$worktree")
  jq -e --arg path "$worktree" '.worktree_path == $path' <<<"$metadata" >/dev/null
  assert_contains "$log" "worktree open --cwd $process_repo --path $worktree --label worker-agent --no-focus"

  : >"$log"
  if FAKE_HERDR_FAILURE=wrong-label run_launcher worker worktree worker-agent "$worktree" >/dev/null 2>&1; then exit 1; fi
  assert_not_contains "$log" 'agent start '

  : >"$log"
  if PATH="$fake_bin:$PATH" HERDR_ENV=1 FAKE_HERDR_LOG="$log" bash "$launcher" worker sibling bad-name 2>/dev/null; then exit 1; fi
  test ! -s "$log"
  if PATH="$fake_bin:$PATH" HERDR_ENV=1 FAKE_HERDR_LOG="$log" bash "$launcher" reviewer tab reviewer-agent 2>/dev/null; then exit 1; fi
  test ! -s "$log"
  if PATH="$fake_bin:$PATH" HERDR_ENV=1 FAKE_HERDR_LOG="$log" bash "$launcher" worker worktree worker-agent relative 2>/dev/null; then exit 1; fi
  test ! -s "$log"
  if PATH="$fake_bin:$PATH" HERDR_ENV=0 bash "$launcher" worker tab worker-agent 2>/dev/null; then exit 1; fi
  test ! -s "$log"

  for failure in malformed wrong-type; do
    : >"$log"
    if FAKE_HERDR_FAILURE=$failure PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t1 HERDR_PANE_ID=w1:p1 \
      FAKE_HERDR_LOG="$log" FAKE_HERDR_CANNED="$canned" FAKE_HERDR_ROLE=worker \
      FAKE_HERDR_NAME=worker-agent FAKE_HERDR_WORKSPACE=w1 FAKE_HERDR_TAB=w1:t2 FAKE_HERDR_PANE=w1:p3 FAKE_HERDR_CWD="$pane_repo" \
      bash "$launcher" worker tab worker-agent 2>/dev/null; then exit 1; fi
  done
  for failure in missing wrong-placement; do
    : >"$log"
    if FAKE_HERDR_FAILURE=$failure PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t1 HERDR_PANE_ID=w1:p1 \
      FAKE_HERDR_LOG="$log" FAKE_HERDR_CANNED="$canned" FAKE_HERDR_ROLE=architect \
      bash "$launcher" architect sibling architect-agent 2>/dev/null; then exit 1; fi
  done
  for failure in wrong-focus wrong-argv wrong-identity; do
    : >"$log"
    if FAKE_HERDR_FAILURE=$failure PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t1 HERDR_PANE_ID=w1:p1 \
      FAKE_HERDR_LOG="$log" FAKE_HERDR_CANNED="$canned" FAKE_HERDR_ROLE=worker \
      FAKE_HERDR_NAME=worker-agent FAKE_HERDR_WORKSPACE=w1 FAKE_HERDR_TAB=w1:t2 FAKE_HERDR_PANE=w1:p3 FAKE_HERDR_CWD="$pane_repo" \
      bash "$launcher" worker tab worker-agent 2>/dev/null; then exit 1; fi
  done
  for failure in wrong-worktree wrong-repository; do
    : >"$log"
    if FAKE_HERDR_FAILURE=$failure PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t1 HERDR_PANE_ID=w1:p1 \
    FAKE_HERDR_LOG="$log" FAKE_HERDR_CANNED="$canned" FAKE_HERDR_ROLE=worker \
    FAKE_HERDR_SOURCE_REPO="$process_repo" \
    FAKE_HERDR_NAME=worker-agent FAKE_HERDR_WORKSPACE=w2 FAKE_HERDR_TAB=w2:t1 FAKE_HERDR_PANE=w2:p1 \
    FAKE_HERDR_CWD="$worktree" bash "$launcher" worker worktree worker-agent "$worktree" 2>/dev/null; then exit 1; fi
    assert_not_contains "$log" 'agent start '
  done
}

assert_herdr_agent_launcher

assert_contains "$source_dir/README.md" '`wbd` is always Hub-only'
assert_contains "$source_dir/README.md" '`beads-hub` and `beads-hub-closeout` skills'
assert_contains "$source_dir/README.md" 'atomically installs `bd`, `bv`, `wbd`, and `wbv`'
assert_contains "$source_dir/README.md" '`~/.local/libexec/beads-viewer`'
assert_contains "$source_dir/README.md" '~/.local/libexec/beads-viewer/migrate-beads-hub-prefix.sh'
assert_contains "$source_dir/README.md" 'Disabling the module stops future installation and management without deleting'
python3 -c 'import json,tomllib,sys; source=sys.argv[1]; pins=tomllib.load(open(source+"/.chezmoidata.toml", "rb"))["pins"]; config=json.load(open(source+"/renovate.json")); managers=config["customManagers"]; assert pins["beads"]["branch"] == "feat/bulk-history-read"; assert pins["beadsViewer"]["branch"] == "feature/repository-aware-correlations"; runtime=[manager for manager in managers if manager.get("depTypeTemplate") == "beads-runtime" and manager.get("datasourceTemplate") == "git-refs"]; assert len(runtime) == 2; assert any(rule.get("groupName") == "Beads runtime" for rule in config["packageRules"])' "$source_dir"
beads_ref=$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1], "rb"))["pins"]["beads"]["ref"])' "$source_dir/.chezmoidata.toml")
beads_viewer_ref=$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1], "rb"))["pins"]["beadsViewer"]["ref"])' "$source_dir/.chezmoidata.toml")
ponytail_ref=$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1], "rb"))["pins"]["ponytailSkill"])' "$source_dir/.chezmoidata.toml")

assert_warp_policy() {
  local file=$1
  python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); keys=data["terminal"]["input"]["extra_meta_keys"]; assert keys["left_alt"] is True; assert keys["right_alt"] is False' "$file"
}

starship_test_dir="$root/starship-init"
mkdir -p "$starship_test_dir/bin" "$starship_test_dir/home"
cat >"$starship_test_dir/bin/starship" <<'EOF'
#!/bin/sh
test "$1 $2" = "init zsh" && printf 'STARSHIP_TEST_INITIALIZED=1\n'
EOF
chmod +x "$starship_test_dir/bin/starship"

starship_init_state() {
  HOME="$starship_test_dir/home" \
    PATH="$starship_test_dir/bin:$PATH" \
    TERM_PROGRAM=$1 \
    HERDR_ENV=$2 \
    STARSHIP_SOURCE="$source_dir/dot_config/zsh/starship.zsh" \
    zsh -dfc 'source "$STARSHIP_SOURCE"; printf "%s|%s|%s\n" "${STARSHIP_TEST_INITIALIZED:-0}" "${TRANSIENT_PROMPT_PROMPT-unset}" "${TRANSIENT_PROMPT_RPROMPT-unset}"'
}

test "$(starship_init_state WarpTerminal '')" = '0||'
test "$(starship_init_state WarpTerminal 1)" = '1|unset|unset'
test "$(starship_init_state Apple_Terminal '')" = '1|unset|unset'

warp_dir="$root/warp-modifier"
mkdir -p "$warp_dir"

run_warp_case() {
  local name=$1
  local before="$warp_dir/$name.before"
  local after="$warp_dir/$name.after"
  local second="$warp_dir/$name.second"
  sh "$source_dir/dot_warp/modify_settings.toml" <"$before" >"$after"
  assert_warp_policy "$after"
  sh "$source_dir/dot_warp/modify_settings.toml" <"$after" >"$second"
  cmp -s "$after" "$second"
}

: >"$warp_dir/empty.before"
run_warp_case empty
cat >"$warp_dir/empty.expected" <<'EOF'
[terminal.input.extra_meta_keys]
left_alt = true
right_alt = false
EOF
cmp -s "$warp_dir/empty.expected" "$warp_dir/empty.after"

cat >"$warp_dir/unrelated.before" <<'EOF'
# Keep this comment and spacing exactly.
[appearance]
theme = "Machine-specific theme"

[privacy]
telemetry = false
EOF
run_warp_case unrelated
assert_contains "$warp_dir/unrelated.after" '# Keep this comment and spacing exactly.'
assert_contains "$warp_dir/unrelated.after" 'theme = "Machine-specific theme"'
assert_contains "$warp_dir/unrelated.after" 'telemetry = false'
python3 -c 'import sys; before=open(sys.argv[1], "rb").read(); after=open(sys.argv[2], "rb").read(); policy=b"\n[terminal.input.extra_meta_keys]\nleft_alt = true\nright_alt = false\n"; assert after == before + policy' "$warp_dir/unrelated.before" "$warp_dir/unrelated.after"

cat >"$warp_dir/opposite.before" <<'EOF'
[terminal.input.extra_meta_keys]
left_alt = false # Warp default
right_alt = true

[editor]
font_size = 14
EOF
run_warp_case opposite
assert_contains "$warp_dir/opposite.after" 'left_alt = true # Warp default'
assert_contains "$warp_dir/opposite.after" 'right_alt = false'
assert_contains "$warp_dir/opposite.after" 'font_size = 14'

cat >"$warp_dir/missing.before" <<'EOF'
[terminal.input.extra_meta_keys]
left_alt = true

[terminal]
copy_on_select = true
EOF
run_warp_case missing
test "$(grep -Fc 'left_alt = true' "$warp_dir/missing.after")" -eq 1
test "$(grep -Fc 'right_alt = false' "$warp_dir/missing.after")" -eq 1
assert_contains "$warp_dir/missing.after" 'copy_on_select = true'

assert_contains "$source_dir/scripts/backup-paths.txt" '.config/ghostty'
assert_contains "$source_dir/scripts/backup-paths.txt" 'Library/Application Support/com.mitchellh.ghostty/config'
test "$(grep -Fxc '.config/helix' "$source_dir/scripts/backup-paths.txt")" -eq 1
test "$(grep -Fxc '.warp/settings.toml' "$source_dir/scripts/backup-paths.txt")" -eq 1

backup_home="$root/backup-home"
backup_destination="$root/backup-output"
mkdir -p "$backup_home/.warp"
printf '%s\n' '[privacy]' 'telemetry = false' >"$backup_home/.warp/settings.toml"
printf '%s\n' 'synthetic runtime state' >"$backup_home/.warp/runtime-state"
HOME="$backup_home" sh "$source_dir/scripts/backup-home-paths.sh" --destination "$backup_destination"
cmp -s "$backup_home/.warp/settings.toml" "$backup_destination/.warp/settings.toml"
test ! -e "$backup_destination/.warp/runtime-state"

migration_dir="$root/zshrc-migration"
mkdir -p "$migration_dir"
cat >"$migration_dir/before" <<'EOF'
ZSH_THEME="agnoster"
# >>> portable chezmoi setup >>>
source "$HOME/.config/zsh/portable.zsh"
# <<< portable chezmoi setup <<<
EOF
sh "$source_dir/modify_dot_zshrc" <"$migration_dir/before" >"$migration_dir/after"
sh "$source_dir/modify_dot_zshrc" <"$migration_dir/after" >"$migration_dir/second-apply"
cmp -s "$migration_dir/after" "$migration_dir/second-apply"
test "$(grep -Fc '# >>> portable chezmoi early setup >>>' "$migration_dir/after")" -eq 1
test "$(grep -Fc '# >>> portable chezmoi setup >>>' "$migration_dir/after")" -eq 1
test "$(grep -Fc 'ZSH_THEME="agnoster"' "$migration_dir/after")" -eq 1

agents_modifier_dir="$root/agents-modifier"
mkdir -p "$agents_modifier_dir"
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/work.toml" \
  <"$source_dir/dot_config/opencode/modify_AGENTS.md.tmpl" >"$agents_modifier_dir/enabled.sh"
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/ghostty-only.toml" \
  <"$source_dir/dot_config/opencode/modify_AGENTS.md.tmpl" >"$agents_modifier_dir/disabled.sh"
sh -n "$agents_modifier_dir/enabled.sh"
sh -n "$agents_modifier_dir/disabled.sh"

cat >"$agents_modifier_dir/balanced.before" <<'EOF'
# Existing guidance
<!-- portable-work-beads:start -->
replace this managed text
<!-- portable-work-beads:end -->
Preserve this trailing guidance.
EOF
sh "$agents_modifier_dir/enabled.sh" \
  <"$agents_modifier_dir/balanced.before" >"$agents_modifier_dir/balanced.after"
assert_contains "$agents_modifier_dir/balanced.after" '# Existing guidance'
assert_contains "$agents_modifier_dir/balanced.after" 'Preserve this trailing guidance.'
assert_contains "$agents_modifier_dir/balanced.after" 'load the global `beads-hub` skill before acting'
assert_contains "$agents_modifier_dir/balanced.after" 'use only `wbd` and approved `wbv --robot-*` queries'
assert_contains "$agents_modifier_dir/balanced.after" 'never raw `bd`, `bv`, or `br`'
assert_contains "$agents_modifier_dir/balanced.after" 'Commit correlation and Bead closure must not occur during implementation, commit, push, or PR creation. Perform both only after the change is merged, through the `beads-hub-closeout` workflow.'
assert_not_contains "$agents_modifier_dir/balanced.after" 'replace this managed text'
test "$(grep -Fc '<!-- portable-beads-hub:start -->' "$agents_modifier_dir/balanced.after")" -eq 1
assert_not_contains "$agents_modifier_dir/balanced.after" 'portable-work-beads:start'
sh "$agents_modifier_dir/enabled.sh" \
  <"$agents_modifier_dir/balanced.after" >"$agents_modifier_dir/balanced.second"
cmp -s "$agents_modifier_dir/balanced.after" "$agents_modifier_dir/balanced.second"

sh "$agents_modifier_dir/disabled.sh" \
  <"$agents_modifier_dir/balanced.after" >"$agents_modifier_dir/disabled.after"
assert_contains "$agents_modifier_dir/disabled.after" '# Existing guidance'
assert_contains "$agents_modifier_dir/disabled.after" 'Preserve this trailing guidance.'
assert_not_contains "$agents_modifier_dir/disabled.after" 'portable-work-beads:start'
assert_not_contains "$agents_modifier_dir/disabled.after" 'portable-beads-hub:start'
assert_not_contains "$agents_modifier_dir/disabled.after" 'beads-hub` skill'

assert_malformed_agents() {
  local name=$1
  if sh "$agents_modifier_dir/enabled.sh" \
    <"$agents_modifier_dir/$name.before" \
    >"$agents_modifier_dir/$name.after" \
    2>"$agents_modifier_dir/$name.err"; then
    printf 'expected malformed AGENTS markers to fail: %s\n' "$name" >&2
    exit 1
  fi
  cmp -s "$agents_modifier_dir/$name.before" "$agents_modifier_dir/$name.after"
  assert_contains "$agents_modifier_dir/$name.err" 'beads-hub AGENTS modifier:'
}

cat >"$agents_modifier_dir/unmatched-start.before" <<'EOF'
Preserve before unmatched start.
<!-- portable-beads-hub:start -->
Preserve after unmatched start.
EOF
assert_malformed_agents unmatched-start
assert_contains "$agents_modifier_dir/unmatched-start.err" 'unmatched start marker'

cat >"$agents_modifier_dir/orphan-end.before" <<'EOF'
Preserve before orphan end.
<!-- portable-beads-hub:end -->
Preserve after orphan end.
EOF
assert_malformed_agents orphan-end
assert_contains "$agents_modifier_dir/orphan-end.err" 'orphan end marker'

cat >"$agents_modifier_dir/nested-start.before" <<'EOF'
<!-- portable-beads-hub:start -->
Preserve inside outer marker.
<!-- portable-beads-hub:start -->
Preserve inside nested marker.
<!-- portable-beads-hub:end -->
<!-- portable-beads-hub:end -->
EOF
assert_malformed_agents nested-start
assert_contains "$agents_modifier_dir/nested-start.err" 'nested start marker'

cat >"$agents_modifier_dir/duplicate-balanced.before" <<'EOF'
<!-- portable-beads-hub:start -->
First managed block.
<!-- portable-beads-hub:end -->
Preserve content between blocks.
<!-- portable-beads-hub:start -->
Second managed block.
<!-- portable-beads-hub:end -->
EOF
assert_malformed_agents duplicate-balanced
assert_contains "$agents_modifier_dir/duplicate-balanced.err" 'multiple managed blocks'

printf '%s\r\n' \
  'Preserve CRLF before.' \
  '<!-- portable-work-beads:start -->' \
  'Replace CRLF managed text.' \
  '<!-- portable-work-beads:end -->' \
  'Preserve CRLF after.' >"$agents_modifier_dir/crlf.before"
sh "$agents_modifier_dir/enabled.sh" \
  <"$agents_modifier_dir/crlf.before" >"$agents_modifier_dir/crlf.after"
assert_not_contains "$agents_modifier_dir/crlf.after" 'Replace CRLF managed text.'
test "$(grep -Fc '<!-- portable-beads-hub:start -->' "$agents_modifier_dir/crlf.after")" -eq 1
assert_not_contains "$agents_modifier_dir/crlf.after" 'portable-work-beads:start'
python3 -c 'import sys; data=open(sys.argv[1], "rb").read(); assert b"Preserve CRLF before.\r\nPreserve CRLF after.\r\n" in data' "$agents_modifier_dir/crlf.after"
sh "$agents_modifier_dir/enabled.sh" \
  <"$agents_modifier_dir/crlf.after" >"$agents_modifier_dir/crlf.second"
cmp -s "$agents_modifier_dir/crlf.after" "$agents_modifier_dir/crlf.second"

sh "$agents_modifier_dir/disabled.sh" \
  <"$agents_modifier_dir/crlf.before" >"$agents_modifier_dir/crlf.disabled"
printf '%s\r\n' 'Preserve CRLF before.' 'Preserve CRLF after.' >"$agents_modifier_dir/crlf.expected"
cmp -s "$agents_modifier_dir/crlf.expected" "$agents_modifier_dir/crlf.disabled"

prompt_config_dir="$root/prompt-config"
mkdir -p "$prompt_config_dir"
chezmoi execute-template --init \
  --source "$source_dir" \
  --config "$source_dir/tests/fixtures/personal.toml" \
  --promptBool 'Enable the Beads module=true' \
  --promptBool 'Enable the OpenCode Beads integration=true' \
  <"$source_dir/.chezmoi.toml.tmpl" >"$prompt_config_dir/personal.toml"
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb"))["data"]; assert data["modules"]["beads"] is True; assert data["integrations"]["opencodeBeads"] is True' "$prompt_config_dir/personal.toml"
chezmoi execute-template --init \
  --source "$source_dir" \
  --config "$prompt_config_dir/personal.toml" \
  --promptBool 'Enable the Beads module=true' \
  --promptBool 'Enable the OpenCode Beads integration=false' \
  <"$source_dir/.chezmoi.toml.tmpl" >"$prompt_config_dir/personal-second.toml"
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb"))["data"]; assert data["modules"]["beads"] is True; assert data["integrations"]["opencodeBeads"] is False' "$prompt_config_dir/personal-second.toml"
chezmoi execute-template --init \
  --source "$source_dir" \
  --config "$source_dir/tests/fixtures/work.toml" \
  --promptBool 'Enable the Beads module=false' \
  <"$source_dir/.chezmoi.toml.tmpl" >"$prompt_config_dir/work-disabled.toml"
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb"))["data"]; assert data["modules"]["beads"] is False; assert data["integrations"]["opencodeBeads"] is False' "$prompt_config_dir/work-disabled.toml"
chezmoi execute-template --init \
  --source "$source_dir" \
  --config "$source_dir/tests/fixtures/work.toml" \
  --promptBool 'Enable the Beads module=true' \
  --promptBool 'Enable the OpenCode Beads integration=false' \
  <"$source_dir/.chezmoi.toml.tmpl" >"$prompt_config_dir/work-integration-disabled.toml"
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb"))["data"]; assert data["modules"]["beads"] is True; assert data["integrations"]["opencodeBeads"] is False' "$prompt_config_dir/work-integration-disabled.toml"

personal_home="$root/personal/home"
render_scripts personal
assert_ponytail_external "$root/personal/rendered/externals.toml"
assert_not_contains "$root/personal/rendered/externals.toml" '.config/opencode/skills/beads-hub/SKILL.md'
assert_not_contains "$root/personal/rendered/externals.toml" '.config/opencode/skills/beads-hub-closeout/SKILL.md'
assert_not_contains "$root/personal/rendered/externals.toml" '.config/opencode/skills/beads-hub-closeout/validate.sh'
assert_contains "$root/personal/rendered/Brewfile" 'brew "eza"'
assert_contains "$root/personal/rendered/Brewfile" 'brew "helix"'
assert_contains "$root/personal/rendered/Brewfile" 'cask "lm-studio"'
assert_contains "$root/personal/rendered/Brewfile" 'brew "elio"'
assert_contains "$root/personal/rendered/Brewfile" 'brew "glow"'
assert_not_contains "$root/personal/rendered/Brewfile" 'brew "beads"'
assert_not_contains "$root/personal/rendered/Brewfile" 'brew "beads_viewer"'
assert_not_contains "$root/personal/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'Angel-O/beads'
assert_not_contains "$root/personal/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'Angel-O/beads_viewer'
assert_contains "$root/personal/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'exit 0'
assert_not_contains "$root/personal/rendered/Brewfile" 'brew "bat"'
assert_not_contains "$root/personal/rendered/Brewfile" 'brew "git-delta"'
assert_contains "$source_dir/.chezmoi.toml.tmpl" 'sourceDir = {{ .chezmoi.sourceDir | quote }}'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin thomasschafer.herdr-kiosk "thomasschafer/herdr-kiosk"'
assert_not_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'den-tanui/herdr-zoxide'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin ez-corp.space-usage "ezcorp-org/herdr-pc-ram-and-cpu-usage-overlay"'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin robert-flo.elio "robert-flo/herdr-terminal-file-manager"'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'reviewr_root="$HOME/workspace/source/herdr-reviewr"'
assert_contains "$root/personal/rendered/run_after_40-install-herdr-integrations.sh.tmpl" 'herdr integration install opencode'
assert_not_contains "$root/personal/rendered/run_after_40-install-herdr-integrations.sh.tmpl" 'herdr integration status'
assert_not_contains "$root/personal/rendered/run_after_40-install-herdr-integrations.sh.tmpl" 'codex completion'
mkdir -p "$personal_home/.config/opencode" "$personal_home/.local/bin" \
  "$personal_home/.local/libexec/beads-viewer"
printf '%s\n' preserved-wbd >"$personal_home/.local/bin/wbd"
printf '%s\n' preserved-wbv >"$personal_home/.local/bin/wbv"
printf '%s\n' preserved-migration >"$personal_home/.local/libexec/beads-viewer/migrate-beads-hub-prefix.sh"
cat >"$personal_home/.config/opencode/AGENTS.md" <<'EOF'
Keep this personal instruction.
<!-- portable-work-beads:start -->
stale managed content
<!-- portable-work-beads:end -->
EOF
apply_fixture personal

test -f "$personal_home/.config/ghostty/config"
launcher_transition_home="$root/launcher-transition/home"
mkdir -p "$launcher_transition_home"
chezmoi apply --source "$source_dir" --destination "$launcher_transition_home" \
  --config "$source_dir/tests/fixtures/personal.toml" --cache "$root/launcher-transition/cache" \
  --persistent-state "$root/launcher-transition/state.boltdb" --exclude scripts,externals --force
test -x "$launcher_transition_home/.local/bin/herdr-agent-launch"
chezmoi execute-template --source "$source_dir" \
  --config "$source_dir/tests/fixtures/external-opencode-beads.toml" \
  <"$source_dir/.chezmoiremove.tmpl" >"$root/launcher-transition/remove-list"
grep -Fxq '.local/bin/herdr-agent-launch' "$root/launcher-transition/remove-list"
test -f "$personal_home/.config/helix/config.toml"
assert_contains "$personal_home/.config/helix/config.toml" 'theme = "dracula_at_night"'
test -f "$personal_home/.warp/settings.toml"
assert_warp_policy "$personal_home/.warp/settings.toml"
assert_contains "$personal_home/.config/ghostty/config" 'macos-option-as-alt = true'
assert_contains "$personal_home/.config/herdr/plugins/config/ez-corp.space-usage/config.toml" 'interval_seconds = 30'
assert_contains "$personal_home/.config/herdr/plugins/config/ez-corp.space-usage/config.toml" 'window_title_totals = false'
assert_contains "$personal_home/.config/herdr/plugins/config/ez-corp.space-usage/config.toml" 'ram_display = "absolute"'
assert_contains "$personal_home/.config/herdr/plugins/config/ez-corp.space-usage/config.toml" 'icons = "nerdfont"'
assert_contains "$personal_home/.config/herdr/config.toml" 'window_title = "{hostname}: {workspace}"'
assert_contains "$personal_home/.config/herdr/config.toml" 'rows = [["state_icon", "workspace", "agent"], ["state_text", { token = "tab", dim = false }]]'
assert_contains "$personal_home/.config/herdr/config.toml" 'command = "thomasschafer.herdr-kiosk.open-picker"'
assert_contains "$personal_home/.config/herdr/config.toml" 'key = "prefix+o"'
assert_not_contains "$personal_home/.config/herdr/config.toml" 'herdr-zoxide.browse'
test ! -e "$personal_home/.config/herdr/plugins/config/thomasschafer.herdr-kiosk/config.toml"
assert_contains "$personal_home/.config/herdr/config.toml" 'command = "robert-flo.elio.open"'
assert_contains "$personal_home/.config/herdr/plugins/config/persiyanov.reviewr/config.toml" 'file_markdown_renderer = "glow -s dracula -w {width} -"'
assert_not_contains "$personal_home/.config/herdr/config.toml" 'key = "prefix+m"'
assert_contains "$personal_home/.config/herdr-labels/config.toml" 'bv = "ai board"'
assert_contains "$personal_home/.config/herdr-labels/config.toml" 'wbv = "ai board"'
assert_contains "$personal_home/.config/zsh/starship.zsh" '[[ ${TERM_PROGRAM:-} == "WarpTerminal" && ${HERDR_ENV:-} != 1 ]]'
assert_contains "$personal_home/.config/zsh/starship.zsh" "TRANSIENT_PROMPT_PROMPT=''"
assert_contains "$personal_home/.config/zsh/starship.zsh" 'Keep completed prompts compact in every terminal, including Warp.'
test -f "$personal_home/.config/opencode/portable.jsonc"
test -f "$personal_home/.config/opencode/tui.jsonc"
test -x "$personal_home/.local/bin/herdr-agent-launch"
assert_contains "$personal_home/.config/opencode/tui.jsonc" '"./herdr-tui-session.js"'
assert_agent_contracts "$personal_home/.config/opencode/agents"
for agent in orchestrator integration investigator reviewer worker architect planner; do
  test -f "$personal_home/.config/opencode/agents/$agent.md"
done
assert_contains "$personal_home/.config/opencode/agents/integration.md" 'only supplied commands that are clearly repository-wide integration validation'
assert_contains "$personal_home/.config/opencode/agents/integration.md" 'Refuse and report a blocker for any supplied command that is outside or ambiguous'
assert_contains "$personal_home/.config/opencode/agents/integration.md" 'may perform its own internal setup or build steps'
assert_contains "$personal_home/.config/opencode/agents/integration.md" 'Report each exact command and result, including blockers and unrelated pre-existing failures.'
assert_not_contains "$personal_home/.config/opencode/agents/integration.md" 'full test suites'
assert_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'agent: orchestrator'
assert_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'Require every implementation, design, or review delegate to load `ponytail` in its own session.'
assert_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'Load the `herdr` skill.'
assert_contains "$personal_home/.config/opencode/commands/orchestrate.md" '~/.local/bin/herdr-agent-launch worker tab worker'
assert_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'herdr agent prompt worker "<contract>" --wait'
assert_contains "$personal_home/.config/opencode/commands/orchestrate.md" '~/.local/bin/herdr-agent-launch architect sibling <architect-name>'
assert_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'herdr agent prompt <architect-name> "<design-prompt>" --wait'
assert_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'Do not run `opencode` directly or pass model, variant, or reasoning flags'
assert_not_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'opencode --agent'
assert_not_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'opencode run'
assert_not_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'opencode -m'
assert_not_contains "$personal_home/.config/opencode/commands/orchestrate.md" ' --model'
assert_not_contains "$personal_home/.config/opencode/commands/orchestrate.md" ' --variant'
assert_not_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'reasoning-effort'
assert_not_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'reasoning effort'
assert_not_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'openai/gpt-'
assert_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'reuse it for every review and rereview'
python3 - "$personal_home/.config/opencode/commands/orchestrate.md" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
architecture = text.index('If the user selects architecture')
handoff = text.index('After worker handoff')
scope = text.index('## Scope And Complexity Gate')
for sentence in (
    'Invoke one `reviewer` subagent session and reuse it for every review and rereview.',
    'Send accepted findings to the worker; return corrected work to that same reviewer session.',
):
    position = text.index(sentence)
    assert architecture < handoff < position < scope
PY
assert_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'only supplied repository-wide integration-validation commands'
assert_not_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'repository-wide test commands'
assert_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'assign it generic formatting, linting, static tooling, build, unit-test, focused-test, or affected-scope checks'
assert_not_contains "$personal_home/.config/opencode/commands/orchestrate.md" 'herdr agent start'
assert_delivery_contract "$personal_home/.config/opencode/agents/orchestrator.md"
assert_delivery_contract "$personal_home/.config/opencode/commands/orchestrate.md"
assert_orchestration_reuse_contract "$personal_home/.config/opencode/agents/orchestrator.md"
assert_orchestration_reuse_contract "$personal_home/.config/opencode/commands/orchestrate.md"
assert_reference_branch_contract "$personal_home/.config/opencode/agents/orchestrator.md"
assert_reference_branch_contract "$personal_home/.config/opencode/commands/orchestrate.md"
assert_contains "$personal_home/.config/opencode/agents/orchestrator.md" 'Reuse the reviewer session sequentially for every review and rereview.'
assert_orchestration_reuse_contract "$source_dir/docs/opencode-agent-orchestration.md"
assert_reference_branch_contract "$source_dir/docs/opencode-agent-orchestration.md"
assert_contains "$personal_home/.config/opencode/agents/orchestrator.md" 'from the recorded worker worktree, not the orchestrator parent checkout'
cmp -s "$source_dir/dot_config/opencode/plugins/plan-diagrams.js" "$personal_home/.config/opencode/plugins/plan-diagrams.js"
cmp -s "$source_dir/dot_config/opencode/skills/plan-diagrams/SKILL.md" "$personal_home/.config/opencode/skills/plan-diagrams/SKILL.md"
cmp -s "$source_dir/dot_config/opencode/skills/terminal-mermaid/SKILL.md" "$personal_home/.config/opencode/skills/terminal-mermaid/SKILL.md"
assert_contains "$personal_home/.config/opencode/AGENTS.md" 'Keep this personal instruction.'
assert_not_contains "$personal_home/.config/opencode/AGENTS.md" 'portable-work-beads:start'
grep -Fxq preserved-wbd "$personal_home/.local/bin/wbd"
grep -Fxq preserved-wbv "$personal_home/.local/bin/wbv"
grep -Fxq preserved-migration "$personal_home/.local/libexec/beads-viewer/migrate-beads-hub-prefix.sh"
test ! -e "$personal_home/.config/opencode/skills/work-beads/SKILL.md"
test ! -e "$personal_home/.config/opencode/skills/beads-hub/SKILL.md"
test ! -e "$personal_home/.config/opencode/commands/orchestrate-bead.md"
test -L "$personal_home/.config/starship/current.toml"
test -f "$personal_home/.config/zsh/portable.zsh"
test -f "$personal_home/.config/zsh/git-worktrees.zsh"
assert_contains "$personal_home/.config/zsh/git-worktrees.zsh" "alias gwtl='git wtl'"
assert_contains "$personal_home/.config/zsh/git-worktrees.zsh" 'gwtco() {'
assert_contains "$personal_home/.config/zsh/git-worktrees.zsh" 'gwts() {'
assert_contains "$personal_home/.config/zsh/git-worktrees.zsh" 'cdmain() {'
assert_contains "$personal_home/.config/zsh/opencode.zsh" "alias warpconf='code ~/.warp/launch_configurations'"
test -f "$personal_home/.config/git/portable.inc"
test ! -e "$personal_home/README.md"
test ! -e "$personal_home/tests"
jq -e '.provider.openai and (.plugin | index("opencode-lmstudio@1.0.0-rc.2")) and (.plugin | index("opencode-mermaid-renderer@0.0.1")) and (.permission.skill == {"plan-diagrams": "deny"}) and (.agent.plan.permission.skill == {"plan-diagrams": "allow"}) and (.agent.title.model == "openai/gpt-5.4-mini")' "$personal_home/.config/opencode/portable.jsonc" >/dev/null
personal_managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/personal.toml" --include files)
printf '%s\n' "$personal_managed" | grep -Fxq '.config/opencode/skills/plan-diagrams/SKILL.md'
printf '%s\n' "$personal_managed" | grep -Fxq '.config/opencode/skills/terminal-mermaid/SKILL.md'
printf '%s\n' "$personal_managed" | grep -Fxq '.local/bin/herdr-agent-launch'
python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1], "rb"))' "$personal_home/.config/herdr/config.toml"
zsh -n "$personal_home"/.config/zsh/*.zsh
HOME="$personal_home" zsh -dfc 'source "$HOME/.config/zsh/opencode.zsh"; alias opencode >/dev/null; alias warpconf >/dev/null'

personal_beads_home="$root/personal-with-beads/home"
render_scripts personal-with-beads
assert_beads_viewer_externals "$root/personal-with-beads/rendered/externals.toml"
assert_not_contains "$root/personal-with-beads/rendered/Brewfile" 'brew "beads"'
assert_contains "$root/personal-with-beads/rendered/Brewfile" 'brew "go"'
assert_contains "$root/personal-with-beads/rendered/Brewfile" 'brew "jq"'
assert_not_contains "$root/personal-with-beads/rendered/Brewfile" 'brew "beads_viewer"'
assert_contains "$root/personal-with-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'beads_source_repo="Angel-O/beads"'
assert_contains "$root/personal-with-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" "beads_wanted_ref=\"$beads_ref\""
assert_contains "$root/personal-with-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'viewer_source_repo="Angel-O/beads_viewer"'
assert_contains "$root/personal-with-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" "viewer_wanted_ref=\"$beads_viewer_ref\""
mkdir -p "$personal_beads_home/.config/opencode"
printf '%s\n' 'Preserve personal Beads guidance.' >"$personal_beads_home/.config/opencode/AGENTS.md"
apply_fixture personal-with-beads
test ! -e "$personal_beads_home/.local/bin/wbd"
test ! -e "$personal_beads_home/.local/bin/wbv"
test -x "$personal_beads_home/.local/bin/herdr-agent-launch"
test ! -e "$personal_beads_home/.config/opencode/skills/beads-hub/SKILL.md"
test ! -e "$personal_beads_home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
test ! -e "$personal_beads_home/.config/opencode/skills/beads-hub-closeout/validate.sh"
test ! -e "$personal_beads_home/.config/opencode/skills/work-beads/SKILL.md"
assert_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'agent: orchestrator'
assert_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'The active Bead orchestration contract applies equally to a single concrete work item and to each selected epic child.'
assert_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'semantic worker name that is unique among currently active workers and free of private work-item/context identifiers'
assert_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'passes the worker name verbatim as its workspace label'
assert_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" '~/.local/bin/herdr-agent-launch worker worktree <worker-name> <dedicated-worktree-path>'
assert_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" '~/.local/bin/herdr-agent-launch architect sibling <architect-name>'
assert_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'herdr agent prompt <architect-name> "<design-prompt>" --wait'
assert_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'Do not run `opencode` directly or pass model, variant, or reasoning flags'
assert_not_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'opencode --agent'
assert_not_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'opencode run'
assert_not_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'opencode -m'
assert_not_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" ' --model'
assert_not_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" ' --variant'
assert_not_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'reasoning-effort'
assert_not_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'reasoning effort'
assert_not_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'openai/gpt-'
assert_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'one `reviewer` subagent session'
assert_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'reuse that same session sequentially'
assert_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'including implementation, formatting, focused tests, builds, and static tooling'
assert_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'Repository-wide integration validation belongs to the integration subagent after worker handoff.'
assert_not_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'full test suites belong to the integration subagent'
assert_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'the `integration` subagent against the same child worktree in parallel with review'
assert_not_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'herdr agent start'
assert_not_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'select each worker'
assert_delivery_contract "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md"
assert_orchestration_reuse_contract "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md"
assert_reference_branch_contract "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md"
assert_contains "$personal_beads_home/.config/opencode/commands/orchestrate-bead.md" 'from the recorded worker worktree, not the orchestrator parent checkout'
assert_contains "$personal_beads_home/.config/opencode/AGENTS.md" 'Preserve personal Beads guidance.'
test "$(grep -Fc '<!-- portable-beads-hub:start -->' "$personal_beads_home/.config/opencode/AGENTS.md")" -eq 1
assert_contains "$personal_beads_home/.config/herdr-labels/config.toml" 'bv = "ai board"'
assert_contains "$personal_beads_home/.config/herdr-labels/config.toml" 'wbv = "ai board"'
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); assert data["process_aliases"] == {"bv": "ai board", "wbv": "ai board"}' "$personal_beads_home/.config/herdr-labels/config.toml"
apply_fixture personal-with-beads
personal_beads_diff=$(chezmoi diff \
  --source "$source_dir" \
  --destination "$personal_beads_home" \
  --config "$source_dir/tests/fixtures/personal-with-beads.toml" \
  --cache "$root/personal-with-beads/cache" \
  --persistent-state "$root/personal-with-beads/chezmoistate.boltdb" \
  --exclude scripts,externals)
test -z "$personal_beads_diff"

work_home="$root/work/home"
render_scripts work
assert_ponytail_external "$root/work/rendered/externals.toml"
assert_beads_viewer_externals "$root/work/rendered/externals.toml"
assert_contains "$root/work/rendered/Brewfile" 'brew "eza"'
assert_contains "$root/work/rendered/Brewfile" 'brew "helix"'
assert_not_contains "$root/work/rendered/Brewfile" 'cask "lm-studio"'
assert_contains "$root/work/rendered/Brewfile" 'brew "elio"'
assert_contains "$root/work/rendered/Brewfile" 'brew "glow"'
assert_not_contains "$root/work/rendered/Brewfile" 'brew "beads"'
assert_contains "$root/work/rendered/Brewfile" 'brew "go"'
assert_contains "$root/work/rendered/Brewfile" 'brew "jq"'
assert_not_contains "$root/work/rendered/Brewfile" 'brew "beads_viewer"'
assert_contains "$root/work/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'beads_source_repo="Angel-O/beads"'
assert_contains "$root/work/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" "beads_wanted_ref=\"$beads_ref\""
assert_contains "$root/work/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'viewer_source_repo="Angel-O/beads_viewer"'
assert_contains "$root/work/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" "viewer_wanted_ref=\"$beads_viewer_ref\""
assert_contains "$root/work/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin thomasschafer.herdr-kiosk "thomasschafer/herdr-kiosk"'
assert_contains "$root/work/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin persiyanov.reviewr "persiyanov/herdr-reviewr"'
assert_not_contains "$root/work/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin robert-flo.elio'
mkdir -p "$work_home/.config/opencode" "$work_home/.warp"
cat >"$work_home/.zshrc" <<'EOF'
ZSH_THEME="agnoster"
eval "$(direnv hook zsh)"
export PRIVATE_WORK_SHELL_VALUE=present
alias zconfig='code ~/.zshrc'
alias reload='source ~/.zshrc'
EOF
cat >"$work_home/.gitconfig" <<'EOF'
[user]
	name = Work User
	email = work@example.invalid
EOF
cat >"$work_home/.config/opencode/opencode.jsonc" <<'EOF'
{
  "provider": {
    "work-private-provider": {
      "models": {"private-model": {}}
    }
  },
  "work_private_setting": true
}
EOF
cat >"$work_home/.config/opencode/tui.jsonc" <<'EOF'
{"work_private_tui_setting": true}
EOF
cat >"$work_home/.config/opencode/AGENTS.md" <<'EOF'
# Existing user guidance

Preserve this private instruction exactly.
EOF
cat >"$work_home/.warp/settings.toml" <<'EOF'
# Synthetic machine-local Warp setting.
[privacy]
telemetry = false
EOF
cp "$work_home/.warp/settings.toml" "$root/work/warp-settings.before"

apply_fixture work
assert_contains "$work_home/.zshrc" 'ZSH_THEME="agnoster"'
assert_contains "$work_home/.zshrc" 'direnv hook zsh'
assert_contains "$work_home/.zshrc" 'portable chezmoi early setup'
assert_contains "$work_home/.zshrc" 'portable chezmoi setup'
assert_contains "$work_home/.config/zsh/early.zsh" 'herdr-labels.zsh'
assert_contains "$work_home/.config/zsh/herdr-labels.zsh" 'angel-o.labels-*/shell/hook.zsh'
assert_contains "$work_home/.config/herdr-labels/config.toml" 'bv = "ai board"'
assert_contains "$work_home/.config/herdr-labels/config.toml" 'wbv = "ai board"'
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); assert data["process_aliases"] == {"bv": "ai board", "wbv": "ai board"}' "$work_home/.config/herdr-labels/config.toml"
assert_not_contains "$work_home/.config/zsh/herdr.zsh" 'hook.zsh'
assert_contains "$work_home/.gitconfig" 'email = work@example.invalid'
assert_contains "$work_home/.gitconfig" '.config/git/portable.inc'
assert_contains "$work_home/.config/opencode/opencode.jsonc" 'work-private-provider'
assert_contains "$work_home/.config/opencode/tui.jsonc" 'work_private_tui_setting'
assert_contains "$work_home/.config/opencode/AGENTS.md" 'Preserve this private instruction exactly.'
test -f "$work_home/.config/helix/config.toml"
assert_contains "$work_home/.config/helix/config.toml" 'theme = "dracula_at_night"'
test "$(grep -Fc '<!-- portable-beads-hub:start -->' "$work_home/.config/opencode/AGENTS.md")" -eq 1
assert_contains "$work_home/.config/opencode/AGENTS.md" 'load the global `beads-hub` skill before acting'
assert_contains "$work_home/.config/opencode/AGENTS.md" 'never raw `bd`, `bv`, or `br`'
test ! -e "$work_home/.local/bin/wbd"
test ! -e "$work_home/.local/bin/wbv"
test ! -e "$work_home/.config/opencode/skills/beads-hub/SKILL.md"
test ! -e "$work_home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
test ! -e "$work_home/.config/opencode/skills/beads-hub-closeout/validate.sh"
test ! -e "$work_home/.config/opencode/skills/work-beads/SKILL.md"
cmp -s "$root/work/warp-settings.before" "$work_home/.warp/settings.toml"
assert_not_contains "$work_home/.config/opencode/portable.jsonc" '"provider"'
assert_not_contains "$work_home/.config/opencode/portable.jsonc" 'opencode-lmstudio'
cmp -s "$source_dir/dot_config/opencode/plugins/plan-diagrams.js" "$work_home/.config/opencode/plugins/plan-diagrams.js"
cmp -s "$source_dir/dot_config/opencode/skills/plan-diagrams/SKILL.md" "$work_home/.config/opencode/skills/plan-diagrams/SKILL.md"
cmp -s "$source_dir/dot_config/opencode/skills/terminal-mermaid/SKILL.md" "$work_home/.config/opencode/skills/terminal-mermaid/SKILL.md"
assert_not_contains "$work_home/.config/herdr/config.toml" 'robert-flo.elio.open'
assert_not_contains "$work_home/.config/herdr/config.toml" 'key = "prefix+m"'
assert_not_contains "$work_home/.config/herdr/plugins/config/persiyanov.reviewr/config.toml" 'file_markdown_renderer = "glow -s dracula -w {width} -"'
assert_not_contains "$work_home/.config/zsh/opencode.zsh" '{{'
assert_not_contains "$work_home/.config/zsh/opencode.zsh" 'alias warpconf='
jq -e '(.plugin | index("opencode-handoff@0.5.0")) and (.plugin | index("opencode-mermaid-renderer@0.0.1")) and (.permission.skill == {"plan-diagrams": "deny"}) and (.agent.plan.permission.skill == {"plan-diagrams": "allow"}) and (.agent.title == null)' "$work_home/.config/opencode/portable.jsonc" >/dev/null
python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1], "rb"))' "$work_home/.config/herdr/config.toml"
zsh -n "$work_home"/.config/zsh/*.zsh
HOME="$work_home" zsh -dfc 'source "$HOME/.config/zsh/opencode.zsh"; alias opencode >/dev/null; ! alias warpconf >/dev/null 2>&1'
HOME="$work_home" zsh -dfc 'alias zconfig="code ~/.zshrc"; alias reload="source ~/.zshrc"; source "$HOME/.config/zsh/helpers.zsh"'

if command -v sha256sum >/dev/null 2>&1; then
  before=$(find "$work_home" -type f -exec sha256sum {} + | sort)
else
  before=$(find "$work_home" -type f -exec shasum -a 256 {} + | sort)
fi
apply_fixture work
if command -v sha256sum >/dev/null 2>&1; then
  after=$(find "$work_home" -type f -exec sha256sum {} + | sort)
else
  after=$(find "$work_home" -type f -exec shasum -a 256 {} + | sort)
fi
test "$before" = "$after"
remaining_diff=$(chezmoi diff \
  --source "$source_dir" \
  --destination "$work_home" \
  --config "$source_dir/tests/fixtures/work.toml" \
  --cache "$root/work/cache" \
  --persistent-state "$root/work/chezmoistate.boltdb" \
  --exclude scripts,externals)
test -z "$remaining_diff"
test "$(grep -Fc '# >>> portable chezmoi early setup >>>' "$work_home/.zshrc")" -eq 1
test "$(grep -Fc '# >>> portable chezmoi setup >>>' "$work_home/.zshrc")" -eq 1
test "$(grep -Fc '# >>> portable chezmoi setup >>>' "$work_home/.gitconfig")" -eq 1
early_line=$(grep -nF '# >>> portable chezmoi early setup >>>' "$work_home/.zshrc" | cut -d: -f1)
work_line=$(grep -nF 'ZSH_THEME="agnoster"' "$work_home/.zshrc" | cut -d: -f1)
normal_line=$(grep -nF '# >>> portable chezmoi setup >>>' "$work_home/.zshrc" | cut -d: -f1)
test "$early_line" -lt "$work_line"
test "$work_line" -lt "$normal_line"
work_managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/work.toml" --include files)
printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/portable.jsonc'
printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/plugins/plan-diagrams.js'
printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/skills/plan-diagrams/SKILL.md'
printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/skills/terminal-mermaid/SKILL.md'
printf '%s\n' "$work_managed" | grep -Fxq '.local/bin/herdr-agent-launch'
printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/commands/orchestrate-bead.md'
! printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/skills/beads-hub/SKILL.md'
! printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/skills/work-beads/SKILL.md'

external_home="$root/external-opencode-beads/home"
render_scripts external-opencode-beads
assert_beads_viewer_externals "$root/external-opencode-beads/rendered/externals.toml"
assert_not_contains "$root/external-opencode-beads/rendered/Brewfile" 'brew "beads"'
assert_contains "$root/external-opencode-beads/rendered/Brewfile" 'brew "go"'
assert_contains "$root/external-opencode-beads/rendered/Brewfile" 'brew "jq"'
assert_not_contains "$root/external-opencode-beads/rendered/Brewfile" 'brew "beads_viewer"'
assert_contains "$root/external-opencode-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'beads_source_repo="Angel-O/beads"'
assert_contains "$root/external-opencode-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" "beads_wanted_ref=\"$beads_ref\""
assert_contains "$root/external-opencode-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'viewer_source_repo="Angel-O/beads_viewer"'
assert_contains "$root/external-opencode-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" "viewer_wanted_ref=\"$beads_viewer_ref\""
mkdir -p "$external_home/.config/opencode/command" "$external_home/.config/opencode/skills/existing-skill"
printf '%s\n' 'Legacy orchestrate command.' >"$external_home/.config/opencode/command/orchestrate-bead.md"
cat >"$external_home/.config/opencode/opencode.jsonc" <<'EOF'
{"external_opencode_setting": true}
EOF
cat >"$external_home/.config/opencode/skills/existing-skill/SKILL.md" <<'EOF'
# Existing external skill

Preserve this unmanaged skill.
EOF
cat >"$external_home/.config/opencode/AGENTS.md" <<'EOF'
# Existing external OpenCode guidance

Preserve this external instruction.
EOF
cp "$external_home/.config/opencode/opencode.jsonc" "$root/external-opencode-beads/opencode.before"
cp "$external_home/.config/opencode/skills/existing-skill/SKILL.md" "$root/external-opencode-beads/skill.before"

external_managed="$root/external-opencode-beads/managed"
chezmoi managed \
  --source "$source_dir" \
  --config "$source_dir/tests/fixtures/external-opencode-beads.toml" \
  --exclude externals \
  --include files \
  | grep -E '^(\.config/opencode|\.local/bin)' >"$external_managed"
cat >"$root/external-opencode-beads/managed.expected" <<'EOF'
.config/opencode/AGENTS.md
.config/opencode/commands/orchestrate-bead.md
EOF
cmp -s "$root/external-opencode-beads/managed.expected" "$external_managed"

apply_fixture external-opencode-beads
test ! -e "$external_home/.local/bin/wbd"
test ! -e "$external_home/.local/bin/wbv"
test ! -e "$external_home/.config/opencode/skills/beads-hub/SKILL.md"
test ! -e "$external_home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
test ! -e "$external_home/.config/opencode/skills/beads-hub-closeout/validate.sh"
test ! -e "$external_home/.config/opencode/skills/work-beads/SKILL.md"
test ! -e "$external_home/.config/opencode/portable.jsonc"
test ! -e "$external_home/.config/opencode/plugins/env-protection.js"
test ! -e "$external_home/.config/opencode/plugins/plan-diagrams.js"
test ! -e "$external_home/.config/opencode/skills/plan-diagrams/SKILL.md"
test ! -e "$external_home/.config/opencode/skills/terminal-mermaid/SKILL.md"
test ! -e "$external_home/.config/opencode/commands/herdr-name.md"
test ! -e "$external_home/.config/opencode/command/orchestrate-bead.md"
assert_not_contains "$external_home/.config/opencode/commands/orchestrate-bead.md" 'agent: orchestrator'
assert_not_contains "$external_home/.config/opencode/commands/orchestrate-bead.md" 'herdr agent start'
assert_not_contains "$external_home/.config/opencode/commands/orchestrate-bead.md" 'agent worker'
assert_not_contains "$external_home/.config/opencode/commands/orchestrate-bead.md" 'agent architect'
assert_contains "$external_home/.config/opencode/commands/orchestrate-bead.md" 'select each worker'
test ! -e "$external_home/.local/bin/opencode-env"
test ! -e "$external_home/.local/bin/herdr-agent-launch"
cmp -s "$root/external-opencode-beads/opencode.before" "$external_home/.config/opencode/opencode.jsonc"
cmp -s "$root/external-opencode-beads/skill.before" "$external_home/.config/opencode/skills/existing-skill/SKILL.md"
assert_contains "$external_home/.config/opencode/AGENTS.md" 'Preserve this external instruction.'
test "$(grep -Fc '<!-- portable-beads-hub:start -->' "$external_home/.config/opencode/AGENTS.md")" -eq 1

if command -v sha256sum >/dev/null 2>&1; then
  external_before=$(find "$external_home" -type f -exec sha256sum {} + | sort)
else
  external_before=$(find "$external_home" -type f -exec shasum -a 256 {} + | sort)
fi
apply_fixture external-opencode-beads
if command -v sha256sum >/dev/null 2>&1; then
  external_after=$(find "$external_home" -type f -exec sha256sum {} + | sort)
else
  external_after=$(find "$external_home" -type f -exec shasum -a 256 {} + | sort)
fi
test "$external_before" = "$external_after"
external_diff=$(chezmoi diff \
  --source "$source_dir" \
  --destination "$external_home" \
  --config "$source_dir/tests/fixtures/external-opencode-beads.toml" \
  --cache "$root/external-opencode-beads/cache" \
  --persistent-state "$root/external-opencode-beads/chezmoistate.boltdb" \
  --exclude scripts,externals)
test -z "$external_diff"

integration_disabled_home="$root/beads-integration-disabled/home"
render_scripts beads-integration-disabled
assert_not_contains "$root/beads-integration-disabled/rendered/externals.toml" '.config/opencode/skills/beads-hub/SKILL.md'
assert_not_contains "$root/beads-integration-disabled/rendered/externals.toml" '.config/opencode/skills/beads-hub-closeout/SKILL.md'
assert_not_contains "$root/beads-integration-disabled/rendered/externals.toml" '.config/opencode/skills/beads-hub-closeout/validate.sh'
mkdir -p "$integration_disabled_home/.config/opencode/skills/beads-hub" "$integration_disabled_home/.config/opencode/skills/beads-hub-closeout"
printf '%s\n' 'previously installed external skill' >"$integration_disabled_home/.config/opencode/skills/beads-hub/SKILL.md"
printf '%s\n' 'previously installed external closeout skill' >"$integration_disabled_home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
printf '%s\n' 'previously installed external closeout validator' >"$integration_disabled_home/.config/opencode/skills/beads-hub-closeout/validate.sh"
cat >"$integration_disabled_home/.config/opencode/opencode.jsonc" <<'EOF'
{"unmanaged_setting": "preserve"}
EOF
cat >"$integration_disabled_home/.config/opencode/AGENTS.md" <<'EOF'
Preserve disabled-integration guidance.
<!-- portable-work-beads:start -->
Remove this stale managed block.
<!-- portable-work-beads:end -->
EOF
apply_fixture beads-integration-disabled
test ! -e "$integration_disabled_home/.local/bin/wbd"
test ! -e "$integration_disabled_home/.local/bin/wbv"
test ! -e "$integration_disabled_home/.config/opencode/skills/work-beads/SKILL.md"
test ! -e "$integration_disabled_home/.config/opencode/skills/beads-hub/SKILL.md"
test ! -e "$integration_disabled_home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
test ! -e "$integration_disabled_home/.config/opencode/skills/beads-hub-closeout/validate.sh"
test ! -e "$integration_disabled_home/.config/opencode/commands/orchestrate.md"
test -f "$integration_disabled_home/.config/opencode/portable.jsonc"
assert_contains "$integration_disabled_home/.config/opencode/opencode.jsonc" '"unmanaged_setting": "preserve"'
assert_contains "$integration_disabled_home/.config/opencode/AGENTS.md" 'Preserve disabled-integration guidance.'
assert_not_contains "$integration_disabled_home/.config/opencode/AGENTS.md" 'portable-work-beads:start'

# Disabling the integration removes the previously managed global skill while
# preserving unrelated global OpenCode guidance.
transition_root="$root/beads-integration-transition"
transition_home="$transition_root/home"
mkdir -p "$transition_home/.config/opencode/skills/work-beads"
printf '%s\n' 'Preserve transition guidance.' >"$transition_home/.config/opencode/AGENTS.md"
printf '%s\n' 'obsolete managed work-beads skill' >"$transition_home/.config/opencode/skills/work-beads/SKILL.md"
chezmoi apply \
  --source "$source_dir" \
  --destination "$transition_home" \
  --config "$source_dir/tests/fixtures/external-opencode-beads.toml" \
  --cache "$transition_root/cache" \
  --persistent-state "$transition_root/chezmoistate.boltdb" \
  --exclude scripts,externals \
  --force
test ! -e "$transition_home/.config/opencode/skills/work-beads/SKILL.md"
test ! -e "$transition_home/.config/opencode/skills/beads-hub/SKILL.md"
assert_contains "$transition_home/.config/opencode/AGENTS.md" 'portable-beads-hub:start'
assert_not_contains "$transition_home/.config/opencode/AGENTS.md" 'portable-work-beads:start'
mkdir -p "$transition_home/.config/opencode/skills/beads-hub"
printf '%s\n' 'simulated installed external skill' >"$transition_home/.config/opencode/skills/beads-hub/SKILL.md"
mkdir -p "$transition_home/.config/opencode/skills/beads-hub-closeout"
printf '%s\n' 'simulated installed external closeout skill' >"$transition_home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
printf '%s\n' 'simulated installed external closeout validator' >"$transition_home/.config/opencode/skills/beads-hub-closeout/validate.sh"
chezmoi apply \
  --source "$source_dir" \
  --destination "$transition_home" \
  --config "$source_dir/tests/fixtures/beads-integration-disabled.toml" \
  --cache "$transition_root/cache" \
  --persistent-state "$transition_root/chezmoistate.boltdb" \
  --exclude scripts,externals \
  --force
test ! -e "$transition_home/.config/opencode/skills/work-beads/SKILL.md"
test ! -e "$transition_home/.config/opencode/skills/beads-hub/SKILL.md"
test ! -e "$transition_home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
test ! -e "$transition_home/.config/opencode/skills/beads-hub-closeout/validate.sh"
test ! -e "$transition_home/.local/bin/wbd"
test ! -e "$transition_home/.local/bin/wbv"
assert_contains "$transition_home/.config/opencode/AGENTS.md" 'Preserve transition guidance.'
assert_not_contains "$transition_home/.config/opencode/AGENTS.md" 'portable-work-beads:start'
assert_not_contains "$transition_home/.config/opencode/AGENTS.md" 'portable-beads-hub:start'

legacy_home="$root/legacy-beads/home"
render_scripts legacy-beads
assert_not_contains "$root/legacy-beads/rendered/externals.toml" '.config/opencode/skills/beads-hub/SKILL.md'
assert_not_contains "$root/legacy-beads/rendered/externals.toml" '.config/opencode/skills/beads-hub-closeout/SKILL.md'
assert_not_contains "$root/legacy-beads/rendered/externals.toml" '.config/opencode/skills/beads-hub-closeout/validate.sh'
mkdir -p "$legacy_home/.config/opencode"
cat >"$legacy_home/.config/opencode/AGENTS.md" <<'EOF'
Preserve legacy guidance.
<!-- portable-work-beads:start -->
Remove this legacy stale block.
<!-- portable-work-beads:end -->
EOF
apply_fixture legacy-beads
test ! -e "$legacy_home/.local/bin/wbd"
test ! -e "$legacy_home/.local/bin/wbv"
test ! -e "$legacy_home/.config/opencode/skills/work-beads/SKILL.md"
test ! -e "$legacy_home/.config/opencode/skills/beads-hub/SKILL.md"
test ! -e "$legacy_home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
test ! -e "$legacy_home/.config/opencode/skills/beads-hub-closeout/validate.sh"
assert_contains "$legacy_home/.config/opencode/AGENTS.md" 'Preserve legacy guidance.'
assert_not_contains "$legacy_home/.config/opencode/AGENTS.md" 'portable-work-beads:start'

bash "$source_dir/tests/test-beads.sh" "$source_dir" "$root"

shell_home="$root/shell-only/home"
render_scripts shell-only
assert_contains "$root/shell-only/rendered/Brewfile" 'brew "elio"'
apply_fixture shell-only
test -f "$shell_home/.config/zsh/early.zsh"
test ! -e "$shell_home/.warp"
assert_not_contains "$shell_home/.config/zsh/early.zsh" 'herdr-labels.zsh'
assert_not_contains "$shell_home/.config/zsh/portable.zsh" 'herdr.zsh'
test "$(grep -Fc '# >>> portable chezmoi early setup >>>' "$shell_home/.zshrc")" -eq 1

disabled_home="$root/herdr-disabled-plugins/home"
render_scripts herdr-disabled-plugins
assert_contains "$root/herdr-disabled-plugins/rendered/Brewfile" 'brew "elio"'
assert_not_contains "$root/herdr-disabled-plugins/rendered/Brewfile" 'brew "glow"'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'Angel-O/herdr-agent-resume'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'Angel-O/herdr-labels'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'beyondlex/herdr-recent-navigator'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ezcorp-org/herdr-pc-ram-and-cpu-usage-overlay'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'jeffarese/herdr-bar'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'thomasschafer/herdr-kiosk'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'robert-flo/herdr-terminal-file-manager'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'persiyanov/herdr-reviewr'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'reviewr_root='
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'brew install rust'
apply_fixture herdr-disabled-plugins
test ! -e "$disabled_home/.warp"
assert_not_contains "$disabled_home/.config/herdr/config.toml" 'plugin_action'
assert_not_contains "$disabled_home/.config/herdr/config.toml" 'key = "prefix+m"'
assert_not_contains "$disabled_home/.config/herdr/config.toml" '"$usage"'
assert_not_contains "$disabled_home/.config/zsh/early.zsh" 'herdr-labels.zsh'
test ! -e "$disabled_home/.config/herdr/reviewr-toggle-tab.sh"
test ! -e "$disabled_home/.config/herdr/plugins/config/ez-corp.space-usage/config.toml"
test ! -e "$disabled_home/.config/herdr/plugins/config/herdr-bar/config.json"
test ! -e "$disabled_home/.config/herdr/plugins/config/thomasschafer.herdr-kiosk/config.toml"
test ! -e "$disabled_home/.config/herdr/plugins/config/persiyanov.reviewr/config.toml"
test ! -e "$disabled_home/.config/herdr-labels/config.toml"
python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1], "rb"))' "$disabled_home/.config/herdr/config.toml"

ghostty_home="$root/ghostty-only/home"
render_scripts ghostty-only
assert_contains "$root/ghostty-only/rendered/Brewfile" 'brew "eza"'
assert_contains "$root/ghostty-only/rendered/Brewfile" 'brew "helix"'
mkdir -p "$ghostty_home/.config/opencode"
cat >"$ghostty_home/.config/opencode/AGENTS.md" <<'EOF'
Preserve this guidance with OpenCode disabled.
<!-- portable-work-beads:start -->
remove this managed section
<!-- portable-work-beads:end -->
EOF
ghostty_old_dir="$ghostty_home/Library/Application Support/com.mitchellh.ghostty"
mkdir -p "$ghostty_old_dir"
printf '%s\n' '# exploratory comments' 'theme = Dracula' >"$ghostty_old_dir/config"
HOME="$ghostty_home" sh "$root/ghostty-only/rendered/run_once_after_25-migrate-ghostty-config.sh.tmpl"
test ! -e "$ghostty_old_dir/config"
ghostty_archive=$(find "$ghostty_old_dir" -name 'config.pre-chezmoi-*' -type f)
assert_contains "$ghostty_archive" '# exploratory comments'
HOME="$ghostty_home" sh "$root/ghostty-only/rendered/run_once_after_25-migrate-ghostty-config.sh.tmpl"
apply_fixture ghostty-only
test -f "$ghostty_home/.config/ghostty/config"
test ! -e "$ghostty_home/.config/helix"
test ! -e "$ghostty_home/.warp"
test ! -e "$ghostty_home/.config/herdr/config.toml"
test ! -e "$ghostty_home/.config/opencode/portable.jsonc"
test ! -e "$ghostty_home/.local/bin/herdr-agent-launch"
test ! -e "$ghostty_home/.config/opencode/agents"
test ! -e "$ghostty_home/.config/opencode/commands/orchestrate.md"
assert_contains "$ghostty_home/.config/opencode/AGENTS.md" 'Preserve this guidance with OpenCode disabled.'
assert_not_contains "$ghostty_home/.config/opencode/AGENTS.md" 'portable-work-beads:start'
test ! -e "$ghostty_home/.config/starship/current.toml"
test ! -e "$ghostty_home/.config/zsh/portable.zsh"
test ! -e "$ghostty_home/.config/git/portable.inc"

helix_home="$root/helix-only/home"
render_scripts helix-only
mkdir -p "$helix_home/.config/helix/runtime" "$helix_home/.cache/helix"
printf '%s\n' 'preserve generated runtime data' >"$helix_home/.config/helix/runtime/generated"
printf '%s\n' 'preserve runtime log' >"$helix_home/.cache/helix/helix.log"
apply_fixture helix-only
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); assert data == {"theme": "dracula_at_night"}' "$helix_home/.config/helix/config.toml"
grep -Fxq 'preserve generated runtime data' "$helix_home/.config/helix/runtime/generated"
grep -Fxq 'preserve runtime log' "$helix_home/.cache/helix/helix.log"
test ! -e "$helix_home/.config/ghostty/config"
helix_managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/helix-only.toml" --include files | grep '^\.config/helix')
test "$helix_managed" = '.config/helix/config.toml'

warp_home="$root/warp-only/home"
render_scripts warp-only
mkdir -p "$warp_home/.warp"
cat >"$warp_home/.warp/settings.toml" <<'EOF'
# Synthetic setting that the modifier must preserve.
[privacy]
telemetry = false

[terminal.input.extra_meta_keys]
left_alt = false
EOF
apply_fixture warp-only
assert_warp_policy "$warp_home/.warp/settings.toml"
assert_contains "$warp_home/.warp/settings.toml" '# Synthetic setting that the modifier must preserve.'
assert_contains "$warp_home/.warp/settings.toml" 'telemetry = false'
test ! -e "$warp_home/.config/ghostty/config"

printf 'Docker dotfiles validation passed.\n'
