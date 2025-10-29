//+------------------------------------------------------------------+
//|                                            Trade Vantage Basic EA|
//|                                       Created By Trade Vantage FX|
//|                                     info.tradevantagefx@gmail.com|
//+------------------------------------------------------------------+
#define MA_1_EA_H
#include "TradeVantage_Util.mqh"

#property copyright "info.tradevantagefx@gmail.com"
#property link      "info.tradevantagefx@gmail.com"
#property version   "2.0.1"
#property strict
#property description "Moving Average sample expert advisor"

#define MAGICMA  20131111
//--- Inputs
input double Lots          =0.1;
input double MaximumRisk   =0.02;
input double DecreaseFactor=3;
input int    MovingPeriod  =12;
input int    MovingShift   =6;

//--- Global Variables for Dashboard
int dashboardX = 10; // X position of the dashboard
int dashboardY = 20; // Y position of the dashboard
color textColor = clrWhite; // Text color
color bgColor = clrBlack; // Background color
int fontSize = 10; // Font size
string fontName = "Arial"; // Font name

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
   RemoveIndicagtorsOnTester();
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
   ObjectSetInteger(0, "DashboardBG", OBJPROP_XSIZE, 200);
   ObjectSetInteger(0, "DashboardBG", OBJPROP_YSIZE, 120);
   ObjectSetInteger(0, "DashboardBG", OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, "DashboardBG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "DashboardBG", OBJPROP_BORDER_COLOR, clrWhite);

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
   ObjectSetInteger(0, "Balance", OBJPROP_YDISTANCE, dashboardY + 30);
   ObjectSetString(0, "Balance", OBJPROP_TEXT, "Balance: " + DoubleToString(AccountBalance(), 2));
   ObjectSetInteger(0, "Balance", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "Balance", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "Balance", OBJPROP_FONT, fontName);

//--- Equity
   ObjectCreate(0, "Equity", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Equity", OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, "Equity", OBJPROP_YDISTANCE, dashboardY + 50);
   ObjectSetString(0, "Equity", OBJPROP_TEXT, "Equity: " + DoubleToString(AccountEquity(), 2));
   ObjectSetInteger(0, "Equity", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "Equity", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "Equity", OBJPROP_FONT, fontName);

//--- Drawdown %
   ObjectCreate(0, "Drawdown", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Drawdown", OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, "Drawdown", OBJPROP_YDISTANCE, dashboardY + 70);
   ObjectSetString(0, "Drawdown", OBJPROP_TEXT, "Drawdown: 0.00%");
   ObjectSetInteger(0, "Drawdown", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "Drawdown", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "Drawdown", OBJPROP_FONT, fontName);

//--- Stop Loss (SL)
   ObjectCreate(0, "SL", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "SL", OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, "SL", OBJPROP_YDISTANCE, dashboardY + 90);
   ObjectSetString(0, "SL", OBJPROP_TEXT, "SL: 0.00");
   ObjectSetInteger(0, "SL", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "SL", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "SL", OBJPROP_FONT, fontName);

//--- Take Profit (TP)
   ObjectCreate(0, "TP", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "TP", OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, "TP", OBJPROP_YDISTANCE, dashboardY + 110);
   ObjectSetString(0, "TP", OBJPROP_TEXT, "TP: 0.00");
   ObjectSetInteger(0, "TP", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "TP", OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, "TP", OBJPROP_FONT, fontName);
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
   ObjectDelete(0, "Drawdown");
   ObjectDelete(0, "SL");
   ObjectDelete(0, "TP");
  }
//+------------------------------------------------------------------+
//| Update the dashboard                                             |
//+------------------------------------------------------------------+
void UpdateDashboard()
  {
   UpdateDateValues()
//--- Update Balance
   ObjectSetString(0, "Balance", OBJPROP_TEXT, "Balance: " + DoubleToString(AccountBalance(), 2));

//--- Update Equity
   ObjectSetString(0, "Equity", OBJPROP_TEXT, "Equity: " + DoubleToString(AccountEquity(), 2));

//--- Update Drawdown %
   double drawdown = CalculateDrawdown();
   ObjectSetString(0, "Drawdown", OBJPROP_TEXT, "Drawdown: " + DoubleToString(drawdown, 2) + "%");

//--- Update SL and TP
   double sl = 0.0, tp = 0.0;
   if(OrdersTotal() > 0)
     {
      if(OrderSelect(0, SELECT_BY_POS))
        {
         sl = OrderStopLoss();
         tp = OrderTakeProfit();
        }
     }
   ObjectSetString(0, "SL", OBJPROP_TEXT, "SL: " + DoubleToString(sl, 2));
   ObjectSetString(0, "TP", OBJPROP_TEXT, "TP: " + DoubleToString(tp, 2));
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
   double lot=Lots;
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
      res=OrderSend(Symbol(),OP_SELL,LotsOptimized(),Bid,3,0,0,"",MAGICMA,0,Red);
      return;
     }
//--- buy conditions
   if(Open[1]<ma && Close[1]>ma)
     {
      res=OrderSend(Symbol(),OP_BUY,LotsOptimized(),Ask,3,0,0,"",MAGICMA,0,Blue);
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
         if(Open[1]>ma && Close[1]<ma)
           {
            if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,White))
               Print("OrderClose error ",GetLastError());
           }
         break;
        }
      if(OrderType()==OP_SELL)
        {
         if(Open[1]<ma && Close[1]>ma)
           {
            if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,White))
               Print("OrderClose error ",GetLastError());
           }
         break;
        }
     }
//---
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
//---
  }
//+------------------------------------------------------------------+
