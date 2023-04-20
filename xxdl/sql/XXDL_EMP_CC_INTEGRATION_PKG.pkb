create or replace PACKAGE  BODY    XXDL_EMP_CC_INTEGRATION_PKG AS
/* $Header $
============================================================================+
File Name   : XXDL_EMP_CC_INTEGRATION_PKG.pks
Object      : XXDL_EMP_CC_INTEGRATION_PKG
Description : Package for employee and cc integration
History     :
v1.0 09.05.2022 - 
============================================================================+*/


/*===========================================================================+
Procedure   : PROCESS_RECORDS_SCHED
Description : Scheduled process
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure PROCESS_RECORDS_SCHED is

l_result  varchar2(25);
p_status varchar2(2000) ;
p_message varchar2(2000);
l_max_date date;
begin



select  max(creation_date) 
into l_max_date
from XXDL_EMP_CC_INTEGRATION;

if(l_max_date is null)
then
l_max_date := to_date( '2023-01-09 08:00', 'YYYY-MM-DD HH24:MI');
end if;

l_max_date := l_max_date - 2/24;


XXDL_EMP_CC_INTEGRATION_PKG.get_DATA(to_char(l_max_date   , 'YYYY-MM-DD HH24:MI'));
XXDL_EMP_CC_INTEGRATION_PKG.PROCESS_RECORDS;

end PROCESS_RECORDS_SCHED;

/*===========================================================================+
Procedure   : get_data
Description :
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
PROCEDURE GET_DATA(P_CREATION_DATE IN VARCHAR2)
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
--p_ws_call_id number;
L_STATUS VARCHAR2(15);
L_MESSAGE VARCHAR2(2000);
BEGIN
dbms_output.disable;
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
            <pub:parameterNameValues>
               <!--Zero or more repetitions:-->
               <pub:item>
                  <pub:name>P_CREATION_DATE</pub:name>
                  <pub:values>
                     <!--Zero or more repetitions:-->
                     <pub:item>'||P_CREATION_DATE||'</pub:item>
                  </pub:values>
               </pub:item>
            </pub:parameterNameValues>
            <pub:reportAbsolutePath>Custom/XXDL_Integration/XXDL_EMP_CC_REP.xdo</pub:reportAbsolutePath>
            <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
         </pub:reportRequest>
         <pub:appParams></pub:appParams>
      </pub:runReport>
   </soap:Body>
</soap:Envelope>';


  l_soap_env := to_clob(l_text);

    XXFN_CLOUD_WS_PKG.WS_CALL(
        p_ws_url => l_url||'/xmlpserver/services/ExternalReportWSSService?WSDL',
        p_soap_env => l_soap_env,
        p_soap_act => 'runReport',
        p_content_type => 'application/soap+xml;charset="UTF-8"',
        x_return_status => l_return_status,
        x_return_message => l_return_message,
        x_ws_call_id => l_ws_call_id);

  --p_ws_call_id := l_ws_call_id;
  dbms_lob.freetemporary(l_soap_env);

--dbms_output.put_line('ws_call_id'||l_ws_call_id);
  if(l_return_status = 'S') then

      SELECT xml.vals
      INTO l_result_clob
      FROM xxfn_ws_call_log_v a,
        XMLTable(xmlnamespaces('http://xmlns.oracle.com/oxp/service/PublicReportService' AS "ns2",'http://www.w3.org/2003/05/soap-envelope' AS "env"), '/env:Envelope/env:Body/ns2:runReportResponse/ns2:runReportReturn' PASSING a.response_xml COLUMNS vals CLOB PATH './ns2:reportBytes') xml
      WHERE a.ws_call_id = l_ws_call_id
      AND xml.vals      IS NOT NULL;



      l_result_clob_decode := xxfn_cloud_ws_pkg.DecodeBASE64(l_result_clob);
      l_resp_xml_id := XMLType.createXML(l_result_clob_decode);


      FOR cur_rec IN (
      SELECT xt.*
      FROM   XMLTABLE('/DATA_DS/NALOZI'
               PASSING l_resp_xml_id
               COLUMNS
                   PERSON_ID NUMBER PATH 'PERSON_ID',
                   COMPANY VARCHAR2(50) PATH 'COMPANY',
                   PERSON_NUMBER NUMBER PATH 'PERSON_NUMBER',
                   PERSON_NAME VARCHAR2(960) PATH 'PERSON_NAME',
                   CREATION_DATE VARCHAR2(35) PATH 'CREATION_DATE'

               ) xt)
      LOOP

            begin

            insert into
            XXDL_EMP_CC_INTEGRATION
            (ID,
              COMPANY,
             EMPLOYEE_NUMBER,
             EMPLOYEE_DESCRIPTION,
             CREATION_DATE,
            status,
            MESSAGE)
            values 
            (CUR_REC.PERSON_ID,
            cur_rec.COMPANY,
            CUR_REC.PERSON_NUMBER,
            CUR_REC.PERSON_NAME,
            cast(to_timestamp_tz( cur_rec.CREATION_DATE,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone),

            null,
            null);

             exception when dup_val_on_index then
              NULL;
            /* 
             update xxdl_joppd_payments_int
             set 
             LEGAL_ENTITY_NAME = cur_rec.LEGAL_ENTITY_NAME,
             LEGAL_ENTITY_IDENTIFIER = cur_rec.LEGAL_ENTITY_IDENTIFIER,
            OIB = cur_rec.oib,
            NAME = cur_rec.name,
            SURNAME = cur_rec.surname,
            PERIOD_FROM = cur_rec.period_from,
            PERIOD_TO = cur_rec.period_to,
            PAYMENT_DATE = cur_rec.PAYMENT_DATE,
            PAYMENT_AMOUNT = cur_rec.payment_amount,
             PERSON_NUMBER = cur_rec.PERSON_NUMBER

             where legal_entity_id = cur_rec.legal_entity_id
             and invoice_id = cur_rec.invoice_id
             and period_name = cur_rec.period_name;
             */
             end;

         commit;
      end loop;


else
     --  p_Status := 'E';
      -- p_msg := substrb('Error in XXDL_EMP_CC_INTEGRATION_PKG.GET_DATA, Call to report XXDL_EMP_CC_REP did not end with S', 1, 2000);
      -- return;
      NULL;
end if;


--exception
  --when others then

       --p_Status := 'E';
      -- p_msg := substrb('Exception in XXDL_EMP_CC_INTEGRATION_PKG.GET_DATA; SQLCODE:'||SQLCODE||'; SQLERRM:'|| SQLERRM, 1, 2000);

end GET_DATA;


/*===========================================================================+
Procedure   : PROCESS_RECORDS
Description : 
Usage       :
Arguments   : 
Remarks     :
============================================================================+*/
procedure PROCESS_RECORDS IS

cursor c_main is
select id,
        company,
        employee_number,
        employee_description
from xxdl_emp_cc_integration
where nvl(status, 'E') != 'S';

x_return_status varchar2(500);
x_return_message varchar2(32000);

l_rest_env clob;
l_response_clob clob;
l_text varchar2(32000);
x_ws_call_id number;

l_url varchar2(75);
l_value_set_name varchar2(50);
l_value_id number;

BEGIN
dbms_output.disable;

select value 
into l_url
from xx_configuration
where name = 'ServiceRootURL'; 

--l_url:= 'https://fa-ewha-test-saasfaprod1.fa.ocs.oraclecloud.com/';


for c_main_rec in c_main loop

if upper(c_main_rec.company) = 'DALEKOVOD' then l_value_set_name := 'Podkonto%20DALEKOVOD';
elsif upper(c_main_rec.company) = 'DALEKOVOD ADRIA' then l_value_set_name := 'Podkonto%20DALEKOVOD%20ADRIA';
elsif upper(c_main_rec.company) = 'DALEKOVOD EMU' then l_value_set_name := 'Podkonto%20DALEKOVOD%20EMU';
elsif upper(c_main_rec.company) = 'DALEKOVOD NORGE' then l_value_set_name := 'Podkonto%20DALEKOVOD%20PODRUZNICE';
elsif upper(c_main_rec.company) = 'DALEKOVOD NUF' then l_value_set_name := 'Podkonto%20DALEKOVOD%20PODRUZNICE';
elsif upper(c_main_rec.company) = 'DALEKOVOD PROJEKT' then l_value_set_name := 'Podkonto%20DALEKOVOD%20PROJEKT';
elsif upper(c_main_rec.company) = 'EL-RA' then l_value_set_name := 'Podkonto%20EL-RA';
elsif upper(c_main_rec.company) = 'PROIZVODNJA MK' then l_value_set_name := 'Podkonto%20PROIZVODNJA%20MK';
elsif upper(c_main_rec.company) = 'PROIZVODNJA OSO' then l_value_set_name := 'Podkonto%20PROIZVODNJA%20OSO';


--elsif upper(c_main_rec.company) = 'DALEKOVOD EUR' then l_value_set_name := 'Radni%20nalog%20DALEKOVOD%20EUR';
elsif upper(c_main_rec.company) = 'EUR TEST' then l_value_set_name := 'Podkonto%20EUR%20TEST';
elsif upper(c_main_rec.company) = 'PODRUŽNICE' then l_value_set_name := 'Podkonto%20DALEKOVOD%20PODRUZNICE';


end if;

l_text := '	{
    "IndependentValue": null,
    "IndependentValueNumber": null,
    "IndependentValueDate": null,
    "IndependentValueTimestamp": null,
    "Value": "1'||c_main_rec.employee_number||'",
    "ValueNumber": null,
    "ValueDate": null,
    "ValueTimestamp": null,
    "TranslatedValue": null,
    "Description": "'||c_main_rec.employee_description||'",
    "EnabledFlag": "Y",
    "StartDateActive": null,
    "EndDateActive": null,
    "SortOrder": null,
    "SummaryFlag": "N",
    "DetailPostingAllowed": "Y",
    "DetailBudgetingAllowed": "Y",
    "AccountType": "A",
    "ControlAccount": "N",
    "ReconciliationFlag": "N",
    "FinancialCategory": null,
    "ExternalDataSource": null
	}';



    l_rest_env := '';
   -- dbms_output.put_line (l_text);
    l_rest_env := to_clob(l_text);
    l_text := '';


    XXFN_CLOUD_WS_PKG.WS_REST_CALL(
          p_ws_url => l_url||'fscmRestApi/resources/11.13.18.05/valueSets/'||l_value_set_name||'/child/values',
          p_rest_env => l_rest_env,
          p_rest_act => 'POST',
          p_content_type => 'application/json;charset="UTF-8"',
       --  p_content_type => 'application/vnd.oracle.adf.action+json;charset="UTF-8"',
          x_return_status => x_return_status,
          x_return_message => x_return_message,
          x_ws_call_id => x_ws_call_id);

    dbms_lob.freetemporary(l_rest_env);
   -- dbms_output.put_line('ws_call_id:'|| x_ws_call_id);
   -- dbms_output.put_line('Return status: '||x_return_status);
   -- dbms_output.put_line('Return message:'||x_return_message);-- null ako je uspjelo

    /*{
      "result" : "The current action Validate Invoice has completed successfully."
    }*/


    if(x_return_status = 'S')
    then
    select response_clob
    into l_response_clob
    from xxfn_ws_call_log
    where ws_call_id = x_ws_call_id;

    APEX_JSON.parse(l_response_clob);
    l_value_id := apex_json.get_varchar2(p_path=> 'ValueId');
   -- dbms_output.put_line('new value_id:'||l_value_id);

      UPDATE XXDL_EMP_CC_INTEGRATION
      SET 
      last_WS_CALL_ID = x_WS_CALL_ID,
      status = x_return_status,
      message = 'Success', -- ako je uspjelo x_return_message is null 
      fusion_value_Set_id = l_value_id,
      LAST_UPDATE_DATE = SYSDATE
      WHERE ID = C_MAIN_REC.ID;

      --  if (x_return_message = 'The current action Apply Prepayments has completed successfully.')
      --  then
     --   x_return_Status := 'S';
     --   else
      --  x_return_status := 'E';
      --  end if;
    else
       begin

      select response_clob
      into l_response_clob
      from xxfn_ws_call_log
      where ws_call_id = x_ws_call_id;

       x_return_message := substrb(to_char(l_response_clob), 1, 2000);

      UPDATE XXDL_EMP_CC_INTEGRATION
      SET 
      last_WS_CALL_ID = X_WS_CALL_ID,
      status = x_return_status,
      message = x_return_message, 
      fusion_value_Set_id = l_value_id,
      LAST_UPDATE_DATE = SYSDATE
      WHERE ID = C_MAIN_REC.ID;

       exception when others then 
         x_return_status := 'E';
         x_return_message := substrb('Exception in XXDL_EMP_CC_INTEGRATION_PKG.PROCESS_RECORDS, sqlcode:'||SQLCODE||', sqlerrm:'||SQLERRM, 1, 2000);

         UPDATE XXDL_EMP_CC_INTEGRATION
          SET 
          last_WS_CALL_ID = X_WS_CALL_ID,
          status = x_return_status,
          message = x_return_message, 
          fusion_value_Set_id = l_value_id,
          LAST_UPDATE_DATE = SYSDATE
          WHERE ID = C_MAIN_REC.ID;
       end;
    end if;
    commit;

end loop;-- end main loop



END PROCESS_RECORDS;



end XXDL_EMP_CC_INTEGRATION_PKG;