import { Plugin } from "@opencode/plugin/tui"
import { createSignal, For, Show } from "solid-js"
import { createSidebarRows, focusLiveTarget, isInitiatingSession, sidebarHeading } from "./navigation.js"
import { discoverIncomingTargets, discoverTargets, focusPane, startRefresh } from "./herdr.js"

const REFRESH_MS = 4_000

async function refresh(api: any, sessionID: string) {
  const socket = process.env.HERDR_SOCKET_PATH
  if (!socket || process.env.HERDR_ENV !== "1") return []
  const session = api.data.session.get(sessionID)
  const targets = session?.agent === "orchestrator"
    ? await discoverTargets(sessionID, socket)
    : await discoverIncomingTargets(sessionID, socket)
  for (const location of new Set(targets.map((target) => target.agent.cwd).filter(Boolean))) {
    try {
      await api.data.location.agent.sync({ directory: location })
    } catch {}
  }
  return targets
}

function focus(api: any, target: any) {
  const paneID = target.agent.pane_id
  if (typeof paneID !== "string" || !paneID) {
    api.ui.toast.show({ message: "Session is no longer available", variant: "warning" })
    return
  }
  void focusLiveTarget(
    target,
    () => {
      const route = api.ui.router.current()
      return route?.type === "session" && isInitiatingSession(target, route.sessionID)
        ? refresh(api, route.sessionID)
        : []
    },
    (id) => focusPane(id),
  ).catch(() => {
    api.ui.toast.show({ message: "Session is no longer available", variant: "warning" })
  })
}

export default Plugin.define({
  id: "dotfiles.herdr-delegates",
  setup(api: any) {
    if (process.env.HERDR_ENV !== "1" || !process.env.HERDR_SOCKET_PATH) return
    const [targets, setTargets] = createSignal<any[]>([])
    const rows = createSidebarRows(
      targets,
      (location: any) => api.data.location.agent.list(location ?? api.location) ?? [],
      api.theme.text.base,
    )
    const disposeRefresh = startRefresh(() => {
      const route = api.ui.router.current()
      const sessionID = route?.type === "session" ? route.sessionID : undefined
      return sessionID ? refresh(api, sessionID) : []
    }, setTargets, () => {
      api.ui.toast.show({ message: "Delegate links temporarily unavailable", variant: "warning" })
    }, REFRESH_MS)
    const slot = api.ui.slot({
      append: "sidebar.content",
      render: () => (
        <Show when={rows().length > 0}>
          <box flexDirection="column">
            <text fg={api.theme.text.base}><strong>{sidebarHeading(targets())}</strong></text>
            <For each={rows()}>{(row) => {
              return (
                <box
                  flexDirection="column"
                  onMouseUp={(event: any) => {
                    if (event.button === 0) {
                      event.preventDefault()
                      focus(api, row.target)
                    }
                  }}
                >
                  <text fg={row.color} selectable={false}>{row.label}</text>
                </box>
              )
            }}</For>
          </box>
        </Show>
      ),
    })
    return () => {
      disposeRefresh()
      slot()
    }
  },
})
