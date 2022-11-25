create or replace package body xxdl_sla_mappings_pkg is
  /* $Header $
  ============================================================================+
  File Name   : XXDL_SLA_MAPPINGS_PKG.pks
  Object      : XXDL_SLA_MAPPINGS_PKG
  Description : Package to support mappings generation
  History     :
  v1.0 13.05.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/

  -- File names
  c_base_name    constant varchar2(100) := 'MappingsInterface.csv';
  c_csv_filename constant varchar2(100) := 'MappingsInterface_[BATCH_ID].csv';
  c_zip_filename constant varchar2(100) := 'MappingsInterface_[BATCH_ID].zip';

  -- Other constants
  c_directory constant varchar2(100) := 'FBDI';
  c_author    constant varchar2(100) := 'XXDL_INTEGRATION';

  -- Log variables
  c_module constant varchar2(100) := 'XXDL_SLA_MAPPINGS_PKG';
  g_log_level varchar2(10) := xxdl_log_pkg.g_level_statement; -- Use for detailed logging
  --g_log_level    varchar2(10) := xxdl_log_pkg.g_level_error; -- Regular error only logging
  g_last_message varchar2(2000);
  g_report_id    number := -1;

  -- Mappings interface statuses
  g_stat_new       varchar2(10) := 'NEW';
  g_stat_processed varchar2(10) := 'PROCESSED';

  e_processing_exception exception;

  /*===========================================================================+
  Procedure   : xlog
  Description : Logs a statement level message 
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure xlog(p_text in varchar2) as
  begin
    g_last_message := p_text;
    if g_log_level = xxdl_log_pkg.g_level_statement then
      dbms_output.put_line(to_char(sysdate, 'dd.mm.yyyy hh24:mi:ss') || '| ' || p_text);
      xxdl_log_pkg.log(p_module => c_module, p_log_level => xxdl_log_pkg.g_level_statement, p_message => p_text);
    end if;
  end;

  /*===========================================================================+
  Procedure   : xout
  Description : Reports a message
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure xout(p_line in varchar2) as
  begin
    xlog('>> ' || p_line);
    xxdl_report_pkg.put_line(p_report_id => g_report_id, p_line => p_line);
  end;

  /*===========================================================================+
  Procedure   : elog
  Description : Log an error level message 
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure elog(p_text in varchar2) as
  begin
    dbms_output.put_line(to_char(sysdate, 'dd.mm.yyyy hh24:mi:ss') || '| ' || p_text);
    if g_last_message is not null then
      xxdl_log_pkg.log(p_module => c_module, p_log_level => xxdl_log_pkg.g_level_error, p_message => 'Last message: ' || g_last_message);
      g_last_message := null;
    end if;
    xxdl_log_pkg.log(p_module => c_module, p_log_level => xxdl_log_pkg.g_level_error, p_message => p_text);
    xout('ERROR: ' || p_text);
  end;

  /*===========================================================================+
  Procedure   : query_dump_to_csv
  Description : Create csv file from SQL query
  Usage       : 
  Arguments   : p_query     - SQL query
                p_separator - CSV separator:  ; , |
                p_dir       - directory on server to store .csv file
                p_filename  - name of the .csv file
  Returns     : number of rows
  ============================================================================+*/
  function query_dump_to_csv(p_query in varchar2, p_separator in varchar2 default ',', p_dir in varchar2, p_filename in varchar2) return number is
  
    l_output      utl_file.file_type;
    l_thecursor   integer default dbms_sql.open_cursor;
    l_rec_tab     dbms_sql.desc_tab;
    l_rec_rec     dbms_sql.desc_rec;
    l_columnvalue varchar2(2000);
    l_status      integer;
    l_colcnt      number default 0;
    l_col_cnt     number default 0; --number of columns in ref cursor
    l_separator   varchar2(10) default '';
    l_cnt         number default 0;
    fhandle       utl_file.file_type;
  begin
  
    xlog('Dumping SQL result to .csv file');
    xlog('Filename: ' || p_filename);
    xlog('Directory: ' || p_dir);
    l_output := utl_file.fopen(p_dir, p_filename, 'w', 32767);
    --export to cloud expects this date format
    execute immediate 'alter session set nls_date_format=''YYYY/MM/DD hh24:mi:ss'' ';
    xlog('Starting to parse SQL query');
  
    dbms_sql.parse(l_thecursor, p_query, dbms_sql.native);
  
    xlog('Describing the columns in SQL Query');
    dbms_sql.describe_columns(l_thecursor, l_col_cnt, l_rec_tab);
  
    for i in 1 .. l_col_cnt loop
      begin
        dbms_sql.define_column(l_thecursor, i, l_columnvalue, 2000);
        l_colcnt := i;
      exception
        when others then
          if (sqlcode = -1007) then
            xlog('Error code: ' || sqlcode || ' Msg:' || sqlerrm);
            exit;
          else
            raise;
          end if;
      end;
    end loop;
  
    xlog('SQL Query parsed.');
  
    --  xlog('Defining SQL columns.');
    --  dbms_sql.define_column(l_theCursor, 1, l_columnValue, 2000);
  
    xlog('Executing SQL command.');
    l_status := dbms_sql.execute(l_thecursor);
  
    xlog('Looping through SQL result.');
    loop
      exit when(dbms_sql.fetch_rows(l_thecursor) <= 0);
      l_separator := '';
      for i in 1 .. l_colcnt loop
        dbms_sql.column_value(l_thecursor, i, l_columnvalue);
        utl_file.put(l_output, l_separator || '"' || l_columnvalue || '"');
        l_separator := p_separator;
      end loop;
      utl_file.new_line(l_output);
      l_cnt := l_cnt + 1;
    end loop;
  
    dbms_sql.close_cursor(l_thecursor);
    xlog('Looping closed, output ready.');
  
    utl_file.fclose(l_output);
    xlog('Writing to file finished.');
  
    return l_cnt;
  exception
    when utl_file.invalid_path then
      elog('ERROR: Invalid path for file.');
    when utl_file.invalid_mode then
      elog('ERROR: The open_mode parameter in FOPEN is invalid');
    when utl_file.invalid_filehandle then
      elog('ERROR: File handle is invalid.');
    when utl_file.invalid_operation then
      elog('ERROR: File could not be opened or operated on as requested.');
    when utl_file.read_error then
      elog('ERROR: Destination buffer too small, or operating system error occurred during the read operation');
    when utl_file.write_error then
      elog('ERROR: Operating system error occurred during the write operation.');
    when utl_file.internal_error then
      elog('ERROR: Unspecified PL/SQL error');
    when utl_file.charsetmismatch then
      elog('ERROR: A file is opened using FOPEN_NCHAR, but later I/O operations use nonchar functions such as PUTF or GET_LINE.');
    when utl_file.file_open then
      elog('ERROR: The requested operation failed because the file is open.');
    when utl_file.invalid_maxlinesize then
      elog('Error: The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
    when utl_file.access_denied then
      elog('ERROR: Permission to access to the file location is denied.');
    when utl_file.invalid_offset then
      elog('ERROR: Causes of the INVALID_OFFSET exception:');
    when others then
      elog('ERROR: OTHERS');
      elog('SQLCODE: ' || sqlcode);
      elog('SQLERRM: ' || sqlerrm);
      raise;
  end;

  /*===========================================================================+
  Procedure   : create_file
  Description : Create zip file with mapping values from XXDL_SLA_MAPPINGS_INTERFACE table
  Usage       : Used for sending values to Fusion
  Arguments   :
  ============================================================================+*/
  procedure create_file(x_filename_zip out varchar2, p_batch_id number) as
    l_rows         number;
    l_zipped_blob  blob;
    l_csv_filename varchar2(100);
  
  begin
  
    xlog('Procedure create_file started');
  
    l_csv_filename := replace(c_csv_filename, '[BATCH_ID]', p_batch_id);
    xlog('l_csv_filename: ' || l_csv_filename);
    x_filename_zip := replace(c_zip_filename, '[BATCH_ID]', p_batch_id);
    xlog('x_filename_zip: ' || x_filename_zip);
  
    xlog('Creating csv from XXDL_SLA_MAPPINGS_INTERFACE');
    xlog('Calling query_dump_to_csv...');
    l_rows := query_dump_to_csv('
    select i.line_num,
       i.application_name,
       i.mapping_short_name,
       i.out_chart_of_accounts,
       null,
       i.out_segment,
       null,
       null,
       i.out_value,
       i.source_value_1,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       ''N'',
       ''END''
  from xxdl_sla_mappings_interface i where i.status = ''' || g_stat_new || ''' and i.batch_id = ' || p_batch_id,
                                ',',
                                c_directory,
                                l_csv_filename);
  
    xlog('l_rows: ' || l_rows);
  
    if l_rows = 0 then
      x_filename_zip := null;
    else
    
      xlog('Zipping file...');
      xlog('x_filename_zip: ' || x_filename_zip);
      xxdl_as_zip_pkg.add1file(l_zipped_blob, c_base_name, xxdl_as_zip_pkg.file2blob(c_directory, l_csv_filename));
      xxdl_as_zip_pkg.finish_zip(l_zipped_blob);
      xxdl_as_zip_pkg.save_zip(l_zipped_blob, c_directory, x_filename_zip);
      dbms_lob.freetemporary(l_zipped_blob);
    
    end if;
  
    xlog('Procedure create_file ended');
  
  end;

  /*===========================================================================+
  Procedure   : send_csv_to_cloud
  Description : Send .csv file to cloud
  Usage       : 
  Arguments   : p_document    - full file encoded with base64 encryption
                p_doc_name    - full name of the file with extension, PozSupplierInt.csv. Usually the file has the same name as interface table
                p_doc_type    - extension of the file, .csv or .txt
                p_author      - username of the user which uploads to cloud
                p_app_account - name of the cloud account/package for import, procurement => prc$/supplier$/import$
                p_job_name    - actually the path of the cloud ESS job (cloud concurrent), suppliers => /oracle/apps/ess/financials/commonModules/shared/common/interfaceLoader/,InterfaceLoaderController
                p_job_option  - additional job options which need to be passed to ESS job, for supplier its InterfaceDetails=24
                p_wsdl_link   - URL of the web service we are calling, e.g. https://ehaz-test.fa.em2.oraclecloud.com:443/fscmService/ErpIntegrationService
                p_wsdl_method  - Web service method we are calling, importBulkData, runReport
  ============================================================================+*/
  procedure send_csv_to_cloud(p_document      in varchar2,
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
                              x_ws_call_id    out number) is
  
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
  
    xlog('Calling external web service');
  
    xlog('WSDL method:' || p_wsdl_method);
    xlog('Doc name:' || p_doc_name);
    xlog('Author:' || p_author);
    xlog('Account:' || p_app_account);
    xlog('Job:' || p_job_name);
    xlog('p_wsdl_link: ' || p_wsdl_link);
    xlog('Job option:' || p_job_option);
  
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
  
    xxfn_cloud_ws_pkg.ws_call(p_ws_url         => p_wsdl_link,
                              p_soap_env       => l_soap_env,
                              p_soap_act       => p_wsdl_method,
                              p_content_type   => 'text/xml;charset="UTF-8"',
                              x_return_status  => l_return_status,
                              x_return_message => l_return_message,
                              x_ws_call_id     => x_ws_call_id);
  
    dbms_lob.freetemporary(l_soap_env);
    xlog('Web service call ID:' || x_ws_call_id);
    xlog('Return status: ' || l_return_status);
    if l_return_status != 'S' then
      xlog('Return message:' || l_return_message);
    end if;
  
    x_return_status := l_return_status;
    x_msg           := l_return_message;
  
  end send_csv_to_cloud;
  /*===========================================================================+
  Function    : base64_encode_file
  Description : Encodes file contents with base64
  Usage       : called from package XXPO_NCS_FBDI_PKG
  Arguments   : p_dir                - directory where file is stored
                p_filename           - name of the file
  Returns     : Encoded contents of a file
  ============================================================================+*/
  procedure base64_encode_file(p_dir in varchar2, p_filename in varchar2, p_encode out varchar2) is
    l_encoded blob;
    l_b_file  bfile;
    l_step    pls_integer := 12000;
    l_clob    clob;
  begin
  
    xlog('Starting base64 encoding');
  
    xlog('Opening file:' || p_filename);
  
    l_b_file := bfilename(p_dir, p_filename);
    dbms_lob.fileopen(l_b_file, dbms_lob.file_readonly);
  
    for i in 0 .. trunc((dbms_lob.getlength(l_b_file) - 1) / l_step) loop
      l_clob := l_clob || utl_raw.cast_to_varchar2(utl_encode.base64_encode(dbms_lob.substr(l_b_file, l_step, i * l_step + 1)));
    end loop;
  
    p_encode := l_clob;
    dbms_lob.fileclose(l_b_file);
  exception
    when others then
      dbms_lob.fileclose(l_b_file);
      raise;
  end;

  /*===========================================================================+
  Function   : get_essjob_req_id
  Description : Gets cloud request_id based on  l_ws_call_id
  Usage       : When ant to know which concurrrent has been submitted
  Arguments   : 
  ============================================================================+*/
  function get_essjob_req_id(p_ws_call_id number) return number as
    l_cloud_request_id number;
  begin
  
    select extractvalue(response_xml,
                        '/env:Envelope/env:Body/ns0:submitESSJobRequestResponse/result',
                        'xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns0="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/" xmlns="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/"') request_id
      into l_cloud_request_id
      from xxfn_ws_call_log_v
     where ws_call_id = p_ws_call_id;
  
    return l_cloud_request_id;
  
  end;

  /*===========================================================================+
  Function   : get_importbulkdata_req_id
  Description : Gets cloud request_id based on  l_ws_call_id
  Usage       : When ant to know which concurrrent has been submitted
  Arguments   : 
  ============================================================================+*/
  function get_importbulkdata_req_id(p_ws_call_id number) return number as
    l_cloud_request_id number;
  begin
  
    select extractvalue(response_xml,
                        '/env:Envelope/env:Body/ns0:importBulkDataResponse/result',
                        'xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns0="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/" xmlns="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/"') request_id
      into l_cloud_request_id
      from xxfn_ws_call_log_v
     where ws_call_id = p_ws_call_id;
  
    return l_cloud_request_id;
  
  end;

  /*===========================================================================+
  Procedure   : purge_mappings_interface
  Description : Purge complete mappings interface in Fusion
  Usage       :
  Arguments   : 
  Remarks     :
  ============================================================================+*/
  procedure purge_mappings_interface as
    l_purge_req_id number;
    l_job_status   varchar2(100);
    l_ws_call_id   number;
  begin
    xlog('Calling "Purge Interface Tables" for all records');
    -- 131: The Interface Options Id selected to purge
    xxdl_cloud_utils_pkg.submit_ess_job(p_job_name        => '/oracle/apps/ess/financials/commonModules/shared/common/interfaceLoader/',
                                        p_definition_name => 'InterfaceLoaderPurge',
                                        p_params          => '131, ,0,99999999, ,ORA_FBDI,USER, ,',
                                        x_ws_call_id      => l_ws_call_id);
  
    xlog('l_ws_call_id: ' || l_ws_call_id);
  
    l_purge_req_id := get_essjob_req_id(l_ws_call_id);
  
    xxdl_cloud_utils_pkg.wait_for_ess_job(l_purge_req_id, l_job_status, 20);
  
    xlog('Purge process finished with status: ' || l_job_status);
  
  end;
  /*===========================================================================+
  Procedure   : get_mapping_set_values
  Description : Gets mapping set values from fusion sources into local interface table xxdl_sla_mappings_interface
                Returns group of batches grouped by coa
  Usage       :
  Arguments   : 
  Remarks     :
  ============================================================================+*/
  procedure get_mapping_set_values(p_mapping_set_code varchar2, p_chart_of_accounts varchar, x_group_id out number) is
  
    l_body           varchar2(30000);
    l_result         varchar2(500);
    l_result_clob    clob;
    l_return_status  varchar2(500);
    l_return_message varchar2(32000);
    l_soap_env       clob;
    l_text           varchar2(32000);
    l_ws_call_id     number;
  
    l_resp_xml           xmltype;
    l_resp_xml_id        xmltype;
    l_result_nr_id       varchar2(500);
    l_result_varchar     varchar2(32000);
    l_result_clob_decode clob;
  
    l_row xxdl_sla_mappings_interface%rowtype;
  
    l_count number;
  
    l_batch_id number;
    l_prev_coa varchar2(100);
  
    l_application_name varchar2(100);
    l_out_segment      varchar2(100);
  
  begin
  
    xlog('Procedure get_new_mapping_values started');
  
    xlog('Getting mapping set definition');
    begin
      select s.application_name,
             s.out_segment
        into l_application_name,
             l_out_segment
        from xxdl_sla_map_set_definition s
       where s.mapping_set_code = p_mapping_set_code
         and s.enabled = 'Y';
    exception
      when no_data_found then
        xlog('There is no mapping set defined in xxdl_sla_map_set_definition table or it is disabled');
        raise e_processing_exception;
    end;
  
    execute immediate 'alter session set NLS_TIMESTAMP_TZ_FORMAT= ''YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM''';
  
    l_text := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
       <soap:Header/>
       <soap:Body>
          <pub:runReport>
             <pub:reportRequest>
                <pub:attributeFormat>xml</pub:attributeFormat>
                <pub:attributeLocale></pub:attributeLocale>
                <pub:attributeTemplate></pub:attributeTemplate>
                <pub:parameterNameValues>
                   <!--Zero or more repetitions:-->
                </pub:parameterNameValues>
                <pub:reportAbsolutePath>Custom/XXDL_MAPPING_SETS/[MAPPING_SET_CODE]_REP.xdo</pub:reportAbsolutePath>
                <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
             </pub:reportRequest>
             <pub:appParams></pub:appParams>
          </pub:runReport>
       </soap:Body>
    </soap:Envelope>';
  
    l_text := replace(l_text, '[MAPPING_SET_CODE]', p_mapping_set_code);
  
    l_soap_env := to_clob(l_text);
  
    l_count := 0;
  
    xlog('Calling ws_call to get the report');
    xlog('xxdl_config_pkg.servicerooturl: ' || xxdl_config_pkg.servicerooturl);
    xxfn_cloud_ws_pkg.ws_call(p_ws_url         => xxdl_config_pkg.servicerooturl || '/xmlpserver/services/ExternalReportWSSService?WSDL',
                              p_soap_env       => l_soap_env,
                              p_soap_act       => 'runReport',
                              p_content_type   => 'application/soap+xml;charset="UTF-8"',
                              x_return_status  => l_return_status,
                              x_return_message => l_return_message,
                              x_ws_call_id     => l_ws_call_id);
  
    dbms_lob.freetemporary(l_soap_env);
  
    xlog('x_return_status: ' || l_return_status);
    if (l_return_status != 'S') then
      xlog('Error getting data from BI report for mapping set ' || p_mapping_set_code);
      xlog('l_return_message: ' || l_return_message);
      raise e_processing_exception;
    end if;
  
    xlog('Extracting xml response');
  
    begin
      select response_xml into l_resp_xml from xxfn_ws_call_log_v where ws_call_id = l_ws_call_id;
    exception
      when no_data_found then
        xlog('Error extracting xml from the response');
        raise e_processing_exception;
    end;
  
    begin
      select xml.vals
        into l_result_clob
        from xxfn_ws_call_log_v a,
             xmltable(xmlnamespaces('http://xmlns.oracle.com/oxp/service/PublicReportService' as "ns2",
                                    'http://www.w3.org/2003/05/soap-envelope' as "env"),
                      '/env:Envelope/env:Body/ns2:runReportResponse/ns2:runReportReturn' passing a.response_xml columns vals clob path
                      './ns2:reportBytes') xml
       where a.ws_call_id = l_ws_call_id
         and xml.vals is not null;
    exception
      when no_data_found then
        elog('Error getting l_result_clob from xml response');
        raise e_processing_exception;
    end;
  
    l_result_clob_decode := xxfn_cloud_ws_pkg.decodebase64(l_result_clob);
  
    l_resp_xml_id := xmltype.createxml(l_result_clob_decode);
  
    xlog('Looping thru the mapping values');
  
    l_count    := 0;
    l_prev_coa := 'XX';
    l_batch_id := 0;
    x_group_id := xxdl_sla_map_group_s1.nextval;
  
    -- Loop thru the records, ordered by COA, and process them in batches grouped by COA
    xout(' ');
    for c_rec in (select xt.*
                    from xmltable('/DATA_DS/G_1' passing l_resp_xml_id columns source_value_1 varchar2(250) path 'SOURCE_VALUE_1',
                                  out_chart_of_accounts varchar2(250) path 'OUT_CHART_OF_ACCOUNTS',
                                  out_value varchar2(250) path 'OUT_VALUE',
                                  source_reference_info varchar2(250) path 'SOURCE_REFERENCE_INFO') xt
                   order by out_chart_of_accounts) loop
    
      -- Avoid coa that are not selected
      -- TODO: Consider moving to report parameter
      if nvl(p_chart_of_accounts, c_rec.out_chart_of_accounts) != c_rec.out_chart_of_accounts then
        continue;
      end if;
    
      -- If coa is changed, new batch is created
      if l_prev_coa != c_rec.out_chart_of_accounts then
        l_batch_id := xxdl_sla_map_batch_s1.nextval;
        xlog('New batch id: ' || l_batch_id);
        l_count := 0;
      end if;
    
      l_prev_coa := c_rec.out_chart_of_accounts;
    
      l_count := l_count + 1;
    
      xout(c_rec.out_chart_of_accounts || ', ' || c_rec.source_value_1 || ', ' || c_rec.out_value || ', ' || c_rec.source_reference_info);
    
      l_row.batch_id              := l_batch_id;
      l_row.group_id              := x_group_id;
      l_row.line_num              := l_count;
      l_row.status                := 'NEW';
      l_row.application_name      := l_application_name;
      l_row.mapping_short_name    := p_mapping_set_code;
      l_row.out_chart_of_accounts := c_rec.out_chart_of_accounts;
      l_row.out_segment           := l_out_segment;
      l_row.out_value             := c_rec.out_value;
      l_row.source_value_1        := c_rec.source_value_1;
      l_row.source_reference_info := c_rec.source_reference_info;
      l_row.creation_date         := sysdate;
      l_row.last_update_date      := sysdate;
    
      insert into xxdl_sla_mappings_interface values l_row;
    
    end loop;
  
    xlog('Procedure get_new_mapping_values ended');
  
  exception
    when e_processing_exception then
      xlog('e_processing_exception risen');
  end;

  -- Prcedure declaration since it is called from reprocess_records
  procedure process_interface(p_batch_id number, p_reprocess_flag boolean, p_purge_flag boolean);

  /*===========================================================================+
  Procedure   : reprocess_records
  Description : Reprocess records - creates a new batch without errored records and process them
  Usage       :
  Arguments   :
  Remarks     :
  ============================================================================+*/
  procedure reprocess_records(p_mapping_set_code varchar2, p_chart_of_accounts varchar, p_purge_flag boolean) as
    l_reprocess_group_id number;
    l_reprocess_batch_id number;
  begin
    xlog('Procedure reprocess_records started');
  
    get_mapping_set_values(p_mapping_set_code => p_mapping_set_code, p_chart_of_accounts => p_chart_of_accounts, x_group_id => l_reprocess_group_id);
  
    xlog('Getting single batch_id to be reprocessed');
    l_reprocess_batch_id := 0;
    begin
      select batch_id
        into l_reprocess_batch_id
        from xxdl_sla_mappings_interface
       where group_id = l_reprocess_group_id
         and rownum = 1;
    exception
      when no_data_found then
        xlog('There is no records to be reprocessed');
    end;
  
    if l_reprocess_batch_id != 0 then
      xlog('Reprocessing valid records');
    
      process_interface(p_batch_id => l_reprocess_batch_id, p_reprocess_flag => false, p_purge_flag => p_purge_flag);
    end if;
  
    xlog('Procedure reprocess_records ended');
  
  end;

  /*===========================================================================+
  Procedure   : process_interface
  Description : Sends mapping values from local interface table xxdl_sla_mappings_interface to cloud
                After first processing round it can reprocess records with avoiding errored records
  Usage       :
  Arguments   :
  Remarks     :
  ============================================================================+*/
  procedure process_interface(p_batch_id number, p_reprocess_flag boolean, p_purge_flag boolean) as
  
    l_filename_zip        varchar2(250);
    l_document            varchar2(30000);
    l_doc_type            varchar2(100) := '.csv';
    l_app_account         varchar2(300) := 'fin$/fusionAccountingHub$/import';
    l_job_name            varchar2(500) := '/oracle/apps/ess/financials/commonModules/shared/common/interfaceLoader/,InterfaceLoaderController';
    l_job_option          varchar2(300) := 'InterfaceDetails=131';
    l_wsdl_link           varchar2(500) := xxdl_config_pkg.servicerooturl || '/fscmService/ErpIntegrationService';
    l_wsdl_method         varchar2(100) := 'importBulkData';
    l_return_status       varchar2(2000);
    l_msg                 varchar2(30000);
    l_req_id              number;
    l_ws_call_id          number;
    l_loadfile_req_id     number;
    l_import_setup_req_id number;
    l_purge_req_id        number;
    l_job_status          varchar2(100);
  
    l_reprocess_batch_id number;
    l_chart_of_accounts  varchar2(100);
    l_mapping_set_code   varchar2(100);
  
  begin
  
    xlog('Procedure process_interface started');
    xlog('p_batch_id: ' || p_batch_id);
    if p_reprocess_flag then
      xlog('p_reprocess_flag: true');
    else
      xlog('p_reprocess_flag: false');
    end if;
  
    xlog('Getting l_chart_of_accounts');
    begin
      select out_chart_of_accounts,
             mapping_short_name
        into l_chart_of_accounts,
             l_mapping_set_code
        from xxdl_sla_mappings_interface
       where batch_id = p_batch_id
         and rownum = 1;
    exception
      when no_data_found then
        xlog('There is no records to process in batch');
        return;
    end;
  
    xlog('Creating the file');
    create_file(x_filename_zip => l_filename_zip, p_batch_id => p_batch_id);
  
    if l_filename_zip is not null then
      base64_encode_file(c_directory, l_filename_zip, l_document);
    
      -- Creates file in the cloud
      xlog('Calling send_csv_to_cloud');
      send_csv_to_cloud(p_document      => l_document,
                        p_doc_name      => l_filename_zip,
                        p_doc_type      => l_doc_type,
                        p_author        => c_author,
                        p_app_account   => l_app_account,
                        p_job_name      => l_job_name,
                        p_job_option    => l_job_option,
                        p_wsdl_link     => l_wsdl_link,
                        p_wsdl_method   => l_wsdl_method,
                        x_return_status => l_return_status,
                        x_msg           => l_msg,
                        x_ws_call_id    => l_ws_call_id);
      xlog('l_ws_call_id: ' || l_ws_call_id);
    
      l_loadfile_req_id := get_importbulkdata_req_id(l_ws_call_id);
      xlog('l_loadfile_req_id: ' || l_loadfile_req_id);
    
      xlog('Updating interface - mark lines as processed');
      update xxdl_sla_mappings_interface i
         set i.status = g_stat_processed, i.file_name = l_filename_zip, i.last_update_date = sysdate, i.ess_job_request_id = l_loadfile_req_id
       where batch_id = p_batch_id
         and status = g_stat_new;
      xlog('Rows updated: ' || sql%rowcount);
    
    else
      xlog('No lines to process for the batch');
      return;
    end if;
  
    xlog('Commit interface changes');
    commit;
  
    xxdl_cloud_utils_pkg.wait_for_ess_job(l_loadfile_req_id, l_job_status, 20);
  
    xlog('Load file process status: ' || l_job_status);
  
    if nvl(l_job_status, 'X') != 'SUCCEEDED' then
      xlog('Process has errors');
    end if;
  
    if p_reprocess_flag then
    
      -- *** Reprocess records, to get batch without errors 
      xout('Processing interface values without errors:');
      reprocess_records(l_mapping_set_code, l_chart_of_accounts, true);
    
    end if;
  
    if p_purge_flag then
    
      -- *** Purge Interface, so there will be no errors in it
      xlog('Call "Purge Interface Tables" for loader id: ' || l_loadfile_req_id || ' batch_id: ' || p_batch_id);
      -- 131: The Interface Options Id selected to purge
      xxdl_cloud_utils_pkg.submit_ess_job(p_job_name        => '/oracle/apps/ess/financials/commonModules/shared/common/interfaceLoader/',
                                          p_definition_name => 'InterfaceLoaderPurge',
                                          p_params          => '131,' || l_loadfile_req_id || ', , , ,ORA_FBDI,USER, ,',
                                          x_ws_call_id      => l_ws_call_id);
    
      xlog('l_ws_call_id: ' || l_ws_call_id);
    
      l_purge_req_id := get_essjob_req_id(l_ws_call_id);
    
      xxdl_cloud_utils_pkg.wait_for_ess_job(l_purge_req_id, l_job_status, 20);
    
      xlog('Purge process finished with status: ' || l_job_status);
    
    end if;
  
    if p_reprocess_flag then
    
      -- *** Reprocessing second time, after clear interface table, to keep errors in interface
      xout('Processing interface values with errors, to keep them in interface:');
      reprocess_records(l_mapping_set_code, l_chart_of_accounts, false);
    
    end if;
  
    xlog('Procedure process_interface ended');
  
  end;
  /*===========================================================================+
  Procedure   : process_interface_group
  Description : Calls process_interface for every batch in the group
  Usage       :
  Arguments   :
  Remarks     :
  ============================================================================+*/
  procedure process_interface_group(p_group_id number, p_reprocess_flag boolean, p_purge_flag boolean) as
  
    cursor cur_batches is
      select batch_id,
             count(1) records_count
        from xxdl_sla_mappings_interface
       where group_id = p_group_id
       group by batch_id;
  
  begin
  
    xlog('Procedure process_interface_group started');
  
    for c_batch in cur_batches loop
      xout('Processing batch : ' || c_batch.batch_id);
      xlog('Number of records: ' || c_batch.records_count);
      xlog('Processing all interface values');
      process_interface(p_batch_id => c_batch.batch_id, p_reprocess_flag => p_reprocess_flag, p_purge_flag => p_purge_flag);
    end loop;
    xlog('Procedure process_interface_group ended');
  
  end;

  /*===========================================================================+
  Procedure   : refresh_mapping_set
  Description : Refreshes single mapping values from BI report
  Usage       :
  Arguments   : 
  Remarks     :
  ============================================================================+*/
  procedure refresh_mapping_set(p_mapping_set_code varchar2) is
  
    l_group_id number;
  
  begin
    xlog('refresh_mapping_set started');
    xlog('p_mapping_set_code: ' || p_mapping_set_code);
  
    xxdl_report_pkg.create_report(p_report_type => 'Refresh Mapping Set',
                                  p_report_name => 'Refresh ' || p_mapping_set_code,
                                  x_report_id   => g_report_id);
  
    xout('*** Refresh mapping set report ***');
    xout('Mapping set: ' || p_mapping_set_code);
    xout('');
  
    get_mapping_set_values(p_mapping_set_code => p_mapping_set_code, p_chart_of_accounts => null, x_group_id => l_group_id);
  
    xout('Group id: ' || l_group_id);
  
    process_interface_group(p_group_id => l_group_id, p_reprocess_flag => true, p_purge_flag => true);
  
    xout('*** End of report ***');
  
    xlog('refresh_mapping_set ended');
  exception
    when others then
      elog('SQLERRM: ' || sqlerrm);
      elog('BACKTRACE: ' || dbms_utility.format_error_backtrace);
      raise;
  end;
  /*===========================================================================+
  Procedure   : refresh_all_mapping_sets
  Description : Refreshes all mapping sets registered in xxdl_sla_map_set_definition
                from cloud sources to cloud mapping sets
  Usage       :
  Arguments   : 
  Remarks     :
  ============================================================================+*/
  procedure refresh_all_mapping_sets is
    -- List of mapping sets to be refreshed
    -- There must exist corresponding BI report with mapping set values in folder
    -- /Shared Folders/Custom/XXDL_MAPPING_SETS
    cursor cur_map_sets is
      select s.mapping_set_code from xxdl_sla_map_set_definition s where enabled = 'Y';
  begin
    xlog('refresh_all_mapping_sets started');
    for c_set in cur_map_sets loop
      refresh_mapping_set(c_set.mapping_set_code);
    end loop;
  
    referesh_work_orders_mappings;
  
    xlog('refresh_all_mapping_sets ended');
  exception
    when others then
      elog('SQLERRM: ' || sqlerrm);
      elog('BACKTRACE: ' || dbms_utility.format_error_backtrace);
      raise;
  end;

  /*===========================================================================+
  Procedure   : referesh_so_from_wo_mapping
  Description : Refreshes sales order from Work order mapping
  Usage       :
  Arguments   : 
  Remarks     :
  ============================================================================+*/
  procedure referesh_so_from_wo_mapping as
    cursor cur_wo is
      select work_order_number,
             sales_order,
             company
        from xxdl_wo_cc_integration wo
       where not exists (select 1
                from xxdl_sync_statuses s
               where s.entity_type = 'XXDL_SO_FROM_REQ_WO'
                 and s.id1 = wo.work_order_number
                 and s.sync_status = 'OK')
         and wo.sales_order is not null
         and wo.status = 'S'
       order by company,
                sales_order;
  
    l_int_row  xxdl_sla_mappings_interface%rowtype;
    l_stat_row xxdl_sync_statuses%rowtype;
    l_batch_id number;
    l_group_id number;
    l_count    number;
    l_prev_coa varchar2(100);
  begin
  
    xlog('referesh_so_from_wo_mapping started');
  
    xxdl_report_pkg.create_report(p_report_type => 'Refresh Work Orders Mappings',
                                  p_report_name => 'Refresh XXDL_SO_FROM_REQ_WO',
                                  x_report_id   => g_report_id);
  
    xout('*** Refresh Work Orders Mappings: XXDL_SO_FROM_REQ_WO ***');
    xout('');
  
    l_prev_coa := 'XX';
    l_batch_id := 0;
  
    l_group_id := xxdl_sla_map_group_s1.nextval;
  
    for c_wo in cur_wo loop
    
      -- If coa is changed, new batch is created
      if l_prev_coa != c_wo.company then
        l_batch_id := xxdl_sla_map_batch_s1.nextval;
        xlog('New batch id: ' || l_batch_id);
        l_count := 0;
      end if;
    
      l_count := l_count + 1;
    
      l_prev_coa := c_wo.company;
    
      xout(c_wo.company || ', ' || c_wo.work_order_number || ', ' || c_wo.sales_order);
    
      l_int_row.batch_id              := l_batch_id;
      l_int_row.group_id              := l_group_id;
      l_int_row.line_num              := l_count;
      l_int_row.status                := 'NEW';
      l_int_row.application_name      := 'Purchasing';
      l_int_row.mapping_short_name    := 'XXDL_SO_FROM_REQ_WO';
      l_int_row.out_chart_of_accounts := c_wo.company;
      l_int_row.out_segment           := 'Nalog prodaje';
      l_int_row.out_value             := c_wo.sales_order;
      l_int_row.source_value_1        := c_wo.work_order_number;
      l_int_row.source_reference_info := 'WO: ' || c_wo.work_order_number;
      l_int_row.creation_date         := sysdate;
      l_int_row.last_update_date      := sysdate;
    
      insert into xxdl_sla_mappings_interface values l_int_row;
    
      l_stat_row.entity_type      := 'XXDL_SO_FROM_REQ_WO';
      l_stat_row.id1              := c_wo.work_order_number;
      l_stat_row.id2              := 'X';
      l_stat_row.sync_status      := 'OK';
      l_stat_row.creation_date    := sysdate;
      l_stat_row.last_update_date := sysdate;
    
      --delete errored record if exists
      delete from xxdl_sync_statuses
       where entity_type = 'XXDL_SO_FROM_REQ_WO'
         and id1 = c_wo.work_order_number
         and id2 = 'X';
    
      -- Insert ok record
      insert into xxdl_sync_statuses values l_stat_row;
    
    end loop;
  
    if l_count > 0 then
      -- Processing interface
      process_interface_group(p_group_id => l_group_id, p_reprocess_flag => false, p_purge_flag => true);
    else
      xout('There is no XXDL_SO_FROM_REQ_WO to process');
    end if;
  
    xlog('referesh_so_from_wo_mapping ended');
  
  end;

  /*===========================================================================+
  Procedure   : referesh_cc_from_wo_mapping
  Description : Refreshes XXDL_CC_FROM_REQ_WO mapping
  Usage       :
  Arguments   : 
  Remarks     :
  ============================================================================+*/
  procedure referesh_cc_from_wo_mapping as
    cursor cur_wo is
      select work_order_number,
             cost_center,
             company
        from xxdl_wo_cc_integration wo
       where not exists (select 1
                from xxdl_sync_statuses s
               where s.entity_type = 'XXDL_CC_FROM_REQ_WO'
                 and s.id1 = wo.work_order_number
                 and s.sync_status = 'OK')
         and wo.cost_center is not null
         and wo.status = 'S'
       order by company,
                work_order_number;
  
    l_int_row  xxdl_sla_mappings_interface%rowtype;
    l_stat_row xxdl_sync_statuses%rowtype;
    l_batch_id number;
    l_group_id number;
    l_count    number;
    l_prev_coa varchar2(100);
  begin
  
    xlog('referesh_cc_from_wo_mapping started');
  
    xxdl_report_pkg.create_report(p_report_type => 'Refresh Work Orders Mappings',
                                  p_report_name => 'Refresh XXDL_CC_FROM_REQ_WO',
                                  x_report_id   => g_report_id);
  
    xout('*** Refresh Work Orders Mappings: XXDL_CC_FROM_REQ_WO ***');
    xout('');
  
    l_prev_coa := 'XX';
    l_batch_id := 0;
  
    l_group_id := xxdl_sla_map_group_s1.nextval;
  
    l_count := 0;
  
    for c_wo in cur_wo loop
    
      -- If coa is changed, new batch is created
      if l_prev_coa != c_wo.company then
        l_batch_id := xxdl_sla_map_batch_s1.nextval;
        xlog('New batch id: ' || l_batch_id);
        l_count := 0;
      end if;
    
      l_count := l_count + 1;
    
      xout(c_wo.company || ', ' || c_wo.work_order_number || ', ' || c_wo.cost_center);
    
      l_int_row.batch_id              := l_batch_id;
      l_int_row.group_id              := l_group_id;
      l_int_row.line_num              := l_count;
      l_int_row.status                := 'NEW';
      l_int_row.application_name      := 'Purchasing';
      l_int_row.mapping_short_name    := 'XXDL_CC_FROM_REQ_WO';
      l_int_row.out_chart_of_accounts := c_wo.company;
      l_int_row.out_segment           := 'Mjesto troska';
      l_int_row.out_value             := c_wo.cost_center;
      l_int_row.source_value_1        := c_wo.work_order_number;
      l_int_row.source_reference_info := 'WO: ' || c_wo.work_order_number;
      l_int_row.creation_date         := sysdate;
      l_int_row.last_update_date      := sysdate;
    
      insert into xxdl_sla_mappings_interface values l_int_row;
    
      l_stat_row.entity_type      := 'XXDL_CC_FROM_REQ_WO';
      l_stat_row.id1              := c_wo.work_order_number;
      l_stat_row.id2              := 'X';
      l_stat_row.sync_status      := 'OK';
      l_stat_row.creation_date    := sysdate;
      l_stat_row.last_update_date := sysdate;
    
      --delete errored record if exists
      delete from xxdl_sync_statuses
       where entity_type = 'XXDL_CC_FROM_REQ_WO'
         and id1 = c_wo.work_order_number
         and id2 = 'X';
    
      -- Insert ok record
      insert into xxdl_sync_statuses values l_stat_row;
    
    end loop;
  
    if l_count > 0 then
      -- Processing interface
      process_interface_group(p_group_id => l_group_id, p_reprocess_flag => false, p_purge_flag => true);
    else
      xout('There is no XXDL_CC_FROM_REQ_WO to process');
    end if;
  
    xlog('referesh_cc_from_wo_mapping ended');
  
  end;

  /*===========================================================================+
  Procedure   : referesh_work_orders_mappings
  Description : Refreshes mappings related to work orders from xxdl_wo_cc_integration table
  Usage       :
  Arguments   : 
  Remarks     :
  ============================================================================+*/
  procedure referesh_work_orders_mappings as
  begin
  
    referesh_so_from_wo_mapping;
    referesh_cc_from_wo_mapping;
  
  end;

end;
/
