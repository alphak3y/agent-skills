# Safari iOS Mobile — Common Pitfalls & Solutions

## Description
Fixes for common Safari iOS rendering issues in mobile web apps. Use when building or debugging mobile UI that works in Chrome DevTools / Responsively but breaks on real iPhones.

## Key Lesson
**Always test on a real iPhone.** Chrome DevTools, Responsively, and simulators all use Chrome's engine. Real iPhones use Safari WebKit — different rendering, different bugs.

---

## 1. Z-Index / Stacking Context Trap

**Symptom:** Modal/drawer renders behind other elements despite `z-index: 9999`.

**Cause:** A parent element has `transform`, `will-change`, `filter`, `backdrop-filter`, or `opacity < 1` — any of these create a new stacking context. Z-index can never escape a stacking context, no matter how high.

**Fix:** Use a React portal to render the element directly on `document.body`:
```tsx
import { createPortal } from "react-dom";

// Inside render:
{isOpen && typeof document !== 'undefined' && createPortal(
  <MyDrawer />,
  document.body
)}
```

---

## 2. Body Scroll Lock

**Symptom:** Background page scrolls when modal/drawer is open.

**Cause:** Safari ignores `overflow: hidden` on `<body>`.

**Fix:** Use `position: fixed` on body, save and restore scroll position:
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

---

## 3. Date Input Styling

**Symptom:** `<input type="date">` renders as oversized empty rectangles, ignores Tailwind classes, `.showPicker()` doesn't work.

**Cause:** Safari uses shadow DOM for date inputs with its own padding/sizing. `appearance: none` kills the native picker entirely. `.showPicker()` may not work in all Safari versions.

**Fix:** Invisible date input overlay pattern:
```tsx
<div className="relative">
  {/* Visible styled element */}
  <div className="w-full flex items-center gap-2 px-3 py-3 bg-trail-white border rounded-xl">
    <CalendarIcon />
    <span>{selectedDate || 'Select date'}</span>
  </div>
  {/* Invisible native input on top */}
  <input
    type="date"
    className="absolute inset-0 opacity-0 w-full h-full cursor-pointer"
    value={date}
    onChange={(e) => setDate(e.target.value)}
  />
</div>
```
The user taps the invisible native input → Safari opens its native date picker → `onChange` fires → you display the formatted date in your styled element.

**Do NOT use:** `.showPicker()` (unreliable on Safari), `appearance: none` (kills the picker), `sr-only` class (removes from tap target).

---

## 4. Viewport Height (`vh` vs `dvh`)

**Symptom:** Full-screen drawer is too tall or too short, overlaps Safari's address bar.

**Cause:** Safari's `100vh` includes the address bar area. When the bar shrinks on scroll, content doesn't adjust.

**Fix:** Use `dvh` (dynamic viewport height) where supported:
```css
:root { --dvh: 1vh; }
@supports (height: 1dvh) { :root { --dvh: 1dvh; } }
```

Or better — use fixed positioning with explicit bounds instead of height calculations:
```tsx
<div className="fixed inset-x-0 top-[8vh] bottom-0">
```
This is more reliable than `max-h-[90dvh]`.

---

## 5. Safe Area Insets

**Symptom:** Content hidden behind iPhone notch/Dynamic Island or home indicator bar.

**Prerequisites:** `viewport-fit=cover` must be set in the viewport meta tag:
```tsx
export const viewport: Viewport = { viewportFit: "cover" };
```

**Fix:** Use `env()` for padding:
```tsx
style={{ 
  paddingBottom: 'env(safe-area-inset-bottom, 0px)',
  paddingTop: 'env(safe-area-inset-top, 0px)' 
}}
```

---

## 6. Horizontal Overflow in Drawers

**Symptom:** Content scrolls left-right inside a modal/drawer.

**Cause:** Child elements (especially date inputs, grids) have intrinsic widths wider than the container.

**Fix:** Add `overflow-x-hidden` to the drawer container.

---

## 7. Frosted Glass / Backdrop Blur

**Symptom:** `backdrop-filter: blur()` looks washed out or muddy on Safari.

**Reality:** It technically works on Safari 13+ but the visual result with colored backgrounds behind it rarely looks "premium." Often just looks dirty.

**Recommendation:** Prefer solid backgrounds over frosted glass on mobile. Save blur effects for desktop where you control the background.

---

## Testing Checklist
- [ ] Test on real iPhone (not just DevTools/Responsively)
- [ ] Check with Safari address bar visible AND hidden (scroll down to hide it)
- [ ] Test with Dynamic Island / notch area
- [ ] Test landscape orientation
- [ ] Verify date pickers open native iOS picker
- [ ] Verify modals/drawers aren't trapped behind other elements
- [ ] Verify no horizontal scroll in drawers/modals
