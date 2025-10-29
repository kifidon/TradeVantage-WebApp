//+------------------------------------------------------------------+
//| Monitor Closed Trades for Max Lot TP Closure                     |
//+------------------------------------------------------------------+
void MonitorClosedTrades()
{
   static datetime lastCheckTime = 0;
   
   // Check history periodically
   if(TimeCurrent() - lastCheckTime < 1)
      return;
   
   lastCheckTime = TimeCurrent();
   
   // Check recently closed orders
   for(int i = OrdersHistoryTotal() - 1; i >= MathMax(0, OrdersHistoryTotal() - 10); i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            // Check if order was closed by TP and lot size was at max
            if(OrderProfit() > 0 && OrderLots() >= MaxLotSize - 0.01)
            {
               if(OrderType() == OP_BUY && maxLotBuyReached)
               {
                  HandleMaxLotTPClose(OP_BUY);
                  maxLotBuyReached = false;
               }
               else if(OrderType() == OP_SELL && maxLotSellReached)
               {
                  HandleMaxLotTPClose(OP_SELL);
                  maxLotSellReached = false;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Handle Max Lot TP Close Event                                    |
//+------------------------------------------------------------------+
void HandleMaxLotTPClose(int orderType)
{
   string orderTypeText = (orderType == OP_BUY) ? "BUY" : "SELL";
   
   if(StopTradingAfterMaxTP)
   {
      // Stop trading for this order type
      if(orderType == OP_BUY)
         buyTradingStopped = true;
      else
         sellTradingStopped = true;
      
      Print("Max lot ", orderTypeText, " trade closed with TP. Trading STOPPED for ", orderTypeText);
      Comment("EA Trading STOPPED for ", orderTypeText, " after max lot TP close");
   }
   else if(RestartAfterMaxTP)
   {
      // Restart EA - reset lot sizes to default
      double resetLot = ResetToDefault ? LotSize : ResetLotSize;
      
      if(orderType == OP_BUY)
         currentBuyLot = resetLot;
      else
         currentSellLot = resetLot;
      
      Print("Max lot ", orderTypeText, " trade closed with TP. EA RESTARTED - Lot size reset to ", resetLot);
      Comment("EA RESTARTED for ", orderTypeText, " - Lot reset to ", resetLot);
   }
   else
   {
      // Continue trading - lot size already handled by CalculateLotSize
      Print("Max lot ", orderTypeText, " trade closed with TP. Continuing normal trading cycle.");
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size with Martingale                               |
//+------------------------------------------------------------------+
double CalculateLotSize(int orderType)
{
   double newLot = LotSize;
   
   if(!UseMartingale)
      return NormalizeLot(newLot);
   
   // Get the last closed order for this type
   datetime lastCloseTime = 0;
   double lastClosedLot = 0;
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == orderType)
         {
            if(OrderCloseTime() > lastCloseTime)
            {
               lastCloseTime = OrderCloseTime();
               lastClosedLot = OrderLots();
            }
         }
      }
   }
   
   // If there's a last closed order, apply martingale
   if(lastClosedLot > 0)
   {
      newLot = lastClosedLot * MartingaleMultiplier;
   }
   else
   {
      // Check if there are open orders of this type
      bool hasOpenOrders = false;
      for(int i = 0; i < OrdersTotal(); i++)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == orderType)
            {
               hasOpenOrders = true;
               newLot = OrderLots() * MartingaleMultiplier;
               break;
            }
         }
      }
      
      // If no open orders, use current lot size
      if(!hasOpenOrders)
      {
         if(orderType == OP_BUY)
            newLot = currentBuyLot;
         else
            newLot = currentSellLot;
      }
   }
   
   // Check if max lot size is reached
   if(newLot >= MaxLotSize)
   {
      newLot = MaxLotSize;
      
      // Mark that max lot has been reached for this order type
      if(orderType == OP_BUY)
         maxLotBuyReached = true;
      else
         maxLotSellReached = true;
      
      // Reset to default or custom lot size after reaching max
      double resetLot = ResetToDefault ? LotSize : ResetLotSize;
      
      // Update the current lot size for next cycle
      if(orderType == OP_BUY)
         currentBuyLot = resetLot;
      else
         currentSellLot = resetLot;
      
      Print("Max lot size reached for ", (orderType == OP_BUY ? "BUY" : "SELL"), 
            ". Will reset to ", resetLot, " on next trade.");
   }
   
   return NormalizeLot(newLot);
}

//+------------------------------------------------------------------+
//| Normalize Lot Size                                               |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   
   if(lot < minLot)
      lot = minLot;
   if(lot > maxLot)
      lot = maxLot;
   
   lot = NormalizeDouble(lot / lotStep, 0) * lotStep;
   
   return lot;
}

//+------------------------------------------------------------------+
//| Check for BB Close Exit (on bar close)                          |
//+------------------------------------------------------------------+
void CheckBBCloseExit()
{
   double upperBB = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_AppliedPrice, MODE_UPPER, 1);
   double lowerBB = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_AppliedPrice, MODE_LOWER, 1);
   
   double closePrice = Close[1];
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            // Close Buy orders when price closes above upper BB
            if(OrderType() == OP_BUY)
            {
               if(closePrice >= upperBB)
               {
                  bool closed = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrGreen);
                  if(closed)
                     Print("Buy order closed - Price closed above Upper BB: ", OrderTicket());
                  else
                     Print("Error closing Buy order: ", GetLastError());
               }
            }
            
            // Close Sell orders when price closes below lower BB
            if(OrderType() == OP_SELL)
            {
               if(closePrice <= lowerBB)
               {
                  bool closed = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrGreen);
                  if(closed)
                     Print("Sell order closed - Price closed below Lower BB: ", OrderTicket());
                  else
                     Print("Error closing Sell order: ", GetLastError());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//|                                    BB Dual Entry EA.mq4          |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "BB Dual Entry Strategy"
#property link      ""
#property version   "1.10"
#property strict

//--- Input Parameters
input string    Section1 = "========== Bollinger Bands Settings ==========";
input int       BB_Period = 20;              // BB Period
input double    BB_Deviation = 2.0;          // BB Deviation
input ENUM_APPLIED_PRICE BB_AppliedPrice = PRICE_CLOSE; // BB Applied Price

input string    Section2 = "========== Trading Settings ==========";
input double    LotSize = 0.1;               // Initial Lot Size
input bool      UseMartingale = true;        // Use Martingale
input double    MartingaleMultiplier = 1.2;  // Martingale Multiplier
input double    MaxLotSize = 10.0;           // Maximum Lot Size
input bool      ResetToDefault = true;       // Reset to Default Lot After Max
input double    ResetLotSize = 0.1;          // Reset Lot Size (if not default)
input bool      RestartAfterMaxTP = true;    // Restart EA After Max Lot TP Close
input bool      StopTradingAfterMaxTP = false; // Stop Trading After Max Lot TP Close
input int       MagicNumber = 12345;         // Magic Number
input int       Slippage = 3;                // Slippage

input string    Section3 = "========== Exit Method Selection ==========";
enum EXIT_METHOD
{
   EXIT_TP_SL_TS,    // TP/SL/Trailing Stop
   EXIT_BB_TOUCH,    // BB Touch Exit
   EXIT_BB_CLOSE     // BB Close Exit
};
input EXIT_METHOD ExitMethod = EXIT_TP_SL_TS; // Exit Method

input string    Section4 = "========== Exit Settings (TP/SL/TS Method) ==========";
input double    TakeProfit = 500;            // Take Profit (points)
input double    StopLoss = 300;              // Stop Loss (points)
input bool      UseTrailingStop = true;      // Use Trailing Stop
input double    TrailingStop = 200;          // Trailing Stop (points)
input double    TrailingStep = 50;           // Trailing Step (points)

input string    Section5 = "========== Exit Settings (BB Touch Method) ==========";
input bool      UseSL_BBTouch = true;        // Use Stop Loss with BB Touch
input double    StopLoss_BBTouch = 300;      // Stop Loss for BB Touch Method (points)

input string    Section6 = "========== Exit Settings (BB Close Method) ==========";
input bool      UseSL_BBClose = true;        // Use Stop Loss with BB Close
input double    StopLoss_BBClose = 300;      // Stop Loss for BB Close Method (points)

input string    Section7 = "========== Trend Identification ==========";
input int       TrendMA_Period = 50;         // Trend MA Period
input ENUM_MA_METHOD TrendMA_Method = MODE_SMA; // Trend MA Method
input ENUM_APPLIED_PRICE TrendMA_AppliedPrice = PRICE_CLOSE; // Trend MA Applied Price
input double    SidewaysThreshold = 0.0005;  // Sideways Threshold (price range)
input int       TrendLookback = 10;          // Trend Lookback Bars

input string    Section8 = "========== Dashboard Settings ==========";
input bool      ShowDashboard = true;        // Show Dashboard
input int       Dashboard_X = 20;            // Dashboard X Position
input int       Dashboard_Y = 30;            // Dashboard Y Position
input color     Dashboard_Color = clrWhite;  // Dashboard Text Color
input color     Dashboard_TitleColor = clrYellow; // Dashboard Title Color
input int       Dashboard_FontSize = 9;      // Dashboard Font Size
input string    Dashboard_Font = "Arial Bold"; // Dashboard Font

//--- Global Variables
datetime lastBarTime = 0;
datetime lastExitCheckBar = 0;  // Track last bar for BB Close exits
int totalBuyOrders = 0;
int totalSellOrders = 0;
double totalProfit = 0;
double totalLoss = 0;
string currentTrend = "Sideways";
double currentBuyLot = 0;   // Current lot size for buy orders
double currentSellLot = 0;  // Current lot size for sell orders
bool maxLotBuyReached = false;  // Track if max lot was reached for buy
bool maxLotSellReached = false; // Track if max lot was reached for sell
bool buyTradingStopped = false; // Trading stopped for buy after max TP
bool sellTradingStopped = false; // Trading stopped for sell after max TP

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize lot sizes
   currentBuyLot = LotSize;
   currentSellLot = LotSize;
   
   if(ShowDashboard)
      CreateDashboard();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   RemoveDashboard();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Monitor closed trades for max lot TP closes
   MonitorClosedTrades();
   
   // Check if a new bar has formed
   if(Time[0] == lastBarTime)
   {
      // Still check for BB Touch exits on every tick
      if(ExitMethod == EXIT_BB_TOUCH)
         CheckBBTouchExit();
      
      // Apply trailing stop on every tick if using TP/SL/TS method
      if(ExitMethod == EXIT_TP_SL_TS && UseTrailingStop)
         ApplyTrailingStop();
      
      // Update dashboard
      if(ShowDashboard)
         UpdateDashboard();
      
      return;
   }
   
   lastBarTime = Time[0];
   
   // Calculate Bollinger Bands
   double upperBB = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_AppliedPrice, MODE_UPPER, 1);
   double lowerBB = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_AppliedPrice, MODE_LOWER, 1);
   double middleBB = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_AppliedPrice, MODE_MAIN, 1);
   
   double closePrice = Close[1];
   
   // Identify Trend
   currentTrend = IdentifyTrend();
   
   // Check for BB Close exits on new bar
   if(ExitMethod == EXIT_BB_CLOSE)
      CheckBBCloseExit();
   
   // Entry Logic: Price closed below lower BB - Open BUY only
   if(closePrice < lowerBB && !buyTradingStopped)
   {
      OpenOrder(OP_BUY, "LowerBB");
   }
   
   // Entry Logic: Price closed above upper BB - Open SELL only
   if(closePrice > upperBB && !sellTradingStopped)
   {
      OpenOrder(OP_SELL, "UpperBB");
   }
   
   // Update Dashboard
   if(ShowDashboard)
      UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Open Single Order (Buy or Sell)                                  |
//+------------------------------------------------------------------+
void OpenOrder(int orderType, string signal)
{
   double price = (orderType == OP_BUY) ? Ask : Bid;
   double point = Point;
   
   if(Point == 0.00001 || Point == 0.001)
      point = Point * 10;
   else
      point = Point;
   
   // Calculate lot size with martingale
   double lotSize = CalculateLotSize(orderType);
   
   double tp = 0;
   double sl = 0;
   
   // Set TP and SL based on exit method
   if(ExitMethod == EXIT_TP_SL_TS)
   {
      // Use TP/SL/TS method
      if(orderType == OP_BUY)
      {
         tp = (TakeProfit > 0) ? price + TakeProfit * point : 0;
         sl = (StopLoss > 0) ? price - StopLoss * point : 0;
      }
      else // OP_SELL
      {
         tp = (TakeProfit > 0) ? price - TakeProfit * point : 0;
         sl = (StopLoss > 0) ? price + StopLoss * point : 0;
      }
   }
   else if(ExitMethod == EXIT_BB_TOUCH)
   {
      // Use BB Touch method - only set SL if enabled
      tp = 0;  // Will exit when price touches opposite BB
      if(orderType == OP_BUY)
         sl = (UseSL_BBTouch && StopLoss_BBTouch > 0) ? price - StopLoss_BBTouch * point : 0;
      else
         sl = (UseSL_BBTouch && StopLoss_BBTouch > 0) ? price + StopLoss_BBTouch * point : 0;
   }
   else if(ExitMethod == EXIT_BB_CLOSE)
   {
      // Use BB Close method - only set SL if enabled
      tp = 0;  // Will exit when price closes beyond opposite BB
      if(orderType == OP_BUY)
         sl = (UseSL_BBClose && StopLoss_BBClose > 0) ? price - StopLoss_BBClose * point : 0;
      else
         sl = (UseSL_BBClose && StopLoss_BBClose > 0) ? price + StopLoss_BBClose * point : 0;
   }
   
   // Prepare order comment
   string orderTypeText = (orderType == OP_BUY) ? "Buy" : "Sell";
   color orderColor = (orderType == OP_BUY) ? clrBlue : clrRed;
   
   // Open Order
   int ticket = OrderSend(Symbol(), orderType, lotSize, price, Slippage, sl, tp, 
                          "BB " + orderTypeText + " " + signal, MagicNumber, 0, orderColor);
   
   if(ticket > 0)
   {
      Print(orderTypeText + " order opened: ", ticket, " Lot: ", lotSize);
      
      // Update current lot for next trade
      if(orderType == OP_BUY)
         currentBuyLot = lotSize;
      else
         currentSellLot = lotSize;
   }
   else
      Print("Error opening ", orderTypeText, " order: ", GetLastError());
}

//+------------------------------------------------------------------+
//| Check for BB Touch Exit                                          |
//+------------------------------------------------------------------+
void CheckBBTouchExit()
{
   double upperBB = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_AppliedPrice, MODE_UPPER, 0);
   double lowerBB = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_AppliedPrice, MODE_LOWER, 0);
   
   double currentPrice = (Bid + Ask) / 2;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            // Close Buy orders when price touches upper BB
            if(OrderType() == OP_BUY)
            {
               if(Bid >= upperBB)
               {
                  bool closed = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrGreen);
                  if(closed)
                     Print("Buy order closed at Upper BB: ", OrderTicket());
                  else
                     Print("Error closing Buy order: ", GetLastError());
               }
            }
            
            // Close Sell orders when price touches lower BB
            if(OrderType() == OP_SELL)
            {
               if(Ask <= lowerBB)
               {
                  bool closed = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrGreen);
                  if(closed)
                     Print("Sell order closed at Lower BB: ", OrderTicket());
                  else
                     Print("Error closing Sell order: ", GetLastError());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop to open positions                            |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
   double point = Point;
   
   if(Point == 0.00001 || Point == 0.001)
      point = Point * 10;
   else
      point = Point;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderType() == OP_BUY)
            {
               double newSL = Bid - TrailingStop * point;
               if(newSL > OrderStopLoss() && (OrderStopLoss() == 0 || newSL > OrderStopLoss() + TrailingStep * point))
               {
                  OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrBlue);
               }
            }
            else if(OrderType() == OP_SELL)
            {
               double newSL = Ask + TrailingStop * point;
               if(newSL < OrderStopLoss() || OrderStopLoss() == 0)
               {
                  if(OrderStopLoss() == 0 || newSL < OrderStopLoss() - TrailingStep * point)
                  {
                     OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrRed);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Identify Market Trend                                            |
//+------------------------------------------------------------------+
string IdentifyTrend()
{
   double ma_current = iMA(Symbol(), 0, TrendMA_Period, 0, TrendMA_Method, TrendMA_AppliedPrice, 0);
   double ma_previous = iMA(Symbol(), 0, TrendMA_Period, 0, TrendMA_Method, TrendMA_AppliedPrice, TrendLookback);
   
   double priceRange = iHigh(Symbol(), 0, iHighest(Symbol(), 0, MODE_HIGH, TrendMA_Period, 0)) - 
                       iLow(Symbol(), 0, iLowest(Symbol(), 0, MODE_LOW, TrendMA_Period, 0));
   
   // Check for sideways market
   if(priceRange < SidewaysThreshold)
      return "Sideways";
   
   // Determine trend direction
   if(ma_current > ma_previous && Close[0] > ma_current)
      return "Up";
   else if(ma_current < ma_previous && Close[0] < ma_current)
      return "Down";
   else
      return "Sideways";
}

//+------------------------------------------------------------------+
//| Create Dashboard Objects                                         |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   string labels[] = {"Title", "ExitMethod", "Martingale", "Status", "Equity", "Balance", "BuyOrders", "SellOrders", "Profit", "Loss", "Trend"};
   
   for(int i = 0; i < ArraySize(labels); i++)
   {
      string objName = "Dashboard_" + labels[i];
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, Dashboard_X);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, Dashboard_Y + i * 20);
      
      // Set color - title gets special color
      if(labels[i] == "Title")
         ObjectSetInteger(0, objName, OBJPROP_COLOR, Dashboard_TitleColor);
      else
         ObjectSetInteger(0, objName, OBJPROP_COLOR, Dashboard_Color);
      
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, Dashboard_FontSize);
      ObjectSetString(0, objName, OBJPROP_FONT, Dashboard_Font);
   }
}

//+------------------------------------------------------------------+
//| Update Dashboard Information                                     |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   // Count orders and calculate profit/loss
   totalBuyOrders = 0;
   totalSellOrders = 0;
   totalProfit = 0;
   totalLoss = 0;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderType() == OP_BUY)
               totalBuyOrders++;
            else if(OrderType() == OP_SELL)
               totalSellOrders++;
            
            if(OrderProfit() > 0)
               totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
            else
               totalLoss += OrderProfit() + OrderSwap() + OrderCommission();
         }
      }
   }
   
   // Get exit method text
   string exitMethodText = "";
   if(ExitMethod == EXIT_TP_SL_TS)
      exitMethodText = "TP/SL/TS";
   else if(ExitMethod == EXIT_BB_TOUCH)
      exitMethodText = "BB Touch";
   else if(ExitMethod == EXIT_BB_CLOSE)
      exitMethodText = "BB Close";
   
   // Get martingale status
   string martingaleText = UseMartingale ? "ON (x" + DoubleToString(MartingaleMultiplier, 2) + ")" : "OFF";
   
   // Get trading status
   string statusText = "Active";
   if(buyTradingStopped && sellTradingStopped)
      statusText = "STOPPED (Both)";
   else if(buyTradingStopped)
      statusText = "BUY Stopped";
   else if(sellTradingStopped)
      statusText = "SELL Stopped";
   
   // Update labels
   ObjectSetString(0, "Dashboard_Title", OBJPROP_TEXT, "=== BB DUAL ENTRY DASHBOARD ===");
   ObjectSetString(0, "Dashboard_ExitMethod", OBJPROP_TEXT, "Exit Method: " + exitMethodText);
   ObjectSetString(0, "Dashboard_Martingale", OBJPROP_TEXT, "Martingale: " + martingaleText);
   ObjectSetString(0, "Dashboard_Status", OBJPROP_TEXT, "Status: " + statusText);
   ObjectSetString(0, "Dashboard_Equity", OBJPROP_TEXT, "Equity: " + DoubleToString(AccountEquity(), 2));
   ObjectSetString(0, "Dashboard_Balance", OBJPROP_TEXT, "Balance: " + DoubleToString(AccountBalance(), 2));
   ObjectSetString(0, "Dashboard_BuyOrders", OBJPROP_TEXT, "Buy Orders: " + IntegerToString(totalBuyOrders));
   ObjectSetString(0, "Dashboard_SellOrders", OBJPROP_TEXT, "Sell Orders: " + IntegerToString(totalSellOrders));
   ObjectSetString(0, "Dashboard_Profit", OBJPROP_TEXT, "Profit: " + DoubleToString(totalProfit, 2));
   ObjectSetString(0, "Dashboard_Loss", OBJPROP_TEXT, "Loss: " + DoubleToString(totalLoss, 2));
   ObjectSetString(0, "Dashboard_Trend", OBJPROP_TEXT, "Trend: " + currentTrend);
   
   // Color code trend
   color trendColor = clrYellow;
   if(currentTrend == "Up")
      trendColor = clrLime;
   else if(currentTrend == "Down")
      trendColor = clrRed;
   
   ObjectSetInteger(0, "Dashboard_Trend", OBJPROP_COLOR, trendColor);
}

//+------------------------------------------------------------------+
//| Remove Dashboard Objects                                         |
//+------------------------------------------------------------------+
void RemoveDashboard()
{
   string labels[] = {"Title", "ExitMethod", "Martingale", "Status", "Equity", "Balance", "BuyOrders", "SellOrders", "Profit", "Loss", "Trend"};
   
   for(int i = 0; i < ArraySize(labels); i++)
   {
      ObjectDelete(0, "Dashboard_" + labels[i]);
   }
}
//+------------------------------------------------------------------+