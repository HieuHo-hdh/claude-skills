---
name: fe-notifications
description: Use when wiring server-driven notifications or real-time features into a frontend app. Decision tree per transport - polling (unread badge, periodic refresh), SSE (one-way push, cookie auth, auto-reconnect), WebSocket (bidirectional - chat, presence, typing). Query cache owns the data; subscriptions trigger invalidation.
---

# fe-notifications

Default: start with polling. Upgrade to SSE only when staleness is user-visible. Upgrade to WebSocket only when the client talks back on the same channel (chat, presence, collaborative editing).

## Contents

**Pick a transport** - decision tree before any code.
- [Decision tree](#decision-tree) - polling vs. SSE vs. WebSocket.
- [Shared conventions](#shared-conventions) - who owns the data, how the badge is derived.

**Transport A - polling** - TanStack Query + `refetchInterval`.
- [A1. Schema + API](#a1-schema--api) - zod at the boundary.
- [A2. Query hook](#a2-query-hook) - key factory, interval, pause when hidden.
- [A3. Badge consumer](#a3-badge-consumer) - unread count from the cache.
- [A4. Mark-read mutation](#a4-mark-read-mutation) - optimistic + invalidate.

**Transport B - SSE (server-sent events)** - one-way push, cookie auth.
- [B1. Server contract](#b1-server-contract) - event names, payload shape.
- [B2. Subscription hook](#b2-subscription-hook) - `EventSource` + query invalidation.
- [B3. Mount once](#b3-mount-once) - top-level layout only.
- [B4. Reconnect + visibility](#b4-reconnect--visibility) - pause on hidden, resume on focus.

**Transport C - WebSocket** - bidirectional (chat, presence).
- [C1. Connection manager](#c1-connection-manager) - open / close / reconnect with backoff.
- [C2. Send + receive](#c2-send--receive) - message shape, routing.
- [C3. Reconnect + heartbeat](#c3-reconnect--heartbeat) - ping / pong, exponential backoff.

**I/O & verification**
- [Input](#input) - prerequisites from upstream skills.
- [Output](#output) - files emitted per transport.
- [Verification](#verification) - polling pause, SSE reconnect, WS backoff.
- [Anti-patterns - reject on sight](#anti-patterns---reject-on-sight)

## Prerequisites

- **`fe-setup` has run** - project scaffolded at `source-code/<project-name>/` with `CLAUDE.md` recording state library and HTTP client.
- **TanStack Query is wired** (or an equivalent server-cache). Polling and SSE both drive the same cache - do not emit this skill into a project that fetches data straight into Zustand / Redux.
- **Backend contract known** - endpoint URL, event names, auth model. Without this, do not guess - ask.
- **`fe-auth` has run** if the endpoints are authenticated. SSE and WebSocket inherit the auth model (cookie for same-origin, token for cross-origin).

## Working directory

Runs inside `source-code/<project-name>/`. Confirm the directory, read `CLAUDE.md` for state library + HTTP client, and if multiple projects live under `source-code/`, ask which one first. All emitted files go under that project only.

**Full rule:** `.claude/rules/fe-workspace-layout.md` - Path B.

## Shared conventions

- **State ownership:** `.claude/rules/fe-state-management.md` - server data lives in the query cache (TanStack / RTK Query / slice-per-entity). Zustand / Context hold the subscription *handle*, never the notification list.
- **Coding:** `.claude/rules/fe-coding-conventions.md` - zod-parse responses, no `any` on event payloads, no fetch calls in component bodies.
- **A11y:** `.claude/rules/fe-a11y.md` - the badge needs a text alternative (`aria-label` includes the count); toast notifications use `role="status"` for info / `role="alert"` for errors.
- **Project structure:** `.claude/rules/fe-project-structure.md` - API in `src/api/`, hooks in `src/hooks/`, schemas in `src/schemas/`, connection manager in `src/lib/`.

## Decision tree

Pick one transport per feature. Combining is allowed (polling + SSE on the same resource), but only when the upgrade is deliberate.

| Need                                                                | Transport  | Why                                                                                 |
| ------------------------------------------------------------------- | ---------- | ----------------------------------------------------------------------------------- |
| Unread badge, inbox list - 1-5 min staleness OK                     | Polling    | Simplest; survives any auth / proxy / CDN. Pauses when tab hidden.                  |
| Live counter / inbox - staleness is user-visible, server pushes only | SSE        | HTTP, cookie-auth-friendly, auto-reconnect. Half the moving parts of WebSocket.     |
| Chat, typing indicator, presence, cursors                           | WebSocket  | Only transport where the *client* also pushes frames on the same channel.           |
| Alerts when tab closed                                              | Web Push + Service Worker | Separate concern; not covered here. Pair with any of the above. |

**Rule of thumb:** can the client talk back on the same connection? If no → SSE. If yes → WebSocket. If "doesn't matter yet" → polling.

## A1. Schema + API

```ts
// src/schemas/notification.ts
import { z } from 'zod'

export const notificationSchema = z.object({
  id: z.string(),
  title: z.string(),
  body: z.string(),
  readAt: z.string().datetime().nullable(),
  createdAt: z.string().datetime(),
})
export type Notification = z.infer<typeof notificationSchema>

export const notificationListSchema = z.object({
  items: z.array(notificationSchema),
  unreadCount: z.number().int().nonnegative(),
})
export type NotificationList = z.infer<typeof notificationListSchema>
```

```ts
// src/api/notifications.ts
import { api } from '@/lib/http'
import { notificationListSchema } from '@/schemas/notification'

export const fetchNotifications = async () => {
  const res = await api.get('/notifications')
  return notificationListSchema.parse(res.data.data)
}

export const markAsRead = (id: string) => api.post(`/notifications/${id}/read`)
export const markAllAsRead = () => api.post('/notifications/read-all')
```

The server returns `unreadCount` alongside `items` so the badge never computes `items.filter(...).length` - that drifts the moment pagination enters.

## A2. Query hook

```ts
// src/hooks/use-notifications.ts
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { fetchNotifications, markAllAsRead, markAsRead } from '@/api/notifications'

export const notificationKeys = {
  all: ['notifications'] as const,
  list: () => [...notificationKeys.all, 'list'] as const,
}

const FIVE_MIN = 5 * 60 * 1000

export const useNotifications = (enabled = true) =>
  useQuery({
    queryKey: notificationKeys.list(),
    queryFn: fetchNotifications,
    enabled,
    refetchInterval: FIVE_MIN,
    refetchIntervalInBackground: false, // pause when tab hidden
    refetchOnWindowFocus: true,         // fresh count on tab return
    staleTime: 60 * 1000,
  })
```

- `enabled` lets the hook short-circuit for anonymous users - pass `isAuthed` from the auth store.
- `refetchIntervalInBackground: false` matters more than the interval itself. A dashboard left open in a background tab for 8 hours should not fire 96 requests.
- `staleTime` prevents a focus-driven refetch from firing instantly after an interval tick.

## A3. Badge consumer

```tsx
// src/components/NotificationsBell/NotificationsBell.tsx
import { Bell } from 'lucide-react'
import { useNotifications } from '@/hooks/use-notifications'
import { cn } from '@/lib/cn'

export const NotificationsBell = ({ className }: { className?: string }) => {
  const { data } = useNotifications()
  const unread = data?.unreadCount ?? 0

  return (
    <button
      type="button"
      aria-label={unread ? `Notifications, ${unread} unread` : 'Notifications'}
      className={cn('relative inline-flex h-11 w-11 items-center justify-center', className)}
    >
      <Bell aria-hidden="true" />
      {unread > 0 && (
        <span
          aria-hidden="true"
          className="absolute right-1 top-1 min-w-5 rounded-full bg-accent px-1 text-xs font-semibold text-accent-foreground"
        >
          {unread > 99 ? '99+' : unread}
        </span>
      )}
    </button>
  )
}
```

Badge is cosmetic (`aria-hidden`); the count lives in `aria-label` so screen readers get it from one source. Touch target is 44×44 (`h-11 w-11`) per `.claude/rules/fe-responsive.md`.

## A4. Mark-read mutation

```ts
// src/hooks/use-notifications.ts (continued)
export const useMarkAsRead = () => {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: markAsRead,
    onMutate: async (id) => {
      await qc.cancelQueries({ queryKey: notificationKeys.list() })
      const prev = qc.getQueryData(notificationKeys.list())
      qc.setQueryData(notificationKeys.list(), (old: NotificationList | undefined) => {
        if (!old) return old
        return {
          items: old.items.map((n) => (n.id === id ? { ...n, readAt: new Date().toISOString() } : n)),
          unreadCount: Math.max(0, old.unreadCount - 1),
        }
      })
      return { prev }
    },
    onError: (_e, _id, ctx) => ctx?.prev && qc.setQueryData(notificationKeys.list(), ctx.prev),
    onSettled: () => qc.invalidateQueries({ queryKey: notificationKeys.list() }),
  })
}
```

Optimistic update because the UI should drop the badge the instant the user taps - a 300 ms round-trip undoing it feels broken.

## B1. Server contract

The server emits named events on a long-lived HTTP response:

```http
GET /api/notifications/stream
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive

event: notification
data: {"id":"n_123","title":"...","body":"...","createdAt":"..."}

event: unread-count
data: {"count": 4}

: heartbeat
```

- **Event names are explicit** (`notification`, `unread-count`, `read`). Avoid untyped messages - the client code should route on `event`, not on payload shape.
- **Heartbeat line** every 15-30s keeps intermediate proxies from closing the stream.
- **Auth:** SSE uses the same cookies as the rest of the app on the **same origin**. Cross-origin SSE with cookies needs `withCredentials: true` + CORS `Access-Control-Allow-Credentials`.

## B2. Subscription hook

```ts
// src/hooks/use-notifications-stream.ts
import { useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { notificationKeys } from '@/hooks/use-notifications'
import { notificationSchema } from '@/schemas/notification'

export const useNotificationsStream = (enabled: boolean) => {
  const qc = useQueryClient()

  useEffect(() => {
    if (!enabled) return
    const es = new EventSource('/api/notifications/stream', { withCredentials: true })

    const onNotification = (e: MessageEvent) => {
      const parsed = notificationSchema.safeParse(JSON.parse(e.data))
      if (!parsed.success) return
      qc.invalidateQueries({ queryKey: notificationKeys.list() })
    }
    const onUnreadCount = () => qc.invalidateQueries({ queryKey: notificationKeys.list() })

    es.addEventListener('notification', onNotification)
    es.addEventListener('unread-count', onUnreadCount)

    return () => {
      es.removeEventListener('notification', onNotification)
      es.removeEventListener('unread-count', onUnreadCount)
      es.close()
    }
  }, [enabled, qc])
}
```

The hook does **not** write notification data into the cache directly - it invalidates and lets the polling hook refetch the authoritative list. This keeps one source of truth (the server) and avoids race conditions between a stream event and an in-flight list request.

For high-frequency events where a refetch per event is wasteful (chat, cursors), skip invalidation and call `setQueryData` to splice the incoming item - but accept that your event schema must now carry the full entity.

## B3. Mount once

Mount the subscription in **one** place - the root layout for authed users:

```tsx
// src/layouts/private-layout.tsx
'use client'
import { useAuthStore } from '@/store/auth-store'
import { useNotificationsStream } from '@/hooks/use-notifications-stream'

export const PrivateLayout = ({ children }: { children: React.ReactNode }) => {
  const isAuthed = useAuthStore((s) => s.status === 'authenticated')
  useNotificationsStream(isAuthed)
  return <>{children}</>
}
```

Never call `useNotificationsStream` from a feature component - every mount opens a new `EventSource`, and most browsers cap you at ~6 per origin. A duplicate subscription will silently stall the whole app.

## B4. Reconnect + visibility

`EventSource` reconnects automatically with the server-provided `retry:` field (default ~3s). Two things it does not do:

- **Pause when tab hidden.** The connection stays open. If events are expensive, close it on `document.hidden` and reopen on `visibilitychange`:

  ```ts
  useEffect(() => {
    if (!enabled) return
    let es: EventSource | null = null
    const open = () => { es = new EventSource('/api/notifications/stream', { withCredentials: true }); /* add listeners */ }
    const close = () => { es?.close(); es = null }
    const onVis = () => (document.hidden ? close() : open())
    open()
    document.addEventListener('visibilitychange', onVis)
    return () => { document.removeEventListener('visibilitychange', onVis); close() }
  }, [enabled])
  ```

- **Give up gracefully.** `EventSource` reconnects forever. If the server returns 401, the browser retries anyway - add a one-shot token refresh via `fe-auth`'s interceptor pattern, or let the auth guard unmount the layout (which closes the stream in cleanup).

## C1. Connection manager

WebSocket wants a tiny lifecycle object you can share across hooks. Keep it framework-free:

```ts
// src/lib/socket.ts
type Handlers = {
  onMessage: (data: unknown) => void
  onOpen?: () => void
  onClose?: () => void
}

export const createSocket = (url: string, handlers: Handlers) => {
  let ws: WebSocket | null = null
  let retry = 0
  let closed = false
  let heartbeat: ReturnType<typeof setInterval> | null = null

  const connect = () => {
    ws = new WebSocket(url)
    ws.onopen = () => {
      retry = 0
      handlers.onOpen?.()
      heartbeat = setInterval(() => ws?.readyState === WebSocket.OPEN && ws.send('{"type":"ping"}'), 20_000)
    }
    ws.onmessage = (e) => {
      try { handlers.onMessage(JSON.parse(e.data)) } catch { /* drop malformed */ }
    }
    ws.onclose = () => {
      if (heartbeat) clearInterval(heartbeat)
      handlers.onClose?.()
      if (closed) return
      const delay = Math.min(1_000 * 2 ** retry++, 30_000)
      setTimeout(connect, delay)
    }
    ws.onerror = () => ws?.close()
  }

  connect()

  return {
    send: (msg: unknown) =>
      ws?.readyState === WebSocket.OPEN ? ws.send(JSON.stringify(msg)) : false,
    close: () => { closed = true; ws?.close() },
  }
}
```

- **Auth:** browsers do not let you set custom headers on `WebSocket`. Options: subprotocol (`new WebSocket(url, [`bearer.${token}`])`), query param (`?token=...` - avoid, logs leak), or a cookie session set beforehand on the same origin.
- **No zod on every frame** for high-frequency sockets - validate the message *type* field, trust the shape per route. Zod at the API boundary is still required for the REST side.

## C2. Send + receive

Chat example - one hook owns the socket for the current room:

```ts
// src/hooks/use-chat-socket.ts
import { useEffect, useRef } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { createSocket } from '@/lib/socket'

export const chatKeys = { messages: (roomId: string) => ['chat', roomId, 'messages'] as const }

export const useChatSocket = (roomId: string | null) => {
  const qc = useQueryClient()
  const socket = useRef<ReturnType<typeof createSocket> | null>(null)

  useEffect(() => {
    if (!roomId) return
    socket.current = createSocket(`wss://${location.host}/ws/chat/${roomId}`, {
      onMessage: (msg) => {
        if (!isObject(msg) || typeof msg.type !== 'string') return
        if (msg.type === 'message') {
          qc.setQueryData(chatKeys.messages(roomId), (old: Message[] = []) => [...old, msg.payload as Message])
        }
      },
    })
    return () => socket.current?.close()
  }, [roomId, qc])

  const sendMessage = (text: string) => socket.current?.send({ type: 'message', payload: { text } })
  return { sendMessage }
}

const isObject = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null
```

- `setQueryData` to splice the new message - a `invalidateQueries` on every incoming message would refetch the whole thread.
- The hook returns `sendMessage`; typing / presence follow the same shape (`socket.send({ type: 'typing' })`).

## C3. Reconnect + heartbeat

- **Exponential backoff** with a cap (30s above) prevents a hammering retry loop against a dead server.
- **Heartbeat ping every 20-30s.** Load balancers (ALB, nginx) idle-close silent sockets after 60s. The ping also gives the client a cheap liveness check.
- **Reconnect replays state** - after `onOpen`, re-subscribe to rooms the user is in. Do not assume the server remembers.
- **Pause on `document.hidden`:** optional; most chat UIs leave the socket open so unread counts update. Close it only if message volume is costly.

## Input

- `fe-setup` selections - state library, HTTP client, framework (App Router changes mount location).
- Backend contract - REST endpoints (`/notifications`, `/notifications/:id/read`), SSE path, WebSocket URL.
- Auth model - cookie vs. bearer; shapes the SSE / WS auth path.

## Output

Per chosen transport:

- **Polling only:** `src/schemas/notification.ts`, `src/api/notifications.ts`, `src/hooks/use-notifications.ts`, `src/components/NotificationsBell/`.
- **+ SSE:** `src/hooks/use-notifications-stream.ts`, one call to `useNotificationsStream` in the private layout.
- **+ WebSocket:** `src/lib/socket.ts`, one feature hook per concern (`use-chat-socket.ts`, `use-presence-socket.ts`).

One-line note in `CLAUDE.md` under capability status:

```md
notifications: polling 5m + SSE stream (unread badge, inbox)
```

## Verification

Run from `source-code/<project-name>/`. Stop and fix on first failure.

```bash
pnpm typecheck
pnpm lint
pnpm test:run    # mock EventSource / WebSocket in jsdom
pnpm build
pnpm dev         # manual flow below
```

- **Polling pause.** Open the app, switch to another tab for 2 min, come back - DevTools → Network should show **zero** `/notifications` requests during the hidden window and exactly one on tab return.
- **Badge count.** Mark one as read; the count drops instantly (optimistic). Refresh the page; the server-authoritative count matches.
- **SSE reconnect.** DevTools → Network → right-click the `stream` row → Block request URL, wait, unblock. The browser auto-reconnects; the badge updates once more without a page reload.
- **SSE single connection.** Grep sweep:

  ```bash
  rg -n "useNotificationsStream\(" src
  ```

  Exactly **one** call site. More than one is a bug.
- **WebSocket backoff.** Kill the server; the console should show reconnect attempts at ~1s, 2s, 4s, 8s, 16s, 30s, 30s, …, not a tight loop.
- **A11y sweep.** The bell button announces "Notifications, 4 unread" via screen reader, not just "Notifications". The red badge dot passes 3:1 contrast against its surrounding surface.

## Anti-patterns - reject on sight

- Storing `notifications` or `unreadCount` in Zustand / Redux - the query cache (or RTK Query cache / slice) owns it. See `.claude/rules/fe-state-management.md`.
- Computing `unreadCount` on the client via `items.filter(n => !n.readAt).length` - drifts the moment the list paginates. Server returns the count.
- `useNotificationsStream` mounted in a feature component - every mount opens a new `EventSource`; the browser caps you at ~6 per origin.
- SSE handler doing `setQueryData` with a half-shaped payload - prefer `invalidateQueries` unless the event carries the full entity.
- WebSocket URL built with `http://` - the correct scheme is `ws://` / `wss://`.
- Bearer token on the WebSocket query string in production - leaks into proxy logs. Use subprotocol or a same-origin session cookie.
- Reconnect loop with no backoff cap - a server outage becomes a client-side DoS.
- Toast on every incoming notification without rate-limiting - a burst from the server becomes a noise wall; batch via `role="status"` live region.
- Polling at `refetchInterval: 1000` because "the user wants it fresh" - that is what SSE is for. 5-60s is the healthy polling range.
- Firing a fetch inside the component body alongside the query hook ("just to warm the cache") - the hook already handles it.
