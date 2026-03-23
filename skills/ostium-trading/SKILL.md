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

### Open a Trade

```python
from decimal import Decimal

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
# Returns: {"receipt": AttributeDict({...}), "order_id": int}
tx_hash = result['receipt']['transactionHash'].hex()
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

## Known Gotchas

1. **Slippage MUST be `Decimal`** — `set_slippage_percentage(Decimal('1.0'))` not `float`. The SDK uses `decimal.Decimal` internally and will throw `TypeError` on float.

2. **perform_trade returns nested dict** — `result['receipt']['transactionHash']`, not `result['transactionHash']`.

3. **Non-market orders need slippage=0** — For limit and stop orders, pass `slippage=0` in `openTrade` (breaking change Feb 2026). Market orders and closes are unaffected.

4. **RWA markets have trading hours** — Oil, stocks, FX are NOT 24/7. Check hours before placing orders. Pending market orders placed during closed hours queue until market opens.

5. **Geo-restrictions on frontend only** — `app.ostium.com` may show `restricted=true` for some IPs (US, AWS). The smart contracts and all APIs are unrestricted. Bot trading works fine from any IP.

6. **`balance.get_balance()` may be sync** — Some SDK methods are sync, some async. Wrap with `asyncio.iscoroutine()` check if unsure.

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
