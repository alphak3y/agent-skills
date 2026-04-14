# PII Protection — Prevent Personal Data Leaks

## Description
Mandatory rules for handling personally identifiable information (PII) in web applications. Use when building any feature that touches customer data: names, emails, phones, addresses, DOB, license numbers, payment info, signatures.

## When to Use
- Building any customer-facing form or checkout flow
- Passing data between pages/steps in a wizard
- Writing API endpoints that return customer data
- Logging or error handling that might include PII
- Code review of any storefront/marketplace/admin PR

---

## Rule 1: Never Put PII in URL Parameters

URLs are logged by proxies, CDNs, analytics tools, browser history, and server access logs. PII in URLs = PII everywhere.

```tsx
// ❌ WRONG — PII in URL
const url = `/payment?email=${email}&phone=${phone}&name=${name}`;
params.set("customerEmail", email);
params.set("customerPhone", phone);

// ✅ CORRECT — PII in sessionStorage
saveCustomerContact({ email, phone });
const url = `/payment?customerId=${uuid}`; // UUIDs are not PII
```

**What's safe in URLs:** UUIDs, step names, item IDs, dates, boolean flags, non-sensitive config.

**What's NOT safe in URLs:** emails, phone numbers, names, addresses, DOB, license numbers, signatures, payment info, any customer-provided text.

### Pattern: sessionStorage for Wizard Steps

```typescript
const STORAGE_KEY = "renta_customer_contact";

export function saveCustomerContact(data: { email?: string | null; phone?: string | null }): void {
  if (typeof window === "undefined") return;
  try { sessionStorage.setItem(STORAGE_KEY, JSON.stringify(data)); } catch {}
}

export function getCustomerContact(): { email: string | null; phone: string | null } {
  if (typeof window === "undefined") return { email: null, phone: null };
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : { email: null, phone: null };
  } catch { return { email: null, phone: null }; }
}

export function clearCustomerContact(): void {
  if (typeof window === "undefined") return;
  try { sessionStorage.removeItem(STORAGE_KEY); } catch {}
}
```

Always clear sessionStorage after the flow completes (successful booking, page exit).

## Rule 2: Never Use `select('*')` on Public API Endpoints

Public endpoints should return only the fields the client needs. `select('*')` leaks internal columns like `ip_address`, `user_agent`, `signature_data`, `metadata`, etc.

```typescript
// ❌ WRONG — leaks all columns to the client
const { data } = await supabase.from("waiver_tokens").select("*").eq("token", token).single();

// ✅ CORRECT — explicit columns only
const { data } = await supabase
  .from("waiver_tokens")
  .select("id, tenant_id, signer_name, signer_email, signed_at, expires_at")
  .eq("token", token)
  .single();
```

**Admin endpoints** (behind `withAdminAuth`): `select('*')` is acceptable but explicit is still preferred.
**Public/storefront endpoints**: always explicit columns.

## Rule 3: Never Expose Raw Error Messages to Clients

Error messages from the database or internal services can contain table names, column names, constraint names, and customer data.

```typescript
// ❌ WRONG — leaks internals
return NextResponse.json({ error: err.message }, { status: 500 });

// ✅ CORRECT — generic message, log details server-side
console.error("[booking] Creation failed:", err instanceof Error ? err.message : err);
return NextResponse.json({ error: "Something went wrong. Please try again." }, { status: 500 });
```

## Rule 4: Sanitize Console Logs

Server-side logs can be accessed by ops teams, log aggregation tools, and error tracking services. Don't log customer PII.

```typescript
// ❌ WRONG — logs customer email
console.error("Failed for customer:", customer.email, err);

// ✅ CORRECT — log ID only
console.error("[booking] Failed for customer:", customer.id, "error:", err.message);
```

**Safe to log:** IDs (UUIDs), timestamps, error codes, status codes, request paths.
**Not safe to log:** emails, phone numbers, names, addresses, IP addresses (contextual), payment details.

## Rule 5: Return 404 Instead of 403 for Non-Owner Access

When a user tries to access a resource they don't own, return 404 ("not found") instead of 403 ("forbidden"). A 403 confirms the resource EXISTS, which leaks information.

```typescript
// ❌ WRONG — confirms the booking exists
if (booking.customerId !== currentUser.id) {
  return NextResponse.json({ error: "Unauthorized" }, { status: 403 });
}

// ✅ CORRECT — attacker can't tell if booking exists or not
if (booking.customerId !== currentUser.id) {
  return NextResponse.json({ error: "Booking not found" }, { status: 404 });
}
```

## Rule 6: Always Return Success on Lookup Endpoints

Endpoints that check if an email/phone exists should always return success to prevent enumeration attacks.

```typescript
// ❌ WRONG — attacker can probe for valid emails
if (!customer) return NextResponse.json({ error: "Customer not found" }, { status: 404 });

// ✅ CORRECT — always success, no enumeration
const customer = await lookupByEmail(email);
return NextResponse.json({ customer }); // null if not found, caller handles
```

For self-service endpoints (forgot password, request new waiver link):
```typescript
return NextResponse.json({
  success: true,
  message: "If we found your account, we've sent a link to your email.",
});
```

## Rule 7: Rate Limit by Identity, Not Just IP

IP-based rate limiting is a floor. Add identity-based limits for sensitive operations:

```typescript
// IP rate limit (high ceiling — kiosk-friendly)
checkRateLimit(ip, { maxRequests: 50, windowMs: 15 * 60 * 1000, prefix: "ip" });

// Identity rate limit (tight — prevents per-user abuse)
checkRateLimit(email, { maxRequests: 3, windowMs: 15 * 60 * 1000, prefix: "email" });
```

## Audit Commands

```bash
# Find PII in URL params
grep -rn "params.set\|searchParams" src/ --include="*.ts" --include="*.tsx" | grep -i "email\|phone\|name\|address\|dob\|license"

# Find select('*') on public endpoints
grep -rn "select('\*')\|select(\"\\*\")" src/app/api/storefront/ src/app/api/marketplace/ --include="*.ts"

# Find raw error messages returned to clients
grep -rn "err\.message\|error\.message" src/app/api/ --include="*.ts" | grep "NextResponse\|json("

# Find PII in console logs
grep -rn "console\.\(log\|error\)" src/app/api/ --include="*.ts" | grep -i "email\|phone\|name\|customer"

# Find non-null email assertions
grep -rn "\.email!" src/ --include="*.ts" --include="*.tsx"
```
