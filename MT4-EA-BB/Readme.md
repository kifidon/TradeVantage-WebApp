# BB_MA_EA - Bollinger Bands & Moving Average Expert Advisor

## Overview
BB_MA_EA is an **Expert Advisor (EA) for MetaTrader 4 (MT4)** that implements a trading strategy based on **Bollinger Bands** and **Moving Average crossovers**. The EA determines trade signals using Bollinger Bands and Moving Average strategies and manages trade execution with risk management settings.

## Things to do
1. ~~to the EA with Liquidation add account number~~
2. ~~Add Expiry Date (Priority)~~
3. ~~Both account number and expiry date should not be in the input (priority)~~
4. These Features to will be added to the deployment hosting process
  ```

Deep Seek EA - (15Min) R3 (No Lines) Revise.mq4 & Trade Vantage EA - Snipper - Ken.mq4

  4. Add email notification to user - to notify user of
  5.       Send Welcome message to the user at registered email
  6.       Send Expiration notification to User's email daily 4 days before expiration to notify user that that EA will be expiring
  7.       Send Expiration notice to User's email and Trade Pro FX Admins email on date of EA expiration to notify that EA has expired.
  8.       Include in the drafted email an option for User to unsubscribe to email notification.
  9.       Combine the two Eas into a modular EA
            Module 1 with its own Magic nuber and inputs
            Module 2 with its own Magic nuber and inputs 1
  10. The reason for separate Magic numbers is to ensure that each EA operates independently
  11. Add feaure in input to turn on / off either module
  12. Add Dashboard
        Total Balance =
        Total Equity =
        Drawdown %
        Module 1
          Total number of Buy
          Total number of Sell
        Module 2
          Total number of Buy
          Total number of Sell
    13. Add Account number
    14. Add EA Expiry date yyy.mm.dd
    15. Ensure that the indicator lines do not show up on the chart especially during & after running STRATEGY TESTER
    16. Ability to track profit in order to charge comission
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""16Mar2025

Deep Seek EA - 1 MA.mq4

  Add email notification to user - to notify user of
  1.       Send Welcome message to the user at registered email
  2.       Send Expiration notification to User's email daily 4 days before expiration to notify user that that EA will be expiring
  3.       Send Expiration notice to User's email and Trade Pro FX Admins email on date of EA expiration to notify that EA has expired.
  4.       Include in the drafted email an option for User to unsubscribe to email notification.
  5. Add Dashboard
        Total Balance =
        Total Equity =
        Drawdown %
        Module 1
          Total number of Buy
          Total number of Sell       
  6. Add Account number
  7. Add EA Expiry date yyyy.mm.dd
  8. Ensure that the indicator lines do not show up on the chart especially during & after running STRATEGY TESTER
  9. Ability to track profit in order to charge comission
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""17Mar2025

Deep Seek EA - Break & Retest + MA Cross Modular

Add email notification to user - to notify user of
  1.       Send Welcome message to the user at registered email
  2.       Send Expiration notification to User's email daily 4 days before expiration to notify user that that EA will be expiring
  3.       Send Expiration notice to User's email and Trade Pro FX Admins email on date of EA expiration to notify that EA has expired.
  4.       Include in the drafted email an option for User to unsubscribe to email notification.
  5. Add Dashboard
        Total Balance =
        Total Equity =
        Drawdown %
        Module 1
          Total number of Buy
          Total number of Sell
          Module 1 daily profit - in $
        Module 2
          Total number of Buy
          Total number of Sell
          Module 2 daily profit - in $
  6. Add Account number
  7. Add EA Expiry date yyyy.mm.dd
  8. Ensure that the indicator lines do not show up on the chart especially during & after running STRATEGY TESTER
  9. Ability to track profit in order to charge comission
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""19Mar2025

Deep Seek EA - MA (15Min) Multiplier- Contingency

Add email notification to user - to notify user of
  1.       Send Welcome message to the user at registered email
  2.       Send Expiration notification to User's email daily 4 days before expiration to notify user that that EA will be expiring
  3.       Send Expiration notice to User's email and Trade Pro FX Admins email on date of EA expiration to notify that EA has expired.
  4.       Include in the drafted email an option for User to unsubscribe to email notification.
  5. Add Dashboard
        Total Balance =
        Total Equity =
        Drawdown %
        Module 1
          Total number of Buy
          Total number of Sell
          Module 1 daily profit - in $
        Module 2
          Total number of Buy
          Total number of Sell
          Module 2 daily profit - in $
  6. Add Account number
  7. Add EA Expiry date yyyy.mm.dd
  8. Check 1.5 Multiplier - Make sure it works (When trade closes in negative, multiply the next trade by 1.5. Once trade closes in positive, revert back to default lot size)
  
  9. Ensure that the indicator lines do not show up on the chart especially during & after running STRATEGY TESTER
  10. Ability to track profit in order to charge comission
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""01Apr2025




## Features
- Uses **Bollinger Bands** to identify price breakouts.
- Implements a **Fast & Slow Moving Average crossover strategy**.
- Configurable **lot size, stop loss, and take profit**.
- Allows **account-specific execution**.
- Limits the **number of trades per candle** to prevent overtrading.
- Implements **trend filtering** using Bollinger Band averages over past candles.

## Parameters
| Parameter                  | Description                                      | Default Value |
|----------------------------|--------------------------------------------------|--------------|
| LotSize                    | Lot size for trades                              | 0.1          |
| BBPeriod                   | Bollinger Bands period                           | 20           |
| BBDeviation                | Bollinger Bands deviation                        | 2.0          |
| FastMAPeriod               | Fast Moving Average period                       | 10           |
| SlowMAPeriod               | Slow Moving Average period                       | 20           |
| MagicNumber                | Unique identifier for trades                     | 123456       |
| Slippage                   | Allowed slippage in points                       | 3            |
| StopLoss                   | Stop loss in points                              | 50           |
| TakeProfit                 | Take profit in points                            | 100          |
| AllowedAccountNumber       | Restrict EA to a specific account (0 = any)      | 0            |
| MaxTradesPerCandleBuy      | Maximum buy trades per candle                    | 1            |
| MaxTradesPerCandleSell     | Maximum sell trades per candle                   | 1            |
| BackTrack                  | Number of past candles for trend analysis        | 10           |

## Trading Logic
### Entry Conditions
- **Buy Signal**:
  - Price crosses **above** the Bollinger Bands middle band.
  - Fast MA crosses **above** Slow MA.
  - Trend filter confirms **uptrend**.
  - Number of buy trades for the candle **is within limit**.

- **Sell Signal**:
  - Price crosses **below** the Bollinger Bands middle band.
  - Fast MA crosses **below** Slow MA.
  - Trend filter confirms **downtrend**.
  - Number of sell trades for the candle **is within limit**.

### Trade Execution
- The EA opens trades using the **OrderSend()** function.
- Trades are placed with a **stop loss and take profit**.
- Buy orders use the **Bid price**, and Sell orders use the **Ask price**.
- The EA prevents overtrading by limiting trades per candle.

### Trend Detection
- Uses the **getTrend()** function to analyze the middle Bollinger Band over the last `BackTrack` candles.
- If the **current middle band** is above the **average of past bands**, the trend is **up**.
- Otherwise, the trend is **down**.

## Installation & Usage
1. Copy the **BB_MA_EA.mq4** file to `MQL4/Experts/` in your MetaTrader 4 directory.
2. Restart MetaTrader 4 or refresh the **Navigator** panel.
3. Attach **BB_MA_EA** to a chart.
4. Configure the input parameters as needed.
5. Enable **AutoTrading** to allow trade execution.

## Notes
- The EA checks if it is running on the allowed account before executing trades.
- If an order fails, the error is printed in the **Expert Logs**.
- The EA does **not** use martingale or grid strategies—each trade is independent.

## Disclaimer
This EA is for **educational purposes**. Use at your own risk. Always test on a **demo account** before using real funds.

---
**Developed with MetaEditor**


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
GPT - BB Dual Entry EA.mq4

  Add email notification to user - to notify user of
  1.       Send Welcome message to the user at registered email
  2.       Send Expiration notification to User's email daily 4 days before expiration to notify user that that EA will be expiring and will be renewed authomatically through card onfile.
  3.       Send Expiration notice to User's email and Trade Pro FX Admins email on date of EA expiration to notify that EA has expired.
  3B          If renewed -  Send email to user notifying that EA is renewed
  4.       Include in the drafted email an option for User to unsubscribe to email notification.
  5.      
  6. Add Account number
  7. Add EA Expiry date yyyy.mm.dd
  8. Ensure that the indicator lines do not show up on the chart especially during & after running STRATEGY TESTER
  9. Ability to track profit in order to charge comission
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""22Oct2025

Trend FX EA
Add email notification to user - to notify user of
  1.       Send Welcome message to the user at registered email
  2.       Send Expiration notification to User's email daily 4 days before expiration to notify user that that EA will be expiring and will be renewed authomatically through card onfile.
  3.       Send Expiration notice to User's email and Trade Pro FX Admins email on date of EA expiration to notify that EA has expired.
  3B          If renewed -  Send email to user notifying that EA is renewed
  4.       Include in the drafted email an option for User to unsubscribe to email notification.
  5.      
  6. Add Account number...................Completed
  7. Add EA Expiry date yyyy.mm.dd...........Completed
  8. Ensure that the indicator lines do not show up on the chart especially during & after running STRATEGY TESTER
  9. Ability to track profit in order to charge comission
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""28Oct2025

