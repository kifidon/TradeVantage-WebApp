//+------------------------------------------------------------------+
//|                                     Combined MA Strategy EA      |
//|                                       Created By Trade Vantage FX|
//|                                     info.tradevantagefx@gmail.com|
//+------------------------------------------------------------------+
#property copyright "info.tradevantagefx@gmail.com"
#property link      "info.tradevantagefx@gmail.com"
#property version   "2.0.2"
#property strict
#property description "Combined Moving Average Expert Advisor"

//--- Inputs for Strategy 1 (MA12, shift 6)
input string   Strategy1="------- Strategy 1 (MA12-shift6) -------";
input double   Lots1          =0.01;
input double   MaximumRisk1   =0.02;
input double   DecreaseFactor1=3;
input int      MovingPeriod1  =12;
input int      MovingShift1   =6;
input double   LotMultiplier1 =1.5;
input double   TrailingStop1  =50;
input double   TrailingStep1  =10;
#define MAGICMA1  010101

//--- Inputs for Strategy 2 (MA7, shift 2)
input string   Strategy2="------- Strategy 2 (MA7-shift2) -------";
input double   Lots2          =0.01;
input double   MaximumRisk2   =0.02;
input double   DecreaseFactor2=3;
input int      MovingPeriod2  =7;
input int      MovingShift2   =2;
input double   LotMultiplier2 =1.5;
input double   TrailingStop2  =50;
input double   TrailingStep2  =10;
#define MAGICMA2  020202

//--- Global Variables for Dashboard
int dashboardX = 10;
int dashboardY = 20;
color textColor = clrWhite;
color bgColor = clrBlack;
int fontSize = 10;
string fontName = "Arial";

//--- Global Variables for Lot Size Management
double currentLots1 = Lots1;
int lossCount1 = 0;
double currentLots2 = Lots2;
int lossCount2 = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   CreateDashboard();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteDashboard();
}

//+------------------------------------------------------------------+
//| Dashboard functions                                              |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   // Background
   ObjectCreate(0, "DashboardBG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "DashboardBG", OBJPROP_XDISTANCE, dashboardX);
   ObjectSetInteger(0, "DashboardBG", OBJPROP_YDISTANCE, dashboardY);
   ObjectSetInteger(0, "DashboardBG", OBJPROP_XSIZE, 200);
   ObjectSetInteger(0, "DashboardBG", OBJPROP_YSIZE, 120);
   ObjectSetInteger(0, "DashboardBG", OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, "DashboardBG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "DashboardBG", OBJPROP_BORDER_COLOR, clrWhite);

   // Account Number
   ObjectCreate(0, "AccountNumber", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "AccountNumber", OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, "AccountNumber", OBJPROP_YDISTANCE, dashboardY + 10);
   ObjectSetString(0, "AccountNumber", OBJPROP_TEXT, "Account: " + IntegerToString(AccountNumber()));
   ObjectSetInteger(0, "AccountNumber", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "AccountNumber", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "AccountNumber", OBJPROP_FONT, fontName);

   // Balance
   ObjectCreate(0, "Balance", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Balance", OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, "Balance", OBJPROP_YDISTANCE, dashboardY + 30);
   ObjectSetString(0, "Balance", OBJPROP_TEXT, "Balance: " + DoubleToString(AccountBalance(), 2));
   ObjectSetInteger(0, "Balance", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "Balance", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "Balance", OBJPROP_FONT, fontName);

   // Equity
   ObjectCreate(0, "Equity", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Equity", OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, "Equity", OBJPROP_YDISTANCE, dashboardY + 50);
   ObjectSetString(0, "Equity", OBJPROP_TEXT, "Equity: " + DoubleToString(AccountEquity(), 2));
   ObjectSetInteger(0, "Equity", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "Equity", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "Equity", OBJPROP_FONT, fontName);

   // Drawdown %
   ObjectCreate(0, "Drawdown", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Drawdown", OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, "Drawdown", OBJPROP_YDISTANCE, dashboardY + 70);
   ObjectSetString(0, "Drawdown", OBJPROP_TEXT, "Drawdown: 0.00%");
   ObjectSetInteger(0, "Drawdown", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "Drawdown", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "Drawdown", OBJPROP_FONT, fontName);

   // Open Positions
   ObjectCreate(0, "Positions", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Positions", OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, "Positions", OBJPROP_YDISTANCE, dashboardY + 90);
   ObjectSetString(0, "Positions", OBJPROP_TEXT, "Positions: 0");
   ObjectSetInteger(0, "Positions", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "Positions", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "Positions", OBJPROP_FONT, fontName);
}

void DeleteDashboard()
{
   ObjectDelete(0, "DashboardBG");
   ObjectDelete(0, "AccountNumber");
   ObjectDelete(0, "Balance");
   ObjectDelete(0, "Equity");
   ObjectDelete(0, "Drawdown");
   ObjectDelete(0, "Positions");
}

void UpdateDashboard()
{
   // Update Balance
   ObjectSetString(0, "Balance", OBJPROP_TEXT, "Balance: " + DoubleToString(AccountBalance(), 2));

   // Update Equity
   ObjectSetString(0, "Equity", OBJPROP_TEXT, "Equity: " + DoubleToString(AccountEquity(), 2));

   // Update Drawdown %
   double drawdown = CalculateDrawdown();
   ObjectSetString(0, "Drawdown", OBJPROP_TEXT, "Drawdown: " + DoubleToString(drawdown, 2) + "%");

   // Update Positions count
   int totalPositions = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && (OrderMagicNumber() == MAGICMA1 || OrderMagicNumber() == MAGICMA2))
            totalPositions++;
      }
   }
   ObjectSetString(0, "Positions", OBJPROP_TEXT, "Positions: " + IntegerToString(totalPositions));
}

double CalculateDrawdown()
{
   double balance = AccountBalance();
   double equity = AccountEquity();
   if(balance > 0)
      return (balance - equity) / balance * 100.0;
   return 0.0;
}

//+------------------------------------------------------------------+
//| Strategy-specific functions                                      |
//+------------------------------------------------------------------+
int CalculateCurrentOrders(string symbol, int magic)
{
   int buys = 0, sells = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false) break;
      if(OrderSymbol() == symbol && OrderMagicNumber() == magic)
      {
         if(OrderType() == OP_BUY) buys++;
         if(OrderType() == OP_SELL) sells++;
      }
   }
   if(buys > 0) return(buys);
   else return(-sells);
}

double LotsOptimized(double lots, double maximumRisk, double decreaseFactor, int lossCount, double lotMultiplier)
{
   double lot = lots * MathPow(lotMultiplier, lossCount);
   lot = NormalizeDouble(AccountFreeMargin() * maximumRisk / 1000.0, 1);
   
   int orders = HistoryTotal();
   int losses = 0;
   
   if(decreaseFactor > 0)
   {
      for(int i = orders - 1; i >= 0; i--)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) == false)
         {
            Print("Error in history!");
            break;
         }
         if(OrderSymbol() != Symbol() || OrderType() > OP_SELL)
            continue;
         if(OrderProfit() > 0) break;
         if(OrderProfit() < 0) losses++;
      }
      if(losses > 1)
         lot = NormalizeDouble(lot - lot * losses / decreaseFactor, 1);
   }
   
   if(lot < 0.1) lot = 0.1;
   return(lot);
}

void UpdateLotSize(double profit, double &currentLots, double baseLots, int &lossCount, double lotMultiplier)
{
   if(profit < 0)
   {
      lossCount++;
      currentLots *= lotMultiplier;
   }
   else
   {
      lossCount = 0;
      currentLots = baseLots;
   }
}

void CheckForOpen(int magic, int movingPeriod, int movingShift, double &currentLots)
{
   if(Volume[0] > 1) return;
   
   double ma = iMA(NULL, 0, movingPeriod, movingShift, MODE_SMA, PRICE_CLOSE, 0);
   
   // Sell conditions
   if(Open[1] > ma && Close[1] < ma)
   {
      if(CalculateCurrentOrders(Symbol(), magic) == 0)
      {
         double lot = LotsOptimized(currentLots, 
                                 (magic == MAGICMA1 ? MaximumRisk1 : MaximumRisk2), 
                                 (magic == MAGICMA1 ? DecreaseFactor1 : DecreaseFactor2),
                                 (magic == MAGICMA1 ? lossCount1 : lossCount2),
                                 (magic == MAGICMA1 ? LotMultiplier1 : LotMultiplier2));
         
         int res = OrderSend(Symbol(), OP_SELL, lot, Bid, 3, 0, 0, "", magic, 0, Red);
         if(res < 0)
            Print("Error opening SELL order (", magic, "): ", GetLastError());
      }
      return;
   }
   
   // Buy conditions
   if(Open[1] < ma && Close[1] > ma)
   {
      if(CalculateCurrentOrders(Symbol(), magic) == 0)
      {
         double lot = LotsOptimized(currentLots, 
                                 (magic == MAGICMA1 ? MaximumRisk1 : MaximumRisk2), 
                                 (magic == MAGICMA1 ? DecreaseFactor1 : DecreaseFactor2),
                                 (magic == MAGICMA1 ? lossCount1 : lossCount2),
                                 (magic == MAGICMA1 ? LotMultiplier1 : LotMultiplier2));
         
         int res = OrderSend(Symbol(), OP_BUY, lot, Ask, 3, 0, 0, "", magic, 0, Blue);
         if(res < 0)
            Print("Error opening BUY order (", magic, "): ", GetLastError());
      }
      return;
   }
}

void CheckForClose(int magic, int movingPeriod, int movingShift, double &currentLots, int &lossCount, double baseLots, double lotMultiplier)
{
   if(Volume[0] > 1) return;
   
   double ma = iMA(NULL, 0, movingPeriod, movingShift, MODE_SMA, PRICE_CLOSE, 0);
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false) break;
      if(OrderMagicNumber() != magic || OrderSymbol() != Symbol()) continue;
      
      if(OrderType() == OP_BUY)
      {
         if(Open[1] > ma && Close[1] < ma)
         {
            if(OrderClose(OrderTicket(), OrderLots(), Bid, 3, White))
               UpdateLotSize(OrderProfit(), currentLots, baseLots, lossCount, lotMultiplier);
            else
               Print("OrderClose error ", GetLastError());
            break;
         }
      }
      
      if(OrderType() == OP_SELL)
      {
         if(Open[1] < ma && Close[1] > ma)
         {
            if(OrderClose(OrderTicket(), OrderLots(), Ask, 3, White))
               UpdateLotSize(OrderProfit(), currentLots, baseLots, lossCount, lotMultiplier);
            else
               Print("OrderClose error ", GetLastError());
            break;
         }
      }
   }
}

void TrailingStopManagement(int magic, double trailingStop, double trailingStep)
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false) break;
      if(OrderMagicNumber() != magic || OrderSymbol() != Symbol()) continue;
      
      if(OrderType() == OP_BUY)
      {
         if(Bid - OrderOpenPrice() > trailingStop * Point)
         {
            if(OrderStopLoss() < Bid - (trailingStop + trailingStep) * Point)
            {
               if(!OrderModify(OrderTicket(), OrderOpenPrice(), Bid - trailingStop * Point, OrderTakeProfit(), 0, clrNONE))
                  Print("OrderModify error ", GetLastError());
            }
         }
      }
      
      if(OrderType() == OP_SELL)
      {
         if(OrderOpenPrice() - Ask > trailingStop * Point)
         {
            if(OrderStopLoss() > Ask + (trailingStop + trailingStep) * Point || OrderStopLoss() == 0)
            {
               if(!OrderModify(OrderTicket(), OrderOpenPrice(), Ask + trailingStop * Point, OrderTakeProfit(), 0, clrNONE))
                  Print("OrderModify error ", GetLastError());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| OnTick function                                                  |
//+------------------------------------------------------------------+
void OnTick()
{
   if(Bars < 100 || IsTradeAllowed() == false) return;
   
   // Process Strategy 1 (MA12-shift6)
   if(CalculateCurrentOrders(Symbol(), MAGICMA1) == 0)
      CheckForOpen(MAGICMA1, MovingPeriod1, MovingShift1, currentLots1);
   else
      CheckForClose(MAGICMA1, MovingPeriod1, MovingShift1, currentLots1, lossCount1, Lots1, LotMultiplier1);
   
   TrailingStopManagement(MAGICMA1, TrailingStop1, TrailingStep1);
   
   // Process Strategy 2 (MA7-shift2)
   if(CalculateCurrentOrders(Symbol(), MAGICMA2) == 0)
      CheckForOpen(MAGICMA2, MovingPeriod2, MovingShift2, currentLots2);
   else
      CheckForClose(MAGICMA2, MovingPeriod2, MovingShift2, currentLots2, lossCount2, Lots2, LotMultiplier2);
   
   TrailingStopManagement(MAGICMA2, TrailingStop2, TrailingStep2);
   
   // Update dashboard
   UpdateDashboard();
}
//+------------------------------------------------------------------+