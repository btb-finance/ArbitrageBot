#!/usr/bin/env python3
import asyncio
import aiohttp
import json
from web3 import Web3

TRADE_AMOUNT_WEI = Web3.to_wei("0.002", 'ether')
ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
LARRY_ADDRESS = "0x888d81e3ea5E8362B5f69188CBCF34Fa8da4b888"
CONTRACT_ADDRESS = "0xC14957db5A544167633cF8B480eB6FbB25b6da19"

async def test_kyberswap_api():
    async with aiohttp.ClientSession() as session:
        # Get route
        route_url = "https://aggregator-api.kyberswap.com/base/api/v1/routes"
        params = {
            "tokenIn": ETH_ADDRESS,
            "tokenOut": LARRY_ADDRESS,
            "amountIn": str(TRADE_AMOUNT_WEI)
        }
        
        async with session.get(route_url, params=params) as response:
            if response.status == 200:
                route_data = await response.json()
                print(f"Route response: {json.dumps(route_data, indent=2)}")
                
                if route_data.get('data') and route_data['data'].get('routeSummary'):
                    route_summary = route_data['data']['routeSummary']
                    
                    # Build swap
                    build_url = "https://aggregator-api.kyberswap.com/base/api/v1/route/build"
                    payload = {
                        "routeSummary": route_summary,
                        "sender": CONTRACT_ADDRESS,
                        "recipient": CONTRACT_ADDRESS,
                        "slippageTolerance": 300,
                        "deadline": 1735308000
                    }
                    
                    async with session.post(build_url, json=payload) as build_response:
                        if build_response.status == 200:
                            build_data = await build_response.json()
                            print(f"Build response: {json.dumps(build_data, indent=2)}")
                        else:
                            print(f"Build failed: {build_response.status}")
                            print(await build_response.text())
            else:
                print(f"Route failed: {response.status}")
                print(await response.text())

if __name__ == "__main__":
    asyncio.run(test_kyberswap_api())