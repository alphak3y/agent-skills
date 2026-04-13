# react-day-picker v9 — Styling & Integration Guide

## Description
Patterns for integrating react-day-picker v9 with Tailwind CSS. Use when building branded date pickers, date range selectors, or any calendar UI. Covers the critical pitfalls that waste hours.

## When to Use
- Adding a date picker to any page
- Styling react-day-picker with Tailwind
- Debugging disabled/selected/range styles not applying
- Building a hybrid mobile (native) + desktop (branded) date picker

---

## Critical Rule: Always Import the Default Stylesheet

```tsx
import "react-day-picker/style.css";
```

**Without this, disabled states, range states, and modifier styles silently fail.** The default stylesheet sets CSS variables like `--rdp-disabled-opacity` that the component relies on. If you skip it and only use `classNames`, modifiers won't apply.

## Styling with classNames

v9 uses three enums for `classNames` keys:

```tsx
import { UI, DayFlag, SelectionState } from "react-day-picker";

// UI — structural elements
UI.Root        // "root"
UI.Day         // "day"
UI.DayButton   // "day_button"
UI.Nav         // "nav"
UI.MonthCaption // "month_caption"
// ... etc

// DayFlag — day state modifiers
DayFlag.disabled  // "disabled"
DayFlag.today     // "today"
DayFlag.outside   // "outside"
DayFlag.hidden    // "hidden"
DayFlag.focused   // "focused"

// SelectionState — selection modifiers
SelectionState.selected      // "selected"
SelectionState.range_start   // "range_start"
SelectionState.range_middle  // "range_middle"
SelectionState.range_end     // "range_end"
```

All three go into the same `classNames` prop:

```tsx
<DayPicker
  classNames={{
    [UI.Root]: "font-sans",
    [UI.Nav]: "flex gap-1",
    [DayFlag.disabled]: "!text-gray-300 !cursor-default",
    [SelectionState.selected]: "!bg-orange-500 !text-white",
  }}
/>
```

## The Disabled Styles Trap

**Problem:** You set `disabled={{ before: today }}` and `classNames={{ [DayFlag.disabled]: "text-gray-300" }}` but disabled dates look identical to active ones.

**Cause:** Your custom classNames REPLACE the defaults. The default `.rdp-disabled` class includes opacity and pointer-events rules. Without it, your disabled class is just a text color that gets overridden by the day button styles.

**Fix options (in order of reliability):**

### Option 1: modifiersStyles (most reliable)
```tsx
<DayPicker
  modifiersStyles={{
    disabled: { opacity: 0.25, pointerEvents: 'none' }
  }}
/>
```
Inline styles always win specificity battles.

### Option 2: CSS Variable Override
```css
.rdp-root {
  --rdp-disabled-opacity: 0.25;
}
```

### Option 3: Extend Default ClassNames
```tsx
import { getDefaultClassNames } from "react-day-picker";
const defaults = getDefaultClassNames();

<DayPicker
  classNames={{
    disabled: `${defaults.disabled} !text-gray-300`,
  }}
/>
```

### Recommended: Belt and Suspenders
Use BOTH the stylesheet import AND modifiersStyles:
```tsx
import "react-day-picker/style.css";

<DayPicker
  classNames={{
    [DayFlag.disabled]: "!text-summit-black/20 !cursor-default !pointer-events-none",
  }}
  modifiersStyles={{
    disabled: { opacity: 0.25, pointerEvents: 'none' },
  }}
/>
```

## Range Selection Styling

For a continuous range strip (no vertical lines between days):

```tsx
// Use inset box-shadow instead of borders for seamless range strip
[SelectionState.range_start]:
  "!bg-orange-500/15 !rounded-l-xl !rounded-r-none !shadow-[inset_0_1px_0_rgba(255,107,44,0.25),inset_0_-1px_0_rgba(255,107,44,0.25),inset_1px_0_0_rgba(255,107,44,0.25)]",
[SelectionState.range_end]:
  "!bg-orange-500/15 !rounded-r-xl !rounded-l-none !shadow-[inset_0_1px_0_rgba(255,107,44,0.25),inset_0_-1px_0_rgba(255,107,44,0.25),inset_-1px_0_0_rgba(255,107,44,0.25)]",
[SelectionState.range_middle]:
  "!bg-orange-500/10 !rounded-none !shadow-[inset_0_1px_0_rgba(255,107,44,0.25),inset_0_-1px_0_rgba(255,107,44,0.25)]",
```

**Do NOT use `border`** — it creates vertical lines between each day cell. Use `inset box-shadow` for top/bottom/left/right border effects without gaps.

## Hover Range Preview

React-day-picker v9 doesn't show range preview on hover by default. Add it manually:

```tsx
const [hoveredDate, setHoveredDate] = useState<Date | null>(null);

<DayPicker
  modifiers={{
    hoverRange: (date: Date) => {
      if (!selected?.from || !hoveredDate) return false;
      // Only show preview when pickup is selected but return isn't yet
      const hasRealRange = selected.to && selected.from.getTime() !== selected.to.getTime();
      if (hasRealRange) return false;
      
      const fromTime = selected.from.getTime();
      const hovTime = hoveredDate.getTime();
      const dateTime = date.getTime();
      return dateTime >= Math.min(fromTime, hovTime) && dateTime <= Math.max(fromTime, hovTime);
    },
  }}
  modifiersClassNames={{
    hoverRange: "!bg-orange-500/5 !rounded-none",
  }}
  onDayMouseEnter={(date) => setHoveredDate(date)}
  onDayMouseLeave={() => setHoveredDate(null)}
/>
```

**Key gotcha:** react-day-picker sets `to = from` on first click. Check `from.getTime() !== to.getTime()` to detect "user clicked pickup but hasn't picked return yet."

## Preventing Past Month Navigation

`startMonth` prop may not visually disable the back arrow. Handle it manually:

```tsx
const [month, setMonth] = useState(today);
const isCurrentMonth = month.getFullYear() === today.getFullYear() 
  && month.getMonth() === today.getMonth();

<DayPicker
  month={month}
  onMonthChange={(m) => {
    if (m < new Date(today.getFullYear(), today.getMonth(), 1)) return;
    setMonth(m);
  }}
  components={{
    Chevron: (props) => (
      <ChevronIcon 
        orientation={props.orientation} 
        disabled={props.orientation === "left" && isCurrentMonth} 
      />
    ),
  }}
/>
```

## Hybrid: Native Mobile + Branded Desktop

Best pattern for cross-platform date pickers:

- **Mobile (<md):** Invisible `<input type="date">` overlay (see safari-ios-mobile skill)
- **Desktop (md+):** react-day-picker with full brand styling

```tsx
// Mobile: invisible overlay triggers native iOS/Android picker
<div className="relative md:hidden">
  <div className="styled-display">{date || "Select date"}</div>
  <input type="date" className="absolute inset-0 opacity-0 w-full h-full" />
</div>

// Desktop: branded calendar
<div className="hidden md:block">
  <DateRangeCalendar ... />
</div>
```

**Never use `.showPicker()` on mobile Safari** — it's unreliable. The invisible overlay always works.

## Auto-Close Behavior

Don't auto-close immediately when both dates are selected — react-day-picker sets `to = from` on first click, which triggers false positives:

```tsx
onSelect={(from, to) => {
  setFromDate(from);
  setToDate(to);
  // Only auto-close on a REAL range (from ≠ to)
  // Or better: don't auto-close at all, let user close manually
}}
```

## Focus Outline / Highlight on Click

The default stylesheet and browser add focus outlines when clicking date cells. Kill them:

```tsx
[UI.DayButton]:
  "...your styles... !outline-none !ring-0 !shadow-none focus:!outline-none focus:!ring-0 focus-visible:!outline-none focus-visible:!ring-0",
```

Use `!important` on all four — the default rdp stylesheet, Tailwind preflight, and browser defaults all compete for focus styling.

## Hover Color on Selected Range

The default hover (`hover:bg-gray-*`) clashes with the orange range highlighting. Use a warm orange hover that blends with the range:

```tsx
[UI.DayButton]:
  "...your styles... hover:bg-blaze-orange/20",
```

**Don't use gray/neutral hover colors** — they look dirty against the warm orange range strip. Match the hover to the range color family at a slightly higher opacity.

Sweet spot: 20% opacity of your brand accent color.

## Disabled Date Appearance

Past dates should be clearly faded — Airbnb uses light gray text. The key is importing the default stylesheet AND using modifiersStyles:

```tsx
import "react-day-picker/style.css";

<DayPicker
  classNames={{
    [DayFlag.disabled]: "!text-summit-black/20 !cursor-default !pointer-events-none",
  }}
  modifiersStyles={{
    disabled: { opacity: 0.25, pointerEvents: 'none' },
  }}
/>
```

Belt and suspenders — classNames for Tailwind integration, modifiersStyles as inline fallback.

## Preventing Past Month Navigation

`startMonth` prop may not visually gray out the back arrow. Handle manually:

```tsx
const isCurrentMonth = month.getFullYear() === today.getFullYear() 
  && month.getMonth() === today.getMonth();

<DayPicker
  month={month}
  onMonthChange={(m) => {
    if (m < new Date(today.getFullYear(), today.getMonth(), 1)) return;
    setMonth(m);
  }}
  components={{
    Chevron: (props) => (
      <ChevronIcon 
        orientation={props.orientation} 
        disabled={props.orientation === "left" && isCurrentMonth}
      />
    ),
  }}
/>
```

Gray out the chevron icon at ~20% opacity when disabled. Don't just hide it — that shifts the layout.

## Mobile Accordion Pattern

On mobile, don't drop the calendar inline — it pushes content off-screen. Use an accordion panel:

```tsx
// Collapsed: "Add dates" button matching other input styles
// Expanded: fixed panel sliding up from bottom with scrim overlay

<div className="fixed inset-x-0 top-[35vh] bottom-0 z-[10002] bg-white rounded-t-2xl flex flex-col">
  <div className="shrink-0">Header (X + title + Clear)</div>
  <div className="flex-1 flex items-center px-4">Calendar</div>
  <div className="shrink-0 px-4 pb-4">Done button</div>
</div>
```

Key decisions:
- **Scrim** (`bg-black/20`) covers everything behind the panel — tap to dismiss
- **`top-[35vh]`** — panel covers bottom 65% of screen, hiding fields below the trigger
- **`flex flex-col`** — header pinned top, Done pinned bottom, calendar centered in middle
- **`compact` prop** — pass to calendar to disable `showOutsideDays` and `fixedWeeks` on mobile (saves ~2 rows of vertical space)
- **No auto-close** — let user review selection and tap Done. Auto-close on range selection feels abrupt on mobile.
- **`activeSection` state** — only one section expanded at a time (accordion). Tapping WHERE/WHAT closes calendar.

## Full-Width Calendar Grid on Mobile

The default day grid has fixed `w-10` cells = 280px total. On a 430px phone, it looks off-center.

Fix: make grid rows `w-full` and let cells stretch:

```tsx
[UI.Weekdays]: "grid grid-cols-7 mb-1 w-full",
[UI.Week]: "grid grid-cols-7 w-full",
[UI.MonthGrid]: "w-full",
[UI.Day]: "h-10 relative flex items-center justify-center",  // no fixed width
[UI.DayButton]: "w-10 h-10 ...",  // button stays 40px, centered in flexible cell
```

## Configurable Past Date Restriction

The calendar needs different behavior for booking vs admin:

```tsx
interface Props {
  disablePastDates?: boolean; // default true
  min?: string;              // earliest selectable date
  max?: string;              // latest selectable date
}

// Booking flow: can't pick past dates
<DateRangeCalendar disablePastDates={true} />  // default

// Admin reporting: past dates allowed, capped at tenant creation
<DateRangeCalendar disablePastDates={false} min={tenantCreatedAt} />
```

Also gate month navigation on `disablePastDates` — don't block past month nav for admin.

## Controlled vs Uncontrolled Date Inputs

If using `DateInput` inside a `<form>` that submits via `FormData`:

```tsx
// ❌ WRONG — display never updates, calendar can't highlight selection
<DateInput name="validFrom" value="" onChange={() => {}} />

// ✅ CORRECT — controlled state, display + calendar work
const [date, setDate] = useState("");
<DateInput name="validFrom" value={date} onChange={setDate} />
```

The `name` prop still works for FormData — the hidden input carries it. But you MUST use controlled state for the branded display to update.

## Date Display Formatting — Always UTC

All date formatting must use `timeZone: 'UTC'` to prevent hydration mismatches:

```tsx
// ❌ WRONG — server (UTC) and client (local tz) render different dates
new Date(dateStr).toLocaleDateString()

// ✅ CORRECT — always renders the same regardless of timezone
date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', timeZone: 'UTC' })
```

Centralize formatters in `src/lib/utils/dates.ts` and import everywhere.

## Date Display While Selecting

When showing the selected range in the UI (e.g., search pill):

```tsx
// Both selected: "Apr 14 – Apr 18"
// Pickup only: "Apr 14 – …" (ellipsis, not the same date twice)
// Nothing: "Add dates"

const display = (from && to && from !== to)
  ? `${format(from)} – ${format(to)}`
  : from
    ? `${format(from)} – …`
    : "";
```

**Never show "Apr 14 – Apr 14"** — react-day-picker sets `to = from` on first click. Always check `from !== to`.
