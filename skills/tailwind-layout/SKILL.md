---
name: tailwind-layout
description: Tailwind CSS layout patterns for consistent, aligned, responsive UIs across all screen sizes. Use when building or modifying card grids, booking wizards, step indicators, sidebars, sticky bars, or any responsive layout with Tailwind. Also use when making design recommendations for different screen sizes or devices. Prevents common alignment bugs like uneven card heights, misaligned buttons, cramped grids, and broken flex layouts. Covers responsive breakpoints, device-aware layouts, and touch targets. Use before writing any Tailwind grid/flex layout code or recommending layout changes.
---

# Tailwind Layout Patterns

Mandatory patterns for layout work. Violations cause visual bugs.

## Equal-Height Cards in Grids

Cards in a CSS grid row MUST have aligned content. Three properties are ALWAYS required together:

```tsx
{/* Outer card wrapper */}
<div className="h-full flex flex-col ...">
  {/* Fixed content (e.g., image) */}
  <div className="aspect-[4/3]">...</div>
  
  {/* Flexible content area */}
  <div className="p-4 flex-grow flex flex-col">
    <h3>Title</h3>
    <p>Price</p>
    {/* Optional content that varies between cards */}
    {deposit && <p>Deposit info</p>}
    
    {/* Action pinned to bottom */}
    <button className="mt-auto pt-3 w-full">Select</button>
  </div>
</div>
```

**All four are required:**
1. `h-full flex flex-col` on outer card (stretches to grid row height)
2. `flex-grow flex flex-col` on content area (fills remaining space)
3. `<div className="flex-grow" />` spacer before the bottom element (pushes it down)
4. `flex items-center justify-center` on bottom button (centers text inside)

```tsx
<div className="p-4 flex-grow flex flex-col">
  <h3>Title</h3>
  <p>Price</p>
  {deposit && <p>Deposit info</p>}
  
  {/* Spacer pushes button to bottom */}
  <div className="flex-grow" />
  
  {/* Button text is centered */}
  <button className="mt-3 w-full h-11 flex items-center justify-center">Select</button>
</div>
```

**Common mistakes:**
- Adding `mt-auto` without `flex-grow flex flex-col` on parent — button won't move because parent has no extra space.
- Using `pt-3` (padding-top) on a button with `flex items-center justify-center` — the padding is INSIDE the button, pushing text down. Use `mt-3` (margin-top) for spacing ABOVE the button instead.
- Using `mt-auto` directly on the button without a spacer — works for pushing down but can conflict with `mt-3` spacing. A `flex-grow` spacer div is cleaner.

## Responsive Grid Columns

Match column count to available card width. Minimum comfortable card width: ~280px.

```tsx
{/* Standard product grid with sidebar */}
<div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4 lg:gap-5">
```

**Breakpoint math before choosing columns:**
- Calculate: (container width - sidebar - gaps) ÷ columns = card width
- If card width < 280px → use fewer columns at that breakpoint
- Always verify at the breakpoint boundary (e.g., exactly 1024px for `lg`)

## Sidebar Layouts

Use fixed sidebar width, not fractional grid, when sidebar has predictable content (prices, summaries, CTAs):

```tsx
{/* Fixed sidebar — content gets guaranteed minimum width */}
<div className="lg:grid lg:grid-cols-[1fr_340px] xl:grid-cols-[1fr_380px] lg:gap-8">
  <div>{/* Main content — gets all remaining space */}</div>
  <div className="hidden lg:block">
    <div className="sticky top-24">{/* Sidebar */}</div>
  </div>
</div>
```

**Why not `grid-cols-3` with `col-span-2`/`col-span-1`?** Fractional splits give the sidebar a percentage of width. On narrow viewports the sidebar gets too small; on wide viewports the main content doesn't gain enough. Fixed sidebar width ensures prices never truncate and names never wrap excessively.

**Sidebar text protection:**
```tsx
<span className="truncate">Long item name</span>
<span className="whitespace-nowrap">$75/day</span>
```
Prices get `whitespace-nowrap`; names get `truncate`. Never the reverse.

## Step Indicators / Steppers

Use CSS grid for equal-width steps regardless of label length:

```tsx
<div className="grid grid-cols-4 gap-0 max-w-2xl mx-auto">
  {steps.map((step, i) => (
    <div key={step.key} className="flex flex-col items-center text-center relative">
      {/* Connector line — absolute positioned between circles */}
      {i < steps.length - 1 && (
        <div className="absolute top-[18px] left-[calc(50%+18px)] right-[calc(-50%+18px)] h-0.5 bg-gray-200" />
      )}
      {/* Circle */}
      <div className="relative z-10 w-9 h-9 rounded-full flex items-center justify-center text-sm font-semibold">
        {i + 1}
      </div>
      {/* Label below circle */}
      <span className="hidden sm:block text-xs font-medium mt-1.5 leading-tight max-w-[5rem]">
        {step.label}
      </span>
    </div>
  ))}
</div>
```

**Why not `flex justify-between`?** Long labels (e.g., "Choose Your Ride" vs "Payment") eat proportionally more space, making connector lines uneven. Grid forces equal columns.

**Constrain width:** `max-w-2xl mx-auto` — steppers should never stretch to full container width on wide screens.

## Responsive Design by Screen Size

Tailwind breakpoints and what they map to in the real world:

| Breakpoint | Min Width | Typical Devices | Orientation |
|---|---|---|---|
| Default | 0px | iPhone SE, small Android | Portrait |
| `sm` | 640px | Large phones, small tablets | Portrait |
| `md` | 768px | iPad Mini/Air, tablets | Portrait |
| `lg` | 1024px | iPad Pro, small laptops, 13" MacBook | Landscape |
| `xl` | 1280px | 14" laptops, desktop monitors | Landscape |
| `2xl` | 1536px | 16" MacBook Pro, large monitors | Landscape |

### Layout Strategy Per Breakpoint

**Mobile (default → sm):** Single column. Full-width cards. No sidebar — use bottom sheets or collapsible sections. Touch targets minimum 44px (`h-11`). Generous padding (`px-4`).

**Tablet (md):** Two-column grids. Sidebar still hidden — not enough room for content + sidebar together. Consider showing key info (selection count, total) in a sticky bottom bar instead.

**Small laptop (lg, 1024px):** Sidebar can appear. Use **2-column** product grids with sidebar — NOT 3-column. At 1024px with a 340px sidebar, 3 columns would give ~190px cards (too small). Container max-width: 1200px.

**Laptop (xl, 1280px):** 3-column grids become viable with sidebar. Widen container to 1400px. Cards get ~307px each — comfortable.

**Large display (2xl, 1536px+):** Don't let content stretch further. Cap at 1400px `mx-auto`. Content floating in whitespace is better than content stretching to 1536px.

### Responsive Container Widths

```tsx
<div className="max-w-[1200px] xl:max-w-[1400px] mx-auto px-4 md:px-6 lg:px-8">
```

- `px-4` (16px) mobile → `px-6` (24px) tablet → `px-8` (32px) desktop
- Don't go wider than 1400px — content starts floating on ultra-wide displays
- Test at exact breakpoint boundaries (1024px, 1280px, 1536px)

### Responsive Component Patterns

**Show/hide by breakpoint:**
```tsx
{/* Mobile: bottom bar */}
<div className="lg:hidden fixed bottom-0 ...">
{/* Desktop: sidebar */}
<div className="hidden lg:block ...">
```

**Text scaling:**
```tsx
<h1 className="text-2xl md:text-3xl xl:text-4xl">
<p className="text-sm md:text-base">
```

**Grid column progression:**
```tsx
{/* Cards: 1 → 2 → 2+sidebar → 3+sidebar */}
grid-cols-1 sm:grid-cols-2 xl:grid-cols-3
```

**Spacing scaling:**
```tsx
{/* Tighter on mobile, roomier on desktop */}
gap-4 lg:gap-5 xl:gap-6
py-6 md:py-8 xl:py-12
```

### Touch vs Pointer

Mobile users tap; desktop users click. Design for both:

| Element | Mobile Min | Desktop Min |
|---|---|---|
| Buttons | `h-11` (44px) | `h-10` (40px) |
| Card tap areas | Full card clickable | Hover states OK |
| Close/dismiss | `w-8 h-8` minimum | `w-6 h-6` OK |
| Spacing between tappable items | `gap-3` (12px) | `gap-2` (8px) OK |

### Common Responsive Mistakes

| ❌ Mistake | ✅ Fix |
|---|---|
| Same grid columns at all breakpoints | Progressive: 1 → 2 → 3 with breakpoints |
| Sidebar visible at `md` (768px) | Sidebar at `lg` (1024px) minimum |
| Fixed px widths that don't scale | Use max-w + responsive padding |
| Hiding content on mobile with no alternative | Replace with bottom bar, collapsible, or modal |
| Testing only at one screen size | Check at each breakpoint boundary |
| Same font size everywhere | Scale headings: `text-2xl md:text-3xl xl:text-4xl` |

## Verification Checklist

Before committing any layout change:

1. **Card grids:** Do all cards in a row have the same height? Are buttons aligned?
2. **Sidebar:** Does price text wrap or truncate? Check at `lg` breakpoint (1024px).
3. **Steppers:** Are all steps equal width? Check with longest and shortest labels.
4. **Container:** Does content feel cramped at `lg`? Too floaty at `2xl`?
5. **Mobile:** Does the layout stack cleanly? No horizontal scroll?

## Anti-Patterns

| ❌ Don't | ✅ Do |
|----------|-------|
| `mt-auto` without flex parent chain | Full chain: `h-full flex flex-col` → `flex-grow flex flex-col` → `<div className="flex-grow" />` spacer → button |
| `pt-3` inside a button for spacing above it | `mt-3` on the button (margin outside, not padding inside) |
| Fixed-height button without centering | `h-11 flex items-center justify-center` on every button with fixed height |
| `grid-cols-3` with `col-span-2/1` for sidebar | `grid-cols-[1fr_340px]` fixed sidebar |
| `flex justify-between` for steppers | `grid grid-cols-N` equal columns |
| `lg:grid-cols-3` when cards would be <280px | Do the math, use `xl:grid-cols-3` |
| Centering card text horizontally for alignment | Fix vertical alignment with flex + mt-auto |
