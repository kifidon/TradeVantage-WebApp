//+------------------------------------------------------------------+
//|                                             Trade Pro FX Basic EA|
//|                                           Created By Trade Pro FX|
//|                                         info.tradeprofx@gmail.com|
//+------------------------------------------------------------------+

#property copyright "info.tradeprofx@gmail.com"
#property link      "info.tradeprofx@gmail.com"
#property version   "2.0.1"
#property strict



// Input parameters

input double LotSize = 0.1;                // Lot size

input int BBPeriod = 50;                   // Trend Approximation

input double BBDeviation = 2.0;            // Trend Deviation

input int FastMAPeriod = 10;               // Fast Trend Approximation

input int SlowMAPeriod = 20;               // Slow Trend Approximation

input int MagicNumber = 123456;            // Magic number 

input int Slippage = 3;                    // Slippage in points

input int StopLoss = 15000;                // Stop loss in points

input int TakeProfit = 5000;               // Take profit in points

input int MaxTradesPerCandleBuy = 1;       // Maximum buy trades per candle

input int MaxTradesPerCandleSell = 1;      // Maximum sell trades per candle

input int BackTrack = 1000;                // History

input double VolumeThreshold = 0.5;        // Multiplier 



//+------------------------------------------------------------------+

//| Element Queue for Last 5 Open Prices                             |

//+------------------------------------------------------------------+

#define QUEUE_SIZE 5



double OpenPriceQueue[QUEUE_SIZE]; // Circular buffer for last 5 open prices

const long AllowedAccountNumber = 0;       // Allowed account number (0 = any account)

datetime bootDate = StringToTime("2025.02.02 00:00:00"); // Date of EA boot YYYY.MM.DD HH:MM:SS

int QueueIndex = 0;



// Global variables

int LastCrossDirection = 0;                // 0 = No cross, 1 = Up, -1 = Down

datetime LastTradeTime = 0;                // Time of the last candle

int BuyTradesThisCandle = 0;               // Number of buy trades executed this candle

int SellTradesThisCandle = 0;              // Number of sell trades executed this candle



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

  InitializeQueue();
  return(INIT_SUCCEEDED);

}

//+------------------------------------------------------------------+

//| Expert deinitialization function                                 |

//+------------------------------------------------------------------+

void OnDeinit(const int reason)

  {

   // Deinitialization code

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

      UpdateQueue();
      if (CurrentCandleTime - bootDate > 2952000){
        Print("Expert has expired.");
        return;
      }
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



   // Check liquidity conditions

   bool LiquidityBuySignal = CheckLiquidity(OP_BUY);

   bool LiquiditySellSignal = CheckLiquidity(OP_SELL);



   // Execute trades only if all conditions are met

   if (BB_BuySignal &&  LiquidityBuySignal && BuyTradesThisCandle < MaxTradesPerCandleBuy && getTrend()== 1)

     {

      // Price crossed middle band going up, Fast MA is above Slow MA, and liquidity supports a buy

      LastCrossDirection = 1;

      OpenTrade(OP_BUY);

      BuyTradesThisCandle++; // Increment buy trade counter

     }

   else if (BB_SellSignal &&  LiquiditySellSignal && SellTradesThisCandle < MaxTradesPerCandleSell && getTrend() == 0)

     {

      // Price crossed middle band going down, Fast MA is below Slow MA, and liquidity supports a sell

      LastCrossDirection = -1;

      OpenTrade(OP_SELL);

      SellTradesThisCandle++; // Increment sell trade counter

     }

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

//| Function to check liquidity conditions                           |

//+------------------------------------------------------------------+

bool CheckLiquidity(int OrderType)

  {

   double AverageVolume = 0;

   for (int i = 1; i <= BackTrack; i++)

     {

      AverageVolume += Volume[i];

     }

   AverageVolume /= BackTrack;



   double CurrentVolume = Volume[0];



   if (OrderType == OP_BUY)

     {

      // Buy signal: High volume indicates liquidity for a buy

      return (CurrentVolume >= AverageVolume * VolumeThreshold);

     }

   else if (OrderType == OP_SELL)

     {

      // Sell signal: High volume indicates liquidity for a sell

      return (CurrentVolume >= AverageVolume * VolumeThreshold);

     }



   return false;

  }

//+------------------------------------------------------------------+

//| Function to determine market trend                               |

//+------------------------------------------------------------------+

int getTrend()

  {


   double average = 0;
   double  middleBandNow = iBands(NULL, 0, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_MAIN, 0);
   average = middleBandNow;

  for (int i = 0; i < BackTrack; i++) {
    double middleBandNow = iBands(NULL, 0, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_MAIN, i);
    sumX += i;                      // X is the index, representing time
    sumY += middleBandNow;          // Y is the value of the middle band
    sumXY += i * middleBandNow;     // X * Y
    sumX2 += i * i;                 // X^2
   }

   slope = (BackTrack * sumXY - sumX * sumY) / (middleBandNow * sumX2 - sumX * sumX);
   if (slope > 0 && checkCross(middleBandNow))

     {
      PrintFormat("Average: %.2f", average);
      return 1; // Uptrend

     }

   else if(slope < 0 && checkCross(middleBandNow))

     {
      PrintFormat("Average: %.2f", average);
      return 0; // Downtrend

     }
   return -1;

  }

//+------------------------------------------------------------------+





//+------------------------------------------------------------------+

//| Initialize the queue with the most recent open prices           |

//+------------------------------------------------------------------+

void InitializeQueue()

{

   for (int i = 0; i < QUEUE_SIZE; i++)

   {

      OpenPriceQueue[i] = iOpen(NULL, 0, i); // Initialize with last 5 open prices

   }

}



//+------------------------------------------------------------------+

//| Update the queue with the latest open price                     |

//+------------------------------------------------------------------+

void UpdateQueue()

{

   OpenPriceQueue[QueueIndex] = iOpen(NULL, 0, 0); // Store the latest open price

   QueueIndex = (QueueIndex + 1) % QUEUE_SIZE;     // Move index in circular fashion

}



//+------------------------------------------------------------------+

//| check cross of candles over ma                    |

//+------------------------------------------------------------------+

int checkCross(double bbMiddle)

{

  int cross = 0;

  if(OpenPriceQueue[(QueueIndex + 1) % QUEUE_SIZE] > bbMiddle && OpenPriceQueue[(QueueIndex + 3) % QUEUE_SIZE] < bbMiddle)

  {

    //crossed down
    cross = 1;

  }

  else if(OpenPriceQueue[(QueueIndex + 1) % QUEUE_SIZE] < bbMiddle && OpenPriceQueue[(QueueIndex + 3) % QUEUE_SIZE] > bbMiddle)

  {

    //crossed up
    cross = 1;

  }

  else

  {

    cross = 0;

  }

  return cross;

}

