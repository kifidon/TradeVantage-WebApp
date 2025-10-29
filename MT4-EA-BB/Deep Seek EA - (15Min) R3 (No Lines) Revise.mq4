//+------------------------------------------------------------------+
//|                                            Trade Vantage Basic EA|
//|                                       Created By Trade Vantage FX|
//|                                     info.tradevantagefx@gmail.com|
//+------------------------------------------------------------------+
#property copyright "info.tradevantagefx@gmail.com"
#property link      "info.tradevantagefx@gmail.com"
#property version   "1.001" // Updated version format for MQL5 Market
#property strict
#property description "Trade Vantage 15 Min expert advisor"

#define MAGICMA  20131111
//--- Inputs
input double Lots          =0.01;
input double MaximumRisk   =0.02;
input double DecreaseFactor=3;
input int    MovingPeriod  =12;
input int    MovingShift   =6;
input double LotMultiplier =1.5; // Multiplier
input double TrailingStop  =50;  // Trailing stop in points
input double TrailingStep  =10;  // Trailing step in points
input bool   HideMA        =true; // Option to hide MA lines

//--- Global Variables for Dashboard
int dashboardX = 10; // X position of the dashboard
int dashboardY = 20; // Y position of the dashboard
color textColor = clrBlack; // Text color
color bgColor = clrYellow; // Background color
int fontSize = 8; // Font size
string fontName = "Arial"; // Font name

//--- Global Variables for Lot Size Management
double currentLots = Lots;
int lossCount = 0;

//--- Global Variables for Profit Calculation
double dailyProfit = 0.0;

double weeklyProfit = 0.0;

double monthlyProfit = 0.0;
datetime lastDailyUpdate = 0;
datetime lastWeeklyUpdate = 0;
datetime lastMonthlyUpdate = 0;

//--- Global Variables for Trade Management
double previousHigh = 0.0; // Previous high for Sell trades
double previousLow = 0.0;  // Previous low for Buy trades

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Create the dashboard
   CreateDashboard();
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Delete the dashboard objects
   DeleteDashboard();
//--- Delete MA indicator if HideMA is enabled
   if(HideMA)
     {
      ChartIndicatorDelete(0, 0, "Moving Average");
     }
  }
//+------------------------------------------------------------------+
//| Create the dashboard                                             |
//+------------------------------------------------------------------+
void CreateDashboard()
  {
//--- Background
   ObjectCreate(0, "DashboardBG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "DashboardBG", OBJPROP_XDISTANCE, dashboardX);
   ObjectSetInteger(0, "DashboardBG", OBJPROP_YDISTANCE, dashboardY);
   ObjectSetInteger(0, "DashboardBG", OBJPROP_XSIZE, 250); // Width of the dashboard
   ObjectSetInteger(0, "DashboardBG", OBJPROP_YSIZE, 200); // Height of the dashboard (increased to fit all lines)
   ObjectSetInteger(0, "DashboardBG", OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, "DashboardBG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "DashboardBG", OBJPROP_BORDER_COLOR, clrBlack);

//--- Account Number
   ObjectCreate(0, "AccountNumber", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "AccountNumber", OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, "AccountNumber", OBJPROP_YDISTANCE, dashboardY + 10);
   ObjectSetString(0, "AccountNumber", OBJPROP_TEXT, "Account: " + IntegerToString(AccountNumber()));
   ObjectSetInteger(0, "AccountNumber", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "AccountNumber", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "AccountNumber", OBJPROP_FONT, fontName);

//--- Balance
   ObjectCreate(0, "Balance", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Balance", OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, "Balance", OBJPROP_YDISTANCE, dashboardY + 30); // Increased Y-distance
   ObjectSetString(0, "Balance", OBJPROP_TEXT, "Balance: " + DoubleToString(AccountBalance(), 2));
   ObjectSetInteger(0, "Balance", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "Balance", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "Balance", OBJPROP_FONT, fontName);

//--- Equity
   ObjectCreate(0, "Equity", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Equity", OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, "Equity", OBJPROP_YDISTANCE, dashboardY + 50); // Increased Y-distance
   ObjectSetString(0, "Equity", OBJPROP_TEXT, "Equity: " + DoubleToString(AccountEquity(), 2));
   ObjectSetInteger(0, "Equity", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "Equity", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "Equity", OBJPROP_FONT, fontName);

//--- Daily Profit
   ObjectCreate(0, "DailyProfit", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "DailyProfit", OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, "DailyProfit", OBJPROP_YDISTANCE, dashboardY + 70); // Increased Y-distance
   ObjectSetString(0, "DailyProfit", OBJPROP_TEXT, "Daily Profit: " + DoubleToString(dailyProfit, 2));
   ObjectSetInteger(0, "DailyProfit", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "DailyProfit", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "DailyProfit", OBJPROP_FONT, fontName);

//--- Weekly Profit
   ObjectCreate(0, "WeeklyProfit", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "WeeklyProfit", OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, "WeeklyProfit", OBJPROP_YDISTANCE, dashboardY + 90); // Increased Y-distance
   ObjectSetString(0, "WeeklyProfit", OBJPROP_TEXT, "Weekly Profit: " + DoubleToString(weeklyProfit, 2));
   ObjectSetInteger(0, "WeeklyProfit", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "WeeklyProfit", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "WeeklyProfit", OBJPROP_FONT, fontName);

//--- Monthly Profit
   ObjectCreate(0, "MonthlyProfit", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "MonthlyProfit", OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, "MonthlyProfit", OBJPROP_YDISTANCE, dashboardY + 110); // Increased Y-distance
   ObjectSetString(0, "MonthlyProfit", OBJPROP_TEXT, "Monthly Profit: " + DoubleToString(monthlyProfit, 2));
   ObjectSetInteger(0, "MonthlyProfit", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "MonthlyProfit", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "MonthlyProfit", OBJPROP_FONT, fontName);

//--- Trend Direction
   ObjectCreate(0, "TrendDirection", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "TrendDirection", OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, "TrendDirection", OBJPROP_YDISTANCE, dashboardY + 130); // Increased Y-distance
   ObjectSetString(0, "TrendDirection", OBJPROP_TEXT, "Trend: " + GetTrendDirection());
   ObjectSetInteger(0, "TrendDirection", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "TrendDirection", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "TrendDirection", OBJPROP_FONT, fontName);
  }
//+------------------------------------------------------------------+
//| Delete the dashboard                                             |
//+------------------------------------------------------------------+
void DeleteDashboard()
  {
   ObjectDelete(0, "DashboardBG");
   ObjectDelete(0, "AccountNumber");
   ObjectDelete(0, "Balance");
   ObjectDelete(0, "Equity");
   ObjectDelete(0, "DailyProfit");
   ObjectDelete(0, "WeeklyProfit");
   ObjectDelete(0, "MonthlyProfit");
   ObjectDelete(0, "TrendDirection");
  }
//+------------------------------------------------------------------+
//| Update the dashboard                                             |
//+------------------------------------------------------------------+
void UpdateDashboard()
  {
//--- Update Balance
   ObjectSetString(0, "Balance", OBJPROP_TEXT, "Balance: " + DoubleToString(AccountBalance(), 2));

//--- Update Equity
   ObjectSetString(0, "Equity", OBJPROP_TEXT, "Equity: " + DoubleToString(AccountEquity(), 2));

//--- Update Daily, Weekly, and Monthly Profit
   UpdateProfitCalculations();

   ObjectSetString(0, "DailyProfit", OBJPROP_TEXT, "Daily Profit: " + DoubleToString(dailyProfit, 2));
   ObjectSetString(0, "WeeklyProfit", OBJPROP_TEXT, "Weekly Profit: " + DoubleToString(weeklyProfit, 2));
   ObjectSetString(0, "MonthlyProfit", OBJPROP_TEXT, "Monthly Profit: " + DoubleToString(monthlyProfit, 2));

//--- Update Trend Direction
   string trend = GetTrendDirection();
   ObjectSetString(0, "TrendDirection", OBJPROP_TEXT, "Trend: " + trend);
  }
//+------------------------------------------------------------------+
//| Calculate Drawdown %                                             |
//+------------------------------------------------------------------+
double CalculateDrawdown()
  {
   double balance = AccountBalance();
   double equity = AccountEquity();
   if(balance > 0)
      return (balance - equity) / balance * 100.0;
   return 0.0;
  }
//+------------------------------------------------------------------+
//| Calculate open positions                                         |
//+------------------------------------------------------------------+
int CalculateCurrentOrders(string symbol)
  {
   int buys=0,sells=0;
//---
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==MAGICMA)
        {
         if(OrderType()==OP_BUY)  buys++;
         if(OrderType()==OP_SELL) sells++;
        }
     }
//--- return orders volume
   if(buys>0) return(buys);
   else       return(-sells);
  }
//+------------------------------------------------------------------+
//| Calculate optimal lot size                                       |
//+------------------------------------------------------------------+
double LotsOptimized()
  {
   double lot=currentLots;
   int    orders=HistoryTotal();     // history orders total
   int    losses=0;                  // number of losses orders without a break
//--- select lot size
   lot=NormalizeDouble(AccountFreeMargin()*MaximumRisk/1000.0,1);
//--- calcuulate number of losses orders without a break
   if(DecreaseFactor>0)
     {
      for(int i=orders-1;i>=0;i--)
        {
         if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==false)
           {
            Print("Error in history!");
            break;
           }
         if(OrderSymbol()!=Symbol() || OrderType()>OP_SELL)
            continue;
         //---
         if(OrderProfit()>0) break;
         if(OrderProfit()<0) losses++;
        }
      if(losses>1)
         lot=NormalizeDouble(lot-lot*losses/DecreaseFactor,1);
     }
//--- return lot size
   if(lot<0.1) lot=0.1;
   return(lot);
  }
//+------------------------------------------------------------------+
//| Check for open order conditions                                  |
//+------------------------------------------------------------------+
void CheckForOpen()
  {
   double ma;
   int    res;
//--- go trading only for first tiks of new bar
   if(Volume[0]>1) return;
//--- get Moving Average 
   ma=iMA(NULL,0,MovingPeriod,MovingShift,MODE_SMA,PRICE_CLOSE,0);
//--- sell conditions
   if(Open[1]>ma && Close[1]<ma)
     {
      res=OrderSend(Symbol(),OP_SELL,currentLots,Bid,3,0,0,"",MAGICMA,0,Red);
      if(res<0)
         Print("Error opening SELL order: ",GetLastError());
      else
         previousHigh = High[1]; // Set previous high for Sell trade
      return;
     }
//--- buy conditions
   if(Open[1]<ma && Close[1]>ma)
     {
      res=OrderSend(Symbol(),OP_BUY,currentLots,Ask,3,0,0,"",MAGICMA,0,Blue);
      if(res<0)
         Print("Error opening BUY order: ",GetLastError());
      else
         previousLow = Low[1]; // Set previous low for Buy trade
      return;
     }
//---
  }
//+------------------------------------------------------------------+
//| Check for close order conditions                                 |
//+------------------------------------------------------------------+
void CheckForClose()
  {
   double ma;
//--- go trading only for first tiks of new bar
   if(Volume[0]>1) return;
//--- get Moving Average 
   ma=iMA(NULL,0,MovingPeriod,MovingShift,MODE_SMA,PRICE_CLOSE,0);
//---
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=Symbol()) continue;
      //--- check order type 
      if(OrderType()==OP_BUY)
        {
         // Close Buy trade if price is lower than previous low and multiplier is active
         if(lossCount > 0 && Bid < previousLow)
           {
            if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,White))
               Print("OrderClose error ",GetLastError());
            else
               UpdateLotSize(OrderProfit());
           }
         // Close Buy trade based on MA crossover
         else if(Open[1]>ma && Close[1]<ma)
           {
            if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,White))
               Print("OrderClose error ",GetLastError());
            else
               UpdateLotSize(OrderProfit());
           }
         break;
        }
      if(OrderType()==OP_SELL)
        {
         // Close Sell trade if price is higher than previous high and multiplier is active
         if(lossCount > 0 && Ask > previousHigh)
           {
            if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,White))
               Print("OrderClose error ",GetLastError());
            else
               UpdateLotSize(OrderProfit());
           }
         // Close Sell trade based on MA crossover
         else if(Open[1]<ma && Close[1]>ma)
           {
            if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,White))
               Print("OrderClose error ",GetLastError());
            else
               UpdateLotSize(OrderProfit());
           }
         break;
        }
     }
//---
  }
//+------------------------------------------------------------------+
//| Update lot size based on trade outcome                           |
//+------------------------------------------------------------------+
void UpdateLotSize(double profit)
  {
   if(profit < 0)
     {
      lossCount++;
      currentLots *= LotMultiplier;
     }
   else
     {
      lossCount = 0;
      currentLots = Lots;
     }
  }
//+------------------------------------------------------------------+
//| Trailing Stop Management                                         |
//+------------------------------------------------------------------+
void TrailingStopManagement()
  {
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=Symbol()) continue;
      //--- check order type 
      if(OrderType()==OP_BUY)
        {
         if(Bid-OrderOpenPrice()>TrailingStop*Point)
           {
            if(OrderStopLoss()<Bid-(TrailingStop+TrailingStep)*Point)
              {
               if(!OrderModify(OrderTicket(),OrderOpenPrice(),Bid-TrailingStop*Point,OrderTakeProfit(),0,clrNONE))
                  Print("OrderModify error ",GetLastError());
              }
           }
        }
      if(OrderType()==OP_SELL)
        {
         if(OrderOpenPrice()-Ask>TrailingStop*Point)
           {
            if(OrderStopLoss()>Ask+(TrailingStop+TrailingStep)*Point || OrderStopLoss()==0)
              {
               if(!OrderModify(OrderTicket(),OrderOpenPrice(),Ask+TrailingStop*Point,OrderTakeProfit(),0,clrNONE))
                  Print("OrderModify error ",GetLastError());
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Update Profit Calculations                                       |
//+------------------------------------------------------------------+
void UpdateProfitCalculations()
  {
   datetime currentTime = TimeCurrent();
   if(lastDailyUpdate == 0 || TimeDay(currentTime) != TimeDay(lastDailyUpdate))
     {
      dailyProfit = 0.0;
      lastDailyUpdate = currentTime;
     }
   if(lastWeeklyUpdate == 0 || TimeDayOfWeek(currentTime) < TimeDayOfWeek(lastWeeklyUpdate))
     {
      weeklyProfit = 0.0;
      lastWeeklyUpdate = currentTime;
     }
   if(lastMonthlyUpdate == 0 || TimeMonth(currentTime) != TimeMonth(lastMonthlyUpdate))
     {
      monthlyProfit = 0.0;
      lastMonthlyUpdate = currentTime;
     }

   double profit = AccountBalance() - AccountCredit();
   dailyProfit += profit;
   weeklyProfit += profit;
   monthlyProfit += profit;
  }
//+------------------------------------------------------------------+
//| Get Trend Direction                                              |
//+------------------------------------------------------------------+
string GetTrendDirection()
  {
   double ma = iMA(NULL, 0, MovingPeriod, MovingShift, MODE_SMA, PRICE_CLOSE, 0);
   if(Close[1] > ma) return "Bullish";
   if(Close[1] < ma) return "Bearish";
   return "Neutral";
  }
//+------------------------------------------------------------------+
//| OnTick function                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- check for history and trading
   if(Bars<100 || IsTradeAllowed()==false)
      return;
//--- calculate open orders by current symbol
   if(CalculateCurrentOrders(Symbol())==0) CheckForOpen();
   else                                    CheckForClose();
//--- Update the dashboard
   UpdateDashboard();
//--- Trailing Stop Management
   TrailingStopManagement();
//--- Hide MA lines if enabled
   if(HideMA)
     {
      ChartIndicatorDelete(0, 0, "Moving Average");
     }
//---
  }
//+------------------------------------------------------------------+