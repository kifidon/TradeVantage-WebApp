//+------------------------------------------------------------------+
//|                                            Trade Vantage Basic EA|
//|                                       Created By Trade Vantage FX|
//|                                     info.tradevantagefx@gmail.com|
//+------------------------------------------------------------------+

#property copyright "info.tradevantagefx@gmail.com"
#property link      "info.tradevantagefx@gmail.com"
#property version   "2.0.1"
#property strict

// Input parameters
input double LotSize = 0.01;               // Lot size
input int BBPeriod = 50;                   // Trend Approximation
input double BBDeviation = 2.0;            // Trend Deviation
input int FastMAPeriod = 10;               // Fast Trend Approximation
input int SlowMAPeriod = 20;               // Fast Trend Approximation
input int MagicNumber = 444444;            // Magic number for trades
input int Slippage = 3;                    // Slippage in points
input int StopLoss = 750000;                // Stop loss in points
input int TakeProfit = 5000;               // Take profit in points
input long AllowedAccountNumber = 23499366;       // Allowed account number (0 = any account)
input int MaxTradesPerCandleBuy = 1;       // Maximum buy trades per candle
input int MaxTradesPerCandleSell = 1;      // Maximum sell trades per candle
input int BackTrack = 100;                 // How many candles to consider for average trend 

// Global variables
int LastCrossDirection = 0;                // 0 = No cross, 1 = Up, -1 = Down
datetime LastTradeTime = 0;                // Time of the last candle
int BuyTradesThisCandle = 0;               // Number of buy trades executed this candle
int SellTradesThisCandle = 0;              // Number of sell trades executed this candle

// Dashboard variables
string DashboardPrefix = "Dashboard_";     // Prefix for dashboard objects
int DashboardX = 10;                       // X position of the dashboard
int DashboardY = 20;                       // Y position of the dashboard
int DashboardFontSize = 10;                // Font size for dashboard text
color DashboardFontColor = clrWhite;       // Font color for dashboard text
int DashboardRowSpacing = 25;              // Vertical spacing between rows

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Check if the EA is allowed to run on this account
   if (AllowedAccountNumber != 0 && AccountNumber() != AllowedAccountNumber)
     {
      Alert("EA is not allowed to run on this account. Allowed account: ", AllowedAccountNumber);
      return(INIT_FAILED);
     }

   // Create dashboard
   CreateDashboard();
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Delete dashboard objects
   DeleteDashboard();
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Check if the EA is allowed to run on this account
   if (AllowedAccountNumber != 0 && AccountNumber() != AllowedAccountNumber)
     {
      return; // Exit if the account number does not match
     }

   // Get the current candle time
   datetime CurrentCandleTime = iTime(NULL, 0, 0);

   // Reset trade counters if a new candle has started
   if (CurrentCandleTime != LastTradeTime)
     {
      BuyTradesThisCandle = 0;
      SellTradesThisCandle = 0;
      LastTradeTime = CurrentCandleTime;
     }

   // Get Bollinger Bands values
   double MiddleBand = iBands(NULL, 0, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_MAIN, 0);
   double UpperBand = iBands(NULL, 0, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_UPPER, 0);
   double LowerBand = iBands(NULL, 0, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_LOWER, 0);

   // Get Moving Average values
   double FastMA = iMA(NULL, 0, FastMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
   double SlowMA = iMA(NULL, 0, SlowMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);

   // Get current price
   double CurrentPrice = Close[0];

   // Check for Bollinger Bands cross conditions
   bool BB_BuySignal = (CurrentPrice > MiddleBand && LastCrossDirection != 1);
   bool BB_SellSignal = (CurrentPrice < MiddleBand && LastCrossDirection != -1);

   // Check for Moving Average crossover conditions
   bool MA_BuySignal = (FastMA > SlowMA);
   bool MA_SellSignal = (FastMA < SlowMA);

   // Execute trades only if both strategies agree
   if (BB_BuySignal && MA_BuySignal && BuyTradesThisCandle < MaxTradesPerCandleBuy && getTrend())
     {
      // Price crossed middle band going up and Fast MA is above Slow MA
      LastCrossDirection = 1;
      OpenTrade(OP_BUY);
      BuyTradesThisCandle++; // Increment buy trade counter
     }
   else if (BB_SellSignal && MA_SellSignal && SellTradesThisCandle < MaxTradesPerCandleSell && getTrend() == 0)
     {
      // Price crossed middle band going down and Fast MA is below Slow MA
      LastCrossDirection = -1;
      OpenTrade(OP_SELL);
      SellTradesThisCandle++; // Increment sell trade counter
     }

   // Update dashboard
   UpdateDashboard();
  }
//+------------------------------------------------------------------+
//| Function to open a trade                                         |
//+------------------------------------------------------------------+
void OpenTrade(int OrderType)
  {
   double SL = 0;
   double TP = 0;

   if (OrderType == OP_BUY)
     {
      SL = Bid - StopLoss * Point;
      TP = Bid + TakeProfit * Point;
     }
   else if (OrderType == OP_SELL)
     {
      SL = Ask + StopLoss * Point;
      TP = Ask - TakeProfit * Point;
     }

   int Ticket = OrderSend(Symbol(), OrderType, LotSize, (OrderType == OP_BUY ? Ask : Bid), Slippage, SL, TP, "BB_MA_EA", MagicNumber, 0, (OrderType == OP_BUY ? clrBlue : clrRed));

   if (Ticket < 0)
     {
      Print("Error opening order: ", GetLastError());
     }
  }
//+------------------------------------------------------------------+
//| Function to calculate trend                                      |
//+------------------------------------------------------------------+
int getTrend()
  {
   double middleBand[100];
   double average = 0;
   for (int i = 0; i < BackTrack; i++)
     {
      middleBand[i] = iBands(NULL, 0, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_MAIN, i);
      average += middleBand[i];
     }
   average = average / BackTrack;
   if (average > middleBand[BackTrack - 1])
      return 1;
   else
      return 0;
  }
//+------------------------------------------------------------------+
//| Function to create dashboard                                     |
//+------------------------------------------------------------------+
void CreateDashboard()
  {
   // Create labels for dashboard
   ObjectCreate(0, DashboardPrefix + "SL", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, DashboardPrefix + "SL", OBJPROP_TEXT, "Stop Loss: ");
   ObjectSetInteger(0, DashboardPrefix + "SL", OBJPROP_XDISTANCE, DashboardX);
   ObjectSetInteger(0, DashboardPrefix + "SL", OBJPROP_YDISTANCE, DashboardY);
   ObjectSetInteger(0, DashboardPrefix + "SL", OBJPROP_COLOR, DashboardFontColor);
   ObjectSetInteger(0, DashboardPrefix + "SL", OBJPROP_FONTSIZE, DashboardFontSize);

   ObjectCreate(0, DashboardPrefix + "TP", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, DashboardPrefix + "TP", OBJPROP_TEXT, "Take Profit: ");
   ObjectSetInteger(0, DashboardPrefix + "TP", OBJPROP_XDISTANCE, DashboardX);
   ObjectSetInteger(0, DashboardPrefix + "TP", OBJPROP_YDISTANCE, DashboardY + DashboardRowSpacing);
   ObjectSetInteger(0, DashboardPrefix + "TP", OBJPROP_COLOR, DashboardFontColor);
   ObjectSetInteger(0, DashboardPrefix + "TP", OBJPROP_FONTSIZE, DashboardFontSize);

   ObjectCreate(0, DashboardPrefix + "Drawdown", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, DashboardPrefix + "Drawdown", OBJPROP_TEXT, "Drawdown %: ");
   ObjectSetInteger(0, DashboardPrefix + "Drawdown", OBJPROP_XDISTANCE, DashboardX);
   ObjectSetInteger(0, DashboardPrefix + "Drawdown", OBJPROP_YDISTANCE, DashboardY + 2 * DashboardRowSpacing);
   ObjectSetInteger(0, DashboardPrefix + "Drawdown", OBJPROP_COLOR, DashboardFontColor);
   ObjectSetInteger(0, DashboardPrefix + "Drawdown", OBJPROP_FONTSIZE, DashboardFontSize);

   ObjectCreate(0, DashboardPrefix + "Balance", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, DashboardPrefix + "Balance", OBJPROP_TEXT, "Balance: ");
   ObjectSetInteger(0, DashboardPrefix + "Balance", OBJPROP_XDISTANCE, DashboardX);
   ObjectSetInteger(0, DashboardPrefix + "Balance", OBJPROP_YDISTANCE, DashboardY + 3 * DashboardRowSpacing);
   ObjectSetInteger(0, DashboardPrefix + "Balance", OBJPROP_COLOR, DashboardFontColor);
   ObjectSetInteger(0, DashboardPrefix + "Balance", OBJPROP_FONTSIZE, DashboardFontSize);

   ObjectCreate(0, DashboardPrefix + "Equity", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, DashboardPrefix + "Equity", OBJPROP_TEXT, "Equity: ");
   ObjectSetInteger(0, DashboardPrefix + "Equity", OBJPROP_XDISTANCE, DashboardX);
   ObjectSetInteger(0, DashboardPrefix + "Equity", OBJPROP_YDISTANCE, DashboardY + 4 * DashboardRowSpacing);
   ObjectSetInteger(0, DashboardPrefix + "Equity", OBJPROP_COLOR, DashboardFontColor);
   ObjectSetInteger(0, DashboardPrefix + "Equity", OBJPROP_FONTSIZE, DashboardFontSize);
  }
//+------------------------------------------------------------------+
//| Function to update dashboard                                     |
//+------------------------------------------------------------------+
void UpdateDashboard()
  {
   // Calculate drawdown percentage
   double Balance = AccountBalance();
   double Equity = AccountEquity();
   double DrawdownPercent = 0;
   if (Balance > 0)
      DrawdownPercent = (Balance - Equity) / Balance * 100;

   // Update dashboard values
   ObjectSetString(0, DashboardPrefix + "SL", OBJPROP_TEXT, "Stop Loss: " + DoubleToString(StopLoss, 0) + " pips");
   ObjectSetString(0, DashboardPrefix + "TP", OBJPROP_TEXT, "Take Profit: " + DoubleToString(TakeProfit, 0) + " pips");
   ObjectSetString(0, DashboardPrefix + "Drawdown", OBJPROP_TEXT, "Drawdown %: " + DoubleToString(DrawdownPercent, 2));
   ObjectSetString(0, DashboardPrefix + "Balance", OBJPROP_TEXT, "Balance: " + DoubleToString(Balance, 2));
   ObjectSetString(0, DashboardPrefix + "Equity", OBJPROP_TEXT, "Equity: " + DoubleToString(Equity, 2));
  }
//+------------------------------------------------------------------+
//| Function to delete dashboard                                     |
//+------------------------------------------------------------------+
void DeleteDashboard()
  {
   // Delete dashboard objects
   ObjectDelete(0, DashboardPrefix + "SL");
   ObjectDelete(0, DashboardPrefix + "TP");
   ObjectDelete(0, DashboardPrefix + "Drawdown");
   ObjectDelete(0, DashboardPrefix + "Balance");
   ObjectDelete(0, DashboardPrefix + "Equity");
  }
//+------------------------------------------------------------------+