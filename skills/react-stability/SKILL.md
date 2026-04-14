---
name: react-stability
description: Prevent infinite re-render loops in React/Next.js. Use when diagnosing useEffect firing repeatedly, "Maximum update depth exceeded" errors, or components that flash correct content then reset to loading. Covers unstable references from URL parsing, inline callbacks, and object/array deps in useEffect/useCallback/useMemo.
---

# React Stability — Preventing Infinite Re-Render Loops

## When to Use

- Component loads data, flashes it, then resets to loading (infinite fetch loop)
- Console shows rapid repeated API calls or "Maximum update depth exceeded"
- `useEffect` fires on every render despite no visible state change
- Typing in an input triggers unrelated re-fetches or state resets

## Root Cause Pattern

React hooks compare dependencies by **reference**, not value. These create new references every render:

```typescript
// ❌ BAD — new object every render
const state = decodeBookingState(searchParams);
useEffect(() => { ... }, [state]); // fires EVERY render

// ❌ BAD — new array every render
const items = state.selectedItems.map(i => i.id);
useEffect(() => { ... }, [items]); // fires EVERY render

// ❌ BAD — inline arrow = new function every render
<ChildComponent onSave={(data) => updateItem(i, data)} />
// If child has useEffect depending on onSave → infinite loop
```

## Fix Patterns

### Pattern 1: Stabilize object/array deps with useMemo + primitive key

```typescript
// ✅ GOOD — stable string key, memoized array
const itemIdsKey = state.selectedItems.map(si => si.fleetItemId).join(",");
const stableItemIds = useMemo(
  () => state.selectedItems.map(si => si.fleetItemId),
  [itemIdsKey] // primitive string — stable across renders
);

useEffect(() => {
  fetchData(stableItemIds);
}, [stableItemIds]); // only fires when IDs actually change
```

### Pattern 2: Collapse object deps to a stable boolean

```typescript
// ✅ GOOD — boolean is a primitive, stable across renders
const hasRequiredState = Boolean(state.pickupDate && state.selectedItems.length);

useEffect(() => {
  if (!hasRequiredState) { router.replace("/select"); return; }
  loadData();
}, [hasRequiredState, router]);
```

### Pattern 3: useRef for callback props (inline arrow problem)

```typescript
// ✅ GOOD — ref always holds latest callback without triggering effects
const onSignatureRef = useRef(onSignature);
useLayoutEffect(() => {
  onSignatureRef.current = onSignature;
});

useEffect(() => {
  if (mode === "typed" && name.trim()) {
    onSignatureRef.current({ type: "typed", value: name.trim() });
  }
}, [name, mode]); // onSignature NOT in deps — ref is stable
```

### Pattern 4: Avoid entire state objects as deps

```typescript
// ❌ NEVER do this
useEffect(() => { ... }, [state, router]);

// ✅ Extract only the primitives you need
useEffect(() => { ... }, [state.pickupDate, state.returnDate, router]);
// OR use Pattern 2 (boolean guard)
```

## Diagnosis Checklist

When you see an infinite loop:

1. **Find the useEffect** that's firing repeatedly (add a `console.log` or check network tab for repeated fetches)
2. **Check each dependency** — is it a primitive (string, number, boolean) or a reference (object, array, function)?
3. **Trace the reference** — where is it created? If it's from a function call that runs every render (like `decodeState(params)`), it's a new reference every time
4. **Apply the right pattern:**
   - Object/array → Pattern 1 (useMemo + primitive key) or Pattern 2 (boolean)
   - Callback prop → Pattern 3 (useRef)
   - Whole state object → Pattern 4 (extract primitives)

## Common Sources of Unstable References

| Source | Why it's unstable | Fix |
|--------|------------------|-----|
| `decodeState(searchParams)` | New object every render | Extract primitives or useMemo |
| `.map()` / `.filter()` results | New array every render | useMemo with stable key |
| Inline arrow functions as props | New function every render | useRef or useCallback |
| `JSON.parse()` results | New object every render | useMemo |
| `useSearchParams()` derived state | URLSearchParams creates new refs | Memoize derived values |

## Hydration Mismatch Prevention

Next.js hydration errors happen when server-rendered HTML doesn't match the client's first render. Common in components with client-only state.

### Pattern: SSR Placeholder Shell

When a component has unavoidable server/client differences (timezones, `Date()`, portals, browser APIs), render a static shell on server and switch to interactive on client:

```tsx
export function MyComponent() {
  const [clientReady, setClientReady] = useState(false);
  useEffect(() => { setClientReady(true); }, []);

  // Static shell — matches server render exactly
  if (!clientReady) {
    return (
      <div className="placeholder-shell">
        {/* Minimal static HTML that looks like the component */}
      </div>
    );
  }

  // Full interactive render — client only
  return <FullInteractiveComponent />;
}
```

### Common Hydration Mismatch Sources

| Source | Why it mismatches | Fix |
|--------|------------------|-----|
| `new Date()` | Server time ≠ client time | SSR shell or `suppressHydrationWarning` |
| `typeof document` guards | `false` on server, `true` on client | SSR shell pattern |
| Cycling text/animations | Server picks index 0, client may differ | Return empty until mounted |
| `createPortal` | Server can't render portals | Guard with mounted check |
| `localStorage`/`sessionStorage` | Not available on server | Read after mount only |
| `min={today}` on date inputs | Server: `""`, client: `"2026-04-12"` | `suppressHydrationWarning` on that element |
| Browser extensions (Chrome) | Inject DOM before React hydrates | Nothing you can do — SSR shell avoids the conflict |
| Date formatting without `timeZone: 'UTC'` | Server (UTC) renders "Apr 22", client (MDT) renders "Apr 21" | Always pass `timeZone: 'UTC'` to `toLocaleDateString()` |

### `suppressHydrationWarning` Limitations

- Only suppresses warnings on the **element itself**, not children
- Only works for **text content** differences, not structural (element count/type) differences
- Use for leaf elements (inputs with dynamic `min`/`value`), not wrapper divs
- For structural differences, use the SSR shell pattern instead

## Real-World Example (from Renta codebase)

The booking wizard had this bug on **4 pages** (addons, waiver, payment, SignatureCapture):

```typescript
// This runs every render, creating new state object
const state = decodeBookingState(searchParams);

// This useEffect fires every render because state is always "new"
useEffect(() => {
  if (!state.pickupDate) { redirect(); return; }
  fetchData(state.selectedItems);
}, [state, router]); // ← state is NEVER referentially equal
```

Fixed by stabilizing deps per patterns above. Key lesson: **any function that decodes/parses URL params or JSON into objects will produce new references every render.**

## Next.js App Debugging Heuristics

### localStorage keys: scope to tenant

A global key (e.g. `waiver-banner-dismissed`) makes dismiss state leak across tenants when an operator manages multiple shops in the same browser. Scope the key with `tenantId`:

```typescript
// ❌ BAD — shared across tenants
localStorage.getItem("waiver-banner-dismissed");

// ✅ GOOD — per-tenant
localStorage.getItem(`waiver-banner-dismissed-${tenantId}`);
```

Note: localStorage is still per-device — no cross-machine sync without server state. That's usually fine for dismissible banners and UI preferences.

### Client fetch to API routes: guard against non-JSON errors

If an API route handler can throw, the browser may receive a non-JSON error (Next.js default 500 page or plain text). This breaks client-side `res.json()` and makes banner/UI logic unpredictable.

Always wrap route handlers in a narrow try/catch that returns structured JSON:

```typescript
// ✅ GOOD — client always gets JSON
export async function GET() {
  try {
    const data = await riskyOperation();
    return NextResponse.json(data);
  } catch (err) {
    console.error("Route error:", err instanceof Error ? err.message : err);
    return NextResponse.json(
      { error: "Something went wrong" },
      { status: 500 }
    );
  }
}
```

On the client side, also guard the `.json()` call:

```typescript
// ✅ GOOD — handles non-JSON responses gracefully
const res = await fetch("/api/admin/something");
if (!res.ok) return; // or show fallback UI
const data = await res.json().catch(() => null);
if (!data) return;
```
