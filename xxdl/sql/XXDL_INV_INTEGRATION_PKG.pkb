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
  Procedure   : xml_date_to_char
  Description : Converts date to strings for json usage
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  function json_date_to_char(p_date date) return varchar2 as
    l_char varchar2(100);
  begin
    return to_char(cast(p_date as timestamp with time zone) at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM');
  end;

  /*===========================================================================+
  Procedure   : download_avg_item_cst
  Description : Downloads items average cost from Fusion to XE database
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure download_avg_item_cst is
  
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
  
    l_row xxdl_avg_item_cost%rowtype;
  
    l_count number;
  
    l_last_update_date date;
  
  begin
  
    xlog('Procedure download_avg_item_cst started');
  
    xxdl_report_pkg.create_report(p_report_type => 'Download Fusion Table',
                                  p_report_name => 'Download Average Items Costs',
                                  x_report_id   => g_report_id);
  
    xout('*** Download Average Items Costs ***');
    xout('');
  
    xlog('Getting last update date');
    select max(last_update_date) into l_last_update_date from xxdl_avg_item_cost;
  
    if l_last_update_date is null then
      l_last_update_date := to_date('1-1-1900', 'dd-mm-yyyy');
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
                                <pub:name>p_last_update_date</pub:name>
                                <pub:values>
                                    <pub:item>[P_LAST_UPDATE_DATE]</pub:item>
                                </pub:values>
                            </pub:item>
                        </pub:parameterNameValues>
                        <pub:reportAbsolutePath>Custom/XXDL_INV_Integration/XXDL_AVG_ITEM_COST_REP.xdo</pub:reportAbsolutePath>
                        <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
                    </pub:reportRequest>
                    <pub:appParams></pub:appParams>
                </pub:runReport>
            </soap:Body>
        </soap:Envelope>';
  
    l_text := replace(l_text, '[P_LAST_UPDATE_DATE]', json_date_to_char(l_last_update_date));
  
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
      xlog('Error getting data from BI report for Average Items Costs');
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
                    from xmltable('/DATA_DS/G_1' passing l_resp_xml_id columns cost_org varchar2(100) path 'COST_ORG',
                                  inventory_item_id number path 'INVENTORY_ITEM_ID',
                                  item_number varchar2(100) path 'ITEM_NUMBER',
                                  val_unit_code varchar2(100) path 'VAL_UNIT_CODE',
                                  unit_cost_average number path 'UNIT_COST_AVERAGE',
                                  quantity_onhand number path 'QUANTITY_ONHAND',
                                  uom_code varchar2(30) path 'UOM_CODE',
                                  last_update_date varchar2(100) path 'LAST_UPDATE_DATE') xt) loop
    
      l_count := l_count + 1;
    
      xout(c_rec.item_number || ', ' || c_rec.unit_cost_average);
    
      l_row.cost_org          := c_rec.cost_org;
      l_row.inventory_item_id := c_rec.inventory_item_id;
      l_row.item_number       := c_rec.item_number;
      l_row.val_unit_code     := c_rec.val_unit_code;
      l_row.unit_cost_average := c_rec.unit_cost_average;
      l_row.quantity_onhand   := c_rec.quantity_onhand;
      l_row.uom_code          := c_rec.uom_code;
      l_row.last_update_date  := xml_char_to_date(c_rec.last_update_date);
    
      l_row.downloaded_date := sysdate;
    
      insert into xxdl_avg_item_cost values l_row;
    
    end loop;
  
    xout('Item costs downloaded: ' || l_count);
    xout('*** End of report ***');
  
    xlog('Procedure download_avg_item_cst ended');
  
  exception
    when e_processing_exception then
      xlog('e_processing_exception risen');
      xxdl_report_pkg.set_has_errors(g_report_id);
    
    when others then
      xxdl_report_pkg.set_has_errors(g_report_id);
      elog('SQLERRM: ' || sqlerrm);
      elog('BACKTRACE: ' || dbms_utility.format_error_backtrace);
      raise;
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
                                  shipment_number varchar2(100) path 'SHIPMENT_NUMBER',
                                  receipt_num varchar2(100) path 'RECEIPT_NUM',
                                  transfer_organization_id number path 'TRANSFER_ORGANIZATION_ID',
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
      l_row.shipment_number            := c_rec.shipment_number;
      l_row.receipt_num                := c_rec.receipt_num;
      l_row.transfer_organization_id   := c_rec.transfer_organization_id;
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
      xxdl_report_pkg.set_has_errors(g_report_id);
    
    when others then
      xxdl_report_pkg.set_has_errors(g_report_id);
      elog('SQLERRM: ' || sqlerrm);
      elog('BACKTRACE: ' || dbms_utility.format_error_backtrace);
      raise;
  end;

  /*===========================================================================+
  Procedure   : download_inv_orgs
  Description : Downloads inventory organizations
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure download_inv_orgs is
  
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
  
    l_row xxdl_inv_organizations%rowtype;
  
    l_count number;
  
    l_last_update_date date;
  
  begin
  
    xlog('Procedure download_inv_orgs started');
  
    xxdl_report_pkg.create_report(p_report_type => 'Download Fusion Table',
                                  p_report_name => 'Download Inventory Organizations',
                                  x_report_id   => g_report_id);
  
    xout('*** Download Inventory Organizations ***');
    xout('');
  
    xlog('Getting last update date');
    select max(last_update_date) into l_last_update_date from xxdl_inv_organizations;
    xlog('last_update_date:' || l_last_update_date);
  
    if l_last_update_date is null then
      l_last_update_date := to_date('1-1-1900', 'dd-mm-yyyy');
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
                                <pub:name>p_last_update_date</pub:name>
                                <pub:values>
                                    <pub:item>[P_LAST_UPDATE_DATE]</pub:item>
                                </pub:values>
                            </pub:item>
                        </pub:parameterNameValues>
                        <pub:reportAbsolutePath>Custom/XXDL_INV_Integration/XXDL_INV_ORGANIZATIONS_REP.xdo</pub:reportAbsolutePath>
                        <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
                    </pub:reportRequest>
                    <pub:appParams></pub:appParams>
                </pub:runReport>
            </soap:Body>
        </soap:Envelope>';
  
    l_text := replace(l_text, '[P_LAST_UPDATE_DATE]', json_date_to_char(l_last_update_date));
  
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
                    from xmltable('/DATA_DS/G_1' passing l_resp_xml_id columns organization_id number path 'ORGANIZATION_ID',
                                  organization_code varchar2(30) path 'ORGANIZATION_CODE',
                                  name varchar2(100) path 'NAME',
                                  last_update_date varchar2(100) path 'LAST_UPDATE_DATE') xt) loop
    
      l_count := l_count + 1;
    
      xout(c_rec.organization_id || ', ' || c_rec.organization_code || ', ' || c_rec. last_update_date);
    
      l_row.organization_id   := c_rec.organization_id;
      l_row.organization_code := c_rec.organization_code;
      l_row.name              := c_rec.name;
      l_row.last_update_date  := xml_char_to_date(c_rec.last_update_date);
    
      l_row.downloaded_date := sysdate;
    
      delete from xxdl_inv_organizations where organization_id = c_rec.organization_id;
    
      insert into xxdl_inv_organizations values l_row;
    
    end loop;
  
    xout('Organizations downloaded: ' || l_count);
    xout('*** End of report ***');
  
    xlog('Procedure download_inv_orgs ended');
  
  exception
    when e_processing_exception then
      xlog('e_processing_exception risen');
      xxdl_report_pkg.set_has_errors(g_report_id);
    
    when others then
      xxdl_report_pkg.set_has_errors(g_report_id);
      elog('SQLERRM: ' || sqlerrm);
      elog('BACKTRACE: ' || dbms_utility.format_error_backtrace);
      raise;
  end;

  /*===========================================================================+
  Procedure   : download_items
  Description : Downloads  items from Fusion 
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure download_items is
  
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
  
    l_row xxdl_egp_system_items%rowtype;
  
    l_count number;
  
    l_last_update_date date;
  
  begin
  
    xlog('Procedure download_items started');
  
    xxdl_report_pkg.create_report(p_report_type => 'Download Fusion Table', p_report_name => 'Download Items', x_report_id => g_report_id);
  
    xout('*** Download Items ***');
    xout('');
  
    xlog('Getting last update date');
    select max(last_update_date) into l_last_update_date from xxdl_egp_system_items;
    xlog('last_update_date:' || l_last_update_date);
  
    if l_last_update_date is null then
      l_last_update_date := to_date('1-1-1900', 'dd-mm-yyyy');
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
                                <pub:name>p_last_update_date</pub:name>
                                <pub:values>
                                    <pub:item>[P_LAST_UPDATE_DATE]</pub:item>
                                </pub:values>
                            </pub:item>
                        </pub:parameterNameValues>
                        <pub:reportAbsolutePath>Custom/XXDL_INV_Integration/XXDL_EGP_SYSTEM_ITEMS_REP.xdo</pub:reportAbsolutePath>
                        <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
                    </pub:reportRequest>
                    <pub:appParams></pub:appParams>
                </pub:runReport>
            </soap:Body>
        </soap:Envelope>';
  
    l_text := replace(l_text, '[P_LAST_UPDATE_DATE]', json_date_to_char(l_last_update_date));
  
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
      xlog('Error getting data from BI report for Items');
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
  
    xlog('Looping thru the values');
  
    -- Loop thru the records
    xout(' ');
    for c_rec in (select xt.*
                    from xmltable('/DATA_DS/G_1' passing l_resp_xml_id columns
                                  
                                  organization_id number path 'ORGANIZATION_ID',
                                  inventory_item_id number path 'INVENTORY_ITEM_ID',
                                  item_number varchar2(100) path 'ITEM_NUMBER',
                                  description varchar2(500) path 'DESCRIPTION',
                                  primary_uom_code varchar2(100) path 'PRIMARY_UOM_CODE',
                                  inventory_item_flag varchar2(1) path 'INVENTORY_ITEM_FLAG',
                                  cost_category_code varchar2(30) path 'COST_CATEGORY_CODE',
                                  last_update_date varchar2(100) path 'LAST_UPDATE_DATE') xt) loop
    
      l_count := l_count + 1;
    
      xout(c_rec.item_number || ', ' || c_rec.organization_id);
    
      l_row.organization_id     := c_rec.organization_id;
      l_row.inventory_item_id   := c_rec.inventory_item_id;
      l_row.item_number         := c_rec.item_number;
      l_row.description         := c_rec.description;
      l_row.primary_uom_code    := c_rec.primary_uom_code;
      l_row.inventory_item_flag := c_rec.inventory_item_flag;
      l_row.cost_category_code  := c_rec.cost_category_code;
      l_row.last_update_date    := xml_char_to_date(c_rec.last_update_date);
      l_row.downloaded_date     := sysdate;
    
      delete from xxdl_egp_system_items
       where organization_id = c_rec.organization_id
         and inventory_item_id = c_rec.inventory_item_id;
    
      insert into xxdl_egp_system_items values l_row;
    
    end loop;
  
    xout('Items downloaded: ' || l_count);
    xout('*** End of report ***');
  
    xlog('Procedure download_items ended');
  
  exception
    when e_processing_exception then
      xlog('e_processing_exception risen');
      xxdl_report_pkg.set_has_errors(g_report_id);
    
    when others then
      xxdl_report_pkg.set_has_errors(g_report_id);
      elog('SQLERRM: ' || sqlerrm);
      elog('BACKTRACE: ' || dbms_utility.format_error_backtrace);
      raise;
  end;

  /*===========================================================================+
  Procedure   : process_transactions_interface
  Description : Processes Transactions interface
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure process_transactions_interface(p_batch_id number) as
  
    cursor cur_transactions is
      select *
        from xxdl_inv_material_txns_int
       where status = 'NEW'
         and batch_id = p_batch_id;
  
    l_return_status       varchar2(10);
    l_return_message      varchar2(32000);
    l_ws_call_id          number;
    l_rest_env_template   varchar2(2000);
    l_rest_env            varchar2(2000);
    l_status              varchar2(10);
    l_fusion_interface_id number;
  
    l_use_current_cost_flag varchar2(10);
    l_org                   varchar2(2000);
  
    l_trans_error_message varchar2(2000);
    l_trans_status        varchar2(10);
    l_error_code          varchar2(100);
    l_error_explanation   varchar2(2000);
  begin
  
    xlog('Procedure process_transactions_interface started');
  
    xxdl_report_pkg.create_report(p_report_type => 'Process Transactions Interface',
                                  p_report_name => 'Process Transactions Interface Batch id: ' || p_batch_id,
                                  x_report_id   => g_report_id);
  
    xout('*** Process Transactions Interface ***');
    xout('Batch id: ' || p_batch_id);
    xout('Processing transactions:');
    xout('-----------------------');
  
    l_rest_env_template := '{
          "OrganizationName": "[OrganizationName]",
          "ItemNumber": "[ItemNumber]",
          "TransactionTypeName": "[TransactionTypeName]",
          "TransactionQuantity": "[TransactionQuantity]",
          "TransactionUnitOfMeasure": "[TransactionUnitOfMeasure]",
          "TransactionInterfaceId": "[TransactionInterfaceId]",
          "TransactionDate": "[TransactionDate]",
          "TransactionHeaderId": "[TransactionHeaderId]",
          "SubinventoryCode": "[SubinventoryCode]",
          "LocatorName": "[LocatorName]",
          "trackingAttributesDFF": [{
              "projectId_Display": "[InvProjectNumber]",
              "taskId_Display": "[InvTaskNumber]"
              }],
          "AccountCombination": "[AccountCombination]",
          "SourceCode": "[SourceCode]",
          "SourceLineId": "[SourceLineId]",
          "SourceHeaderId": "[SourceHeaderId]",
          "UseCurrentCostFlag": "[UseCurrentCostFlag]",
          "TransactionCost": "[TransactionCost]",
          "TransactionCostIdentifier": "[TransactionCostIdentifier]",
          "TransactionReference": "[TransactionReference]",
          "TransactionMode": "1",
          "costs": [
              {
                  "CostComponentCode": "ITEM_PRICE",
                  "Cost": [TransactionCost]
              }
          ]
      }';
  
    xout(rpad('Trans. id', 10) || ' ' || rpad('Transaction type', 40) || ' ' || rpad('Status', 10) || 'Error message');
    xout(rpad('--------------', 10) || ' ' || rpad('----------------', 40) || ' ' || rpad('------', 10) || '-------------');
  
    for c_trans in cur_transactions loop
    
      begin
      
        --Lock the record by setting the status
        update xxdl_inv_material_txns_int i
           set i.status = 'IN_PROGRESS', i.last_update_date = sysdate
         where i.transaction_interface_id = c_trans.transaction_interface_id;
      
        -- Default Transaction status is PORCESSED
        -- If error appeares it would change status end error message
        l_trans_status        := 'PROCESSED';
        l_trans_error_message := null;
      
        xlog('c_trans.transaction_interface_id: ' || c_trans.transaction_interface_id);
      
        if c_trans.use_current_cost_flag = 'Y' then
          l_use_current_cost_flag := 'true';
        else
          l_use_current_cost_flag := 'false';
        end if;
      
        l_fusion_interface_id := xxdl_inv_material_txns_fus_s1.nextval;
      
        l_rest_env := l_rest_env_template;
        l_rest_env := replace(l_rest_env, '[OrganizationName]', apex_escape.json(c_trans.organization_name));
        l_rest_env := replace(l_rest_env, '[ItemNumber]', apex_escape.json(c_trans.item_number));
        l_rest_env := replace(l_rest_env, '[TransactionTypeName]', apex_escape.json(c_trans.transaction_type_name));
        l_rest_env := replace(l_rest_env, '[TransactionQuantity]', apex_escape.json(c_trans.transaction_quantity));
        l_rest_env := replace(l_rest_env, '[TransactionUnitOfMeasure]', apex_escape.json(c_trans.transaction_uom));
        l_rest_env := replace(l_rest_env, '[TransactionInterfaceId]', apex_escape.json(l_fusion_interface_id));
        l_rest_env := replace(l_rest_env, '[TransactionDate]', json_date_to_char(c_trans.transaction_date));
        l_rest_env := replace(l_rest_env, '[TransactionHeaderId]', apex_escape.json(l_fusion_interface_id));
        l_rest_env := replace(l_rest_env, '[SubinventoryCode]', apex_escape.json(c_trans.subinventory_code));
        l_rest_env := replace(l_rest_env, '[LocatorName]', apex_escape.json(c_trans.locator_name));
        l_rest_env := replace(l_rest_env, '[InvProjectNumber]', apex_escape.json(c_trans.inv_project_number));
        l_rest_env := replace(l_rest_env, '[InvTaskNumber]', apex_escape.json(c_trans.inv_task_number));
        l_rest_env := replace(l_rest_env, '[AccountCombination]', apex_escape.json(c_trans.account_combination));
        l_rest_env := replace(l_rest_env, '[SourceCode]', apex_escape.json(l_fusion_interface_id));
        l_rest_env := replace(l_rest_env, '[SourceLineId]', apex_escape.json(l_fusion_interface_id));
        l_rest_env := replace(l_rest_env, '[SourceHeaderId]', apex_escape.json(l_fusion_interface_id));
        l_rest_env := replace(l_rest_env, '[UseCurrentCostFlag]', apex_escape.json(l_use_current_cost_flag));
        l_rest_env := replace(l_rest_env, '[TransactionCost]', apex_escape.json(c_trans.transaction_cost));
        l_rest_env := replace(l_rest_env, '[TransactionCostIdentifier]', apex_escape.json('C' || l_fusion_interface_id));
        l_rest_env := replace(l_rest_env, '[TransactionReference]', apex_escape.json(c_trans.transaction_reference));
      
        xxfn_cloud_ws_pkg.ws_rest_call(p_ws_url         => xxdl_config_pkg.servicerooturl ||
                                                           '/fscmRestApi/resources/11.13.18.05/inventoryStagedTransactions',
                                       p_rest_env       => l_rest_env,
                                       p_rest_act       => 'POST',
                                       p_content_type   => 'application/json;charset="UTF-8"',
                                       x_return_status  => l_return_status,
                                       x_return_message => l_return_message,
                                       x_ws_call_id     => l_ws_call_id);
      
        --dbms_lob.freetemporary(l_rest_env);
        xlog('l_ws_call_id:     ' || l_ws_call_id || ' (POST inventoryStagedTransactions)');
        xlog('l_return_status:  ' || l_return_status);
      
        if l_return_status != 'S' then
          elog('*** Error creating inventory transaction');
          elog('l_return_message: ' || l_return_message);
          elog('l_ws_call_id: ' || l_ws_call_id);
        
          l_trans_status        := 'ERROR';
          l_trans_error_message := 'Error during REST API Call. l_ws_call_id: ' || l_ws_call_id || ' l_return_message: ' ||
                                   substr(l_return_message, 1, 1800);
        
          raise e_processing_exception;
        
        end if;
      
        xlog('Checking for errors in REST response');
      
        select json_value(wc.response_json, '$.ErrorCode'),
               json_value(wc.response_json, '$.ErrorExplanation')
          into l_error_code,
               l_error_explanation
          from xxfn_ws_call_log wc
         where wc.ws_call_id = l_ws_call_id;
      
        if l_error_code is not null or l_error_explanation is not null then
          xlog('Error in json response');
          l_trans_error_message := l_error_code || ' ' || l_error_explanation;
          raise e_processing_exception;
        end if;
      
        l_trans_status := 'PROCESSED';
      
      exception
        when e_processing_exception then
          xlog('e_processing_exception');
          l_trans_status := 'ERROR';
        
        when others then
          xlog('When OTHERS reached at transaction level');
          l_trans_status        := 'ERROR';
          l_trans_error_message := sqlerrm;
          elog('SQLERRM: ' || sqlerrm);
          elog('BACKTRACE: ' || dbms_utility.format_error_backtrace);
      end;
    
      xout(rpad(c_trans.transaction_interface_id, 10) || ' ' || rpad(c_trans.transaction_type_name, 40) || ' ' || rpad(l_trans_status, 10) ||
           l_trans_error_message);
    
      if l_trans_status = 'ERROR' then
        xxdl_report_pkg.set_has_errors(g_report_id);
      end if;
    
      xlog('Saving transaction status');
      update xxdl_inv_material_txns_int i
         set i.status = l_trans_status, i.error_message = l_trans_error_message, i.last_update_date = sysdate
       where i.transaction_interface_id = c_trans.transaction_interface_id;
    
      -- Commit is required after each record to reflect Cloud transaction status
      commit;
    
    end loop;
    xout('*** End of report ***');
    xlog('Procedure process_transactions_interface ended');
  exception
    when others then
      elog('*** OTHERS unhandled exception');
      elog('SQLERRM: ' || sqlerrm);
      elog('BACKTRACE: ' || dbms_utility.format_error_backtrace);
      raise;
  end;

end;
/
