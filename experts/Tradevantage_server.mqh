//+---------------------------------------------------------------------+
//| Required MQ5 EA Inputs:                                             |
//|   input string EA_Email;        // User email for authentication    |
//|   input string EA_Password;     // User password for authentication |
//|   #DEFINE (int)    EA_MagicNumber;  // EA magic number (set per Expert) |
//+---------------------------------------------------------------------+
#property strict

#include <WebRequest.mqh>
#include <JSON.mqh>   

//--- configuration
// 5.	Whitelist your URL
// •	In MT4’s settings you must add http://localhost:8000 (or your production URL) to the “Allowed URL” list in the terminal options, or WebRequest will always fail.
#define TV_API_URL     "https://tradevantage-webapp.onrender.com"  // or your deployed API URL
#define TV_EXPERT_ID   123                      // set your EA magic number here

//--- global storage for tokens
string   tv_access_token = "";
string   tv_refresh_token = "";
datetime tv_token_expiry  = 0;

//+------------------------------------------------------------------+
//| Perform HTTP request with JSON and return response string       |
//+------------------------------------------------------------------+
string TV_HttpRequest(const string method, const string endpoint, const string body, int &http_status)
  {
   string url = TV_API_URL + endpoint;
   // Prepare headers
   string headers = "Content-Type: application/json\r\n";
   if(StringLen(tv_access_token) > 0)
      headers += "Authorization: Bearer " + tv_access_token + "\r\n";

   // Prepare request body
   uchar post_bytes[];
   int post_len = 0;
   if(StringLen(body) > 0)
      post_len = StringToCharArray(body, post_bytes);

   // Prepare result buffer
   uchar result_bytes[];

   // Create and configure requester
   CWebRequest request;
   request.SetTimeout(5000);

   // Send request and get HTTP status
   http_status = request.Request(method, url, headers, post_bytes, result_bytes);
   if(http_status <= 0)
     {
      PrintFormat("TV_HttpRequest error: %d (HTTP status), URL: %s", http_status, url);
      return("");
     }

   // Convert response bytes to string
   string response = CharArrayToString(result_bytes, 0, ArraySize(result_bytes));
   return(response);
  }

//+------------------------------------------------------------------+
//| Retrieve a JSON value by key using a proper parser               |
//+------------------------------------------------------------------+
string TV_GetJsonValue(const string json, const string key)
  {
    CJAVal root;
    if(!root.parse(json))
      {
       PrintFormat("JSON parse error: %s", json);
       return("");
      }
    CJAVal val = root[key];
    if(val.isString())
      return val.toString();
    if(val.isInteger())
      return IntegerToString(val.toInteger());
    if(val.isDouble())
      return DoubleToString(val.toDouble(), 8);
    // for arrays or objects, return their string form
    return val.toString();
  }

//+------------------------------------------------------------------+
//| Login: obtain access and refresh tokens                          |
//+------------------------------------------------------------------+
bool TV_Login(const string email, const string password)
  {
   string body = "{\"email\":\"" + email + "\",\"password\":\"" + password + "\"}";
   string resp = TV_HttpRequest("POST", "/api/login/", body);
   if(StringLen(resp)==0) return(false);
   string at = TV_GetJsonValue(resp, "access_token");
   string rt = TV_GetJsonValue(resp, "refresh_token");
   if(StringLen(at)==0 || StringLen(rt)==0) return(false);
   tv_access_token = at;
   tv_refresh_token = rt;
   // set expiry 30 minutes from now (adjust per your server TTL)
   tv_token_expiry = TimeCurrent() + 1800;
   return(true);
  }

//+------------------------------------------------------------------+
//| Refresh tokens if expired                                        |
//+------------------------------------------------------------------+
bool TV_Refresh()
  {
   if(tv_refresh_token=="") return(false);
   string body = "{\"refresh\":\"" + tv_refresh_token + "\"}";
   string resp = TV_HttpRequest("POST", "/api/login/refresh/", body);
   if(StringLen(resp)==0) return(false);
   string at = TV_GetJsonValue(resp, "access");
   if(StringLen(at)==0) return(false);
   tv_access_token = at;
   tv_token_expiry = TimeCurrent() + 1800;
   return(true);
  }

//+------------------------------------------------------------------+
//| Ensure we have a valid access token                              |
//+------------------------------------------------------------------+
bool TV_EnsureAuthenticated(const string email, const string password)
  {
   // If no access token, perform login
   if(tv_access_token == "" && !TV_Login(email, password))
      return(false);

   // Verify subscription via API
   string endpoint = "/api/trade-auth/" + IntegerToString(TV_EXPERT_ID) + "/";
   int status = 0;
   string resp = TV_HttpRequest("GET", endpoint, "", status);

   // On 401 Unauthorized, attempt token refresh and retry once
   if(status == 401)
     {
      if(TV_Refresh())
        {
         resp = TV_HttpRequest("GET", endpoint, "", status);
        }
      else
        {
         return(false);
        }
     }

   // Return true only if we got HTTP 200 and a non-empty response
   return (status == 200 && StringLen(resp) > 0);
  }


//+------------------------------------------------------------------+
//| Create trade on server, returns server-side trade ID             |
//+------------------------------------------------------------------+
int TV_CreateTrade(const int ticket, const double lot, const string symbol, const string direction, const string email, const string password)
  {
   if(!TV_EnsureAuthenticated(email, password)) return(-1);
   string body = "{"
                 "\"ticket_number\":" + IntegerToString(ticket) + ","
                 "\"expert\":" + IntegerToString(TV_EXPERT_ID) + ","
                 "\"lot_size\":" + DoubleToString(lot,2) + ","
                 "\"ticker\":\"" + symbol + "\","
                 "\"direction\":\"" + direction + "\""
                 "}";
   string resp = TV_HttpRequest("POST", "/api/trade/", body);
   if(StringLen(resp)==0) return(-1);
   string sid = TV_GetJsonValue(resp, "id");
   return((int)StringToInteger(sid));
  }

//+------------------------------------------------------------------+
//| Update existing trade                                            |
//+------------------------------------------------------------------+
bool TV_UpdateTrade(const int ticket, const double closePrice, const double profit, const string email, const string password)
  {
   if(!TV_EnsureAuthenticated(email, password)) return(false);
   // retrieve server ID from GlobalVariable
   string varName = "TV_trade_" + IntegerToString(ticket);
   if(!GlobalVariableCheck(varName)) return(false);
   int serverId = (int)GlobalVariableGet(varName);
   string body = "{"
                 "\"close_time\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\","
                 "\"profit\":" + DoubleToString(profit,2)
                 "}";
   string endpoint = "/api/trade/" + IntegerToString(serverId) + "/";
   string resp = TV_HttpRequest("PATCH", endpoint, body);
   return(StringLen(resp)>0);
  }
