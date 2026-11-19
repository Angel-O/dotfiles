#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}

node --input-type=module - "$source_dir/dot_config/opencode/herdr-delegates/navigation.js" <<'JS'
import assert from "node:assert/strict"
import { mkdtemp, mkdir, writeFile, rm } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { pathToFileURL } from "node:url"
const { outgoingTargets, incomingTargets, isInitiatingSession, sidebarHeading, encodedSocket, focusLiveTarget, createSidebarRows, validRecord } = await import(pathToFileURL(process.argv[2]))
const { discoverTargets, discoverIncomingTargets, focusPane, readRecords, startRefresh } = await import(pathToFileURL(process.argv[2].replace("navigation.js", "herdr.js")))
const record = {
  schemaVersion: 1,
  orchestratorSessionID: "sesOrch",
  delegateSessionID: "sesWorker",
  delegateRole: "worker",
  launchName: "worker-one",
}
assert.equal(validRecord(record, "sesWorker.json"), true)
assert.equal(validRecord(record, "wrong.json"), false)
assert.equal(validRecord({ ...record, delegateRole: "subagent" }, "sesWorker.json"), false)
assert.equal(encodedSocket("/tmp/herdr.sock"), "%2Ftmp%2Fherdr.sock")
const worker = {
  name: "worker-one", pane_id: "w:p1", cwd: "/worker",
  agent_session: { agent: "opencode", kind: "id", source: "herdr:opencode", value: "sesWorker" },
}
const architect = {
  name: "worker-one", pane_id: "w:p2",
  agent_session: { agent: "opencode", kind: "id", source: "herdr:opencode", value: "sesArchitect" },
}
const orchestrator = {
  name: "main", pane_id: "o:p1", cwd: "/orchestrator",
  agent_session: { agent: "opencode", kind: "id", source: "herdr:opencode", value: "sesOrch" },
}
const otherOrchestrator = {
  ...orchestrator, pane_id: "o:p2",
  agent_session: { ...orchestrator.agent_session, value: "sesOther" },
}
const locations = []
const agentConfigAt = (location) => {
  locations.push(location)
  if (location?.directory === "/worker") return [{ name: "worker", color: "#configured" }]
  if (location?.directory === "/orchestrator") return [{ name: "orchestrator", color: "#orchestrator" }]
  return []
}
let rowState = []
const displayedRows = createSidebarRows(() => rowState, agentConfigAt, "theme-text")
assert.deepEqual(displayedRows(), [])
rowState = [{ record, agent: worker, label: "worker · worker-one" }]
assert.deepEqual(displayedRows().map(({ label, color }) => ({ label, color })), [
  { label: "worker · worker-one", color: "#configured" },
])
rowState = [{
  record, agent: orchestrator, destinationRole: "orchestrator", label: "orchestrator · main",
}]
assert.deepEqual(displayedRows().map(({ label, color }) => ({ label, color })), [
  { label: "orchestrator · main", color: "#orchestrator" },
])
rowState = [{ record, agent: { ...worker, cwd: undefined }, label: "worker · fallback" }]
assert.deepEqual(displayedRows().map(({ label, color }) => ({ label, color })), [
  { label: "worker · fallback", color: "theme-text" },
])
rowState = []
assert.deepEqual(displayedRows(), [])
assert.deepEqual(locations, [
  { directory: "/worker" }, { directory: "/orchestrator" }, undefined,
])
for (const [field, value] of [["agent", "codex"], ["kind", "path"], ["source", "herdr:other"]]) {
  assert.equal(outgoingTargets([{ record, filename: "sesWorker.json" }], "sesOrch", [
    { ...worker, agent_session: { ...worker.agent_session, [field]: value } },
  ]).length, 0)
}

const records = [
  { record, filename: "sesWorker.json" },
  { record: { ...record, delegateSessionID: "sesArchitect", delegateRole: "architect" }, filename: "sesArchitect.json" },
  { record: { ...record, orchestratorSessionID: "sesOther" }, filename: "sesWorker.json" },
]
const targets = outgoingTargets(records, "sesOrch", [worker, architect])
assert.deepEqual(targets.map(({ label }) => label), ["worker · worker-one", "architect · worker-one"])
assert.equal(sidebarHeading(targets), "Delegates")
assert.equal(outgoingTargets(records, "sesOther", [worker, architect]).length, 1)
const incoming = incomingTargets(records.slice(0, 2), "sesWorker", [orchestrator, otherOrchestrator])
assert.deepEqual(incoming.map(({ destinationSessionID, label }) => ({ destinationSessionID, label })), [
  { destinationSessionID: "sesOrch", label: "orchestrator · main" },
])
assert.equal(sidebarHeading(incoming), "Delegator")
const unnamedOrchestrator = incomingTargets(records.slice(0, 1), "sesWorker", [
  { ...orchestrator, name: undefined },
])[0]
assert.equal(unnamedOrchestrator.label, "orchestrator")
assert.equal(unnamedOrchestrator.destinationSessionID, "sesOrch")
assert.equal(incomingTargets(records.slice(0, 1), "sesWorker", [
  { ...orchestrator, name: "orchestrator" },
])[0].label, "orchestrator")
assert.deepEqual(incomingTargets([records[0], records[2]], "sesWorker", [
  { ...orchestrator, name: undefined },
  { ...otherOrchestrator, name: undefined },
]).map(({ label }) => label), ["orchestrator", "orchestrator"])
assert.equal(isInitiatingSession(targets[0], "sesOrch"), true)
assert.equal(isInitiatingSession(incoming[0], "sesWorker"), true)
assert.equal(isInitiatingSession(targets[0], "sesWorker"), false)
assert.equal(isInitiatingSession(incoming[0], "sesOrch"), false)
assert.deepEqual(incomingTargets(records.slice(0, 2), "sesArchitect", [orchestrator, otherOrchestrator])
  .map(({ record: target }) => target.delegateRole), ["architect"])
assert.deepEqual(incomingTargets(records.slice(0, 2), "sesUnlinked", [orchestrator]), [])
assert.deepEqual(incomingTargets(records.slice(0, 2), "sesWorker", [
  orchestrator, { ...orchestrator, pane_id: "o:p3" },
]), [])
assert.deepEqual(incomingTargets(records.slice(0, 2), "sesWorker", []), [])
assert.deepEqual(incomingTargets(records.slice(0, 2), "sesSubagent", [orchestrator]), [])
assert.equal(outgoingTargets([{ record, filename: "sesWorker.json" }], "sesOrch", [worker, { ...worker, pane_id: "w:p3" }]).length, 0)
assert.equal(outgoingTargets([{ record, filename: "sesWorker.json" }], "sesOrch", []).length, 0)
const duplicate = { record: { ...record, delegateSessionID: "sesOtherWorker" }, filename: "sesOtherWorker.json" }
const duplicateTargets = outgoingTargets([records[0], duplicate], "sesOrch", [
  worker, { ...worker, pane_id: "w:p2", agent_session: { ...worker.agent_session, value: "sesOtherWorker" } },
])
assert.deepEqual(duplicateTargets.map(({ label }) => label), [
  "worker · worker-one · Worker (sesWorker)",
  "worker · worker-one · Worker (sesOtherWorker)",
])
const calls = []
await focusLiveTarget(targets[0], async () => targets, async (paneID) => calls.push(["focus", paneID]))
assert.deepEqual(calls, [["focus", "w:p1"]])
await focusLiveTarget(incoming[0], async () => incoming, async (paneID) => calls.push(["focus", paneID]))
assert.deepEqual(calls.at(-1), ["focus", "o:p1"])
await assert.rejects(
  focusLiveTarget(targets[0], async () => [], async (paneID) => calls.push(["focus", paneID])),
  /no longer uniquely live/,
)
await focusLiveTarget(
  targets[0],
  async () => [{ ...targets[0], agent: { ...worker, pane_id: "moved" } }],
  async (paneID) => calls.push(["focus", paneID]),
)
assert.deepEqual(calls, [["focus", "w:p1"], ["focus", "o:p1"], ["focus", "moved"]])

const home = await mkdtemp(join(tmpdir(), "delegate-sidebar-"))
try {
  const socketA = "/tmp/herdr-a.sock"
  const socketB = "/tmp/herdr-b.sock"
  const directory = (socket) => join(home, ".local/state/herdr/session-relationships", encodedSocket(socket))
  await mkdir(directory(socketA), { recursive: true })
  await mkdir(directory(socketB), { recursive: true })
  await writeFile(join(directory(socketA), "sesWorker.json"), JSON.stringify(record))
  await writeFile(join(directory(socketA), "sesBroken.json"), "{")
  await writeFile(join(directory(socketA), "wrong.json"), JSON.stringify(record))
  await writeFile(join(directory(socketB), "sesElsewhere.json"), JSON.stringify({
    ...record, orchestratorSessionID: "sesOther", delegateSessionID: "sesElsewhere",
  }))
  assert.deepEqual((await readRecords(socketA, home)).map(({ filename }) => filename), ["sesWorker.json"])
  const listCalls = []
  const discovered = await discoverTargets("sesOrch", socketA, home, async (args) => {
    listCalls.push(args)
    return JSON.stringify({ agents: [worker] })
  })
  assert.deepEqual(discovered.map(({ record: target }) => target.delegateSessionID), ["sesWorker"])
  assert.deepEqual(listCalls, [["agent", "list"]])
  assert.deepEqual((await discoverIncomingTargets("sesWorker", socketA, home, async () =>
    JSON.stringify({ agents: [orchestrator, otherOrchestrator] })))
    .map(({ destinationSessionID }) => destinationSessionID), ["sesOrch"])
  assert.deepEqual((await discoverIncomingTargets("sesWorker", socketA, home, async () =>
    JSON.stringify({ agents: [orchestrator] }))).map(({ record: target }) => target.delegateSessionID), ["sesWorker"])
  assert.deepEqual(await discoverIncomingTargets("sesWorker", socketA, home, async () =>
    JSON.stringify({ agents: [orchestrator, { ...orchestrator, pane_id: "o:p3" }] })), [])
  assert.deepEqual((await discoverIncomingTargets("sesWorker", socketA, home, async () =>
    JSON.stringify({ agents: [orchestrator] }))).map(({ destinationSessionID }) => destinationSessionID), ["sesOrch"])
  assert.deepEqual(await discoverTargets("sesOrch", socketB, home, async () => {
    throw new Error("must not list agents without a same-server relationship")
  }), [])
  assert.deepEqual(await discoverTargets("sesOrch", "/tmp/no-records.sock", home, async () => {
    throw new Error("normal absence is not a discovery error")
  }), [])

  const focusCalls = []
  await focusPane("w:p1", async (args) => focusCalls.push(args))
  assert.deepEqual(focusCalls, [["agent", "focus", "w:p1"]])
  assert.throws(() => focusPane("", async (args) => focusCalls.push(args)), /missing Herdr pane/)
  assert.deepEqual(focusCalls, [["agent", "focus", "w:p1"]])
} finally {
  await rm(home, { recursive: true, force: true })
}

const ticks = []
const cleared = []
const clock = {
  setInterval(callback, interval) {
    assert.equal(interval, 25)
    ticks.push(callback)
    return "refresh-timer"
  },
  clearInterval(timer) { cleared.push(timer) },
}
const published = []
const rendered = []
const warnings = []
let releaseInitial
let loads = 0
const stop = startRefresh(() => {
  loads++
  if (loads === 1) return new Promise((resolve) => { releaseInitial = resolve })
  if (loads === 2) return [
    targets[0],
    { ...targets[0], agent: { ...worker, cwd: undefined }, label: "worker · fallback" },
  ]
  if (loads === 3) return []
  if (loads === 4 || loads === 5 || loads === 7) throw new Error("discovery failed")
  return []
}, (items) => {
  rowState = items
  published.push(items)
  rendered.push(displayedRows())
}, () => warnings.push("warning"), 25, clock)
const settle = () => new Promise((resolve) => setImmediate(resolve))
ticks[0]()
await settle()
assert.equal(loads, 1)
releaseInitial([])
await settle()
ticks[0]()
await settle()
assert.equal(published.at(-1).length, 2)
assert.deepEqual(rendered.at(-1).map(({ label, color }) => ({ label, color })), [
  { label: targets[0].label, color: "#configured" },
  { label: "worker · fallback", color: "theme-text" },
])
ticks[0]()
await settle()
assert.deepEqual(published.at(-1), [])
assert.deepEqual(rendered.at(-1), [])
ticks[0]()
await settle()
ticks[0]()
await settle()
assert.equal(warnings.length, 1)
ticks[0]()
await settle()
ticks[0]()
await settle()
assert.equal(warnings.length, 2)
stop()
assert.deepEqual(cleared, ["refresh-timer"])

let releaseDisposed
const afterDispose = []
const stopPending = startRefresh(
  () => new Promise((resolve) => { releaseDisposed = resolve }),
  (items) => afterDispose.push(items),
  () => {},
  25,
  clock,
)
stopPending()
releaseDisposed([targets[0]])
await settle()
assert.deepEqual(afterDispose, [])
JS

python3 - "$source_dir/dot_config/opencode/cli.json.tmpl" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
assert '"./herdr-opencode",' in text
assert '"./herdr-delegates"' in text
assert text.index('"./herdr-opencode"') < text.index('"./herdr-delegates"')
assert '{{ if .modules.herdr }}' in text and '{{ end }}' in text
PY

root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/work.toml" \
  <"$source_dir/dot_config/opencode/cli.json.tmpl" >"$root/enabled.json"
sed 's/herdr = true/herdr = false/' "$source_dir/tests/fixtures/work.toml" >"$root/herdr-disabled.toml"
chezmoi execute-template --source "$source_dir" --config "$root/herdr-disabled.toml" \
  <"$source_dir/dot_config/opencode/cli.json.tmpl" >"$root/disabled.json"
python3 - "$root/enabled.json" "$root/disabled.json" <<'PY'
import json
import sys
from pathlib import Path
enabled, disabled = map(lambda path: json.loads(Path(path).read_text()), sys.argv[1:])
assert enabled["plugins"] == ["./herdr-opencode", "./herdr-delegates"]
assert "plugins" not in disabled
PY

echo 'Herdr delegate navigation behavior and load gating: PASS'
