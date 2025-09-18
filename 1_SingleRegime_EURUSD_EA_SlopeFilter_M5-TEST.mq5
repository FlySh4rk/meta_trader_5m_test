//+------------------------------------------------------------------+
//|                               MultiRegime_EURUSD_EA_SlopeFilter.mq5 |
//|                      Copyright 2025, Sviluppato per Utente AI |
//|                                             Gemini by Google |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Sviluppato per Utente AI"
#property link      "https://www.google.com"
#property version   "2.0" // --- MODIFICATO --- Versione con Filtro Pendenza MA
#property strict

#include <Trade\Trade.mqh>

// --- Oggetti globali
CTrade trade;

// --- Parametri Globali
input group           "Global Settings"
input double          InpRiskPercent       = 1.5;         // InpRiskPercent Rischio percentuale per trade
input ulong           InpMagicNumber       = 666;       // InpMagicNumber Magic Number per questo EA
input uint            InpSlippage          = 10;          // InpSlippage Slippage massimo in punti

// --- MODIFICATO: Parametri Filtro Regime (Pendenza Media Mobile) ---
input group           "Market Regime Filter"
input int             InpMA_Filter_Period    = 200;         // InpMA_Filter_Period Periodo della media mobile per il filtro
input ENUM_MA_METHOD  InpMA_Filter_Method    = MODE_EMA;    // InpMA_Filter_Method Metodo della media mobile (SMA, EMA, etc.)
input int             InpMA_Slope_Period     = 10;          // InpMA_Slope_Period Su quante barre calcolare la pendenza
input double          InpMA_Slope_Threshold  = 1.0;         // InpMA_Slope_Threshold Pendenza minima (in Punti/Barra) per definire un trend

// --- Parametri Logica TREND (Momentum Breakout)
input group           "Trend Strategy Settings"
input int             InpDonchian_Period   = 40;          // InpDonchian_Period Periodo del Canale di Donchian
input int             InpATR_Period_Trend  = 14;          // InpATR_Period_Trend Periodo ATR per la logica Trend
input double          InpSL_ATR_Multiplier_Trend = 3.25;  // InpSL_ATR_Multiplier_Trend Moltiplicatore ATR per lo Stop Loss (Trend)
input double          InpTS_ATR_Multiplier_Trend = 2.0;   // InpTS_ATR_Multiplier_Trend Moltiplicatore ATR per il TRAILING STOP (Trend)

// --- Parametri Logica RANGE (Mean Reversion)
input group           "Range Strategy Settings"
input int             InpBB_Period         = 26;          // InpBB_Period Periodo delle Bande di Bollinger
input double          InpBB_Deviation      = 2.0;         // InpBB_Deviation Deviazione delle Bande di Bollinger
input int             InpRSI_Period        = 12;          // InpRSI_Period Periodo dell'RSI
input double          InpRSI_Overbought    = 70.0;        // InpRSI_Overbought Livello Ipercomprato RSI
input double          InpRSI_Oversold      = 30.0;        // InpRSI_Oversold Livello Ipervenduto RSI
input int             InpATR_Period_Range  = 14;          // InpATR_Period_Range Periodo ATR per la logica Range
input double          InpSL_ATR_Multiplier_Range = 1.25;  // InpSL_ATR_Multiplier_Range Moltiplicatore ATR per lo Stop Loss (Range)
input double          InpTP_Multiplier_Range = 3.0;     // InpTP_Multiplier_Range Moltiplicatore Rischio/Rendimento per il Take Profit

// --- NUOVO: Enumerazioni per la chiarezza del codice ---
enum ENUM_MARKET_REGIME
{
    REGIME_UPTREND,     // Pendenza MA positiva
    REGIME_DOWNTREND,   // Pendenza MA negativa
    REGIME_FLAT         // Pendenza MA piatta
};

enum ENUM_TRADE_DIRECTION
{
    ALLOW_ANY,
    ALLOW_LONGS_ONLY,
    ALLOW_SHORTS_ONLY
};

enum ENUM_DONCHIAN_MODE
{
    DONCHIAN_UPPER, // Per il canale superiore
    DONCHIAN_LOWER  // Per il canale inferiore
};

// --- Handles degli indicatori
int maFilterHandle; // --- NUOVO ---
int atrHandleTrend;
int bbandsHandle;
int rsiHandle;
int atrHandleRange;

//+------------------------------------------------------------------+
//| Funzione di Inizializzazione dell'Expert                       |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Inizializzazione oggetto di trading
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetTypeFillingBySymbol(_Symbol);
    trade.SetDeviationInPoints(InpSlippage);
    
    Print(AccountInfoInteger(ACCOUNT_MARGIN_MODE));

    //--- MODIFICATO: Ottenimento handle del filtro MA
    maFilterHandle = iMA(_Symbol, _Period, InpMA_Filter_Period, 0, InpMA_Filter_Method, PRICE_CLOSE);
    if(maFilterHandle == INVALID_HANDLE)
    {
        printf("Errore nell'ottenere l'handle MA Filter: %d", GetLastError());
        return(INIT_FAILED);
    }

    atrHandleTrend = iATR(_Symbol, _Period, InpATR_Period_Trend);
    if(atrHandleTrend == INVALID_HANDLE)
    {
        printf("Errore nell'ottenere l'handle ATR (Trend): %d", GetLastError());
        return(INIT_FAILED);
    }
    
    bbandsHandle = iBands(_Symbol, _Period, InpBB_Period, 0, InpBB_Deviation, PRICE_CLOSE);
    if(bbandsHandle == INVALID_HANDLE)
    {
        printf("Errore nell'ottenere l'handle Bollinger Bands: %d", GetLastError());
        return(INIT_FAILED);
    }

    rsiHandle = iRSI(_Symbol, _Period, InpRSI_Period, PRICE_CLOSE);
    if(rsiHandle == INVALID_HANDLE)
    {
        printf("Errore nell'ottenere l'handle RSI: %d", GetLastError());
        return(INIT_FAILED);
    }

    atrHandleRange = iATR(_Symbol, _Period, InpATR_Period_Range);
    if(atrHandleRange == INVALID_HANDLE)
    {
        printf("Errore nell'ottenere l'handle ATR (Range): %d", GetLastError());
        return(INIT_FAILED);
    }

    printf("EA Multi-Regime v2.0 (Slope Filter) inizializzato con successo.");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Funzione di De-inizializzazione dell'Expert                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Rilascia gli handles degli indicatori
    IndicatorRelease(maFilterHandle); // --- MODIFICATO ---
    IndicatorRelease(atrHandleTrend);
    IndicatorRelease(bbandsHandle);
    IndicatorRelease(rsiHandle);
    IndicatorRelease(atrHandleRange);
    printf("EA Multi-Regime de-inizializzato.");
}

//+------------------------------------------------------------------+
//| Funzione principale dell'Expert (OnTick)                        |
//+------------------------------------------------------------------+
void OnTick()
{
    MqlRates rates[1];
    static datetime lastBarTime = 0;
    if(CopyRates(_Symbol, _Period, 0, 1, rates) < 1)
    {
        printf("Errore nella copia dei dati della barra");
        return;
    }
    if(rates[0].time == lastBarTime)
        return;
    lastBarTime = rates[0].time;
    
    if(PositionSelect(_Symbol))
    {
        if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
           ManageOpenPosition();
           return;
        }
    }
    
    CheckForNewSignal();
}

////+------------------------------------------------------------------+
////| Controlla le condizioni di mercato e cerca un nuovo segnale      |
////+------------------------------------------------------------------+
//void CheckForNewSignal()
//{
//    //--- Determina il regime di mercato
//    ENUM_MARKET_REGIME regime = GetMarketRegime();
//
//    //--- Applica la NUOVA logica difensiva ---
//    if(regime == REGIME_FLAT)
//    {
//        // Se il mercato è piatto, attiva la logica di Range (sia Long che Short)
//        CheckRangeSignal(ALLOW_ANY);
//    }
//    // Se il regime è UPTREND o DOWNTREND, non viene eseguita nessuna azione.
//    // L'EA rimane inattivo per proteggersi dai trend forti.
//}

//+------------------------------------------------------------------+
//| Controlla le condizioni di mercato e cerca un nuovo segnale      |
//+------------------------------------------------------------------+
void CheckForNewSignal()
{
    // Dichiariamo una variabile per ricevere il valore della pendenza
    double calculated_slope; 
    
    // Chiamiamo la funzione aggiornata, che ci darà sia il regime sia la pendenza
    ENUM_MARKET_REGIME regime = GetMarketRegime(calculated_slope);

    // Usiamo StringFormat per creare un messaggio di log dettagliato e pulito
    string message;

    switch(regime)
    {
        case REGIME_UPTREND:
            message = StringFormat("Regim 5M-TEST: UPTREND (Pendenza: %.2f vs Soglia: -%.2f/+%.2f). Filtro attivo, trading disabilitato.", calculated_slope, InpMA_Slope_Threshold, InpMA_Slope_Threshold);
            Print(message);
            break;
            
        case REGIME_DOWNTREND:
            message = StringFormat("Regim 5M-TEST: DOWNTREND (Pendenza: %.2f vs Soglia: -%.2f/+%.2f). Filtro attivo, trading disabilitato.", calculated_slope, InpMA_Slope_Threshold, InpMA_Slope_Threshold);
            Print(message);
            break;
            
        case REGIME_FLAT:
            message = StringFormat("Regim 5M-TEST: FLAT (Pendenza: %.2f vs Soglia: -%.2f/+%.2f). Controllo segnali Range in corso...", calculated_slope, InpMA_Slope_Threshold, InpMA_Slope_Threshold);
            Print(message);
            CheckRangeSignal(ALLOW_ANY);
            break;
    }
}


//+------------------------------------------------------------------+
//| Determina il regime di mercato usando la pendenza della MA       |
//+------------------------------------------------------------------+
//ENUM_MARKET_REGIME GetMarketRegime()
//{
//    // --- INIZIO BLOCCO CORRETTO ---
//
//    // 1. Definiamo un array dinamico e stabiliamo la sua dimensione.
//    // Ci servono i dati dalla barra 0 alla barra 'InpMA_Slope_Period'.
//    int bars_to_copy = InpMA_Slope_Period + 1;
//    double ma_buffer[];
//    
//    // 2. Impostiamo l'array come una serie, così l'indice 0 corrisponde alla barra corrente.
//    ArraySetAsSeries(ma_buffer, true);
//
//    // 3. Usiamo UNA SOLA chiamata a CopyBuffer per riempire l'array.
//    // Copiamo 'bars_to_copy' valori a partire dalla barra corrente (shift 0).
//    if(CopyBuffer(maFilterHandle, 0, 0, bars_to_copy, ma_buffer) < bars_to_copy)
//    {
//        printf("Errore nella copia dei dati del filtro MA: dati insufficienti sul grafico.");
//        return REGIME_FLAT; // Stato sicuro in caso di errore
//    }
//
//    // 4. Ora che l'array è pieno, accediamo ai dati che ci servono.
//    // ma_buffer[0] contiene il valore della MA della barra corrente.
//    // ma_buffer[InpMA_Slope_Period] contiene il valore della MA di 'InpMA_Slope_Period' barre fa.
//    double ma_now = ma_buffer[0];
//    double ma_past = ma_buffer[InpMA_Slope_Period];
//
//    // --- FINE BLOCCO CORRETTO ---
//
//    // Il resto della logica per calcolare la pendenza rimane identico.
//    double price_diff = ma_now - ma_past;
//    
//    // Normalizziamo la pendenza dividendola per il numero di barre e per la dimensione del punto
//    // Questo ci dà un valore di "Punti per Barra", confrontabile e stabile
//    double slope = (price_diff / InpMA_Slope_Period) / _Point;
//
//    if(slope > InpMA_Slope_Threshold)
//        return REGIME_UPTREND;
//        
//    if(slope < -InpMA_Slope_Threshold)
//        return REGIME_DOWNTREND;
//        
//    return REGIME_FLAT;
//}

//+------------------------------------------------------------------+
//| Determina il regime di mercato e restituisce la pendenza calcolata |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME GetMarketRegime(double &slope_value) // <-- MODIFICA QUI
{
    int bars_to_copy = InpMA_Slope_Period + 1;
    double ma_buffer[];
    ArraySetAsSeries(ma_buffer, true);

    if(CopyBuffer(maFilterHandle, 0, 0, bars_to_copy, ma_buffer) < bars_to_copy)
    {
        printf("Errore nella copia dei dati del filtro MA: dati insufficienti sul grafico.");
        slope_value = 0; // In caso di errore, impostiamo la pendenza a 0
        return REGIME_FLAT;
    }

    double ma_now = ma_buffer[0];
    double ma_past = ma_buffer[InpMA_Slope_Period];
    double price_diff = ma_now - ma_past;
    double slope = (price_diff / InpMA_Slope_Period) / _Point;

    slope_value = slope; // <-- NUOVA RIGA: Assegniamo il valore calcolato alla variabile di output

    if(slope > InpMA_Slope_Threshold)
        return REGIME_UPTREND;
        
    if(slope < -InpMA_Slope_Threshold)
        return REGIME_DOWNTREND;
        
    return REGIME_FLAT;
}

//+------------------------------------------------------------------+
//| Controlla i segnali per la logica TREND (Breakout Donchian)      |
//+------------------------------------------------------------------+
// --- MODIFICATO: La funzione ora accetta un filtro direzionale
void CheckTrendSignal(ENUM_TRADE_DIRECTION direction_filter)
{
    double donchianUpper = GetDonchianValue(InpDonchian_Period, DONCHIAN_UPPER, 2);
    double donchianLower = GetDonchianValue(InpDonchian_Period, DONCHIAN_LOWER, 2);
    if(donchianUpper == 0 || donchianLower == 0) return;

    double closePrice = iClose(_Symbol, _Period, 1);
    
    //--- Segnale LONG: Chiusura sopra il canale
    if(direction_filter != ALLOW_SHORTS_ONLY && closePrice > donchianUpper)
    {
        double atrValue = GetIndicatorValue(atrHandleTrend, 0, 1);
        double slDistance = atrValue * InpSL_ATR_Multiplier_Trend;
        double stopLossPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - slDistance;
        double lotSize = CalculateLotSize(slDistance);
        trade.Buy(lotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), stopLossPrice, 0, "Trend_Long");
    }
    //--- Segnale SHORT: Chiusura sotto il canale
    else if(direction_filter != ALLOW_LONGS_ONLY && closePrice < donchianLower)
    {
        double atrValue = GetIndicatorValue(atrHandleTrend, 0, 1);
        double slDistance = atrValue * InpSL_ATR_Multiplier_Trend;
        double stopLossPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID) + slDistance;
        double lotSize = CalculateLotSize(slDistance);
        trade.Sell(lotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), stopLossPrice, 0, "Trend_Short");
    }
}


//+------------------------------------------------------------------+
//| Controlla i segnali per la logica RANGE (Mean Reversion)         |
//+------------------------------------------------------------------+
// --- MODIFICATO: La funzione ora accetta un filtro direzionale
void CheckRangeSignal(ENUM_TRADE_DIRECTION direction_filter)
{
    double bbUpper[1], bbLower[1];
    CopyBuffer(bbandsHandle, 1, 1, 1, bbUpper); // Upper Band
    CopyBuffer(bbandsHandle, 2, 1, 1, bbLower); // Lower Band
    
    double rsiValue = GetIndicatorValue(rsiHandle, 0, 1);
    double highPrice = iHigh(_Symbol, _Period, 1);
    double lowPrice  = iLow(_Symbol, _Period, 1);
    printf("CHECKING RANGE SIGNAL...");
    //--- Segnale LONG: Prezzo tocca la banda inferiore & RSI ipervenduto
    if(direction_filter != ALLOW_SHORTS_ONLY && lowPrice <= bbLower[0] && rsiValue < InpRSI_Oversold)
    {
        double atrValue = GetIndicatorValue(atrHandleRange, 0, 1);
        double slDistance = atrValue * InpSL_ATR_Multiplier_Range;
        double tpDistance = slDistance * InpTP_Multiplier_Range;
        
        double stopLossPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - slDistance;
        double takeProfitPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + tpDistance;
        double lotSize = CalculateLotSize(slDistance);
        trade.Buy(lotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), stopLossPrice, takeProfitPrice, "Range_Long");
        printf("IT'S A LONG SIGNAL - BUY");
    }
    //--- Segnale SHORT: Prezzo tocca la banda superiore & RSI ipercomprato
    else if(direction_filter != ALLOW_LONGS_ONLY && highPrice >= bbUpper[0] && rsiValue > InpRSI_Overbought)
    {
        double atrValue = GetIndicatorValue(atrHandleRange, 0, 1);
        double slDistance = atrValue * InpSL_ATR_Multiplier_Range;
        double tpDistance = slDistance * InpTP_Multiplier_Range;

        double stopLossPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID) + slDistance;
        double takeProfitPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID) - tpDistance;
        double lotSize = CalculateLotSize(slDistance);
        trade.Sell(lotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), stopLossPrice, takeProfitPrice, "Range_Short");
        printf("IT'S A SHORT SIGNAL - SELL");
    }
    else
    {
        bool longAllowed  = (direction_filter != ALLOW_SHORTS_ONLY);
        bool shortAllowed = (direction_filter != ALLOW_LONGS_ONLY);
        bool longCond     = (lowPrice <= bbLower[0] && rsiValue < InpRSI_Oversold);
        bool shortCond    = (highPrice >= bbUpper[0] && rsiValue > InpRSI_Overbought);

        printf("NO RANGE ENTRY — longAllowed=%s longCond=%s | shortAllowed=%s shortCond=%s | RSI=%.2f bbL=%.5f bbU=%.5f H=%.5f L=%.5f",
               longAllowed ? "Y":"N", longCond ? "Y":"N",
               shortAllowed ? "Y":"N", shortCond ? "Y":"N",
               rsiValue, bbLower[0], bbUpper[0], highPrice, lowPrice);
    }
    
}


//+------------------------------------------------------------------+
//| Gestisce le posizioni aperte (Trailing Stop ATR per Trend)      |
//+------------------------------------------------------------------+
void ManageOpenPosition()
{
    if(!PositionSelect(_Symbol)) return;
    string comment = PositionGetString(POSITION_COMMENT);
    
    if(StringFind(comment, "Trend") == -1)
    {
        return;
    }

    ENUM_POSITION_TYPE posType    = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double             currentSL  = PositionGetDouble(POSITION_SL);
    double             openPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
    double atrValue = GetIndicatorValue(atrHandleTrend, 0, 1);
    if(atrValue <= 0) return;

    double trailDistance = atrValue * InpTS_ATR_Multiplier_Trend;
    double newSL = 0;

    if(posType == POSITION_TYPE_BUY)
    {
        double proposedSL = SymbolInfoDouble(_Symbol, SYMBOL_BID) - trailDistance;
        if(proposedSL > currentSL && proposedSL > openPrice)
        {
            newSL = proposedSL;
        }
    }
    else if(posType == POSITION_TYPE_SELL)
    {
        double proposedSL = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + trailDistance;
        if(proposedSL < currentSL && (proposedSL < openPrice || currentSL == 0))
        {
            newSL = proposedSL;
        }
    }
    
    if(newSL != 0)
    {
        trade.PositionModify(_Symbol, newSL, PositionGetDouble(POSITION_TP));
    }
}

//+------------------------------------------------------------------+
//| Calcola la dimensione del lotto basata sul rischio percentuale   |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossDistanceInPrice)
{
    if(InpRiskPercent <= 0) return 0.01;

    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (InpRiskPercent / 100.0);
    
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double lotSizeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    if(stopLossDistanceInPrice <= 0 || tickValue <= 0)
    {
       return minLot;
    }

    double valuePerLot = (stopLossDistanceInPrice / tickSize) * tickValue;
    if(valuePerLot <= 0)
    {
        return minLot;
    }

    double lotSize = riskAmount / valuePerLot;
    lotSize = floor(lotSize / lotSizeStep) * lotSizeStep;
    if(lotSize < minLot) lotSize = minLot;
    if(lotSize > maxLot) lotSize = maxLot;
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Funzione helper per ottenere un valore da un indicatore          |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int buffer, int shift)
{
    double val[1];
    if(CopyBuffer(handle, buffer, shift, 1, val) <= 0)
    {
        return 0.0;
    }
    return val[0];
}

//+------------------------------------------------------------------+
//| Calcola manualmente il valore del Canale di Donchian             |
//+------------------------------------------------------------------+
double GetDonchianValue(int period, ENUM_DONCHIAN_MODE mode, int shift)
{
    if(Bars(_Symbol, _Period) < period + shift)
    {
        printf("Non ci sono abbastanza barre per calcolare il Donchian Channel.");
        return 0;
    }
    
    double highs[], lows[];
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    if(CopyHigh(_Symbol, _Period, shift, period, highs) == -1 || CopyLow(_Symbol, _Period, shift, period, lows) == -1)
    {
        printf("Errore nella copia dei dati High/Low per Donchian.");
        return 0;
    }
    
    if(mode == DONCHIAN_UPPER)
    {
        return highs[ArrayMaximum(highs, 0, period)];
    }
    else // DONCHIAN_LOWER
    {
        return lows[ArrayMinimum(lows, 0, period)];
    }
}
//+------------------------------------------------------------------+
