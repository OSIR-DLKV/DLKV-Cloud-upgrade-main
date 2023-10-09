create or replace PACKAGE  BODY    XXDL_OA_PLACE_PKG AS
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
l_PROJECT_date date;
l_TASK_date date;
begin



select  max(DATUM_ZADNJEG_AZURIRANJA) 
into l_PROJECT_date
from XXDL_OA_PROJEKTI;

select  max(DATUM_ZADNJE_IZMJENE) 
into l_TASK_date
from XXDL_OA_PROJEKTNI_ZADACI;

if(l_PROJECT_date is null)
then
l_PROJECT_date := to_date( '1900-01-01 08:00', 'YYYY-MM-DD HH24:MI');
end if;

l_PROJECT_date := l_PROJECT_date - 2/24;

if(l_TASK_date is null)
then
l_TASK_date := to_date( '1900-01-01 08:00', 'YYYY-MM-DD HH24:MI');
end if;

l_TASK_date := l_TASK_date - 2/24;


XXDL_OA_PLACE_PKG.get_DATA(to_char(l_PROJECT_date   , 'YYYY-MM-DD HH24:MI'), to_char(l_TASK_date   , 'YYYY-MM-DD HH24:MI'));

end PROCESS_RECORDS_SCHED;

/*===========================================================================+
Procedure   : get_data
Description :
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
PROCEDURE GET_DATA(P_PROJECT_DATE IN VARCHAR2, P_TASK_DATE IN VARCHAR2)
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
                  <pub:name>P_PROJECT_DATE</pub:name>
                  <pub:values>
                     <!--Zero or more repetitions:-->
                     <pub:item>'||P_PROJECT_DATE||'</pub:item>
                  </pub:values>
               </pub:item>
               <pub:item>
                  <pub:name>P_TASK_DATE</pub:name>
                  <pub:values>
                     <!--Zero or more repetitions:-->
                     <pub:item>'||P_TASK_DATE||'</pub:item>
                  </pub:values>
               </pub:item>
            </pub:parameterNameValues>
            <pub:reportAbsolutePath>Custom/XXDL_Integration/PLACE/XXDL_OA_PROJEKTI_REP.xdo</pub:reportAbsolutePath>
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
      FROM   XMLTABLE('/DATA_DS/OA_PROJEKTI'
               PASSING l_resp_xml_id
               COLUMNS
               ID NUMBER PATH 'ID', 
                BROJ varchar2(100) PATH 'BROJ',
                NAZIV varchar2(960) PATH 'NAZIV',
                BUSINESS_UNIT number PATH 'BUSINESS_UNIT',
                DATUM_POCETKA VARCHAR2(35) PATH 'DATUM_POCETKA',
                DATUM_ZAVRSETKA VARCHAR2(35) PATH 'DATUM_ZAVRSETKA',
                DATUM_ZATVARANJA VARCHAR2(35) PATH 'DATUM_ZATVARANJA',
                KREATOR varchar2(256) PATH 'KREATOR',
                DATUM_KREIRANJA VARCHAR2(35) PATH 'DATUM_KREIRANJA',
                ZADNJE_AZURIRAO varchar2(256) PATH 'ZADNJE_AZURIRAO',
                DATUM_ZADNJEG_AZURIRANJA VARCHAR2(35) PATH 'DATUM_ZADNJEG_AZURIRANJA'
               ) xt)
      LOOP

            begin

            insert into
            XXDL_OA_PROJEKTI
            (ID, 
            BROJ,
            NAZIV,
            BUSINESS_UNIT,
            DATUM_POCETKA,
            DATUM_ZAVRSETKA,
            DATUM_ZATVARANJA,
            KREATOR,
            DATUM_KREIRANJA,
            ZADNJE_AZURIRAO,
            DATUM_ZADNJEG_AZURIRANJA
            )
           -- status,
           -- MESSAGE)
            values 
            (CUR_REC.ID, 
            CUR_REC.BROJ,
            CUR_REC.NAZIV,
            CUR_REC.BUSINESS_UNIT,
            cast(to_timestamp_tz( CUR_REC.DATUM_POCETKA,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as date),
            cast(to_timestamp_tz( CUR_REC.DATUM_ZAVRSETKA,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as date),
            cast(to_timestamp_tz(CUR_REC.DATUM_ZATVARANJA,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as date),
            CUR_REC.KREATOR,
            cast(to_timestamp_tz( CUR_REC.DATUM_KREIRANJA,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone),
            CUR_REC.ZADNJE_AZURIRAO,
            cast(to_timestamp_tz( CUR_REC.DATUM_ZADNJEG_AZURIRANJA,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
            --NULL
            --NULL
            );

             exception when dup_val_on_index then
             
             
             update XXDL_OA_PROJEKTI
             set 
             BROJ = CUR_REC.BROJ,
            NAZIV = CUR_REC.NAZIV,
            BUSINESS_UNIT = CUR_REC.BUSINESS_UNIT,
            DATUM_POCETKA =  cast(to_timestamp_tz( CUR_REC.DATUM_POCETKA,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as date),
            DATUM_ZAVRSETKA =  cast(to_timestamp_tz( CUR_REC.DATUM_ZAVRSETKA,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as date),
            DATUM_ZATVARANJA =  cast(to_timestamp_tz(CUR_REC.DATUM_ZATVARANJA,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as date),
            KREATOR = CUR_REC.KREATOR,
            DATUM_KREIRANJA = cast(to_timestamp_tz( CUR_REC.DATUM_KREIRANJA,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone),
            ZADNJE_AZURIRAO = CUR_REC.ZADNJE_AZURIRAO,
            DATUM_ZADNJEG_AZURIRANJA = cast(to_timestamp_tz( CUR_REC.DATUM_ZADNJEG_AZURIRANJA,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)

             where ID =  cur_rec.ID;
            
             end;

         commit;
      end loop;
      
      FOR cur_rec IN (
      SELECT xt.*
      FROM   XMLTABLE('/DATA_DS/OA_PROJEKTNI_ZADACI'
               PASSING l_resp_xml_id
               COLUMNS
               
               TASK_ID number PATH 'TASK_ID', 
                PROJ_ID number PATH 'PROJ_ID',
                TASK_NUMBER varchar2(400) PATH 'TASK_NUMBER' ,
                TASK_NAME varchar2(960) PATH 'TASK_NAME',
                POCETAK VARCHAR2(35) PATH 'POCETAK', 
                ZAVRSETAK VARCHAR2(35) PATH 'ZAVRSETAK', 
                KREIRAO varchar2(256) PATH 'KREIRAO',
                DATUM_KREIRANJA VARCHAR2(35) PATH 'DATUM_KREIRANJA',
                ZADNJE_IZMJENIO varchar2(256) PATH 'ZADNJE_IZMJENIO',
                DATUM_ZADNJE_IZMJENE VARCHAR2(35) PATH 'DATUM_ZADNJE_IZMJENE'

               ) xt)
      LOOP

            begin

            insert into
            XXDL_OA_PROJEKTNI_ZADACI
            (TASK_ID,
                PROJ_ID,
                TASK_NUMBER,
                TASK_NAME,
                POCETAK,
                ZAVRSETAK, 
                KREIRAO,
                DATUM_KREIRANJA,
                ZADNJE_IZMJENIO,
                DATUM_ZADNJE_IZMJENE)
            values 
            (CUR_REC.TASK_ID,
                CUR_REC.PROJ_ID,
                CUR_REC.TASK_NUMBER,
                CUR_REC.TASK_NAME,
                cast(to_timestamp_tz( CUR_REC.POCETAK,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as date),
                cast(to_timestamp_tz( CUR_REC.ZAVRSETAK,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as date),
                CUR_REC.KREIRAO,
               cast(to_timestamp_tz(  CUR_REC.DATUM_KREIRANJA,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone),
                CUR_REC.ZADNJE_IZMJENIO,
            cast(to_timestamp_tz(  CUR_REC.DATUM_ZADNJE_IZMJENE,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
             );

             exception when dup_val_on_index then
              
             
             update XXDL_OA_PROJEKTNI_ZADACI
             set 
                TASK_NUMBER = CUR_REC.TASK_NUMBER,
                TASK_NAME = CUR_REC.TASK_NAME,
                POCETAK = cast(to_timestamp_tz( CUR_REC.POCETAK,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as date),
                ZAVRSETAK = cast(to_timestamp_tz( CUR_REC.ZAVRSETAK,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as date),
                KREIRAO = CUR_REC.KREIRAO,
                DATUM_KREIRANJA = cast(to_timestamp_tz(CUR_REC.DATUM_KREIRANJA,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone),
                ZADNJE_IZMJENIO = CUR_REC.ZADNJE_IZMJENIO,
                DATUM_ZADNJE_IZMJENE =  cast(to_timestamp_tz(  CUR_REC.DATUM_ZADNJE_IZMJENE,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
             where TASK_ID = CUR_REC.TASK_ID
                AND PROJ_ID = CUR_REC.PROJ_ID;
             
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


end XXDL_OA_PLACE_PKG;