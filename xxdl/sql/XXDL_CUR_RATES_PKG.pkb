create or replace package   body             XXDL_CUR_RATES_PKG  is
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
procedure IMPORT_DAILY_CURRENCY_RATES_NP 
IS

X_RETURN_STATUS VARCHAR2(30); -- MSL
X_RETURN_MESSAGE VARCHAR2(2000);
L_RETURN_STATUS VARCHAR2(1);
L_RETURN_MESSAGE VARCHAR2(2000);

L_RETURN_STATUS_b VARCHAR2(1);
L_RETURN_MESSAGE_b VARCHAR2(2000);


BEGIN

  XXDL_CUR_RATES_PKG.GET_GL_DAILY_RATES(L_RETURN_STATUS, L_RETURN_MESSAGE);

  IF(L_RETURN_STATUS = 'S' )
  THEN
  L_RETURN_STATUS := ''; 
  l_return_message := '';
  XXDL_CUR_RATES_PKG.IMPORT_GL_DAILY_RATES(L_RETURN_STATUS, L_RETURN_MESSAGE);
   XXDL_CUR_RATES_PKG.IMPORT_GL_DAILY_RATES_b(L_RETURN_STATUS_b, L_RETURN_MESSAGE_b);
    DBMS_LOCK.sleep(60);
     IF(L_RETURN_STATUS = 'S')
     THEN
         L_RETURN_STATUS := ''; 
         l_return_message := '';
         XXDL_CUR_RATES_PKG.VERIFY_GL_DAILY_RATES(L_RETURN_STATUS, L_RETURN_MESSAGE);

         IF(L_RETURN_STATUS = 'S' )
         THEN
            X_RETURN_STATUS := 'Success';
            l_return_message := '';
            DBMS_OUTPUT.PUT_LINE('X_RETURN_STATUS:'||X_RETURN_STATUS||'X_RETURN_MESSAGE'||X_RETURN_MESSAGE);
         ELSE
             X_RETURN_STATUS := 'Error';
             X_RETURN_MESSAGE := SUBSTRB('Error in XXDL_CUR_RATES_PKG.VERIFY_GL_DAILY_RATES:'||L_RETURN_MESSAGE, 1, 2000);
             DBMS_OUTPUT.PUT_LINE('X_RETURN_STATUS:'||X_RETURN_STATUS||'X_RETURN_MESSAGE'||X_RETURN_MESSAGE);
         END IF;

     ELSE
       X_RETURN_STATUS := 'Error';
       X_RETURN_MESSAGE := SUBSTRB('Error in XXDL_CUR_RATES_PKG.IMPORT_GL_DAILY_RATES:'||L_RETURN_MESSAGE, 1, 2000);
       DBMS_OUTPUT.PUT_LINE('X_RETURN_STATUS:'||X_RETURN_STATUS||'X_RETURN_MESSAGE'||X_RETURN_MESSAGE);
     END IF;
  ELSE

  X_RETURN_STATUS := 'Error';
   X_RETURN_MESSAGE := SUBSTRB('Error in XXDL_CUR_RATES_PKG.GET_GL_DAILY_RATES:'||L_RETURN_MESSAGE, 1, 2000);
DBMS_OUTPUT.PUT_LINE('X_RETURN_STATUS:'||X_RETURN_STATUS||'X_RETURN_MESSAGE'||X_RETURN_MESSAGE);
  END IF;



EXCEPTION WHEN OTHERS THEN
  x_return_status := 'Error';
  x_return_message := SUBSTRB('Exception in XXDL_CUR_RATES_PKG.IMPORT_DAILY_CURRENCY_RATES, SQLCODE:'||SQLCODE||', SQLERRM:'||SQLERRM, 1, 2000);
  DBMS_OUTPUT.PUT_LINE('X_RETURN_STATUS:'||X_RETURN_STATUS||'X_RETURN_MESSAGE'||X_RETURN_MESSAGE);

END;


/*===========================================================================+
Procedure   : import_daily_currency_rates
Description :
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure IMPORT_DAILY_CURRENCY_RATES(
    x_return_status   out nocopy varchar2,
    x_return_message  out nocopy varchar2) IS

L_RETURN_STATUS VARCHAR2(1);
L_RETURN_MESSAGE VARCHAR2(2000);
L_RETURN_STATUS_b VARCHAR2(1);
L_RETURN_MESSAGE_b VARCHAR2(2000);
BEGIN

  XXDL_CUR_RATES_PKG.GET_GL_DAILY_RATES(L_RETURN_STATUS, L_RETURN_MESSAGE);

  IF(L_RETURN_STATUS = 'S' )
  THEN
  L_RETURN_STATUS := ''; 
  l_return_message := '';
  XXDL_CUR_RATES_PKG.IMPORT_GL_DAILY_RATES(L_RETURN_STATUS, L_RETURN_MESSAGE);
  XXDL_CUR_RATES_PKG.IMPORT_GL_DAILY_RATES_b(L_RETURN_STATUS_b, L_RETURN_MESSAGE_b);
DBMS_LOCK.sleep(60);
     IF(L_RETURN_STATUS = 'S')
     THEN
         L_RETURN_STATUS := ''; 
         l_return_message := '';
         XXDL_CUR_RATES_PKG.VERIFY_GL_DAILY_RATES(L_RETURN_STATUS, L_RETURN_MESSAGE);

         IF(L_RETURN_STATUS = 'S' )
         THEN
            X_RETURN_STATUS := 'Success';
            l_return_message := '';
         ELSE
             X_RETURN_STATUS := 'Error';
             X_RETURN_MESSAGE := SUBSTRB('Error in XXDL_CUR_RATES_PKG.VERIFY_GL_DAILY_RATES:'||L_RETURN_MESSAGE, 1, 2000);
         END IF;

     ELSE
       X_RETURN_STATUS := 'Error';
       X_RETURN_MESSAGE := SUBSTRB('Error in XXDL_CUR_RATES_PKG.IMPORT_GL_DAILY_RATES:'||L_RETURN_MESSAGE, 1, 2000);
     END IF;
  ELSE

  X_RETURN_STATUS := 'Error';
   X_RETURN_MESSAGE := SUBSTRB('Error in XXDL_CUR_RATES_PKG.GET_GL_DAILY_RATES:'||L_RETURN_MESSAGE, 1, 2000);

  END IF;



EXCEPTION WHEN OTHERS THEN
  x_return_status := 'Error';
  x_return_message := SUBSTRB('Exception in XXDL_CUR_RATES_PKG.IMPORT_DAILY_CURRENCY_RATES, SQLCODE:'||SQLCODE||', SQLERRM:'||SQLERRM, 1, 2000);

END;

/*===========================================================================+
Procedure   : get_gl_daily_rates
Description : gets daily currency rates into local table
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure GET_GL_DAILY_RATES(p_status out varchar2, p_msg out varchar2) is

cursor c_main(cp_clob in CLOB) is
SELECT line_number, col001, col002, col003, col004, col005, col006, col007, col008, col009, col010, col011, col012
FROM   TABLE(
         APEX_DATA_PARSER.parse(
           p_content         => xxfn_cloud_ws_pkg.clob_to_blob(cp_clob),
           p_file_name       => 'rates.json',
           p_row_selector    => null,
           p_add_headers_row => 'N'
         )
       );

p_url varchar2(1000) := 'https://api.hnb.hr/tecajn-eur/v3';
l_req   utl_http.req;
l_resp  utl_http.resp;
l_text           varchar2(4000);
L_RETURN_TEXT VARCHAR2(4000);
l_csv varchar2(2000);

l_encoded_csv varchar2(20000);
l_line_number number;
l_col001 varchar2(50);
l_col002 varchar2(50);
l_col003 varchar2(50);
l_col004 varchar2(50);
l_col005 varchar2(50);
l_col006 varchar2(50);
l_col007 varchar2(50);
l_col008 varchar2(50);
l_col009 varchar2(50);
l_col010 varchar2(50);
l_col011 varchar2(50);
l_col012 varchar2(50);
begin

   l_csv := '';
  UTL_HTTP.set_wallet('file:' || 'D:\oracle\admin\XE\wallet', 'welcome123');																			
  utl_http.set_response_error_check(false);
  utl_http.set_detailed_excp_support(false);
  
    l_req  := utl_http.begin_request(p_url);
    l_resp := utl_http.get_response(l_req);

     -- loop through the data coming back
    begin
      loop
       utl_http.read_text(l_resp, l_text, 2000);
       L_RETURN_TEXT := L_RETURN_TEXT || L_TEXT;
       dbms_output.put_line(l_text);
      end loop;
   exception
      when utl_http.end_of_body then
       utl_http.end_response(l_resp);
   end;

--dbms_output.put_line( 'result is:'||l_RETURN_text);

for c_main_rec in c_main(to_clob(l_return_text)) loop
--dbms_output.put_line(' col001 is:'||c_main_rec.col001||' col002 is:'||c_main_rec.col002||' col003 is:'||to_number(c_main_rec.col003)||' col004 is:'||c_main_rec.col004||' col005 is:'||c_main_rec.col005||' col006 is:'||to_number(c_main_rec.col006, '999999990D999999','NLS_NUMERIC_CHARACTERS=''.,''')
--||' col007 is:'||to_number(c_main_rec.col007, '999999990D999999','NLS_NUMERIC_CHARACTERS='',.''')||' col008 is:'||to_number(c_main_rec.col008)||' col009 is:'||c_main_rec.col009||' col010 is:'||to_number(c_main_rec.col010, '999999990D999999','NLS_NUMERIC_CHARACTERS=''.,''')||'row is:'||c_main_rec.col011||'row is:'||c_main_rec.col012);


begin
    insert into XXDL_CURRENCY_RATES
    (exchange_rate_number,
     date_of_application,
     currency_code,
     unit,
     buying_rate,
     middle_rate,
     selling_rate,
     creation_date,
     created_by ,
     last_update_date,
     last_updated_by,
     action,
     status,
     last_api_message,
     conversion_rate_type
     ) values 
     (to_number(c_main_rec.col007) , -- bio 8 sad 07
      c_main_rec.col008,
      c_main_rec.col002,
      1,
      to_number(c_main_rec.col005, '999999990D999999','NLS_NUMERIC_CHARACTERS='',.'''),
      to_number(c_main_rec.col006, '999999990D999999','NLS_NUMERIC_CHARACTERS='',.'''),
      to_number(c_main_rec.col009, '999999990D999999','NLS_NUMERIC_CHARACTERS='',.'''),
      sysdate,
      'XX_INTEGRATION',
      sysdate,
      'XX_INTEGRATION',
      null,
      null,
      null,
      'HNB'
      );
exception
    when dup_val_on_index then
    null;
   /* update XXAP_CURRENCY_RATES
    set */
end;

begin
    insert into XXDL_CURRENCY_RATES
    (exchange_rate_number,
     date_of_application,
     currency_code,
     unit,
     buying_rate,
     middle_rate,
     selling_rate,
     creation_date,
     created_by ,
     last_update_date,
     last_updated_by,
     action,
     status,
     last_api_message,
     conversion_rate_type
     ) values 
     (to_number(c_main_rec.col007) , -- bio 8 sad 07
      c_main_rec.col008,
      c_main_rec.col002,
      1,
      to_number(c_main_rec.col005, '999999990D999999','NLS_NUMERIC_CHARACTERS='',.'''),
      to_number(c_main_rec.col006, '999999990D999999','NLS_NUMERIC_CHARACTERS='',.'''),
      to_number(c_main_rec.col009, '999999990D999999','NLS_NUMERIC_CHARACTERS='',.'''),
      sysdate,
      'XX_INTEGRATION',
      sysdate,
      'XX_INTEGRATION',
      null,
      null,
      null,
      'Corporate'
      );
exception
    when dup_val_on_index then
    null;
   /* update XXAP_CURRENCY_RATES
    set */
end;
end loop;
p_status := 'S';
commit;
exception when others then 
p_status := 'E';
p_msg :=substrb('Exception in XXDL_CUR_RATES_PKG.GET_GL_DAILY_RATES, SQLCODE'||SQLCODE||'; SQLERRM:'||SQLERRM, 1, 2000);
end GET_GL_DAILY_RATES;

/*===========================================================================+
Procedure   : import_gl_daily_rates
Description : imports daily currency rates from local table into fusion
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure IMPORT_GL_DAILY_RATES(p_status out varchar2, p_msg out varchar2) is

cursor c_main is
select 'EUR' from_currency,
        currency_code to_currency,
        to_char(to_date(date_of_application, 'RRRR-MM-DD'), 'RRRR/MM/DD') date_from,
        to_char(to_date(date_of_application, 'RRRR-MM-DD'), 'RRRR/MM/DD') date_to,
        --'HNB' conversion_rate_type,
        conversion_rate_type,
         round((1 * unit)/middle_rate, 8) inverse_rate,--conversion_rate,
        round(middle_rate/( unit), 8) conversion_rate--inverse_rate
        from XXDL_CURRENCY_RATES
where trunc(sysdate ) = to_Date(date_of_application, 'RRRR-MM-DD')
and nvl(status, 'E') != 'S'
order by creation_date desc;

 l_encoded_csv varchar2(4000);
 l_csv varchar2(4000);
 l_return_status varchar2(150);
 l_msg varchar2(2000);
 l_ws_call_id number;
 l_url varchar2(150); 
 l_exists number := 0;
begin

  select value 
  into l_url
  from xx_configuration
  where name = 'ServiceRootURL'; 

 -- l_url:= 'https://fa-ewha-test-saasfaprod1.fa.ocs.oraclecloud.com/';

  for c_main_rec in c_main loop

  l_csv := l_csv || c_main_rec.from_currency||',';
  l_csv := l_csv || c_main_rec.to_currency||',';
  l_csv := l_csv || c_main_rec.date_from||',';
  l_csv := l_csv || c_main_rec.date_to||',';
  l_csv := l_csv || c_main_rec.conversion_rate_type||',';
  l_csv := l_csv || c_main_rec.conversion_rate||',';
  l_csv := l_csv || c_main_rec.inverse_rate||',';
  l_csv := l_csv || chr(13);
  l_exists := 1;
  end loop;

  if(l_exists = 0)
  then
  p_status := 'S';
  p_msg := 'Ne postoje neobradeni zapisi tecajnice u tablici XXDL_CURRENCY_RATES!';
  return; 
  end if;

     l_encoded_csv := utl_raw.cast_to_varchar2(utl_encode.base64_encode(utl_raw.cast_to_raw(l_csv)));

  xxfn_cloud_ws_pkg.send_csv_to_cloud(p_document=>l_encoded_csv,
  p_doc_name=>'CurrencyRates.csv',
  p_doc_type=>'.csv',
  p_author=>'XXDL_INTEGRATION',
  p_app_account=>'fin$/generalLedger$/import$',
  p_job_name=>'/oracle/apps/ess/financials/commonModules/shared/common/interfaceLoader/,InterfaceLoaderController',
  p_job_option=>'InterfaceDetails=71',
 -- p_wsdl_link=> 'https://epfc.fa.em2.oraclecloud.com/fscmService/ErpIntegrationService?WSDL',
  p_wsdl_link=>l_url||'fscmService/ErpIntegrationService?WSDL',
  p_wsdl_method=>'importBulkData',
  x_return_status=>l_return_status,
  x_msg=>l_msg,
  x_ws_call_id=>l_ws_call_id);
  dbms_output.put_line('After call send_csv_to_cloud:'||l_url||'fscmService/ErpIntegrationService?WSDL'||l_return_status||'; return message:'||l_msg);
  /*43382<*/
  /*Load Interface File for Import*/
  /*Import and Calculate Daily Rates*/
  p_status := l_return_Status;
  p_msg := substrb (l_msg, 1, 2000);

  exception when others then
  p_status := 'E';
p_msg :=substrb('Exception in XXDL_CUR_RATES_PKG.IMPORT_GL_DAILY_RATES, SQLCODE'||SQLCODE||'; SQLERRM:'||SQLERRM, 1, 2000);

  end IMPORT_GL_DAILY_RATES;

/*===========================================================================+
Procedure   : import_gl_daily_rates_b
Description : imports daily currency rates from local table into fusion
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure IMPORT_GL_DAILY_RATES_b(p_status out varchar2, p_msg out varchar2) is

cursor c_main is
select 'EUR' from_currency,
        currency_code to_currency,
        to_char(to_date(date_of_application, 'RRRR-MM-DD'), 'RRRR/MM/DD') date_from,
        to_char(to_date(date_of_application, 'RRRR-MM-DD'), 'RRRR/MM/DD') date_to,
        'HNB' conversion_rate_type,
         round((1 * unit)/middle_rate, 8) inverse_rate,--conversion_rate,
        round(middle_rate/( unit), 8) conversion_rate--inverse_rate
        from XXDL_CURRENCY_RATES
where trunc(sysdate ) = to_Date(date_of_application, 'RRRR-MM-DD')
and conversion_rate_type = 'HNB'
--and nvl(status, 'E') != 'S'
order by creation_date desc;

 l_encoded_csv varchar2(2000);
 l_csv varchar2(2000);
 l_return_status varchar2(150);
 l_msg varchar2(2000);
 l_ws_call_id number;
 l_url varchar2(150); 
 l_exists number := 0;
begin

  select value 
  into l_url
  from xx_configuration
  where name = 'ServiceRootURL'; 

 -- l_url:= 'https://fa-ewha-test-saasfaprod1.fa.ocs.oraclecloud.com/';

  for c_main_rec in c_main loop

  l_csv := l_csv || c_main_rec.from_currency||',';
  l_csv := l_csv || c_main_rec.to_currency||',';
  l_csv := l_csv || c_main_rec.date_from||',';
  l_csv := l_csv || c_main_rec.date_to||',';
  l_csv := l_csv || c_main_rec.conversion_rate_type||',';
  l_csv := l_csv || c_main_rec.conversion_rate||',';
  l_csv := l_csv || c_main_rec.inverse_rate||',';
  l_csv := l_csv || chr(13);
  l_exists := 1;
  end loop;

  if(l_exists = 0)
  then
  p_status := 'S';
  p_msg := 'Ne postoje neobradeni zapisi tecajnice u tablici XXDL_CURRENCY_RATES!';
  return; 
  end if;

     l_encoded_csv := utl_raw.cast_to_varchar2(utl_encode.base64_encode(utl_raw.cast_to_raw(l_csv)));

  send_csv_to_cloud_b(p_document=>l_encoded_csv,
  p_doc_name=>'CurrencyRates.csv',
  p_doc_type=>'.csv',
  p_author=>'XX_INTEGRATION',
  p_app_account=>'fin$/generalLedger$/import$',
  p_job_name=>'/oracle/apps/ess/financials/commonModules/shared/common/interfaceLoader/,InterfaceLoaderController',
  p_job_option=>'InterfaceDetails=71',
  p_wsdl_link=> 'https://epfc.fa.em2.oraclecloud.com/fscmService/ErpIntegrationService?WSDL',
  --p_wsdl_link=>l_url||'fscmService/ErpIntegrationService?WSDL',
  p_wsdl_method=>'importBulkData',
  x_return_status=>l_return_status,
  x_msg=>l_msg,
  x_ws_call_id=>l_ws_call_id);
  --dbms_output.put_line('After call send_csv_to_cloud:'||l_url||'fscmService/ErpIntegrationService?WSDL'||l_return_status||'; return message:'||l_msg);
  /*43382<*/
  /*Load Interface File for Import*/
  /*Import and Calculate Daily Rates*/
  p_status := l_return_Status;
  p_msg := substrb (l_msg, 1, 2000);

  exception when others then
  p_status := 'E';
p_msg :=substrb('Exception in XXDL_CUR_RATES_PKG.IMPORT_GL_DAILY_RATES, SQLCODE'||SQLCODE||'; SQLERRM:'||SQLERRM, 1, 2000);

  end IMPORT_GL_DAILY_RATES_b;
  
  
  /*===========================================================================+
  Function   : send_csv_to_cloud
  Description : 
  Usage       :
  Arguments   :
  Returns     :
============================================================================+*/
procedure send_csv_to_cloud_b(p_document      in varchar2,
                              p_doc_name      in varchar2,
                              p_doc_type      in varchar2,
                              p_author        in varchar2,
                              p_app_account   in varchar2,
                              p_job_name      in varchar2,
                              p_job_option    in varchar2,
                              p_wsdl_link     in varchar2,
                              p_wsdl_method   in varchar2,
                              x_return_status out varchar2,
                              x_msg           out varchar2,
                              x_ws_call_id out number) is

    l_body               varchar2(30000);
    l_result             varchar2(500);
    l_result_clob        clob;
    l_return_status      varchar2(500);
    l_return_message     varchar2(32000);
    l_soap_env           clob;
    l_text               varchar2(32000);
    l_inflated_resp      blob;
    l_result_nr          varchar2(32000);
    l_resp_xml           xmltype;
    l_resp_xml_id        xmltype;
    l_result_nr_id       varchar2(500);
    l_result_varchar     varchar2(32000);
    l_result_clob_decode clob;

  begin



l_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/" xmlns:erp="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/">
           <soapenv:Header/>
           <soapenv:Body>
              <typ:' || p_wsdl_method || '>
                 <typ:document>
                    <erp:Content>' || p_document || '</erp:Content>
                    <erp:FileName>' || p_doc_name || '</erp:FileName>
                    <erp:ContentType>' || p_doc_type || '</erp:ContentType>
                    <erp:DocumentAuthor>' || p_author || '</erp:DocumentAuthor>
                    <erp:DocumentSecurityGroup>FAFusionImportExport</erp:DocumentSecurityGroup>
                    <erp:DocumentAccount>' || p_app_account || '</erp:DocumentAccount>
                 </typ:document>
                 <typ:jobDetails>
                    <erp:JobName>' || p_job_name || '</erp:JobName>
                    <erp:ParameterList>#NULL</erp:ParameterList>
                 </typ:jobDetails>
                 <typ:notificationCode>#NULL</typ:notificationCode>
                 <typ:callbackURL>#NULL</typ:callbackURL>
                 <typ:jobOptions>' || p_job_option || '</typ:jobOptions>
              </typ:' || p_wsdl_method || '>
           </soapenv:Body>
      </soapenv:Envelope>';

    l_soap_env := to_clob(l_text);

    ws_call_b(p_ws_url         => p_wsdl_link,
                                          p_soap_env       => l_soap_env,
                                          p_soap_act       => p_wsdl_method,
                                          p_content_type   => 'text/xml;charset="UTF-8"',
                                          x_return_status  => l_return_status,
                                          x_return_message => l_return_message,
                                          x_ws_call_id     => x_ws_call_id);

    dbms_lob.freetemporary(l_soap_env);


    x_return_status := l_return_status;
    x_msg           := l_return_message;

  exception
    when others then
null;
  end send_csv_to_cloud_b;




/*===========================================================================+
Procedure   : verify_gl_daily_rates
Description : imports daily currency rates from local table into fusion
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure VERIFY_GL_DAILY_RATES(p_status out varchar2, p_msg out varchar2)
is

l_body VARCHAR2(30000);
l_result varchar2(500);
l_result_clob  clob;
x_return_status varchar2(500);
x_return_message varchar2(32000);
l_soap_env clob;
l_text varchar2(32000);
x_ws_call_id number;
l_inflated_resp blob;
l_result_nr varchar2(32000);
l_resp_xml       XMLType;
l_resp_xml_id   XMLType;
l_result_nr_id  varchar2(500);
l_result_varchar  varchar2(32000);
l_result_clob_decode clob;

l_ws_call_id    number;

l_domain varchar2(150);
l_count number := 0;
l_url varchar2(75);

l_return_status varchar2(10);
l_return_message varchar2(2000);
p_supplier_name varchar2(20);
p_source_system varchar2(2000);
p_source_site_id varchar2(50);
p_supplier_site varchar2(20);
p_ws_call_id number;
BEGIN

execute immediate 'alter session set NLS_TIMESTAMP_TZ_FORMAT= ''YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM''';
--execute immediate 'alter session set nls_date_format=''yyyy-mm-dd hh24:mi:ss''';
--execute immediate 'alter session set NLS_TIMESTAMP_FORMAT= ''YYYY-MM-DD"T"HH24:MI:SS.FF3''';

select value 
into l_url
from xx_configuration
where name = 'ServiceRootURL'; 
 --l_url:= 'https://fa-ewha-test-saasfaprod1.fa.ocs.oraclecloud.com/';

l_text :='<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
   <soap:Header/>
   <soap:Body>
      <pub:runReport>
         <pub:reportRequest>
            <pub:attributeFormat>xml</pub:attributeFormat>
            <pub:attributeLocale></pub:attributeLocale>
            <pub:attributeTemplate></pub:attributeTemplate>
            <pub:reportAbsolutePath>Custom/XXDL_Integration/XX_GET_CURRENCY_RATES_REP.xdo</pub:reportAbsolutePath>
            <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
         </pub:reportRequest>
         <pub:appParams></pub:appParams>
      </pub:runReport>
   </soap:Body>
</soap:Envelope>';

--log('Payload:'||l_text);

 /* If (fnd_profile.value('APPS_DATABASE_ID')='prod') then
                  L_domain:= fnd_profile.value('XXFN_CS_PROD_DOMAIN_PRF');
  Else
                  L_domain:= fnd_profile.value('XXFN_CS_TEST_DOMAIN_PRF');
  end if; */

 --  l_domain := xxpo_cs_download_pkg.get_wsdl_domain;
  --l_domain := 'https://epfc-test.fa.em2.oraclecloud.com';
  l_soap_env := to_clob(l_text);

  l_count := 0;
    XXFN_CLOUD_WS_PKG.WS_CALL(
        p_ws_url => l_url||'/xmlpserver/services/ExternalReportWSSService?WSDL',
        p_soap_env => l_soap_env,
        p_soap_act => 'runReport',
        p_content_type => 'application/soap+xml;charset="UTF-8"',
        x_return_status => l_return_status,
        x_return_message => l_return_message,
        x_ws_call_id => l_ws_call_id);

  p_ws_call_id := l_ws_call_id;
  dbms_lob.freetemporary(l_soap_env);

  p_status := l_return_status;
  p_msg := substrb(l_return_message, 1,2000);

  if(l_return_status = 'S') then
      begin
      select response_xml
      into l_resp_xml
      from xxfn_ws_call_log_v
      where ws_call_id = l_ws_call_id;
      exception
        when no_data_found then
        p_Status := 'E';
        p_msg := substrb('Error in XXDL_CUR_RATES_PKG.VERIFY_GL_DAILY_RATES, there is no data in xxfn_ws_call_log_v, ws_Call_id:'||l_ws_call_id  , 1, 2000);
        return;
      end;

      begin
      SELECT xml.vals
      INTO l_result_clob
      FROM xxfn_ws_call_log_v a,
        XMLTable(xmlnamespaces('http://xmlns.oracle.com/oxp/service/PublicReportService' AS "ns2",'http://www.w3.org/2003/05/soap-envelope' AS "env"), '/env:Envelope/env:Body/ns2:runReportResponse/ns2:runReportReturn' PASSING a.response_xml COLUMNS vals CLOB PATH './ns2:reportBytes') xml
      WHERE a.ws_call_id = l_ws_call_id
      AND xml.vals      IS NOT NULL;
      exception
        when no_data_found then
        p_Status := 'E';
        p_msg := substrb('Error in XXDL_CUR_RATES_PKG.VERIFY_GL_DAILY_RATES, cannot get xml.vals from xxfn_ws_call_log_v, ws_Call_id:'||l_ws_call_id  , 1, 2000);
        return;
      end;


      l_result_clob_decode := xxfn_cloud_ws_pkg.DecodeBASE64(l_result_clob);
      l_resp_xml_id := XMLType.createXML(l_result_clob_decode);
      --log('Parsing report response for suppliers');
      FOR cur_rec IN (
      SELECT xt.*
      FROM   XMLTABLE('/DATA_DS/RATES'
               PASSING l_resp_xml_id
               COLUMNS
                   FROM_CURRENCY varchar2(3) PATH 'FROM_CURRENCY',
                   TO_CURRENCY varchar2(3) PATH 'TO_CURRENCY',
                   CONVERSION_DATE VARCHAR2(10) PATH 'CONVERSION_DATE',
                   CONVERSION_TYPE varchar2(50) PATH 'CONVERSION_TYPE',
                   CONVERSION_RATE varchar2(50) PATH 'CONVERSION_RATE'
               ) xt)
      LOOP

      -- p_supplier_name := cur_rec.vendor_name;
     --  p_supplier_site := cur_rec.vendor_site_code;
     --  p_liability_distribution := cur_rec.LIABILITY_DISTRIBUTION; 
     --  p_suppl_return_Status := 'S';
     --  l_count := l_count +1;

        begin
         update xxdl_currency_rates
         set status = 'S'
         where 1=1
         and  currency_code = cur_rec.to_currency
         and date_of_application = cur_rec.conversion_date
         and conversion_rate_type = cur_rec.conversion_type;
         exception when others then null;
         end;
      end loop;
commit;
else
       p_Status := 'E';
       p_msg := substrb('Error in XXDL_CUR_RATES_PKG.VERIFY_GL_DAILY_RATES, Call to report XX_GET_CURRENCY_RATES_REP did not end with S', 1, 2000);
       return;
end if;


exception
  when others then

       p_Status := 'E';
       p_msg := substrb('Exception in XXDL_CUR_RATES_PKG.VERIFY_GL_DAILY_RATES; SQLCODE:'||SQLCODE||'; SQLERRM:'|| SQLERRM, 1, 2000);

end;

/*===========================================================================+
Procedure   : WS_CALL
Description :
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure WS_CALL_b(
    p_ws_url          varchar2,
    p_soap_env        clob,
    p_soap_act        varchar2,
    p_content_type    varchar2,
    x_return_status   out nocopy varchar2,
    x_return_message  out nocopy varchar2,
    x_ws_call_id      out nocopy number) is
  amount         integer;
  chunk_size     constant pls_integer := 300;
  buff           varchar2(4000);
  written        pls_integer := 0;
  remaining      pls_integer;
  l_username     varchar2(60);
  l_pass         varchar2(60);
begin

  x_ws_call_id := null;

  if p_soap_env is null then
    return;
  end if;

  amount := dbms_lob.getlength(p_soap_env);
  if amount is null then
    return;
  end if;

  /*get username and pass*/
/*  begin
    select fpov.profile_option_value
      into l_username
    from APPS.FND_PROFILE_OPTION_VALUES fpov,
         APPS.FND_PROFILE_OPTIONS fpo
    where fpov.profile_option_id = fpo.profile_option_id
    and fpo.profile_option_name = 'XXFN_CLOUD_INTEGRATION_USER_PRF'
    and rownum = 1;
  exception when OTHERS then
      l_username := null;
  end;
  begin
    select fpov.profile_option_value
      into l_pass
    from APPS.FND_PROFILE_OPTION_VALUES fpov,
         APPS.FND_PROFILE_OPTIONS fpo
    where fpov.profile_option_id = fpo.profile_option_id
    and fpo.profile_option_name = 'XXFN_CLOUD_INTEGRATION_PASS_PRF'
    and rownum = 1;
  exception when OTHERS then
      l_pass := null;
  end;  */


    select value 
  into l_username
  from xx_configuration
  where name = 'ServiceUsername'; 
  
  select value 
  into l_pass
  from xx_configuration
  where name = 'ServicePassword'; 
  
    l_username := 'XX_INTEGRATION';
l_pass := 'kr@mB@mbul!123';


 /* if l_username is null or l_pass is null then
    apps.fnd_file.put_line(apps.fnd_file.log, '**********.');
    apps.fnd_file.put_line(apps.fnd_file.log, 'Profile options for Cloud integrations are not set.');
    apps.fnd_file.put_line(apps.fnd_file.log, 'Please check value of XXFN_CLOUD_INTEGRATION_USER_PRF and XXFN_CLOUD_INTEGRATION_PASS_PRF.');
    apps.fnd_file.put_line(apps.fnd_file.log, '**********.');
  end if; */

  if amount != 0 and p_soap_env is not null then
    while written + chunk_size < amount loop
      remaining := chunk_size;
      -- read blob
      dbms_lob.read(
        lob_loc => p_soap_env,
        amount  => remaining,
        offset  => written+1,
        buffer  => buff);
      written := written + chunk_size;
      XXFN_WS_PKG.BUILD_SOAP_ENVELOPE(buff);
      XXFN_WS_PKG.BUILD_SOAP_ENVELOPEB(utl_raw.cast_to_raw(buff));
    end loop;

    -- put remaining
    remaining := amount - written;
    if remaining != 0 then
      dbms_lob.read(
        lob_loc => p_soap_env,
        amount  => remaining,
        offset  => written+1,
        buffer  => buff);
      XXFN_WS_PKG.BUILD_SOAP_ENVELOPE(buff);
      XXFN_WS_PKG.BUILD_SOAP_ENVELOPEB(utl_raw.cast_to_raw(buff));
    end if;
  end if;

  XXFN_WS_PKG.WS_CALL(
      p_ws_url          => p_ws_url,
      p_soap_act        => p_soap_act,
      p_content_type    => p_content_type,
      p_cloud_user      => l_username,
      p_cloud_pass      => l_pass);

  x_return_status := XXFN_WS_PKG.GET_RETURN_STATUS;
  x_return_message := XXFN_WS_PKG.GET_RETURN_MESSAGE;
  x_ws_call_id := XXFN_WS_PKG.GET_WS_CALL_ID;
exception when OTHERS then
      x_return_status := 'E';
      x_return_message := SQLERRM;
end;

end XXDL_CUR_RATES_PKG;