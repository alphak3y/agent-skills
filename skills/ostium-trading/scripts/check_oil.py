#!/usr/bin/env python3
"""Quick oil market status check. No wallet needed.

Usage:
    python3 scripts/check_oil.py
    python3 scripts/check_oil.py --all-prices
"""

import asyncio
import sys
import json
import httpx


async def main():
    show_all = "--all-prices" in sys.argv

    async with httpx.AsyncClient(timeout=10) as client:
        # Get oil prices
        for asset in ["CLUSD", "BRENTUSD"]:
            resp = await client.get(
                f"https://metadata-backend.ostium.io/PricePublish/latest-price?asset={asset}"
            )
            data = resp.json()
            name = f"{data['from']}-{data['to']}"
            print(f"{name}: ${data['mid']:.2f}  (bid: {data['bid']:.2f}, ask: {data['ask']:.2f})")
            print(f"  Market open: {data.get('isMarketOpen', '?')}")

        # Trading hours
        print()
        for asset in ["CLUSD", "BRENTUSD"]:
            resp = await client.get(
                f"https://metadata-backend.ostium.io/trading-hours/asset-schedule?asset={asset}"
            )
            hours = resp.json()
            print(f"{asset} hours ({hours.get('timezone', '?')}):")
            for h in hours.get("openingHours", []):
                print(f"  {h}")
            print(f"  Open now: {hours.get('isOpenNow')}")
            print()

        # All prices
        if show_all:
            resp = await client.get(
                "https://metadata-backend.ostium.io/PricePublish/latest-prices"
            )
            prices = resp.json()
            print("All prices:")
            for p in prices:
                name = f"{p.get('from', '?')}-{p.get('to', '?')}"
                print(f"  {name}: ${p['mid']:.4f}  open={p.get('isMarketOpen')}")


if __name__ == "__main__":
    asyncio.run(main())
