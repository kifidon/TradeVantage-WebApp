
#ifndef TRADE_VANTAGE_UTIL_H
#define TRADE_VANTAGE_UTIL_H

//--- BACKEND INTEGRATION PARAMETERS
//+------------------------------------------------------------------+
            // Input parameters for backend connection
            input string BackendConfig = "========== Backend Configuration ==========";
            input string API_URL = "https://tradevantage-webapp.onrender.com";  // Backend API URL
            input string JWT_TOKEN = "";  // JWT Authentication Token
            input string EXPERT_UUID = "";  // Expert UUID from TradeVantage
            input int MAGIC_NUMBER = 12345;  // Magic Number for this EA
            input bool ENABLE_BACKEND_SYNC = false;  // Enable backend synchronization
            
            // Subscription authentication cache
            bool gAuthenticated = false;
            datetime gLastAuthCheck = 0;
            int gAuthCheckInterval = 3600;  // Check every hour
            
            // Trade tracking for backend sync
            string gOpenTrades[];  // Store ticket -> UUID mappings
//+------------------------------------------------------------------+

//--- PARAMETERS
//+------------------------------------------------------------------+
            const datetime START_DATE = D'2025.04.01 00:00'; // YYYY.MM.DD HH:MM
            const datetime END_DATE   = D'2025.04.30 23:59'; // YYYY.MM.DD HH:MM
            #define DEBUG 1
            #define ACCOUNT_NUMBER 0
//+------------------------------------------------------------------+

// Define Timer Setting 
#define TIMER_INTERVAL 300
#define START_HOUR  0    // Start time (24-hour format)
#define END_HOUR    23   // End time (4-hour window after start)
#define START_MIN   0    // Start minute
#define END_MIN     59    // End minute
    
void RemoveIndicatorsOnTester() {
    int total = ObjectsTotal();
    if (DEBUG) Print("Starting RemoveIndicatorsOnTester — total objects: ", total);

    for (int i = total - 1; i >= 0; i--) {
        string objName = ObjectName(i);
        if (DEBUG) Print("Found object: ", objName);    
        bool result = ObjectDelete(objName);
        if (result) {
            if (DEBUG) Print("Deleted indicator object: ", objName);
        } else {
            if (DEBUG) Print("Failed to delete object: ", objName, " | Error: ", GetLastError());
        }
        
    }

    if (DEBUG) Print("Clean Up finished.");

}

int AuthenticateSubscription(){
    long userAccountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
    Print("User Account Number: ", userAccountNumber);
    if(userAccountNumber != ACCOUNT_NUMBER && ACCOUNT_NUMBER != 0){
        Print("This EA is not authorized to run on this account. Please contact the Adminsitrator.");
        return 0;
    }
    else{
        Print("EA is authorized to run on this account.");
    }


    datetime currentTime = TimeCurrent();  // Get current server time
    int currentHour = TimeHour(currentTime);;
    int currentMinute = TimeHour(currentTime);;
    Print("Current Time: ", TimeToString(currentTime, TIME_DATE | TIME_SECONDS));
    // Check if the current date is within range
    if (MQLInfoInteger(MQL_TESTER)) {
        return 1; // Skip date check in strategy tester
    }
    if (currentTime < START_DATE || currentTime > END_DATE)
    {
        Print("EA Has Expired (Day). Stopping EA...");
        Print("Your subscrtion has expired on: ", TimeToString(START_DATE, TIME_DATE | TIME_SECONDS), " to ", TimeToString(END_DATE, TIME_DATE | TIME_SECONDS));
        ExpertRemove();  // Quit EA
        return 0 ;
    }

    // Check if the current time is outside the allowed timeframe
    if (currentHour < START_HOUR || (currentHour == START_HOUR && currentMinute < START_MIN) ||
        currentHour > END_HOUR || (currentHour == END_HOUR && currentMinute >= END_MIN))
    {
        Print("EA Has Expired (Time). Stopping EA...");
        ExpertRemove();  // Quit EA
        return 0 ;
    }
    
    // Backend authentication check
    if (ENABLE_BACKEND_SYNC && StringLen(JWT_TOKEN) > 0) {
        if (!gAuthenticated || (currentTime - gLastAuthCheck) > gAuthCheckInterval) {
            int authResult = CheckBackendAuthentication();
            gLastAuthCheck = currentTime;
            if (authResult != 1) {
                Print("Backend authentication failed. EA will continue but backend sync disabled.");
                return 0;
            }
            gAuthenticated = true;
            Print("Backend authentication successful.");
        }
    }
    
    // EA runs normally if within time range
    Print("EA is running. Current Time: ", TimeToString(currentTime, TIME_SECONDS));
    return 1;
}

//+------------------------------------------------------------------+
//| Check Backend Authentication                                     |
//+------------------------------------------------------------------+
int CheckBackendAuthentication() {
    if (StringLen(JWT_TOKEN) == 0 || StringLen(EXPERT_UUID) == 0) {
        Print("JWT_TOKEN or EXPERT_UUID not set. Backend sync disabled.");
        return 0;
    }
    
    string url = API_URL + "/api/trade-auth/" + IntegerToString(MAGIC_NUMBER) + "/";
    string headers = "Authorization: Bearer " + JWT_TOKEN + "\r\n";
    
    char post[];
    char result[];
    string result_headers;
    
    // Make GET request
    int res = WebRequest("GET", url, "", headers, 5000, post, 0, result, result_headers);
    
    if (res == 200) {
        Print("Backend authentication successful: HTTP ", res);
        return 1;
    } else if (res == 410) {
        Print("Subscription expired: HTTP ", res);
        ExpertRemove();
        return 0;
    } else {
        Print("Backend authentication failed: HTTP ", res, " Error: ", GetLastError());
        return 0;
    }
}

//+------------------------------------------------------------------+
//| Send Trade to Backend                                           |
//+------------------------------------------------------------------+
void SendTradeToBackend(int ticket, int orderType, double lotSize, double profit, datetime openTime, datetime closeTime = 0) {
    if (!ENABLE_BACKEND_SYNC || StringLen(JWT_TOKEN) == 0 || StringLen(EXPERT_UUID) == 0) {
        return;  // Backend sync disabled
    }
    
    string direction = (orderType == OP_BUY) ? "BUY" : "SELL";
    string ticker = Symbol();
    
    // Format datetime for backend (ISO 8601 format)
    string openTimeStr = TimeToISOString(openTime);
    string closeTimeStr = "";
    if (closeTime > 0) closeTimeStr = TimeToISOString(closeTime);
    
    // Build JSON payload
    string json = "{";
    json += "\"expert\":\"" + EXPERT_UUID + "\",";
    json += "\"open_time\":\"" + openTimeStr + "\",";
    if (StringLen(closeTimeStr) > 0) {
        json += "\"close_time\":\"" + closeTimeStr + "\",";
    }
    json += "\"profit\":" + DoubleToString(profit, 2) + ",";
    json += "\"lot_size\":" + DoubleToString(lotSize, 2) + ",";
    json += "\"ticker\":\"" + ticker + "\",";
    json += "\"direction\":\"" + direction + "\",";
    json += "\"ticket_number\":" + IntegerToString(ticket);
    json += "}";
    
    string url = API_URL + "/api/trade/";
    string headers = "Authorization: Bearer " + JWT_TOKEN + "\r\n";
    headers += "Content-Type: application/json\r\n";
    
    char post[];
    char result[];
    string result_headers;
    int timeout = 5000;
    
    ArrayResize(post, StringToCharArray(json, post, 0, WHOLE_ARRAY) - 1);
    StringToCharArray(json, post, 0, WHOLE_ARRAY);
    
    // Make POST request
    int res = WebRequest("POST", url, "", headers, timeout, post, 0, result, result_headers);
    
    if (res == 200 || res == 201) {
        string response = CharArrayToString(result);
        Print("Trade sent to backend: Ticket ", ticket, " HTTP ", res);
        
        // Extract UUID from response if available
        if (DEBUG) Print("Response: ", response);
    } else {
        Print("Failed to send trade to backend: HTTP ", res, " Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Update Trade in Backend                                         |
//+------------------------------------------------------------------+
void UpdateTradeInBackend(string tradeUUID, double profit, datetime closeTime) {
    if (!ENABLE_BACKEND_SYNC || StringLen(JWT_TOKEN) == 0 || StringLen(tradeUUID) == 0) {
        return;
    }
    
    string closeTimeStr = TimeToISOString(closeTime);
    
    // Build JSON payload for PATCH
    string json = "{";
    json += "\"profit\":" + DoubleToString(profit, 2) + ",";
    json += "\"close_time\":\"" + closeTimeStr + "\"";
    json += "}";
    
    string url = API_URL + "/api/trade/" + tradeUUID + "/";
    string headers = "Authorization: Bearer " + JWT_TOKEN + "\r\n";
    headers += "Content-Type: application/json\r\n";
    
    char post[];
    char result[];
    string result_headers;
    int timeout = 5000;
    
    ArrayResize(post, StringToCharArray(json, post, 0, WHOLE_ARRAY) - 1);
    StringToCharArray(json, post, 0, WHOLE_ARRAY);
    
    // Make PATCH request
    int res = WebRequest("PATCH", url, "", headers, timeout, post, 0, result, result_headers);
    
    if (res == 200) {
        Print("Trade updated in backend: UUID ", tradeUUID, " HTTP ", res);
    } else {
        Print("Failed to update trade in backend: HTTP ", res, " Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Convert DateTime to ISO 8601 String                             |
//+------------------------------------------------------------------+
string TimeToISOString(datetime time) {
    MqlDateTime struct;
    TimeToStruct(time, struct);
    
    string year = IntegerToString(struct.year);
    string month = StringFormat("%02d", struct.mon);
    string day = StringFormat("%02d", struct.day);
    string hour = StringFormat("%02d", struct.hour);
    string minute = StringFormat("%02d", struct.min);
    string second = StringFormat("%02d", struct.sec);
    
    return year + "-" + month + "-" + day + "T" + hour + ":" + minute + ":" + second + "Z";
}

int lineOfBestFit( int MAPeriod_trend, int n)
{
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (int i = 0; i < n; i++)
    {
        double y = iMA(NULL, 0, MAPeriod_trend, MAShift, MODE_SMA, PRICE_CLOSE, i);
        double x = i;

        sumX += x;
        sumY += y;
        sumXY += x * y;
        sumX2 += x * x;
    }

    double slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);

    if (slope > SLOPE || slope < -SLOPE)
        return 1;
    else
        return 0;
}

#ifdef MA_1_EA_H

int TOTALBUY_trades = 0; 
int TOTALSELL_trades = 0; 
double  TOTALDAY_profit = 0;
double TOTALMONTH_profit = 0;
double TOTALWEEK_profit = 0;

int CURRENT_DAY = 0;
int CURRENT_MONTH = 0;
int CURRENT_WEEK = 0;

double currentLotsize = 0;
int previousBars = 0;



//--- EA 1 MA Dashboard 
//+------------------------------------------------------------------+
//| Dashboard Display for Trading Statistics                        |
//+------------------------------------------------------------------+
#property indicator_chart_window

// Define Colors
#define COLOR_BACKGROUND clrBlack
#define COLOR_TEXT clrWhite
#define COLOR_BUY clrLime
#define COLOR_SELL clrRed




//+------------------------------------------------------------------+
//| Function to Update Labels                                       |
//+------------------------------------------------------------------+
void UpdateLabel(string name, string text)
{
    ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                 |
//+------------------------------------------------------------------+
int EA1_MA_OnInit()
{
    // Set the background
    UpdateDateValues();
    if (AuthenticateSubscription() == 0) {
        return INIT_FAILED;
    }
    int row = 20;
    int nextRow = 20;
    int width = 180;
    currentLotsize = LotSize;
    
    ObjectCreate(0, "Dashboard_Background", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "Dashboard_Background", OBJPROP_XDISTANCE, 0);  // Set X position to 0 (top-left)
    ObjectSetInteger(0, "Dashboard_Background", OBJPROP_YDISTANCE, row);  // Set Y position to 0 (top-left)
    ObjectSetInteger(0, "Dashboard_Background", OBJPROP_XSIZE, width);
    ObjectSetInteger(0, "Dashboard_Background", OBJPROP_YSIZE, 220);
    ObjectSetInteger(0, "Dashboard_Background", OBJPROP_COLOR, C'22,27,27');
    ObjectSetInteger(0, "Dashboard_Background", OBJPROP_BGCOLOR,C'22,27,27');
    ObjectSetInteger(0, "Dashboard_Background", OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, "Dashboard_Background", OBJPROP_STYLE, STYLE_SOLID);
    row += 10;

    CreateLabel("Total Balance", 10, row, COLOR_TEXT);
    row += nextRow;
    CreateLabel("Total Equity", 10, row, COLOR_TEXT);
    row += nextRow;
    CreateLabel("Drawdown %", 10, row, COLOR_TEXT);
    row += nextRow;
    CreateLabel("Lot Size", 10, row, COLOR_TEXT);
    row += nextRow;
    ObjectCreate(0, "Separator1", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "Separator1", OBJPROP_XDISTANCE, 0);  // Set X position to 0 (top-left)
    ObjectSetInteger(0, "Separator1", OBJPROP_YDISTANCE, row);  // Set Y position to 0 (top-left)
    ObjectSetInteger(0, "Separator1", OBJPROP_XSIZE, width);
    ObjectSetInteger(0, "Separator1", OBJPROP_YSIZE, 5);
    ObjectSetInteger(0, "Separator1", OBJPROP_COLOR, C'22,27,27');
    ObjectSetInteger(0, "Separator1", OBJPROP_BGCOLOR,C'22,27,27');
    ObjectSetInteger(0, "Separator1", OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, "Separator1", OBJPROP_STYLE, STYLE_SOLID);
    row +=10;
    CreateLabel("Total Buy Trades", 10, row, COLOR_BUY);
    row += nextRow;
    CreateLabel("Total Sell Trades", 10, row, COLOR_SELL);
    row += nextRow;
    ObjectCreate(0, "Separator2", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "Separator2", OBJPROP_XDISTANCE, 0);  // Set X position to 0 (top-left)
    ObjectSetInteger(0, "Separator2", OBJPROP_YDISTANCE, row);  // Set Y position to 0 (top-left)
    ObjectSetInteger(0, "Separator2", OBJPROP_XSIZE, width);
    ObjectSetInteger(0, "Separator2", OBJPROP_YSIZE, 5);
    ObjectSetInteger(0, "Separator2", OBJPROP_COLOR, C'22,27,27');
    ObjectSetInteger(0, "Separator2", OBJPROP_BGCOLOR,C'22,27,27');
    ObjectSetInteger(0, "Separator2", OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, "Separator2", OBJPROP_STYLE, STYLE_SOLID);
    row += 10;
    CreateLabel("This Day's Profit", 10, row, COLOR_TEXT);
    row += nextRow;
    CreateLabel("This Week's Profit", 10, row, COLOR_TEXT);
    row += nextRow;
    CreateLabel("This Month's Profit", 10, row, COLOR_TEXT);
    row += nextRow;


    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnTick Function to Update Values                                |
//+------------------------------------------------------------------+
void EA1_MA_OnTickDashboard()
{
    double balance = AccountBalance();
    double equity = AccountEquity();
    double drawdown = 100.0 * (balance - equity) / balance;
    

    string totalBalanceText = "Total Balance: " + StringFormat("%-20s", DoubleToString(balance, 2));
    string totalEquityText = "Total Equity: " + StringFormat("%-20s", DoubleToString(equity, 2));
    string drawdownText = "Drawdown: " + StringFormat("%-20s", DoubleToString(drawdown, 2) + "%");
    string lotSizeText = "Lot Size: " + StringFormat("%-20s", DoubleToString(currentLotsize, 2));
    string totalBuyTradesText = "Total Buy Trades: " + StringFormat("%-20s", IntegerToString(TOTALBUY_trades));
    string totalSellTradesText = "Total Sell Trades: " + StringFormat("%-20s", IntegerToString(TOTALSELL_trades));
    string totalProfitText = "This Day's Profit: " + StringFormat("%-20s", DoubleToString(TOTALDAY_profit, 2));
    string totalProfitTextWeek = "This Week's Profit: " + StringFormat("%-20s", DoubleToString(TOTALWEEK_profit, 2));
    string totalProfitTextMonth = "This Month's Profit: " + StringFormat("%-20s", DoubleToString(TOTALMONTH_profit, 2));
    // Update each label
    UpdateLabel("Total Balance", totalBalanceText);
    UpdateLabel("Total Equity", totalEquityText);
    UpdateLabel("Drawdown %", drawdownText);
    UpdateLabel("Lot Size", lotSizeText);
    UpdateLabel("Total Buy Trades", totalBuyTradesText);
    UpdateLabel("Total Sell Trades", totalSellTradesText);
    UpdateLabel("This Day's Profit", totalProfitText);
    UpdateLabel("This Week's Profit",totalProfitTextWeek);
    UpdateLabel("This Month's Profit", totalProfitTextMonth);
}

//+------------------------------------------------------------------+
//| Function to Create Labels                                       |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, color textColor)
{
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
}

int CountTradesInPosition(int type)
{
    int count = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS) && OrderType() == type)
        {
            count++;
        }
    }
    return count;
}
//--- EA 1 MA Dashboard 

int countTotalProfits(){
    // Get the most recent closed trade from the history
    int totalOrders = OrdersHistoryTotal();
    
    if (totalOrders > 0)
    {
        // Select the most recent closed trade
        if (OrderSelect(totalOrders - 1, SELECT_BY_POS, MODE_HISTORY))
        {
            // Check if the order is a valid buy or sell trade
            if (OrderType() == OP_BUY || OrderType() == OP_SELL)
            {
                // Get the profit of the most recently closed trade
                double profit = OrderProfit();
                
                // Get the time of the most recent trade closure
                datetime closeTime = OrderCloseTime();
                
                MqlDateTime closeStruct;
                TimeToStruct(closeTime, closeStruct);
                
                int closeDay = closeStruct.day;
                int closeMonth = closeStruct.mon;
                int closeWeek = (closeStruct.day_of_year / 7) + 1;
                
                // Add profit to the respective day, month, or week
                if (closeDay == CURRENT_DAY) {
                    TOTALDAY_profit += profit;
                } else {
                    TOTALDAY_profit = profit; // Reset to today's profit
                }
                
                if (closeMonth == CURRENT_MONTH) {
                    TOTALMONTH_profit += profit;
                } else {
                    TOTALMONTH_profit = profit; // Reset to this month's profit
                }
                
                if (closeWeek == CURRENT_WEEK) {
                    TOTALWEEK_profit += profit;
                } else {
                    TOTALWEEK_profit = profit; // Reset to this week's profit
                }
                
            }
        }
    }
    
    return 0; 
}
void UpdateDateValues() {
    // Get the current time
    datetime currentTime = TimeCurrent();
    
    // Extract the day, month, and year from the current time
    MqlDateTime timeStruct;
    TimeToStruct(currentTime, timeStruct);
    if (DEBUG)
        Print("Current Time: ", TimeToString(currentTime, TIME_DATE | TIME_SECONDS));

    int currentDay = timeStruct.day;
    int currentMonth = timeStruct.mon;
    int currentWeek = (timeStruct.day_of_year / 7) + 1;

    // Check if the current day is different from the stored day
    if (currentDay != CURRENT_DAY) {
        CURRENT_DAY = currentDay;
        if(DEBUG){
            Print("Current Day: ", CURRENT_DAY);
        }
        // Optionally reset the profit for the new day
        TOTALDAY_profit = 0;
    }

    // Check if the current month is different from the stored month
    if (currentMonth != CURRENT_MONTH) {
        CURRENT_MONTH = currentMonth;
        if(DEBUG){
            Print("Current Month: ", CURRENT_MONTH);
        }
        // Optionally reset the profit for the new month
        TOTALMONTH_profit = 0;
    }

    // Check if the current week is different from the stored week
    if (currentWeek != CURRENT_WEEK) {
        CURRENT_WEEK = currentWeek;
        if(DEBUG){
            Print("Current Week: ", CURRENT_WEEK);
        }
        // Optionally reset the profit for the new week
        TOTALWEEK_profit = 0;
    }
}



#endif  //MA_1_EA_H
#endif  //TRADE_VANTAGE_UTIL_H