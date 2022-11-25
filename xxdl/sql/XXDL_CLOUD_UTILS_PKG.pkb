create or replace package body xxdl_cloud_utils_pkg is
  /* $Header $
  ============================================================================+
  File Name   : XXDL_CLOUD_UTILS_PKG.pks
  Object      : XXDL_CLOUD_UTILS_PKG
  Description : Package to provide cloud utility procedures
  History     :
  v1.0 24.06.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/

  g_log_level varchar2(10) := xxdl_log_pkg.g_level_statement; -- Use for detailed logging
  --g_log_level    varchar2(10) := xxdl_log_pkg.g_level_error; -- Regular error only logging

  c_module constant varchar2(100) := 'XXDL_CLOUD_UTILS_PKG';

  -- Fusion ESS Job statuses
  g_ess_status_wait      varchar2(10) := 'WAIT';
  g_ess_status_blocked   varchar2(10) := 'BLOCKED';
  g_ess_status_running   varchar2(10) := 'RUNNING';
  g_ess_status_paused    varchar2(10) := 'PAUSED';
  g_ess_status_ready     varchar2(10) := 'READY';
  g_ess_status_completed varchar2(10) := 'COMPLETED';
  g_ess_status_succeeded varchar2(10) := 'SUCCEEDED';

  /*===========================================================================+
  Procedure   : xlog
  Description : Logs a statement level message 
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure xlog(p_text in varchar2) as
  begin
    if g_log_level = xxdl_log_pkg.g_level_statement then
      dbms_output.put_line(to_char(sysdate, 'dd.mm.yyyy hh24:mi:ss') || '| ' || p_text);
      xxdl_log_pkg.log(p_module => c_module, p_log_level => xxdl_log_pkg.g_level_statement, p_message => p_text);
    end if;
  end;

  /*===========================================================================+
  Function   : parse_params
  Description : Exploder params sent as a string
  Usage       : 
  Arguments   : p_params        - list of parameters delimited with comma
  Return      : Return list of parameters in xml definition
  ============================================================================+*/
  function parse_params(p_params in varchar2) return varchar2 is
    l_params varchar2(1000);
  begin
  
    xlog('parse_params started');
    xlog('p_params: ' || p_params);
  
    for c_r in (with data as
                   (select '' || p_params || '' str from dual)
                  select trim(regexp_substr(str, '[^,]+', 1, level)) str from data connect by instr(str, ',', 1, level - 1) > 0) loop
    
      l_params := l_params || '<typ:paramList>' || c_r.str || '</typ:paramList>' || chr(10);
    end loop;
    return l_params;
  
  end;

  /*===========================================================================+
  Procedure   : submit_ess_job
  Description : Submit ESS job on Cloud (conc  urrent)
  Usage       : 
  Arguments   : p_job_name          - path of the ESS job
                p_definition_name   - name of the job
                p_params            - list of parameters delimited with comma
                x_ws_call_id        - ID of ws callw
  ============================================================================+*/
  procedure submit_ess_job(p_job_name in varchar2, p_definition_name in varchar2, p_params in varchar2, x_ws_call_id out number) is
    l_wsdl_link    varchar2(500);
    l_wsdl_domain  varchar2(200);
    l_wsdl_method  varchar2(100) := 'submitESSJobRequest';
    l_ws_http_type varchar2(100) := 'text/xml;charset=UTF-8';
  
    x_return_status  varchar2(500);
    x_return_message varchar2(32000);
    l_soap_env       clob;
    l_text           varchar2(32000);
  
  begin
  
    xlog('submit_ess_job started');
  
    l_wsdl_domain := xxdl_config_pkg.servicerooturl;
  
    l_wsdl_link := l_wsdl_domain || '/fscmService/ErpIntegrationService';
  
    xlog('Preparing soap envelope');
    l_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/">
         <soapenv:Header/>
         <soapenv:Body>
            <typ:submitESSJobRequest>
               <typ:jobPackageName>' || p_job_name || '</typ:jobPackageName>
               <typ:jobDefinitionName>' || p_definition_name || '</typ:jobDefinitionName>
               <!--Zero or more repetitions:-->' || chr(10) || parse_params(p_params) || '
            </typ:submitESSJobRequest>
         </soapenv:Body>
      </soapenv:Envelope>';
  
    xlog('Soap envelope to clob');
    l_soap_env := to_clob(l_text);
  
    xxfn_cloud_ws_pkg.ws_call(p_ws_url         => l_wsdl_link,
                              p_soap_env       => l_soap_env,
                              p_soap_act       => l_wsdl_method,
                              p_content_type   => l_ws_http_type,
                              x_return_status  => x_return_status,
                              x_return_message => x_return_message,
                              x_ws_call_id     => x_ws_call_id);
  
    dbms_lob.freetemporary(l_soap_env);
    xlog('ESS job ID:' || x_ws_call_id);
    xlog('Return status: ' || x_return_status);
  
    if (x_return_status = 'S') then
    
      xlog('ESS job submitted');
    
    else
    
      xlog('ESS job submit failed');
    
    end if;
  
    xlog('submit_ess_job ended');
  
  end;

  /*===========================================================================+
  Procedure   : get_ess_job_status
  Description : Gets ess job status 
  Usage       : To check current status of the ees job. 
                Returns status: WAIT, BLOCKED, RUNNING, PAUSED, READY, COMPLETED, SUCCEEDED
  Arguments   : 
  ============================================================================+*/
  procedure get_ess_job_status(p_job_req_id in number, x_job_status out varchar2) is
    l_wsdl_link    varchar2(500) := xxdl_config_pkg.servicerooturl || '/fscmService/ErpIntegrationService';
    l_wsdl_method  varchar2(100) := 'getESSJobStatus';
    l_ws_http_type varchar2(100) := 'text/xml;charset=UTF-8';
  
    x_return_status  varchar2(500);
    x_return_message varchar2(32000);
    l_soap_env       clob;
    l_text           varchar2(32000);
    l_ws_call_id     number;
  
  begin
  
    if p_job_req_id is null then
      return;
    end if;
  
    --xlog('Procedure get_ess_job_status p_job_req_id: ' || p_job_req_id);
  
    l_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/">
         <soapenv:Header/>
         <soapenv:Body>
            <typ:getESSJobStatus>
               <typ:requestId>' || p_job_req_id || '</typ:requestId>
            </typ:getESSJobStatus>
         </soapenv:Body>
      </soapenv:Envelope>';
  
    l_soap_env := to_clob(l_text);
  
    xxfn_cloud_ws_pkg.ws_call(p_ws_url         => l_wsdl_link,
                              p_soap_env       => l_soap_env,
                              p_soap_act       => l_wsdl_method,
                              p_content_type   => l_ws_http_type,
                              x_return_status  => x_return_status,
                              x_return_message => x_return_message,
                              x_ws_call_id     => l_ws_call_id);
  
    --xlog('xxfn_cloud_ws_pkg.ws_call returned l_ws_call_id: ' || l_ws_call_id);
  
    dbms_lob.freetemporary(l_soap_env);
  
    begin
      select extractvalue(response_xml,
                          '/env:Envelope/env:Body/ns0:getESSJobStatusResponse/result',
                          'xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns0="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/" xmlns="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/"') request_id
        into x_job_status
        from xxfn_ws_call_log_v
       where ws_call_id = l_ws_call_id;
    exception
      when no_data_found then
        xlog('Error getting job status for p_job_req_id: ' || p_job_req_id || ' || l_ws_call_id: ' || l_ws_call_id);
        x_job_status := null;
    end;
  
  end;

  /*===========================================================================+
  Procedure   : wait_for_ess_job
  Description : Waits for ess job to finish
  Usage       : AFter running ess job it is possible to wait for it to finish and check it finals status
  Arguments   :
  ============================================================================+*/
  procedure wait_for_ess_job(p_ess_req_id number, x_job_status out varchar2, p_max_minutes_to_wait number default 10) as
    l_started_time date;
    l_time_elapsed number;
  begin
    -- xlog('Procedure wait_for_ess_job started');
    x_job_status := null;
  
    if p_ess_req_id is null then
      return;    
    end if;
  
    l_started_time := sysdate;
    l_time_elapsed := 0;
    x_job_status   := 'XXX';
    -- xlog('Calling get_ess_job_status in the loop...');
    while x_job_status in
          ('XXX', g_ess_status_wait, g_ess_status_blocked, g_ess_status_running, g_ess_status_paused, g_ess_status_ready, g_ess_status_completed) and
          l_time_elapsed < p_max_minutes_to_wait loop
      l_time_elapsed := (sysdate - l_started_time) * 24 * 60;
      get_ess_job_status(p_ess_req_id, x_job_status);
      -- if procedure returnes null then check again
      if x_job_status is null then
        x_job_status := 'XXX';
      end if;
      xlog('x_job_status: ' || x_job_status);
      -- Check every 10 seconds again
      dbms_lock.sleep(10);
    end loop;
    -- xlog('Procedure wait_for_ess_job ended');
  end;

end;
/
