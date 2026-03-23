# Ostium Contract Addresses — Arbitrum One (Mainnet)

Reverse-engineered from `app.ostium.com` frontend bundles, March 2026.

## Core Protocol

| Contract | Address |
|----------|---------|
| Registry | `0x799a139aE56e11F0476aCE2f6118CfcAed9608d2` |
| Vault | `0x20D419a8e12C45f88fDA7c5760bb6923Cee27F98` |
| Trading | `0x6D0bA1f9996DBD8885827e1b2e8f6593e7702411` |
| Trading Storage | `0xccd5891083a8acd2074690f65d3024e7d13d66e7` |
| Trading Callbacks | `0x7720fC8c8680bF4a1Af99d44c6c265a74e9742a9` |

## Market Data

| Contract | Address |
|----------|---------|
| Pairs Storage | `0x260E349F643f12797fDc6f8c9d3df211D5577823` |
| Pair Infos | `0x3890243a8fc091c626ed26c087a028b46bc9d66c` |
| Open PnL Feed | `0xE607aC9FF58697c5978AfA1Fc1C5C437a6D1858c` |

## Price / Keeper Infrastructure

| Contract | Address |
|----------|---------|
| Price Router | `0x4B0C3c77D398912491f192d265b237C8d4441AD7` |
| Price Upkeep | `0x52B2a78E12b09B66C6c8ce291D653D40bAb77f0c` |
| Private Price Upkeep | `0xB71ec9eBD8145daCaCF6724363143cb5667A3d36` |
| Trades Upkeep | `0x959Da1452238F71F17f7DA5dbA2e9c04FEf57324` |
| Private Trades Upkeep | `0x50B0457B69a4F85c98A044e0b9eB9C65B0D708f9` |
| Keeper | `0x6297ce1a61c2c8a72bfb0de957f6b1cf0413141e` |

## Access Control

| Contract | Address |
|----------|---------|
| Whitelist | `0xe006fAb1ac752B4F0574746F02493B8aCFA3b537` |
| Timelock Manager | `0xbd80d6Eb7D21F6bd3BbBAdf8b7E15F85ffe3888B` |
| Timelock Owner | `0xeB85dC6095c74D36500C9cdcaCc15EcDC223Bbf7` |
| Proxy Admin | `0x083F97BabF33D4abC03151B5DEc98170761f4025` |

## Misc

| Contract | Address |
|----------|---------|
| Locked Deposit NFT | `0xb4f1123BE58f5d69E1cf565ED8756C7fcf31c8D3` |
| Link Upkeep | `0xcdBd6a8c40dD7E914aaBc7447A18cd90FFA93EAA` |
| Verifier | `0xcCF233920e8cc9415ecF503b992881d69b6c47Ad` |
| Faucet | `0x6830C550814105d8B27bDAEC0DB391cAa7B967c8` |
| Token (USDC) | `0xaf88d065e77c8cc2239327c5edb3a432268e5831` |

## Architecture Notes

Ostium is a GainsNetwork-style (gTrade) fork. Trade flow:

1. User calls `trading.openTrade(...)` with collateral, leverage, pair, direction
2. Price oracle (Chainlink / Pyth) delivers price via keeper
3. `trading_callbacks` processes the fill
4. Position stored in `trading_storage`
5. To close: `trading.closeTradeMarket(pairIndex, index)` → oracle fills → PnL settled

## Subgraph

```
https://api.subgraph.ormilabs.com/api/public/67a599d5-c8d2-4cc4-9c4d-2975a97bc5d8/subgraphs/ost-prod/live/gn
```

## Dune Dashboard

https://dune.com/ostium_app/stats
