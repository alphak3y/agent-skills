# Ostium Pair IDs

As of March 2026. Get live list via `await sdk.subgraph.get_pairs()`.

## Commodities
| ID | Pair | Description |
|----|------|-------------|
| 5 | XAU-USD | Gold |
| 6 | HG-USD | Copper |
| 7 | CL-USD | WTI Crude Oil |
| 8 | XAG-USD | Silver |
| 28 | XPD-USD | Palladium |
| 29 | XPT-USD | Platinum |
| 55 | BRENT-USD | Brent Crude Oil |

## Crypto
| ID | Pair | Description |
|----|------|-------------|
| 0 | BTC-USD | Bitcoin |
| 1 | ETH-USD | Ethereum |
| 9 | SOL-USD | Solana |
| 38 | BNB-USD | BNB |
| 39 | XRP-USD | XRP |
| 40 | TRX-USD | TRON |
| 41 | HYPE-USD | Hyperliquid |
| 42 | LINK-USD | Chainlink |
| 43 | ADA-USD | Cardano |

## FX
| ID | Pair | Description |
|----|------|-------------|
| 2 | EUR-USD | Euro |
| 3 | GBP-USD | British Pound |
| 4 | USD-JPY | Japanese Yen |
| 16 | USD-CAD | Canadian Dollar |
| 17 | USD-MXN | Mexican Peso |
| 25 | USD-CHF | Swiss Franc |
| 26 | AUD-USD | Australian Dollar |
| 27 | NZD-USD | New Zealand Dollar |
| 53 | USD-KRW | Korean Won |

## Indices
| ID | Pair | Description |
|----|------|-------------|
| 10 | SPX-USD | S&P 500 |
| 11 | DJI-USD | Dow Jones |
| 12 | NDX-USD | NASDAQ-100 |
| 13 | NIK-JPY | Nikkei 225 |
| 14 | FTSE-GBP | FTSE 100 |
| 15 | DAX-EUR | DAX |
| 30 | HSI-HKD | Hang Seng |
| 54 | KR2550-USD | Korea 2550 |

## Stocks
| ID | Pair | Description |
|----|------|-------------|
| 18 | NVDA-USD | NVIDIA |
| 19 | GOOG-USD | Alphabet |
| 20 | AMZN-USD | Amazon |
| 21 | META-USD | Meta |
| 22 | TSLA-USD | Tesla |
| 23 | AAPL-USD | Apple |
| 24 | MSFT-USD | Microsoft |
| 31 | COIN-USD | Coinbase |
| 32 | HOOD-USD | Robinhood |
| 33 | MSTR-USD | MicroStrategy |
| 34 | CRCL-USD | Circle |
| 35 | BMNR-USD | BitMiner |
| 36 | SBET-USD | SportsBet |
| 37 | GLXY-USD | Galaxy Digital |
| 44 | PLTR-USD | Palantir |
| 45 | AMD-USD | AMD |
| 46 | NFLX-USD | Netflix |
| 47 | ORCL-USD | Oracle |
| 48 | RIVN-USD | Rivian |
| 49 | COST-USD | Costco |
| 50 | XOM-USD | ExxonMobil |
| 51 | CVX-USD | Chevron |
| 52 | URA-USD | Uranium ETF |

## Trading Hours

RWA assets (oil, stocks, FX, indices) have market hours. Crypto is 24/7.

Check hours: `curl 'https://metadata-backend.ostium.io/trading-hours/asset-schedule?asset=CLUSD'`

**Oil (CL-USD / WTI) — New York time:**
- Mon–Thu: 00:00–16:59, 18:10–24:00
- Fri: 00:00–16:59
- Sun: 18:10–24:00

**Oil (BRENT-USD) — New York time:**
- Mon–Thu: 00:00–16:59, 20:02–24:00
- Fri: 00:00–16:59
- Sun: 20:02–24:00
