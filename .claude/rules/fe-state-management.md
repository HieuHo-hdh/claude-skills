# State management

Shared rule for `fe-*` skills that emit data-fetching or state code.

Scope: where each kind of state lives and how each state library shapes it. Read the state library from the project's `CLAUDE.md`. Deviations: state a reason inline.

## Contents

**Principles** - who owns what.
- [Four kinds of state](#four-kinds-of-state) - server, client-global, local, URL.
- [Loading and error status](#loading-and-error-status) - one status vocabulary across libraries.

**Per library** - file shape for each `fe-setup` state choice.
- [Zustand + TanStack Query](#zustand--tanstack-query) - query hooks, key factories, client stores.
- [Redux Toolkit](#redux-toolkit) - slice per entity, thunks, selectors, auth.
- [Context + fetch](#context--fetch) - one hook per entity.

**Lists** - search, filter, sort, pagination.
- [Filters, search, pagination](#filters-search-pagination) - URL vs `useState` vs store.

**Quality**
- [Anti-patterns - reject on sight](#anti-patterns---reject-on-sight)

## Four kinds of state

One owner per datum. Never copy a datum from one owner into another.

| Kind          | Examples                                 | Owner                                                              |
| ------------- | ---------------------------------------- | ------------------------------------------------------------------ |
| Server        | Lists, entities, dashboard metrics       | Query cache (TanStack Query / RTK Query) - or a Redux slice, below |
| Client-global | Session user, theme, sidebar open        | Store (Zustand / Redux slice) or Context                           |
| Local UI      | Draft input, open menu, hovered row      | `useState` / `useReducer` in the component                         |
| URL           | Search, filters, sort, page, selected tab | Router search params                                              |

## Loading and error status

Every async owner exposes the same shape, whatever the library:

```ts
type AsyncStatus = 'idle' | 'loading' | 'succeeded' | 'failed'
// error: string | null - a message, not an Error (serializable, renderable)
```

Pages render loading / error / empty / success explicitly - see `fe-page` step 4.

## Zustand + TanStack Query

- **Server data → TanStack Query.** Never store fetched data in Zustand.
- **Client-global → Zustand**, one store per concern in `src/store/<name>-store.ts`. Select fields, not the whole store: `useUiStore((s) => s.isSideNavOpen)`.
- **Query keys** come from a hoisted factory per entity. Filter values are part of the key.
- **One hook per query / mutation** in `src/hooks/`. Mutations invalidate the affected keys.
- `QueryClient` is created once in `src/lib/query-client.ts`.

```ts
// src/hooks/use-users.ts
export const userKeys = {
  all: ['users'] as const,
  list: (params: UserListParams) => [...userKeys.all, 'list', params] as const,
}

export const useUsers = (params: UserListParams) =>
  useQuery({ queryKey: userKeys.list(params), queryFn: () => fetchUsers(params) })
```

## Redux Toolkit

Two modes. Pick one per entity, not both.

- **Slice per entity** (default) - server data lives in the store with its own status and error.
- **RTK Query** - server data lives in the API cache; no slice for it. Use when the project opts in at `fe-setup`.

**Slice per entity.** File map per entity `user`:

| File                      | Holds                                                                 |
| ------------------------- | --------------------------------------------------------------------- |
| `src/api/users.ts`        | Plain axios functions - no store imports.                             |
| `src/store/users-slice.ts` | State `{ items, status, error }`, thunks that call `api/users.ts`, selectors. |
| `src/store/index.ts`      | `configureStore`, `RootState`, `AppDispatch`, `useAppDispatch`, `useAppSelector`. |
| `src/hooks/use-users.ts`  | Dispatches the thunk on mount, returns `{ users, status, error, reload }`. |

```ts
// src/store/users-slice.ts
export const loadUsers = createAsyncThunk('users/load', (params: UserListParams) => fetchUsers(params))

const usersSlice = createSlice({
  name: 'users',
  initialState: { items: [], status: 'idle', error: null } as UsersState,
  reducers: {},
  extraReducers: (builder) =>
    builder
      .addCase(loadUsers.pending, (s) => { s.status = 'loading'; s.error = null })
      .addCase(loadUsers.fulfilled, (s, a) => { s.status = 'succeeded'; s.items = a.payload })
      .addCase(loadUsers.rejected, (s, a) => { s.status = 'failed'; s.error = a.error.message ?? 'Request failed' }),
})

export const selectUsers = (state: RootState) => state.users.items
```

- Components read through selectors (`useAppSelector(selectUsers)`), never `state.users.items` inline.
- Keep `status` and `error` per entity slice - no global `loading` flag.
- **Auth is a slice with a different shape**: `{ user, status, error }` where `status` is `'idle' | 'authenticating' | 'authenticated' | 'unauthenticated'`. Tokens never enter state. Expose it through a `useAuth()` hook that selects `user` and `status` - see `fe-auth`.
- An empty `reducer: {}` warns in dev. Seed the store with the first slice.

## Context + fetch

- One hook per entity in `src/hooks/` returning `{ data, status, error, refetch }`. Error handling lives in the hook.
- Context is for low-frequency global values (session, theme). Never for lists or anything that re-renders often.

## Filters, search, pagination

Decide per value, not per page:

| Value                                          | Owner                                      | Why                                      |
| ---------------------------------------------- | ------------------------------------------ | ---------------------------------------- |
| Search text, filters, sort, page, page size    | URL search params                          | Shareable, bookmarkable, back-button works |
| Draft input before debounce                    | `useState`                                 | Keystrokes are not URL history           |
| Open popover, expanded row, hovered item       | `useState` / `useReducer`                  | Dies with the component                  |
| Column visibility, density, saved views        | Store with `persist`                       | Survives navigation, not meant for links |
| Fetched rows                                   | Query cache / slice                        | Never mirror into a store                |

- **Validate at the boundary.** Parse search params with Zod (`safeParse`, fall back to defaults) - users edit URLs.
- **Reset `page` to 1** whenever a filter, search, or page size changes.
- **Debounce** text search (~300 ms) before writing to the URL; write with `replace`, not `push`, so typing does not flood history.
- **Filter values feed the fetch** - query key (TanStack), endpoint arg (RTK Query), thunk arg (slice), hook dependency (Context).
- **Server-side by default.** Filter client-side only when the full dataset is already loaded and small.

```ts
const listParamsSchema = z.object({
  q: z.string().default(''),
  role: z.enum(['admin', 'user']).optional(),
  page: z.coerce.number().int().min(1).default(1),
})
```

| Framework     | Read / write search params                                                                |
| ------------- | ----------------------------------------------------------------------------------------- |
| React Router  | `useSearchParams()`                                                                       |
| Next.js       | `useSearchParams()` + `router.replace()`; wrap the reader in `<Suspense>` or `next build` fails |
| Vue Router    | `route.query` + `router.replace({ query })`                                               |

## Anti-patterns - reject on sight

- Server data copied into Zustand or a second Redux slice - two owners drift apart.
- A slice that stores filter values the URL already holds - back button and shared links break.
- Global `isLoading` / `error` flags shared by unrelated entities - one request clears another's error.
- `useEffect` + `fetch` + `setState` when a query hook or thunk exists - see `fe-coding-conventions.md`.
- Components reading `state.<slice>.<field>` inline - go through a selector or hook.
- `Error` objects or `Date` instances in Redux state - not serializable; store the message or an ISO string.
- Selecting the whole Zustand store (`useStore()`) - every change re-renders the component.
- Filter or search state initialized from a prop and never re-synced - URL is the source of truth.
- Auth tokens in any store - see `fe-auth`.
