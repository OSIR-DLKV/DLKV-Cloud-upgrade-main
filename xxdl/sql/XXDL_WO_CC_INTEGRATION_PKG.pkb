create or replace PACKAGE  BODY    XXDL_WO_CC_INTEGRATION_PKG AS
/* $Header $
============================================================================+
File Name   : XXDL_WO_CC_INTEGRATION_PKG.pks
Object      : XXDL_WO_CC_INTEGRATION_PKG
Description : Package for wo and cc integration
History     :
v1.0 09.05.2022 - 
============================================================================+*/


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
        work_order_number,
        work_order_description
from xxdl_wo_cc_integration
where nvl(status, 'E') != 'S'
and nvl(message, 'XXX') not like 'The value%already exists. Enter a unique value. (FND-2894)';

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

/*
if upper(c_main_rec.company) = 'DALEKOVOD' then l_value_set_name := 'Radni%20nalog%20DALEKOVOD';
elsif upper(c_main_rec.company) = 'DALEKOVOD EUR' then l_value_set_name := 'Radni%20nalog%20DALEKOVOD%20EUR';
elsif upper(c_main_rec.company) = 'DALEKOVOD NORGE' then l_value_set_name := 'Radni%20nalog%20PODRUZNICE';
elsif upper(c_main_rec.company) = 'DALEKOVOD NUF' then l_value_set_name := 'Radni%20nalog%20PODRUZNICE';
elsif upper(c_main_rec.company) = 'EUR TEST' then l_value_set_name := 'Radni%20nalog%20EUR%20TEST';
elsif upper(c_main_rec.company) = 'PODRUŽNICE' then l_value_set_name := 'Radni%20nalog%20PODRUZNICE';
elsif upper(c_main_rec.company) = 'PROIZVODNJA MK' then l_value_set_name := 'Radni%20nalog%20PROIZVODNJA%20MK';
elsif upper(c_main_rec.company) = 'PROIZVODNJA OSO' then l_value_set_name := 'Radni%20nalog%20PROIZVODNJA%20OSO'; */
if upper(c_main_rec.company) = 'DALEKOVOD' then l_value_set_name := 'Radni%20nalog%20DALEKOVOD';
elsif upper(c_main_rec.company) = 'DALEKOVOD ADRIA' then l_value_set_name := 'Radni%20nalog%20DALEKOVOD%20ADRIA';
elsif upper(c_main_rec.company) = 'DALEKOVOD EMU' then l_value_set_name := 'Radni%20nalog%20DALEKOVOD%20EMU';
elsif upper(c_main_rec.company) = 'DALEKOVOD NORGE' then l_value_set_name := 'Radni%20nalog%20DALEKOVOD%20PODRUZNICE';
elsif upper(c_main_rec.company) = 'DALEKOVOD NUF' then l_value_set_name := 'Radni%20nalog%20DALEKOVOD%20PODRUZNICE';
elsif upper(c_main_rec.company) = 'DALEKOVOD PROJEKT' then l_value_set_name := 'Radni%20nalog%20DALEKOVOD%20PROJEKT';
elsif upper(c_main_rec.company) = 'EL-RA' then l_value_set_name := 'Radni%20nalog%20EL-RA';
elsif upper(c_main_rec.company) = 'PROIZVODNJA MK' then l_value_set_name := 'Radni%20nalog%20PROIZVODNJA%20MK';
elsif upper(c_main_rec.company) = 'PROIZVODNJA OSO' then l_value_set_name := 'Radni%20nalog%20PROIZVODNJA%20OSO';


--elsif upper(c_main_rec.company) = 'DALEKOVOD EUR' then l_value_set_name := 'Radni%20nalog%20DALEKOVOD%20EUR';
elsif upper(c_main_rec.company) = 'EUR TEST' then l_value_set_name := 'Radni%20nalog%20EUR%20TEST';
elsif upper(c_main_rec.company) = 'PODRUŽNICE' then l_value_set_name := 'Radni%20nalog%20DALEKOVOD%20PODRUZNICE';
end if;

l_text := '	{
    "IndependentValue": null,
    "IndependentValueNumber": null,
    "IndependentValueDate": null,
    "IndependentValueTimestamp": null,
    "Value": "'||c_main_rec.work_order_number||'",
    "ValueNumber": null,
    "ValueDate": null,
    "ValueTimestamp": null,
    "TranslatedValue": null,
    "Description": "'||c_main_rec.work_order_description||'",
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
--    dbms_output.put_line (l_text);
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
 ---   dbms_output.put_line('ws_call_id:'|| x_ws_call_id);
 --   dbms_output.put_line('Return status: '||x_return_status);
 --   dbms_output.put_line('Return message:'||x_return_message);-- null ako je uspjelo

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
--    dbms_output.put_line('new value_id:'||l_value_id);

      UPDATE XXDL_WO_CC_INTEGRATION
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

      UPDATE XXDL_WO_CC_INTEGRATION
      SET 
      last_WS_CALL_ID = X_WS_CALL_ID,
      status = x_return_status,
      message = x_return_message, 
      fusion_value_Set_id = l_value_id,
      LAST_UPDATE_DATE = SYSDATE
      WHERE ID = C_MAIN_REC.ID;

       exception when others then 
         x_return_status := 'E';
         x_return_message := substrb('Exception in XXDL_WO_CC_INTEGRATION_PKG.PROCESS_RECORDS, sqlcode:'||SQLCODE||', sqlerrm:'||SQLERRM, 1, 2000);

         UPDATE XXDL_WO_CC_INTEGRATION
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



end XXDL_WO_CC_INTEGRATION_PKG;