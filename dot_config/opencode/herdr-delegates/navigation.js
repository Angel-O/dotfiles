const SESSION_ID = /^ses[A-Za-z0-9_-]+$/
const LAUNCH_NAME = /^[a-z][a-z0-9_-]{0,31}$/

export function validRecord(record, filename) {
  return record?.schemaVersion === 1 &&
    SESSION_ID.test(record.orchestratorSessionID ?? "") &&
    SESSION_ID.test(record.delegateSessionID ?? "") &&
    ["worker", "architect"].includes(record.delegateRole) &&
    LAUNCH_NAME.test(record.launchName ?? "") &&
    filename === `${record.delegateSessionID}.json`
}

export function outgoingTargets(records, currentSessionID, agents) {
  const targets = records
    .filter(({ record, filename }) => validRecord(record, filename) &&
      record.orchestratorSessionID === currentSessionID)
    .map(({ record }) => {
      const matches = agents.filter((agent) =>
        agent.agent_session?.agent === "opencode" &&
        agent.agent_session?.kind === "id" &&
        agent.agent_session?.source === "herdr:opencode" &&
        agent.agent_session?.value === record.delegateSessionID)
      if (matches.length !== 1 || typeof matches[0].pane_id !== "string" || !matches[0].pane_id) return
      return { record, agent: matches[0] }
    })
    .filter(Boolean)

  const labels = new Map()
  for (const target of targets) {
    const name = target.agent.name || target.record.launchName
    const base = `${target.record.delegateRole} · ${name}`
    labels.set(base, (labels.get(base) ?? 0) + 1)
    target.label = base
  }
  const suffixes = new Map()
  for (const target of targets) {
    if (labels.get(target.label) > 1) {
      const suffix = target.record.delegateSessionID.slice(-6)
      suffixes.set(suffix, (suffixes.get(suffix) ?? 0) + 1)
      target.label += ` · ${suffix}`
    }
  }
  for (const target of targets) {
    const suffix = target.label.slice(-6)
    if (labels.get(target.label.slice(0, -9)) > 1 && suffixes.get(suffix) > 1) {
      target.label += ` (${target.record.delegateSessionID})`
    }
  }
  return targets
}

export async function focusLiveTarget(target, resolve, focusPane) {
  const live = (await resolve()).filter((item) =>
    item.record.delegateSessionID === target.record.delegateSessionID)
  if (live.length !== 1 || typeof live[0].agent.pane_id !== "string" || !live[0].agent.pane_id) {
    throw new Error("delegate is no longer uniquely live")
  }
  return focusPane(live[0].agent.pane_id)
}

export function roleColor(role, agents) {
  return agents.find((agent) => agent.name === role)?.color
}

export function destinationColor(target, agentsAt, fallback) {
  const location = target.agent.cwd ? { directory: target.agent.cwd } : undefined
  return roleColor(target.record.delegateRole, agentsAt(location)) ?? fallback
}

export function createSidebarRows(readTargets, agentsAt, fallback) {
  return () => readTargets().map((target) => ({
    target,
    label: target.label,
    color: destinationColor(target, agentsAt, fallback),
  }))
}

export function encodedSocket(socket) {
  return encodeURIComponent(socket).replace(/[!'()*]/g, (char) =>
    `%${char.charCodeAt(0).toString(16).toUpperCase()}`)
}
