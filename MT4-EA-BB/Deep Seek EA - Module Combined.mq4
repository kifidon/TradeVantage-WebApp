//+------------------------------------------------------------------+
//|                                              Modularized EA      |
//|                                       Created By Trade Vantage FX|
//|                                     info.tradevantagefx@gmail.com|
//+------------------------------------------------------------------+
#property copyright "info.tradevantagefx@gmail.com"
#property link      "info.tradevantagefx@gmail.com"
#property version   "1.000"
#property strict

#include <TraveVantage_Util.mqh>

//--- Inputs for Module 1
input double Module1_Lots          = 0.01;
input double Module1_MaximumRisk   = 0.02;
input double Module1_DecreaseFactor= 3;
input int    Module1_MovingPeriod  = 12;
input int    Module1_MovingShift   = 6;
input double Module1_LotMultiplier = 1.5;
input double Module1_TrailingStop  = 50;
input double Module1_TrailingStep  = 10;
input bool   Module1_HideMA        = true;
input int    Module1_MagicNumber   = 20131111;

//---Module 1 Helpers 

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



//--- Inputs for Module 2
input double Module2_LotSize        = 0.01;
input int    Module2_BBPeriod       = 50;
input double Module2_BBDeviation    = 2.0;
input int    Module2_FastMAPeriod   = 10;
input int    Module2_SlowMAPeriod   = 20;
input int    Module2_MagicNumber    = 444444;
input int    Module2_Slippage       = 3;
input int    Module2_StopLoss       = 750000;
input int    Module2_TakeProfit     = 5000;
input int    Module2_MaxTradesPerCandleBuy  = 1;
input int    Module2_MaxTradesPerCandleSell = 1;
input int    Module2_BackTrack      = 100;

//--- Inputs for Module 3
input double Module3_LotSize        = 0.1;
input int    Module3_StopLossPips   = 750000;
input int    Module3_TakeProfitPips = 2550;
input int    Module3_MagicNumber    = 123456;
input string Module3_TradeComment   = "SR EA";
input int    Module3_SRSensitivity  = 20;

//--- Dashboard Variables
int dashboardX = 10;
int dashboardY = 20;
color textColor = clrBlack; // Font color set to black
color bgColor = clrYellow; // Background color
int fontSize = 8;
string fontName = "Arial";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize dashboards for each module
    CreateDashboard();

    // Module 1 GlobalVariables 
    m1currentLots = Lots;
    m1lossCount = 0;
    m1dailyProfit = 0.0;
    m1weeklyProfit = 0.0;
    m1monthlyProfit = 0.0;
    m1lastDailyUpdate = 0;
    m1lastWeeklyUpdate = 0;
    m1lastMonthlyUpdate = 0;

    //--- Global Variables for Trade Management
    double previousHigh = 0.0; // Previous high for Sell trades
    double previousLow = 0.0;  // Previous low for Buy trades

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Delete dashboards
    DeleteDashboard();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Execute Module 1 logic
    ExecuteModule1();

    // Execute Module 2 logic
    ExecuteModule2();

    // Execute Module 3 logic
    ExecuteModule3();

    // Update dashboards
    UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Execute Module 1 logic    (15Min R3)                             |
//+------------------------------------------------------------------+
void ExecuteModule1()
{
//--- check for history and trading
   if(Bars<100 || IsTradeAllowed()==false)
      return;
//--- calculate open orders by current symbol
   if(EAR3_CalculateCurrentOrders(Symbol())==0) EAR3_CheckForOpen(Module1_MovingPeriod,Module1_MovingShift);
   else                                    EAR3_CheckForClose(Module1_MovingPeriod,Module1_MovingShift);
//--- Update the dashboard
//    UpdateDashboard();
//--- Trailing Stop Management
   TrailingStopManagement(Module1_TrailingStop,Module1_TrailingStep);
//--- Hide MA lines if enabled
   if(HideMA)
     {
      ChartIndicatorDelete(0, 0, "Moving Average");
     }
//---
}

//+------------------------------------------------------------------+
//| Execute Module 2 logic                                           |
//+------------------------------------------------------------------+
void ExecuteModule2()
{
    // Module 2 logic here (from original EA)
    // Ensure all functions and variables are prefixed with "Module2_"
    // Example: Module2_OpenTrade(), Module2_getTrend(), etc.
    // Use Module2_MagicNumber for trades
}

//+------------------------------------------------------------------+
//| Execute Module 3 logic                                           |
//+------------------------------------------------------------------+
void ExecuteModule3()
{
    // Module 3 logic here (from original EA)
    // Ensure all functions and variables are prefixed with "Module3_"
    // Example: Module3_CheckSupportResistance(), Module3_OpenOrder(), etc.
    // Use Module3_MagicNumber for trades
}

//+------------------------------------------------------------------+
//| Create the dashboard                                             |
//+------------------------------------------------------------------+
void CreateDashboard()
{
    // Create dashboard for Module 1
    CreateModuleDashboard("Module1_", dashboardX, dashboardY);

    // Create dashboard for Module 2
    CreateModuleDashboard("Module2_", dashboardX, dashboardY + 200);

    // Create dashboard for Module 3
    CreateModuleDashboard("Module3_", dashboardX, dashboardY + 400);
}

//+------------------------------------------------------------------+
//| Create a dashboard for a specific module                         |
//+------------------------------------------------------------------+
void CreateModuleDashboard(string prefix, int x, int y)
{
    // Background
    ObjectCreate(0, prefix + "DashboardBG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, prefix + "DashboardBG", OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, prefix + "DashboardBG", OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, prefix + "DashboardBG", OBJPROP_XSIZE, 250);
    ObjectSetInteger(0, prefix + "DashboardBG", OBJPROP_YSIZE, 180);
    ObjectSetInteger(0, prefix + "DashboardBG", OBJPROP_BGCOLOR, bgColor);
    ObjectSetInteger(0, prefix + "DashboardBG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, prefix + "DashboardBG", OBJPROP_BORDER_COLOR, clrBlack);

    // Labels for Module 1
    ObjectCreate(0, prefix + "AccountNumber", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, prefix + "AccountNumber", OBJPROP_XDISTANCE, x + 10);
    ObjectSetInteger(0, prefix + "AccountNumber", OBJPROP_YDISTANCE, y + 10);
    ObjectSetString(0, prefix + "AccountNumber", OBJPROP_TEXT, "Account: " + IntegerToString(AccountNumber()));
    ObjectSetInteger(0, prefix + "AccountNumber", OBJPROP_COLOR, textColor);
    ObjectSetInteger(0, prefix + "AccountNumber", OBJPROP_FONTSIZE, fontSize);
    ObjectSetString(0, prefix + "AccountNumber", OBJPROP_FONT, fontName);
    ObjectSetInteger(0, prefix + "AccountNumber", OBJPROP_BACK, false); // Bring font to front

    // Add more labels for other metrics (Balance, Equity, Profit, etc.)
}

//+------------------------------------------------------------------+
//| Update the dashboard                                             |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
    // Update Module 1 dashboard
    UpdateModuleDashboard("Module1_", dashboardX, dashboardY);

    // Update Module 2 dashboard
    UpdateModuleDashboard("Module2_", dashboardX, dashboardY + 200);

    // Update Module 3 dashboard
    UpdateModuleDashboard("Module3_", dashboardX, dashboardY + 400);
}

//+------------------------------------------------------------------+
//| Update a dashboard for a specific module                         |
//+------------------------------------------------------------------+
void UpdateModuleDashboard(string prefix, int x, int y)
{
    // Update labels with current values
    ObjectSetString(0, prefix + "AccountNumber", OBJPROP_TEXT, "Account: " + IntegerToString(AccountNumber()));
    // Update other labels (Balance, Equity, Profit, etc.)
}

//+------------------------------------------------------------------+
//| Delete the dashboard                                             |
//+------------------------------------------------------------------+
void DeleteDashboard()
{
    // Delete Module 1 dashboard
    DeleteModuleDashboard("Module1_");

    // Delete Module 2 dashboard
    DeleteModuleDashboard("Module2_");

    // Delete Module 3 dashboard
    DeleteModuleDashboard("Module3_");
}

//+------------------------------------------------------------------+
//| Delete a dashboard for a specific module                         |
//+------------------------------------------------------------------+
void DeleteModuleDashboard(string prefix)
{
    ObjectDelete(0, prefix + "DashboardBG");
    ObjectDelete(0, prefix + "AccountNumber");
    // Delete other objects
}

//+------------------------------------------------------------------+