# Storefront Contrast — Prevent White-on-White Text

## Description
Mandatory rules for storefront/customer-facing components. Storefronts use tenant brand colors via CSS variables, which can result in light text on light backgrounds. Always set explicit text and background colors.

## When to Use
- Building any component in `src/app/(storefront)/`, `src/components/storefront/`, `src/app/(marketplace)/`
- Any input, button, card, or text element on customer-facing pages
- Code review of storefront PRs

---

## Rule: Always Set Explicit Text + Background Colors

Storefront components inherit from tenant brand CSS variables (`var(--brand-primary)`, etc.) which can be ANY color. Never rely on inherited text color.

```tsx
// ❌ WRONG — inherits text color, might be white on white
<input className="w-full px-4 py-3 border rounded-lg text-lg" />

// ✅ CORRECT — explicit colors, always readable
<input className="w-full px-4 py-3 border rounded-lg text-lg text-gray-900 bg-white placeholder:text-gray-400" />
```

## Required Classes on Storefront Elements

### Inputs
```
text-gray-900 bg-white placeholder:text-gray-400 border-gray-300
```

### Buttons (primary)
```
bg-blaze-orange text-white
```

### Buttons (secondary)
```
bg-white text-gray-900 border-gray-300
```

### Card backgrounds
```
bg-white border-gray-200
```

### Headings
```
text-gray-900
```

### Body text
```
text-gray-700
```

### Muted / helper text
```
text-gray-500
```

### Labels
```
text-gray-700
```

## Never Use on Storefronts

```tsx
// ❌ These rely on inherited/variable colors — unpredictable
var(--brand-primary) for text color
text-[var(--brand-primary)] on light backgrounds
No text-color class at all on inputs or buttons
```

## Audit Command

```bash
# Find inputs without explicit text color
grep -rn '<input' src/app/\(storefront\)/ src/components/storefront/ --include="*.tsx" | grep -v "text-gray\|text-summit\|text-white\|text-blaze"

# Find buttons without explicit text color  
grep -rn '<button' src/app/\(storefront\)/ src/components/storefront/ --include="*.tsx" | grep -v "text-gray\|text-summit\|text-white\|text-blaze"
```
