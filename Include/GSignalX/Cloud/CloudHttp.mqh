//+------------------------------------------------------------------+
//|                                                CloudHttp.mqh      |
//|  WebRequest client for trade-api (no DLLs). Market OK.            |
//+------------------------------------------------------------------+
#ifndef GSX_CLOUD_HTTP_MQH
#define GSX_CLOUD_HTTP_MQH

#define GSX_CLOUD_HTTP_TO_MS  2000
#define GSX_CLOUD_HTTP_RETRIES 1

struct GsxCloudHttpResult
  {
   int    code;
   string body;
   string err;
   bool   ok;
  };

string GsxCloudTrimSlash(const string baseUrl)
  {
   string u = baseUrl;
   StringTrimLeft(u);
   StringTrimRight(u);
   while(StringLen(u) > 0 && StringGetCharacter(u, StringLen(u) - 1) == '/')
      u = StringSubstr(u, 0, StringLen(u) - 1);
   return(u);
  }

bool GsxCloudHttpDo(const string method, const string url, const string bearer,
                    const string jsonBody, GsxCloudHttpResult &out)
  {
   out.code = 0;
   out.body = "";
   out.err = "";
   out.ok = false;

   char data[];
   char result[];
   string headers = "Content-Type: application/json\r\n";
   if(bearer != "")
      headers += "Authorization: Bearer " + bearer + "\r\n";

   int dataLen = 0;
   if(jsonBody != "" && (method == "POST" || method == "PUT" || method == "PATCH"))
     {
      dataLen = StringToCharArray(jsonBody, data, 0, WHOLE_ARRAY, CP_UTF8);
      if(dataLen > 0)
         dataLen--; // drop trailing NUL from StringToCharArray
     }

   string resultHeaders;
   ResetLastError();
   int code = WebRequest(method, url, headers, GSX_CLOUD_HTTP_TO_MS, data, result, resultHeaders);
   if(code == -1)
     {
      out.err = "WebRequest failed err=" + IntegerToString(GetLastError()) +
                " — allow URL in Tools→Options→Expert Advisors";
      return(false);
     }
   out.code = code;
   out.body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   out.ok = (code >= 200 && code < 300);
   if(!out.ok)
      out.err = StringFormat("HTTP %d", code);
   return(true);
  }

bool GsxCloudHttpWithRetry(const string method, const string url, const string bearer,
                           const string jsonBody, GsxCloudHttpResult &out)
  {
   // No Sleep on the entry thread — CloudLoop retries next poll tick.
   for(int i = 0; i <= GSX_CLOUD_HTTP_RETRIES; i++)
     {
      if(GsxCloudHttpDo(method, url, bearer, jsonBody, out))
        {
         if(out.ok || (out.code >= 400 && out.code < 500 && out.code != 429))
            return(true);
        }
     }
   return(out.code > 0 || out.err != "");
  }

#endif
//+------------------------------------------------------------------+
