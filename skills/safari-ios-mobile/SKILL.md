# Safari iOS Mobile — Preventive Rules & Fixes

## Description
Mandatory rules for any mobile/responsive web UI work. Apply BEFORE writing code, not after. Every pattern here exists because Chrome DevTools / Responsively renders differently than real Safari on iPhone.

## When to Use
- **Building** any new component that renders on mobile (modals, drawers, overlays, date pickers, forms)
- **Reviewing** PRs that touch mobile UI
- **Debugging** UI that works in Chrome but breaks on real iPhone

---

## MANDATORY RULES (Apply by Default)

### Rule 1: All Modals/Drawers/Overlays MUST Use Portals

**Every** `fixed` overlay element must render via `createPortal` to `document.body`. No exceptions.

**Why:** Any parent with `transform`, `backdrop-filter`, `will-change`, `filter`, or `opacity < 1` creates a stacking context. Z-index cannot escape stacking contexts — portals are the only reliable fix.

```tsx
import { createPortal } from "react-dom";

// ✅ CORRECT — always portal
{isOpen && typeof document !== 'undefined' && createPortal(
  <div className="fixed inset-0 z-50">...</div>,
  document.body
)}

// ❌ WRONG — z-index trapped by parent stacking context
{isOpen && <div className="fixed inset-0 z-[9999]">...</div>}
```

**Stacking context creators to watch for:**
- `transform` (including `translate-x`, `translate-y`, `-translate-*`)
- `backdrop-filter` / `backdrop-blur-*`
- `will-change`
- `filter`
- `opacity` less than 1 (including `bg-white/95`, `bg-black/50`)
- `isolation: isolate`
- `mix-blend-mode`
- `perspective`
- `clip-path`
- `mask` / `-webkit-mask`
- `contain: layout` or `contain: paint`

### Rule 2: Never Use `overflow: hidden` on `<body>` for Scroll Lock

Safari ignores it. Always use the `position: fixed` pattern:

```tsx
useEffect(() => {
  if (isOpen) {
    const scrollY = window.scrollY;
    document.body.style.position = "fixed";
    document.body.style.top = `-${scrollY}px`;
    document.body.style.left = "0";
    document.body.style.right = "0";
    document.body.style.overflow = "hidden";
  } else {
    const scrollY = document.body.style.top;
    document.body.style.position = "";
    document.body.style.top = "";
    document.body.style.left = "";
    document.body.style.right = "";
    document.body.style.overflow = "";
    window.scrollTo(0, parseInt(scrollY || "0") * -1);
  }
  return () => { /* reset all styles */ };
}, [isOpen]);
```

### Rule 3: Never Use Raw `<input type="date">` in UI

Safari renders them as unstyled empty rectangles and ignores your CSS. `.showPicker()` is unreliable. Always use the **invisible overlay pattern**:

```tsx
<div className="relative">
  {/* Visible styled element — full control over appearance */}
  <div className="w-full flex items-center gap-2 px-3 py-3 border rounded-xl">
    <CalendarIcon className="w-4 h-4 text-gray-400 shrink-0" />
    <span className={date ? 'text-gray-900 font-medium' : 'text-gray-400'}>
      {date ? formatDate(date) : 'Select date'}
    </span>
  </div>
  {/* Invisible native input — handles tap + opens native iOS picker */}
  <input
    type="date"
    className="absolute inset-0 opacity-0 w-full h-full cursor-pointer"
    value={date}
    onChange={(e) => setDate(e.target.value)}
  />
</div>
```

**Banned:** `.showPicker()`, `appearance: none` on date inputs, `sr-only` class on date inputs (removes tap target).

### Rule 4: Never Use `100vh`

Safari's `100vh` includes the address bar area, causing content to overflow or be hidden behind the URL bar.

```css
/* ❌ WRONG */
min-h-[100vh]
min-h-[calc(100vh-4rem)]
max-h-[90vh]

/* ✅ CORRECT — use dvh with fallback */
min-h-[100dvh]
min-h-[calc(100dvh-4rem)]

/* ✅ ALSO CORRECT — fixed positioning avoids height calc entirely */
.fixed.inset-x-0.top-[8vh].bottom-0
```

Add the CSS fallback in globals.css:
```css
:root { --dvh: 1vh; }
@supports (height: 1dvh) { :root { --dvh: 1dvh; } }
```

### Rule 5: Always Add Safe Area Padding on Full-Screen Elements

Any element that touches the screen edges needs safe area padding for the Dynamic Island / notch and home indicator.

**Prerequisite** (set once in root layout):
```tsx
export const viewport: Viewport = { viewportFit: "cover" };
```

**Apply on every full-screen/edge-to-edge element:**
```tsx
style={{
  paddingBottom: 'env(safe-area-inset-bottom, 0px)',
  paddingTop: 'env(safe-area-inset-top, 0px)',
}}
```

### Rule 6: Always Add `overflow-x-hidden` on Drawers/Modals

Child elements (grids, date inputs, tables) can have intrinsic widths wider than the container, causing horizontal scroll.

```tsx
// ✅ Always include overflow-x-hidden on any overlay container
<div className="fixed inset-0 overflow-y-auto overflow-x-hidden">
```

### Rule 7: Avoid Frosted Glass / `backdrop-blur` on Mobile

`backdrop-filter: blur()` technically works but:
1. Creates a stacking context (see Rule 1)
2. Looks washed out / muddy with colored backgrounds behind it
3. Hurts performance on older iPhones

**Prefer solid backgrounds on mobile.** Use `backdrop-blur` only on desktop (`md:backdrop-blur-md`) or accept the stacking context implications.

```tsx
// ❌ Avoid on mobile
className="bg-white/95 backdrop-blur-md"

// ✅ Solid on mobile, blur on desktop
className="bg-white md:bg-white/95 md:backdrop-blur-md"
```

**Exception:** If the element is a top-level sticky nav and no modals render inside it, `backdrop-blur` is acceptable.

### Rule 8: Use `touch-action: manipulation` Globally

Eliminates the 300ms tap delay on iOS Safari and prevents double-tap zoom on interactive elements.

```css
/* globals.css */
button, a, input, select, textarea, [role="button"] {
  touch-action: manipulation;
}
```

### Rule 9: Prefer Fixed Positioning Over Height Calculations

For drawers/sheets, don't calculate max-height. Pin to explicit bounds:

```tsx
// ❌ WRONG — height calc unreliable on Safari
<div className="max-h-[90vh] overflow-y-auto">

// ✅ CORRECT — explicit bounds, no calculation
<div className="fixed inset-x-0 top-[10vh] bottom-0 overflow-y-auto">
```

### Rule 10: Add `overscroll-contain` to Scrollable Overlays

Prevents scroll chaining — when the user scrolls to the end of a drawer, it won't scroll the page behind it.

```tsx
<div className="overflow-y-auto overscroll-contain">
```

---

## Code Review Checklist

When reviewing any PR that touches mobile UI, verify:

- [ ] All `fixed` overlays use `createPortal` to `document.body`
- [ ] No `body.style.overflow = "hidden"` — uses `position: fixed` pattern instead
- [ ] No raw `<input type="date">` — uses invisible overlay pattern
- [ ] No `100vh` — uses `100dvh` or fixed positioning
- [ ] Full-screen elements have `env(safe-area-inset-*)` padding
- [ ] Drawers/modals have `overflow-x-hidden`
- [ ] No `backdrop-blur` on mobile without understanding stacking context impact
- [ ] Scrollable overlays have `overscroll-contain`
- [ ] `touch-action: manipulation` on interactive elements (or set globally)

### Rule 11: Prevent Input Zoom on iOS

Safari automatically zooms the page when a user focuses an `<input>` or `<textarea>` with `font-size` below `16px`. The page zooms in and often doesn't zoom back out.

```css
/* ❌ WRONG — Safari will zoom the page on focus */
input { font-size: 14px; }
input { @apply text-sm; } /* text-sm = 14px in Tailwind */

/* ✅ CORRECT — 16px minimum prevents zoom */
input, textarea, select {
  font-size: 16px; /* or larger */
}

/* ✅ ALSO CORRECT — disable zoom globally (use carefully) */
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
```

**Warning:** `maximum-scale=1` prevents ALL pinch-to-zoom, which is an accessibility concern. Prefer setting `font-size: 16px` on inputs instead.

### Rule 12: Disable Auto-Detection of Phone Numbers and Emails

Safari auto-detects strings that look like phone numbers or email addresses and turns them into tappable links with default blue styling, breaking your layout.

```html
<!-- Add to <head> -->
<meta name="format-detection" content="telephone=no, email=no, address=no" />
```

Then explicitly add `<a href="tel:...">` and `<a href="mailto:...">` where you actually want clickable links.

### Rule 13: Mobile Drawers Should Auto-Height, Not Full-Height

Don't pin drawers from a fixed top to `bottom-0` — this creates dead whitespace below the content.

```css
/* ❌ WRONG — always full height, dead space below content */
.fixed.inset-x-0.top-[8vh].bottom-0

/* ✅ CORRECT — grows from bottom to fit content, capped */
.fixed.inset-x-0.bottom-0.max-h-[92vh]
```

The drawer wraps tightly around its content. `max-h` prevents it from exceeding the viewport on content-heavy pages. `overflow-y-auto` handles the rare case where content exceeds the max.

### Rule 14: Mobile Panels Need Fixed Positioning Outside the Scroll Container

If you add a sub-panel (like a date picker) inside a scrollable drawer, it will scroll with the content and look broken. The panel must be `fixed` positioned as a sibling of the drawer, not a child.

```tsx
// ❌ WRONG — panel inside the scroll container
<div className="overflow-y-auto">
  <FormFields />
  <CalendarPanel />  {/* scrolls with content */}
</div>

// ✅ CORRECT — panel is a fixed sibling, above the drawer
<div className="overflow-y-auto">
  <FormFields />
</div>
{showPanel && <div className="fixed inset-x-0 top-[35vh] bottom-0 z-[10002]">Panel</div>}
{showPanel && <div className="fixed inset-0 bg-black/20 z-[10001]" onClick={close} />}
```

The scrim and panel must have higher z-index than the drawer (`z-[10001]` and `z-[10002]` vs drawer's `z-[10000]`).

---

## Audit Commands

Run these to find violations in an existing codebase:

```bash
# Find modals/overlays not using portals
grep -rn "fixed inset-0" src/ --include="*.tsx" | grep -v "createPortal"

# Find raw date inputs
grep -rn 'type="date"' src/ --include="*.tsx" | grep -v "opacity-0"

# Find 100vh usage
grep -rn "100vh" src/ --include="*.tsx" --include="*.css"

# Find body overflow:hidden scroll locks
grep -rn "body.style.overflow" src/ --include="*.tsx"

# Find backdrop-blur (stacking context creators)
grep -rn "backdrop-blur\|backdrop-filter" src/ --include="*.tsx" --include="*.css"

# Find missing overscroll-contain on scroll containers inside fixed overlays
grep -rn "overflow-y-auto" src/ --include="*.tsx" | grep -v "overscroll-contain"

# Find inputs with font-size below 16px (zoom trigger)
grep -rn "text-xs\|text-sm\|font-size.*1[0-5]px" src/ --include="*.tsx" | grep -i "input\|textarea\|select"

# Find missing format-detection meta tag
grep -rn "format-detection" src/app/layout.tsx

```

---

## Testing Requirements

**Every mobile UI change must be tested on a real iPhone.** Period.

Chrome DevTools, Responsively, and iOS Simulator all use different rendering engines than real Safari. They will miss:
- Stacking context traps
- Date input rendering
- `100vh` miscalculation
- Touch behavior differences
- Safe area inset behavior
- Native picker presentation

**Quick test setup:**
1. Run dev server on your machine
2. Open `http://<your-ip>:<port>` on your iPhone
3. For debugging: iPhone → Settings → Safari → Advanced → Web Inspector → connect via USB + Safari Develop menu on Mac
