# Geopolitical Oil Trading Strategy

A playbook for trading crude oil perpetuals on Ostium based on geopolitical events and news.

## News Sources (by speed)

| Source | Latency | Use For |
|--------|---------|---------|
| Twitter/X (filtered accounts) | Seconds | Breaking news, rumors, first reports |
| Telegram channels (OSINT) | Seconds | Military updates, oil trader chatter |
| Reuters/AP wire | 1–5 min | Confirmed, high-quality reporting |
| GDELT Project API | ~15 min | Free, structured global event database |
| RSS (OilPrice.com, etc.) | 5–30 min | Analysis, context |

### Key Twitter Accounts
- `@sentdefender` — global security
- `@OilShockBlog`, `@EnergyIntel`, `@ABORGENERGY` — oil/energy specific
- `@Reuters`, `@AP` — wire services

### Free APIs (no key required)
- **GDELT DOC API**: `https://api.gdeltproject.org/api/v2/doc/doc` — query by theme (ENV_OIL, MILITARY, SANCTION)
- **Ostium prices**: `https://metadata-backend.ostium.io/PricePublish/latest-price?asset=CLUSD`

## Event Classification

### Categories & Expected Impact

| Category | Direction | Magnitude | Examples |
|----------|-----------|-----------|----------|
| Supply disruption | 🔴 Bullish | Major–Extreme | Pipeline attack, port blockade, Strait of Hormuz |
| Military escalation | 🔴 Bullish | Moderate–Major | Airstrikes on oil infrastructure, naval confrontation |
| Sanctions imposed | 🔴 Bullish | Moderate | New sanctions on Iran/Russia/Venezuela oil |
| Sanctions eased | 🟢 Bearish | Moderate | Waivers granted, enforcement relaxed |
| OPEC+ cuts | 🔴 Bullish | Moderate | Production cut announcements |
| OPEC+ increase | 🟢 Bearish | Moderate | Production quota increase |
| SPR release | 🟢 Bearish | Minor–Moderate | US Strategic Petroleum Reserve release |
| Ceasefire/peace deal | 🟢 Bearish | Moderate–Major | Conflict de-escalation |
| Demand shock | 🟢 Bearish | Major | Recession signals, China lockdowns |

### Magnitude Thresholds
- **Extreme**: 1M+ bpd at risk (Strait of Hormuz, major producer offline)
- **Major**: 200K–1M bpd affected
- **Moderate**: 50K–200K bpd or significant policy shift
- **Minor**: Localized, <50K bpd, or speculative

## LLM Classification Prompt

```
You are an expert oil market analyst specializing in geopolitical risk.
Classify this news item for its impact on crude oil prices.

NEWS: {headline}
BODY: {body}
SOURCE: {source}
CURRENT OIL PRICE: ~${price}/barrel

Respond in JSON:
{
    "direction": "bullish|bearish|neutral",
    "confidence": 0.0-1.0,
    "magnitude": "minor|moderate|major|extreme",
    "category": "<from table above>",
    "timeframe": "immediate|days|weeks",
    "reasoning": "<1-2 sentences>",
    "supply_impact_bpd": <int>,
    "is_rumor": true|false,
    "actionable": true|false
}

Rules:
- Single unverified source → confidence < 0.3
- Confirmed by major wire → confidence +0.2
- News >30 min old and widely reported → actionable: false
- Not about oil/energy → neutral, actionable: false
```

## Position Sizing

### By Signal Strength

| Magnitude | Size Multiplier | Max Leverage |
|-----------|----------------|--------------|
| Minor | 15% of max | 5x |
| Moderate | 35% of max | 4x |
| Major | 65% of max | 3x |
| Extreme | 100% of max | 2x |

Inverse leverage-to-magnitude: bigger events = more volatile = less leverage needed.

### Stop Loss / Take Profit
- Confirmed news: 2% SL, 5% TP (2.5:1 R:R)
- Rumors: 1% SL, 2.5% TP (tighter, quick exit if wrong)
- Default: 1.5% SL, 3.75% TP

### Size Decay
Each subsequent trade in a session is 20% smaller (prevents tilt).

## Risk Management Rules

1. **Max drawdown**: Stop trading if account drops 15% in a day
2. **Max concurrent positions**: 3
3. **Cooldown after loss**: 30 min after a stopped-out trade
4. **News staleness**: Don't trade news older than 30 min
5. **Weekend/low-liquidity**: Reduce size 50% during off-hours
6. **Correlation check**: Don't stack 3 positions on the same event

## Key Insights

### Where the Edge Is
- **NOT speed** — HFT and MEV bots are faster. Your edge is *interpretation quality*.
- **Second-order effects** — The first move on news is often wrong. The second move is where money is made.
- **Off-hours events** — When traditional markets are closed (weekends, holidays) but crypto perps stay open.
- **Change in situation** — Escalation/de-escalation surprises, not ongoing conflict (which gets priced in).

### Pitfalls
- **Funding rates** eat profits on longer holds. News-driven trades should be hours, not days.
- **"Priced in" problem** — Oil trades 23h/day on NYMEX/ICE. By the time news hits Twitter, institutional desks have moved. Ostium's oracle follows those prices.
- **Weekend gaps** — Oil futures close Friday, reopen Sunday. Ostium perps may gap violently. Understand how Ostium handles weekend oracle pricing.
- **Backtesting is nearly impossible** for news-driven strategies. Forward-test in paper/monitor mode for 2-4 weeks.
- **Geopolitical premium fades** — Markets price in ongoing conflicts quickly. The tradeable moment is the *surprise change*.

### Market-Open Entry Pattern (Tested)

The best approach for entering a position at market open:

1. **Wait for `isMarketOpen: true`** from the price API (poll every 15s)
2. **Wait 30 seconds** for the opening price to settle (initial ticks can be volatile)
3. **Fetch fresh price** — don't use the stale closed-market price
4. **Place a limit order** 0.1-0.2% away from current price
5. **Set limit above current for quick fill** — a limit buy above market acts like a controlled market order

This avoids:
- TIMEOUT cancellations from market orders placed during closed hours
- Bad fills from stale prices
- Opening spread volatility

Example from our first live test: Brent closed Friday at $97.19, opened Monday at $98.06 (gap up $0.87). Had we placed a market order at $97.19 it would have either timed out or filled at a worse price.
