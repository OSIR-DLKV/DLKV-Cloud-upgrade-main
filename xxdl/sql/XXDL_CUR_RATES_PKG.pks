create or replace package                XXDL_CUR_RATES_PKG authid definer is
/* $Header $
============================================================================+
File Name   : XX_GL_PKG.pks
Object      : XX_GL_PKG
Description : Endpoint for web service calls
History     :
v1.0 09.05.2020 - 
============================================================================+*/



/*===========================================================================+
Procedure   : import_daily_currency_rates
Description :
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure IMPORT_DAILY_CURRENCY_RATES_NP;

/*===========================================================================+
Procedure   : import_daily_currency_rates
Description :
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure IMPORT_DAILY_CURRENCY_RATES(
    x_return_status   out nocopy varchar2,
    x_return_message  out nocopy varchar2);

/*===========================================================================+
Procedure   : get_gl_daily_rates
Description : gets daily currency rates into local table
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure GET_GL_DAILY_RATES(p_status out varchar2, p_msg out varchar2);

/*===========================================================================+
Procedure   : import_gl_daily_rates
Description : imports daily currency rates from local table into fusion
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure IMPORT_GL_DAILY_RATES(p_status out varchar2, p_msg out varchar2);

/*===========================================================================+
Procedure   : verify_gl_daily_rates
Description : imports daily currency rates from local table into fusion
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure VERIFY_GL_DAILY_RATES(p_status out varchar2, p_msg out varchar2);

end XXDL_CUR_RATES_PKG;