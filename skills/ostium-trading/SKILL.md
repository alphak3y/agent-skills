---
name: ostium-trading
description: "Trade real-world assets (oil, gold, FX, stocks, indices, crypto) on Ostium, a decentralized perpetual exchange on Arbitrum. Use when: placing trades on Ostium, building trading bots, reading positions/prices/pair data, managing orders (open, close, TP/SL, cancel), checking market hours, or integrating with the Ostium Python SDK. Covers the official SDK, contract addresses, REST APIs, subgraph queries, and geopolitical news-driven oil trading strategies."
---

# Ostium Trading

Trade perpetual swaps on [Ostium](https://ostium.com) — a self-custodial DEX on Arbitrum for crypto, commodities, FX, stocks, and indices. Up to 200x leverage, oracle-based pricing, USDC-denominated.

## Quick Start

### Install SDK

```bash
pip install ostium-python-sdk
```

### Initialize

```python
from ostium_python_sdk import OstiumSDK, NetworkConfig

# Mainnet
sdk = OstiumSDK(NetworkConfig.mainnet(), private_key="0x...", rpc_url="https://arb1.arbitrum.io/rpc")

# Testnet (Arbitrum Sepolia)
sdk = OstiumSDK(NetworkConfig.testnet(), private_key="0x...", rpc_url="https://arb-sepolia.g.alchemy.com/v2/...")

# Read-only (no private key)
sdk = OstiumSDK(NetworkConfig.mainnet(), rpc_url="https://arb1.arbitrum.io/rpc")
```

### Get Prices

```python
price, bid, ask = await sdk.price.get_price("CL", "USD")   # WTI Crude Oil
price, bid, ask = await sdk.price.get_price("BRENT", "USD") # Brent Crude
price, bid, ask = await sdk.price.get_price("XAU", "USD")   # Gold
```

### Open a Market Trade

```python
from decimal import Decimal

# IMPORTANT: Check market hours first for RWA assets!
# Market orders during closed hours auto-cancel (TIMEOUT).
sdk.ostium.set_slippage_percentage(Decimal('1.0'))  # MUST be Decimal, not float

trade_params = {
    'collateral': 10,         # USDC amount
    'leverage': 5,            # Multiplier
    'asset_type': 7,          # Pair ID (7 = CL-USD)
    'direction': True,        # True = Long, False = Short
    'order_type': 'MARKET',   # 'MARKET', 'LIMIT', or 'STOP'
    'tp': price * 1.03,       # Take profit price (optional)
    'sl': price * 0.98,       # Stop loss price (optional)
}

result = sdk.ostium.perform_trade(trade_params, at_price=price)
# Returns: {"receipt": AttributeDict({...}), "order_id": int|None}
tx_hash = result['receipt']['transactionHash'].hex()
```

### Open a Limit Order (Best for Market-Open Entries)

```python
# For limit/stop orders: slippage MUST be 0
sdk.ostium.set_slippage_percentage(Decimal('0'))

limit_params = {
    'collateral': 10,
    'leverage': 5,
    'asset_type': 55,         # BRENT-USD
    'direction': True,        # Long
    'order_type': 'LIMIT',    # or 'STOP'
    'tp': price * 1.02,
    'sl': price * 0.98,
}

# Set limit price slightly below current for longs (better entry)
result = sdk.ostium.perform_trade(limit_params, at_price=price * 0.998)
```

### Close / Manage Trades

```python
# Read open positions
trades = await sdk.subgraph.get_open_trades(wallet_address)

# Close a trade (needs pair_id and trade_index from open trades)
sdk.ostium.close_trade(pair_id, trade_index)

# Update TP/SL
sdk.ostium.update_tp(pair_id, trade_index, new_tp_price)
sdk.ostium.update_sl(pair_id, trade_index, new_sl_price)

# Update limit order (price, TP, SL) — requires private_key arg
sdk.ostium.update_limit_order(pair_id, index, private_key, price=new_price, tp=new_tp, sl=new_sl)

# Cancel pending market order
sdk.ostium.open_market_timeout(order_id)

# Cancel limit/stop order
sdk.ostium.cancel_limit_order(pair_id, index)

# Add/remove collateral
sdk.ostium.add_collateral(pair_id, trade_index, amount)
sdk.ostium.remove_collateral(pair_id, trade_index, amount)

# Get live trade metrics (PnL, funding, liquidation price)
metrics = await sdk.get_open_trade_metrics(pair_id, trade_index)
```

### Monitor Order Fill

```python
# Poll subgraph to detect when a limit order fills
async def wait_for_fill(sdk, wallet, pair_id, poll_interval=10):
    while True:
        trades = await sdk.subgraph.get_open_trades(wallet)
        # NOTE: subgraph uses 'isBuy' not 'buy' for open trades
        filled = [t for t in trades if t.get('pair', {}).get('id') == str(pair_id)]
        if filled:
            return filled[0]  # Trade is now open
        
        orders = await sdk.subgraph.get_orders(wallet)
        active = [o for o in orders if o.get('isActive')]
        if not active:
            return None  # Order cancelled or expired
        
        await asyncio.sleep(poll_interval)
```

### Wait for Market Open Then Trade

```python
import httpx

async def wait_for_market_open(asset="BRENTUSD"):
    """Poll until RWA market opens. Returns live price."""
    while True:
        async with httpx.AsyncClient(timeout=10) as http:
            resp = await http.get(
                f"https://metadata-backend.ostium.io/PricePublish/latest-price?asset={asset}"
            )
            data = resp.json()
            if data.get("isMarketOpen"):
                return data["mid"]
        await asyncio.sleep(15)

# Usage:
price = await wait_for_market_open("BRENTUSD")
await asyncio.sleep(30)  # Let opening price settle
# Now fetch fresh price and place order with live data
```

### Check Market Hours

```python
# Price API also returns market status
# Response includes: isMarketOpen, isDayTradingClosed, secondsToToggleIsDayTradingClosed

# Trading hours API returns schedule in America/New_York timezone
# with secondsToToggleMarketStatus countdown
async with httpx.AsyncClient() as http:
    resp = await http.get(
        "https://metadata-backend.ostium.io/trading-hours/asset-schedule?asset=BRENTUSD"
    )
    hours = resp.json()
    # hours['isOpenNow'], hours['secondsToToggleMarketStatus'], hours['timezone']
```

## Known Gotchas

1. **Slippage MUST be `Decimal`** — `set_slippage_percentage(Decimal('1.0'))` not `float`. The SDK uses `decimal.Decimal` internally and will throw `TypeError` on float.

2. **perform_trade returns nested dict** — `result['receipt']['transactionHash']`, not `result['transactionHash']`. Full shape: `{"receipt": AttributeDict({...}), "order_id": int|None}`.

3. **Non-market orders need slippage=0** — For limit and stop orders, set `set_slippage_percentage(Decimal('0'))` before calling `perform_trade` (breaking change Feb 2026). Market orders and closes are unaffected.

4. **Market orders during closed hours get TIMEOUT cancelled** — If you submit a market order while the RWA market is closed, it will sit pending and then auto-cancel with `cancelReason: TIMEOUT`. Your collateral is returned, but you wasted gas. **Always check trading hours before placing market orders on RWA assets.**

5. **Use limit orders for market-open entries** — To get the best fill when a market opens, place a limit order slightly below last close (for longs) or above (for shorts). This avoids the opening spread/volatility and the timeout issue.

6. **Geo-restrictions on frontend only** — `app.ostium.com` may show `restricted=true` for some IPs (US, AWS). The smart contracts and all APIs are unrestricted. Bot trading works fine from any IP.

7. **`balance.get_balance()` may be sync** — Some SDK methods are sync, some async. Wrap with `asyncio.iscoroutine()` check if unsure.

8. **WTI ≠ Brent** — CL-USD (pair 7) is WTI (~$88), BRENT-USD (pair 55) is Brent (~$97). Different benchmarks, different prices (~$9 spread typical), different trading hours. Don't compare prices across them.

9. **Ostium trading hours ≠ traditional futures hours** — Ostium has wider daily breaks than the underlying exchanges (e.g., ~3h break for Brent vs ~1h on ICE). Plan around Ostium's specific schedule, not the exchange schedule.

10. **Never set price parameters from stale/closed-market data** — When a market is closed, the price feed returns the last traded price from Friday. Opening prices can gap significantly. Always wait for the market to open and the price to settle (~30s) before setting entry, TP, and SL levels.

11. **Pending market orders show confusing dates in UI** — Orders submitted during closed hours show a default expiry date (e.g., 31/12) in the Ostium UI, not the creation date. These eventually auto-cancel with TIMEOUT.

12. **Finding stuck orders** — The subgraph `get_orders()` may not return pending market orders. Use `get_order_by_id(order_id)` to check specific orders, or scan nearby order IDs. Cancel with `sdk.ostium.open_market_timeout(order_id)`.

13. **`update_limit_order` requires private_key as 3rd arg** — Unlike other methods that use the SDK's stored key, `update_limit_order(pair_id, index, private_key, price=..., tp=..., sl=...)` needs the key passed explicitly. Omitting it causes a cryptic "Unknown error".

14. **Subgraph field naming inconsistency** — Open trades use `isBuy` (not `buy`). Open limit orders also use `isBuy`. But the SDK's `get_orders()` returns `isBuy` while some raw subgraph entities may differ. Always verify the field name.

15. **Collateral after fill ≠ collateral submitted** — Opening fees are deducted from collateral. A $5 trade may show $4.89 collateral after fill. The `openPrice` is in wei (18 decimals): divide by 1e18 to get USD price.

16. **Price values in subgraph are 18-decimal wei** — `openPrice`, `tp`, `sl` are all in wei. Example: `97735300000000000000` = $97.74. Divide by `10**18`.

17. **Limit order above current price fills immediately** — Setting a limit buy above current market price acts like a market order (fills on next oracle update). Use this for "buy now at up to X" behavior.

18. **Trading hours API timezone is America/New_York** — All schedule times from `metadata-backend.ostium.io/trading-hours/` are in ET. Convert to UTC: during EDT (Mar-Nov) add 4 hours, during EST (Nov-Mar) add 5 hours.

19. **Gas costs on Arbitrum are minimal** — Opening a trade costs ~460K gas (~$0.009). Cancels cost ~130K gas. Don't optimize for gas; optimize for correct execution.

20. **SDK GitHub has more examples** — `https://github.com/0xOstium/use-ostium-python-sdk` has working examples for orders, trades, TP/SL, funding rates, PnL calculation.

## Pair IDs

For full details (fees, OI caps, leverage limits): `await sdk.subgraph.get_pairs()`

See [references/pair-ids.md](references/pair-ids.md) for the complete pair table.

**Key oil pairs:**
- **7** — CL-USD (WTI Crude Oil)
- **55** — BRENT-USD (Brent Crude)

## REST API (No SDK needed)

```bash
# Latest price for a specific asset
curl 'https://metadata-backend.ostium.io/PricePublish/latest-price?asset=CLUSD'

# All prices
curl 'https://metadata-backend.ostium.io/PricePublish/latest-prices'

# Trading hours
curl 'https://metadata-backend.ostium.io/trading-hours/asset-schedule?asset=CLUSD'

# LP exposure
curl -X POST 'https://metadata-backend.ostium.io/vault/lp-exposure' \
  -H "Content-Type: application/json" \
  -d '{"address": "0x..."}'
```

## Contract Addresses (Arbitrum Mainnet)

See [references/contracts.md](references/contracts.md) for all addresses.

**Key contracts:**
- Trading: `0x6D0bA1f9996DBD8885827e1b2e8f6593e7702411`
- Trading Storage: `0xccd5891083a8acd2074690f65d3024e7d13d66e7`
- Vault: `0x20D419a8e12C45f88fDA7c5760bb6923Cee27F98`
- USDC (token): `0xaf88d065e77c8cc2239327c5edb3a432268e5831`

## Wallet Setup

Store secrets outside git, locked permissions:

```bash
mkdir -p ~/.openclaw/secrets && chmod 700 ~/.openclaw/secrets
# Write key file (via SSH, never paste in chat):
# OSTIUM_PRIVATE_KEY=0x...
# OSTIUM_WALLET_ADDRESS=0x...
# ARBITRUM_RPC_URL=https://...
chmod 600 ~/.openclaw/secrets/ostium-wallet.env
```

Load in code: read the env file, parse key=value lines.

## Oil Trading Strategy

See [references/oil-strategy.md](references/oil-strategy.md) for the complete geopolitical oil trading playbook covering:
- News source ranking and ingestion
- LLM signal classification (event categories, prompt template)
- Position sizing by signal strength
- Risk management rules
- Market hours and weekend gap risks
