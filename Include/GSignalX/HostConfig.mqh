//+------------------------------------------------------------------+
//|                                                HostConfig.mqh     |
//|  DRY fillers for Telegram / Prop host configs (no Inp* reads).    |
//|  Service / Desk / Chart pass their inputs explicitly.             |
//+------------------------------------------------------------------+
#ifndef GSX_HOST_CONFIG_MQH
#define GSX_HOST_CONFIG_MQH

#include <GSignalX/TelegramNotifier.mqh>
#include <GSignalX/PropRisk.mqh>

//+------------------------------------------------------------------+
void GsxHostFillTgConfig(GsxTgConfig &c,
                         const bool enable,
                         const string botToken,
                         const string chatId1,
                         const string chatId2,
                         const string chatId3,
                         const int silentStartHourGmt,
                         const int silentEndHourGmt,
                         const int ratePerMin,
                         const int maxRetries)
  {
   c.enable = enable;
   c.botToken = botToken;
   c.chatId1 = chatId1;
   c.chatId2 = chatId2;
   c.chatId3 = chatId3;
   c.silentStartHourGmt = silentStartHourGmt;
   c.silentEndHourGmt = silentEndHourGmt;
   c.ratePerMin = ratePerMin;
   c.maxRetries = maxRetries;
  }

GsxTgConfig GsxHostMakeTgConfig(const bool enable,
                                const string botToken,
                                const string chatId1,
                                const string chatId2,
                                const string chatId3,
                                const int silentStartHourGmt,
                                const int silentEndHourGmt,
                                const int ratePerMin,
                                const int maxRetries)
  {
   GsxTgConfig c;
   GsxHostFillTgConfig(c, enable, botToken, chatId1, chatId2, chatId3,
                       silentStartHourGmt, silentEndHourGmt, ratePerMin, maxRetries);
   return(c);
  }

//+------------------------------------------------------------------+
void GsxHostFillPropConfig(GsxPropConfig &c,
                           const bool enable,
                           const long magic,
                           const double dailyLossMoney,
                           const double dailyLossPct,
                           const double maxEquityDdPct,
                           const int maxTradesDay,
                           const double maxDaySharePct,
                           const double dailyProfitTarget,
                           const int blockFridayHour,
                           const int newsBlackoutMin,
                           const string newsTimesCsv)
  {
   c.enable = enable;
   c.magic = magic;
   c.dailyLossMoney = dailyLossMoney;
   c.dailyLossPct = dailyLossPct;
   c.maxEquityDdPct = maxEquityDdPct;
   c.maxTradesDay = maxTradesDay;
   c.maxDaySharePct = maxDaySharePct;
   c.dailyProfitTarget = dailyProfitTarget;
   c.blockFridayHour = blockFridayHour;
   c.newsBlackoutMin = newsBlackoutMin;
   c.newsTimesCsv = newsTimesCsv;
  }

GsxPropConfig GsxHostMakePropConfig(const bool enable,
                                    const long magic,
                                    const double dailyLossMoney,
                                    const double dailyLossPct,
                                    const double maxEquityDdPct,
                                    const int maxTradesDay,
                                    const double maxDaySharePct,
                                    const double dailyProfitTarget,
                                    const int blockFridayHour,
                                    const int newsBlackoutMin,
                                    const string newsTimesCsv)
  {
   GsxPropConfig c;
   GsxHostFillPropConfig(c, enable, magic, dailyLossMoney, dailyLossPct,
                         maxEquityDdPct, maxTradesDay, maxDaySharePct,
                         dailyProfitTarget, blockFridayHour, newsBlackoutMin,
                         newsTimesCsv);
   return(c);
  }

#endif // GSX_HOST_CONFIG_MQH
//+------------------------------------------------------------------+
