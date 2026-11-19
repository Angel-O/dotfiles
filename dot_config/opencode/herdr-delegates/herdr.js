import { execFile } from "node:child_process"
import { readFile, readdir } from "node:fs/promises"
import { homedir } from "node:os"
import { join } from "node:path"
import { encodedSocket, incomingTargets, outgoingTargets, validRecord } from "./navigation.js"

const RELATIONSHIP_ROOT = ".local/state/herdr/session-relationships"

export function runHerdr(args, execute = execFile) {
  return new Promise((resolve, reject) => {
    execute("herdr", args, { timeout: 3_000 }, (error, stdout) => {
      if (error) reject(error)
      else resolve(stdout)
    })
  })
}

export async function readRecords(socket, home = homedir(), list = readdir, read = readFile) {
  const directory = join(home, RELATIONSHIP_ROOT, encodedSocket(socket))
  let files
  try {
    files = await list(directory)
  } catch (error) {
    if (error?.code === "ENOENT") return []
    throw error
  }
  const records = await Promise.all(files.filter((file) => file.endsWith(".json")).map(async (file) => {
    try {
      const record = JSON.parse(await read(join(directory, file), "utf8"))
      return validRecord(record, file) ? { record, filename: file } : undefined
    } catch {
      return undefined
    }
  }))
  return records.filter(Boolean)
}

export async function discoverTargets(sessionID, socket, home = homedir(), run = runHerdr) {
  const records = await readRecords(socket, home)
  if (!records.some(({ record }) => record.orchestratorSessionID === sessionID)) return []
  const output = await run(["agent", "list"])
  const parsed = JSON.parse(output)
  const agents = Array.isArray(parsed) ? parsed : parsed.agents ?? parsed.result?.agents
  if (!Array.isArray(agents)) throw new Error("invalid Herdr agent list")
  return outgoingTargets(records, sessionID, agents)
}

export async function discoverIncomingTargets(sessionID, socket, home = homedir(), run = runHerdr) {
  const records = await readRecords(socket, home)
  if (!records.some(({ record }) => record.delegateSessionID === sessionID)) return []
  const output = await run(["agent", "list"])
  const parsed = JSON.parse(output)
  const agents = Array.isArray(parsed) ? parsed : parsed.agents ?? parsed.result?.agents
  if (!Array.isArray(agents)) throw new Error("invalid Herdr agent list")
  return incomingTargets(records, sessionID, agents)
}

export function focusPane(paneID, run = runHerdr) {
  if (typeof paneID !== "string" || !paneID) throw new Error("missing Herdr pane")
  return run(["agent", "focus", paneID])
}

export function startRefresh(load, publish, warn, interval, clock = globalThis) {
  let busy = false
  let stopped = false
  let warned = false
  const refresh = async () => {
    if (stopped || busy) return
    busy = true
    try {
      const targets = await load()
      if (!stopped) {
        warned = false
        publish(targets)
      }
    } catch {
      if (!stopped) {
        publish([])
        if (!warned) warn()
        warned = true
      }
    } finally {
      busy = false
    }
  }
  const timer = clock.setInterval(refresh, interval)
  void refresh()
  return () => {
    stopped = true
    clock.clearInterval(timer)
  }
}
