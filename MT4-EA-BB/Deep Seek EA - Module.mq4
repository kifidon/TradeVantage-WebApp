//+------------------------------------------------------------------+
//|                                              MultiModuleEA.mq4   |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                       https://www.metaquotes.net/|
//+------------------------------------------------------------------+
#property strict

// Inputs for Module 1
input int Module1_MagicNumber = 1001;
input double Module1_LotSize = 0.01;
input int Module1_BBPeriod = 50;
input double Module1_BBDeviation = 2.0;
input double Module1_StopLoss = 50.0;
input double Module1_TakeProfit = 100.0;
input double Module1_DrawdownLimit = 10.0; // Percentage

// Inputs for Module 2
input int Module2_MagicNumber = 1002;
input double Module2_LotSize = 0.02;
input int Module2_BBPeriod = 50;
input double Module2_BBDeviation = 2.0;
input double Module2_StopLoss = 50.0;
input double Module2_TakeProfit = 100.0;
input double Module2_DrawdownLimit = 10.0; // Percentage

// Inputs for Module 3
input int Module3_MagicNumber = 1003;
input double Module3_LotSize = 0.015;
input int Module3_MAPeriod = 12;
input int Module3_MAShift = 6;
input double Module3_StopLoss = 50.0;
input double Module3_TakeProfit = 100.0;
input double Module3_DrawdownLimit = 10.0; // Percentage

// Global variables
double Module1_NextLotSize = Module1_LotSize;
double Module2_NextLotSize = Module2_LotSize;
double Module3_NextLotSize = Module3_LotSize;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize dashboards
    CreateDashboard("Module1", 10, 20);
    CreateDashboard("Module2", 10, 150);
    CreateDashboard("Module3", 10, 280);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Delete dashboards
    ObjectDelete(0, "Module1");
    ObjectDelete(0, "Module2");
    ObjectDelete(0, "Module3");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check drawdown limits
    if (CalculateDrawdown() >= Module1_DrawdownLimit) return;
    if (CalculateDrawdown() >= Module2_DrawdownLimit) return;
    if (CalculateDrawdown() >= Module3_DrawdownLimit) return;

    // Execute Module 1 logic
    ExecuteModule1();

    // Execute Module 2 logic
    ExecuteModule2();

    // Execute Module 3 logic
    ExecuteModule3();

    // Update dashboards
    UpdateDashboard("Module1", Module1_MagicNumber);
    UpdateDashboard("Module2", Module2_MagicNumber);
    UpdateDashboard("Module3", Module3_MagicNumber);
}

//+------------------------------------------------------------------+
//| Module 1: Bollinger Bands Strategy                               |
//+------------------------------------------------------------------+
void ExecuteModule1()
{
    double upperBand = iBands(NULL, 0, Module1_BBPeriod, Module1_BBDeviation, 0, PRICE_CLOSE, MODE_UPPER, 0);
    double lowerBand = iBands(NULL, 0, Module1_BBPeriod, Module1_BBDeviation, 0, PRICE_CLOSE, MODE_LOWER, 0);

    // Buy condition
    if (Ask <= lowerBand && CountOpenTrades(Module1_MagicNumber, OP_BUY) == 0)
    {
        CloseAllTrades(Module1_MagicNumber, OP_SELL);
        OpenTrade(OP_BUY, Module1_NextLotSize, Module1_StopLoss, Module1_TakeProfit, Module1_MagicNumber);
    }

    // Sell condition
    if (Bid >= upperBand && CountOpenTrades(Module1_MagicNumber, OP_SELL) == 0)
    {
        CloseAllTrades(Module1_MagicNumber, OP_BUY);
        OpenTrade(OP_SELL, Module1_NextLotSize, Module1_StopLoss, Module1_TakeProfit, Module1_MagicNumber);
    }
}

//+------------------------------------------------------------------+
//| Module 2: Middle Bollinger Band Cross                            |
//+------------------------------------------------------------------+
void ExecuteModule2()
{
    double middleBand = iBands(NULL, 0, Module2_BBPeriod, Module2_BBDeviation, 0, PRICE_CLOSE, MODE_MAIN, 0);

    // Buy condition
    if (Ask > middleBand && CountOpenTrades(Module2_MagicNumber, OP_BUY) == 0)
    {
        OpenTrade(OP_BUY, Module2_NextLotSize, Module2_StopLoss, Module2_TakeProfit, Module2_MagicNumber);
    }

    // Sell condition
    if (Bid < middleBand && CountOpenTrades(Module2_MagicNumber, OP_SELL) == 0)
    {
        OpenTrade(OP_SELL, Module2_NextLotSize, Module2_StopLoss, Module2_TakeProfit, Module2_MagicNumber);
    }
}

//+------------------------------------------------------------------+
//| Module 3: Moving Average Crossover                              |
//+------------------------------------------------------------------+
void ExecuteModule3()
{
    double ma = iMA(NULL, 0, Module3_MAPeriod, Module3_MAShift, MODE_SMA, PRICE_CLOSE, 0);

    // Buy condition
    if (iOpen(NULL, 0, 1) < ma && iClose(NULL, 0, 1) > ma && CountOpenTrades(Module3_MagicNumber, OP_BUY) == 0)
    {
        OpenTrade(OP_BUY, Module3_NextLotSize, Module3_StopLoss, Module3_TakeProfit, Module3_MagicNumber);
    }

    // Sell condition
    if (iOpen(NULL, 0, 1) > ma && iClose(NULL, 0, 1) < ma && CountOpenTrades(Module3_MagicNumber, OP_SELL) == 0)
    {
        OpenTrade(OP_SELL, Module3_NextLotSize, Module3_StopLoss, Module3_TakeProfit, Module3_MagicNumber);
    }
}

//+------------------------------------------------------------------+
//| Utility Functions                                                |
//+------------------------------------------------------------------+
int CountOpenTrades(int magicNumber, int type)
{
    int count = 0;
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == magicNumber && OrderType() == type)
        {
            count++;
        }
    }
    return count;
}

void CloseAllTrades(int magicNumber, int type)
{
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == magicNumber && OrderType() == type)
        {
            OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 3, clrRed);
        }
    }
}

void OpenTrade(int type, double lotSize, double stopLoss, double takeProfit, int magicNumber)
{
    double sl = (type == OP_BUY) ? Bid - stopLoss * Point : Ask + stopLoss * Point;
    double tp = (type == OP_BUY) ? Bid + takeProfit * Point : Ask - takeProfit * Point;
    int ticket = OrderSend(Symbol(), type, lotSize, (type == OP_BUY) ? Ask : Bid, 3, sl, tp, "", magicNumber, 0, clrBlue);
    if (ticket > 0)
    {
        if (OrderSelect(ticket, SELECT_BY_TICKET))
        {
            if (OrderProfit() > 0)
            {
                if (magicNumber == Module1_MagicNumber) Module1_NextLotSize = Module1_LotSize;
                if (magicNumber == Module2_MagicNumber) Module2_NextLotSize = Module2_LotSize;
                if (magicNumber == Module3_MagicNumber) Module3_NextLotSize = Module3_LotSize;
            }
            else
            {
                if (magicNumber == Module1_MagicNumber) Module1_NextLotSize *= 1.5;
                if (magicNumber == Module2_MagicNumber) Module2_NextLotSize *= 1.5;
                if (magicNumber == Module3_MagicNumber) Module3_NextLotSize *= 1.5;
            }
        }
    }
}

double CalculateDrawdown()
{
    double balance = AccountBalance();
    double equity = AccountEquity();
    return ((balance - equity) / balance) * 100;
}

void CreateDashboard(string name, int x, int y)
{
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetString(0, name, OBJPROP_TEXT, name + " Dashboard");
}

void UpdateDashboard(string name, int magicNumber)
{
    string text = name + "\n";
    text += "Drawdown: " + DoubleToString(CalculateDrawdown(), 2) + "%\n";
    text += "Buy Trades: " + IntegerToString(CountOpenTrades(magicNumber, OP_BUY)) + "\n";
    text += "Sell Trades: " + IntegerToString(CountOpenTrades(magicNumber, OP_SELL)) + "\n";
    ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+