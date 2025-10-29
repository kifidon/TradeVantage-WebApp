import ccxt
import asyncio
import numpy as np

DEBUG = True

# KuCoin API credentials
API_KEY = '67a6490caf72b10001520745'
API_SECRET = '7fb66e74-7d9b-4e3c-b335-098fa2b74ebd'

# Initialize KuCoin exchange
exchange = ccxt.kucoin({
    'apiKey': API_KEY,
    'secret': API_SECRET,
})

# Trading pairs for triangular arbitrage
PAIR_1 = 'BTC/USDT'  # Base pair
PAIR_2 = 'ETH/BTC'   # Intermediate pair
PAIR_3 = 'ETH/USDT'  # Final pair

# Trading fee (KuCoin charges 0.1% per trade)
TRADING_FEE = 0.001

# Minimum profit threshold (in USDT)
MIN_PROFIT_THRESHOLD = 10  # Adjust based on your risk tolerance

async def fetch_prices():
    """Fetch real-time prices for the trading pairs."""
    ticker_1 = exchange.fetch_ticker(PAIR_1)
    ticker_2 = exchange.fetch_ticker(PAIR_2)
    ticker_3 = exchange.fetch_ticker(PAIR_3)
    if DEBUG:
        print("Prices Fetched")
    price_1 = ticker_1['last']  # BTC/USDT price
    price_2 = ticker_2['last']  # ETH/BTC price
    price_3 = ticker_3['last']  # ETH/USDT price

    return price_1, price_2, price_3

def calculate_profit(price_1, price_2, price_3, amount):
    """
    Calculate potential profit from triangular arbitrage.
    :param price_1: BTC/USDT price
    :param price_2: ETH/BTC price
    :param price_3: ETH/USDT price
    :param amount: Initial amount in USDT
    :return: Profit in USDT
    """
    # Step 1: Buy BTC with USDT
    btc_amount = amount / price_1 * (1 - TRADING_FEE)

    # Step 2: Buy ETH with BTC
    eth_amount = btc_amount / price_2 * (1 - TRADING_FEE)

    # Step 3: Sell ETH for USDT
    final_amount = eth_amount * price_3 * (1 - TRADING_FEE)

    # Calculate profit
    profit = final_amount - amount
    if DEBUG: 
        print(f"Profit is calculutated to be: {profit}")
    return profit

async def execute_trade(pair, amount, action):
    """Execute market orders for the arbitrage trade."""
    try:
        if action == 'buy':
            print(f"Placing buy order for {pair} with amount {amount}")
            order = await exchange.create_market_buy_order(pair, amount)
        elif action == 'sell':
            print(f"Placing sell order for {pair} with amount {amount}")
            order = await exchange.create_market_sell_order(pair, amount)
        print(f"Order executed: {order}")
    except Exception as e:
        print(f"Error executing trade: {e}")

async def monitor_arbitrage():
    """Monitor for triangular arbitrage opportunities."""
    print("Starting triangular arbitrage bot...")
    while True:
        try:
            # Fetch prices
            price_1, price_2, price_3 = await fetch_prices()

            # Calculate profit for an initial amount of 1000 USDT
            initial_amount = 1000  # Adjust based on your capital
            profit = calculate_profit(price_1, price_2, price_3, initial_amount)

            # Check if profit exceeds the threshold
            if profit > MIN_PROFIT_THRESHOLD:
                print(f"Arbitrage Opportunity Detected! Profit: {profit} USDT")
                
                btc_amount = initial_amount / price_1 * (1 - TRADING_FEE)
                await execute_trade(PAIR_1, btc_amount, 'buy')
                eth_amount = btc_amount / price_2 * (1 - TRADING_FEE)
                await execute_trade(PAIR_2, eth_amount, 'buy')
                final_amount = eth_amount * price_3 * (1 - TRADING_FEE)
                await execute_trade(PAIR_3, final_amount, 'sell')


            # Wait for a few seconds before checking again
            # await asyncio.sleep(5)

        except Exception as e:
            print(f"Error: {e}")
            await asyncio.sleep(10)

# Run the bot
if __name__ == "__main__":
    asyncio.run(monitor_arbitrage())
