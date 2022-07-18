create or replace package body xxdl_inv_integration_pkg is
  /* $Header $
  ============================================================================+
  File Name   : XXDL_INV_INTEGRATION_PKG.pks
  Object      : XXDL_INV_INTEGRATION_PKG
  Description : Package to Inventory integrations 
  History     :
  v1.0 15.7.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/

  -- Log variables
  c_module constant varchar2(100) := 'XXDL_INV_INTEGRATION_PKG ';
  g_log_level varchar2(10) := xxdl_log_pkg.g_level_statement; -- Use for detailed logging
  --g_log_level    varchar2(10) := xxdl_log_pkg.g_level_error; -- Regular error only logging
  g_last_message varchar2(2000);
  g_report_id    number := -1;

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
  Procedure   : xml_char_to_date
  Description : Converts date strings from xml to local date format
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  function xml_char_to_date(p_char varchar) return date as
  begin
    return cast(to_timestamp_tz(p_char, 'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM') as timestamp with local time zone);
  end;

  /*===========================================================================+
  Procedure   : download_transactions
  Description : Downloads inventory transactions from Fusion to XE database
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure download_transactions is
  
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
  
    l_row xxdl_inv_material_txns%rowtype;
  
    l_count number;
  
    l_last_transaction_id number;
  
  begin
  
    xlog('Procedure download_transactions started');
  
    xxdl_report_pkg.create_report(p_report_type => 'Download Fusion Table',
                                  p_report_name => 'Download Material Transactions',
                                  x_report_id   => g_report_id);
  
    xout('*** Download Material Transactions ***');
    xout('');
  
    --execute immediate 'alter session set NLS_TIMESTAMP_TZ_FORMAT= ''YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM''';
  
    xlog('Getting last transaction_id');
    select max(transaction_id) into l_last_transaction_id from xxdl_inv_material_txns;
  
    if l_last_transaction_id is null then
      l_last_transaction_id := -1;
    end if;
  
    l_text := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
            <soap:Header/>
            <soap:Body>
                <pub:runReport>
                    <pub:reportRequest>
                        <pub:attributeFormat>xml</pub:attributeFormat>
                        <pub:attributeLocale></pub:attributeLocale>
                        <pub:attributeTemplate></pub:attributeTemplate>
                        <pub:parameterNameValues>
                            <pub:item>
                                <pub:name>p_last_transaction_id</pub:name>
                                <pub:values>
                                    <pub:item>[P_LAST_TRANSACTION_ID]</pub:item>
                                </pub:values>
                            </pub:item>
                        </pub:parameterNameValues>
                        <pub:reportAbsolutePath>Custom/XXDL_INV_Integration/XXDL_INV_MATERIAL_TXNS_REP.xdo</pub:reportAbsolutePath>
                        <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
                    </pub:reportRequest>
                    <pub:appParams></pub:appParams>
                </pub:runReport>
            </soap:Body>
        </soap:Envelope>';
  
    l_text := replace(l_text, '[P_LAST_TRANSACTION_ID]', l_last_transaction_id);
  
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
      xlog('Error getting data from BI report for Inventory transaction');
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
  
    xlog(to_char(dbms_lob.substr(l_result_clob_decode, 1000, 1)));
  
    l_resp_xml_id := xmltype.createxml(l_result_clob_decode);
  
    xlog('Looping thru the  values');
  
    -- Loop thru the records
    xout(' ');
    for c_rec in (select xt.*
                    from xmltable('/DATA_DS/G_1' passing l_resp_xml_id columns transaction_id number path 'TRANSACTION_ID',
                                  inventory_item_id number path 'INVENTORY_ITEM_ID',
                                  item_number varchar2(300) path 'ITEM_NUMBER',
                                  organization_id number path 'ORGANIZATION_ID',
                                  organization_name varchar2(300) path 'ORGANIZATION_NAME',
                                  subinventory_code varchar2(10) path 'SUBINVENTORY_CODE',
                                  transaction_type_id number path 'TRANSACTION_TYPE_ID',
                                  transaction_type_name varchar2(80) path 'TRANSACTION_TYPE_NAME',
                                  transaction_action_id number path 'TRANSACTION_ACTION_ID',
                                  transaction_source_type_id number path 'TRANSACTION_SOURCE_TYPE_ID',
                                  transaction_source_id number path 'TRANSACTION_SOURCE_ID',
                                  transaction_quantity number path 'TRANSACTION_QUANTITY',
                                  transaction_uom varchar2(3) path 'TRANSACTION_UOM',
                                  primary_quantity number path 'PRIMARY_QUANTITY',
                                  transaction_date varchar2(100) path 'TRANSACTION_DATE',
                                  po_number varchar2(100) path 'PO_NUMBER',
                                  po_approved_date varchar2(100) path 'PO_APPROVED_DATE',
                                  po_unit_price number path 'PO_UNIT_PRICE',
                                  po_party_site_number varchar2(100) path 'PO_PARTY_SITE_NUMBER',
                                  creation_date varchar2(100) path 'CREATION_DATE',
                                  created_by varchar2(64) path 'CREATED_BY') xt
                   order by transaction_id) loop
    
      l_count := l_count + 1;
    
      xout(c_rec.transaction_id || ', ' || c_rec.organization_name);
    
      l_row.transaction_id             := c_rec.transaction_id;
      l_row.inventory_item_id          := c_rec.inventory_item_id;
      l_row.item_number                := c_rec.item_number;
      l_row.organization_id            := c_rec.organization_id;
      l_row.organization_name          := c_rec.organization_name;
      l_row.subinventory_code          := c_rec.subinventory_code;
      l_row.transaction_type_id        := c_rec.transaction_type_id;
      l_row.transaction_type_name      := c_rec.transaction_type_name;
      l_row.transaction_action_id      := c_rec.transaction_action_id;
      l_row.transaction_source_type_id := c_rec.transaction_source_type_id;
      l_row.transaction_source_id      := c_rec.transaction_source_id;
      l_row.transaction_quantity       := c_rec.transaction_quantity;
      l_row.transaction_uom            := c_rec.transaction_uom;
      l_row.primary_quantity           := c_rec.primary_quantity;
      l_row.transaction_date           := xml_char_to_date(c_rec.transaction_date);
      l_row.po_number                  := c_rec.po_number;
      l_row.po_approved_date           := xml_char_to_date(c_rec.po_approved_date);
      l_row.po_unit_price              := c_rec.po_unit_price;
      l_row.po_party_site_number       := c_rec.po_party_site_number;
      l_row.creation_date              := xml_char_to_date(c_rec.creation_date);
      l_row.created_by                 := c_rec.created_by;
      l_row.downloaded_date            := sysdate;
    
      insert into xxdl_inv_material_txns values l_row;
    
    end loop;
  
    xout('Transactions downloaded: ' || l_count);
    xout('*** End of report ***');
  
    xlog('Procedure download_transactions ended');
  
  exception
    when e_processing_exception then
      xlog('e_processing_exception risen');
  end;

end;
/
