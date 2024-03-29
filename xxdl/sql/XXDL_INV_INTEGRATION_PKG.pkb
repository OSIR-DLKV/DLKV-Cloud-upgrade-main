create or replace package body xxdl_inv_integration_pkg is
  /* $Header $
  ============================================================================+
  File Name   : XXDL_INV_INTEGRATION_PKG.pks
  Object      : XXDL_INV_INTEGRATION_PKG
  Description : Package to Inventory integrations 
  History     :
  v1.0 15.07.2022 Marko Sladoljev: Inicijalna verzija
  v1.1 22.12.2022 Marko Sladoljev: Verzija za PROD
  v1.2 06.01.2022 Marko Sladoljev: Izmjene nakon testiranja s reflection - pragma autonomous removed
  v1.3 17.01.2022 Marko Sladoljev: download_mig_transactions
  v1.4 02.02.2022 Marko Sladoljev: Error logging added
  v1.5 24.03.2023 Marko Sladoljev: Transaction processing order by batch_id, transaction date
  v1.6 06.04.2023 Marko Sladoljev: Download entiteta po datumu u natrag
  v1.7 05.05.2023 Marko Sladoljev: New columns: source_header_number, source_line_number
  ============================================================================+*/

  -- Log variables
  c_module constant varchar2(100) := 'XXDL_INV_INTEGRATION_PKG';
  --g_log_level varchar2(10) := xxdl_log_pkg.g_level_statement; -- Use temporarily for detailed logging
  g_log_level    varchar2(10) := xxdl_log_pkg.g_level_error; -- Regular error only logging
  g_last_message varchar2(32000);
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
      --dbms_output.put_line(to_char(sysdate, 'dd.mm.yyyy hh24:mi:ss') || '| ' || p_text);
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
      Procedure   : format_number
      Description : formats number for XML/SJON
  ============================================================================+*/
  function format_number(p_number number) return varchar2 is
  begin
    return to_char(p_number, 'FM999999999999999999990.0999999999999');
  end;

  /*===========================================================================+
  Procedure   : elog
  Description : Log an error level message 
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure elog(p_text in varchar2) as
  begin
    --dbms_output.put_line(to_char(sysdate, 'dd.mm.yyyy hh24:mi:ss') || '| ' || p_text);
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
  function xml_date_to_char(p_date date) return varchar2 as
    l_char varchar2(100);
  begin
    return to_char(cast(p_date as timestamp with time zone) at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM');
  end;

  /*===========================================================================+
  Procedure   : timestamp_to_char
  Description : Converts timestamp to string
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  function timestamp_to_char(p_date timestamp) return varchar2 as
    l_char varchar2(100);
  begin
    return to_char(p_date, 'DD-MM-YYYY HH24:MI:SSxFF');
  end;
  /*===========================================================================+
  Procedure   : timestamp_to_char
  Description : Converts timestamp to string
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  function char_to_timestamp(p_date varchar2) return timestamp as
    l_char varchar2(100);
  begin
    return to_timestamp(p_date, 'DD-MM-YYYY HH24:MI:SSxFF');
  end;

  /*===========================================================================+
  Procedure   : download_avg_item_cst
  Description : Downloads items average cost from Fusion to XE database
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure download_avg_item_cst(p_from_timestamp timestamp default null) is
  
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
  
    l_last_update_date timestamp;
  
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
      l_last_update_date := to_timestamp('1-1-1900', 'dd-mm-yyyy');
    end if;
  
    if p_from_timestamp is not null then
      l_last_update_date := p_from_timestamp;
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
  
    l_text := replace(l_text, '[P_LAST_UPDATE_DATE]', timestamp_to_char(l_last_update_date));
  
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
  
    xlog('l_ws_call_id: ' || l_ws_call_id);
  
    dbms_lob.freetemporary(l_soap_env);
  
    xlog('x_return_status: ' || l_return_status);
    if (l_return_status != 'S') then
      elog('Error getting data from BI report for Average Items Costs');
      elog('l_return_message: ' || l_return_message);
      raise e_processing_exception;
    end if;
  
    xlog('Extracting xml response');
  
    begin
      select response_xml into l_resp_xml from xxfn_ws_call_log_v where ws_call_id = l_ws_call_id;
    exception
      when no_data_found then
        elog('Error extracting xml from the response');
        elog('l_ws_call_id: ' || l_ws_call_id);
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
        elog('ws_call_id: ' || l_ws_call_id);
        raise e_processing_exception;
    end;
  
    l_result_clob_decode := xxfn_cloud_ws_pkg.decodebase64(l_result_clob);
  
    xlog(to_char(dbms_lob.substr(l_result_clob_decode, 1000, 1)));
  
    l_resp_xml_id := xmltype.createxml(l_result_clob_decode);
  
    xlog('Looping thru the  values');
  
    -- Loop thru the records
    xout(' ');
    for c_rec in (select xt.*
                    from xmltable('/DATA_DS/G_1' passing l_resp_xml_id columns
                                  
                                  inventory_item_id number path 'INVENTORY_ITEM_ID',
                                  val_unit_code varchar2(100) path 'VAL_UNIT_CODE',
                                  inv_organization_id number path 'INV_ORGANIZATION_ID',
                                  cost_org_code varchar2(100) path 'COST_ORG_CODE',
                                  inv_org_code varchar2(100) path 'INV_ORG_CODE',
                                  project_number varchar2(100) path 'PROJECT_NUMBER',
                                  unit_cost_average number path 'UNIT_COST_AVERAGE',
                                  quantity_onhand number path 'QUANTITY_ONHAND',
                                  uom_code varchar2(30) path 'UOM_CODE',
                                  last_update_date_char varchar2(100) path 'LAST_UPDATE_DATE_CHAR') xt) loop
    
      l_count := l_count + 1;
    
      if l_count < 10 then
        xout(c_rec.inventory_item_id || ', ' || c_rec.val_unit_code);
      elsif l_count = 10 then
        xout('More records exists...');
      else
        null;
      end if;
    
      l_row.inventory_item_id   := c_rec.inventory_item_id;
      l_row.val_unit_code       := c_rec.val_unit_code;
      l_row.inv_organization_id := c_rec.inv_organization_id;
      l_row.cost_org_code       := c_rec.cost_org_code;
      l_row.inv_org_code        := c_rec.inv_org_code;
      l_row.project_number      := c_rec.project_number;
      l_row.unit_cost_average   := c_rec.unit_cost_average;
      l_row.quantity_onhand     := c_rec.quantity_onhand;
      l_row.uom_code            := c_rec.uom_code;
      l_row.last_update_date    := char_to_timestamp(c_rec.last_update_date_char);
    
      l_row.downloaded_date := sysdate;
    
      delete from xxdl_avg_item_cost
       where inventory_item_id = c_rec.inventory_item_id
         and val_unit_code = c_rec.val_unit_code;
    
      insert into xxdl_avg_item_cost values l_row;
    
    end loop;
  
    -- Delete lobs after successful call
    xxfn_cloud_ws_pkg.delete_lobs_from_log(l_ws_call_id);
  
    xout('Item costs downloaded: ' || l_count);
    xout('*** End of report ***');
  
    xlog('Procedure download_avg_item_cst ended');
  
  exception
    when e_processing_exception then
      elog('e_processing_exception risen');
      xxdl_report_pkg.set_has_errors(g_report_id);
    
    when others then
      xxdl_report_pkg.set_has_errors(g_report_id);
      elog('SQLERRM: ' || sqlerrm);
      elog('BACKTRACE: ' || dbms_utility.format_error_backtrace);
      raise;
  end;

  /*===========================================================================+
  Procedure   : download_mig_transactions
  Description : Downloads migration inventory transactions from Fusion to XE database (XXDL_MIG_MATERIAL_CHECK)
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure download_mig_transactions is
  
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
  
    l_row xxdl_mig_material_check%rowtype;
  
    l_count number;
  
    -- l_last_transaction_id number;
  
    l_last_creation_date timestamp;
  
  begin
  
    xlog('Procedure download_mig_transactions started');
  
    xxdl_report_pkg.create_report(p_report_type => 'Download Fusion Table',
                                  p_report_name => 'Download Material Transactions',
                                  x_report_id   => g_report_id);
  
    xout('*** Download Material Transactions ***');
    xout('');
  
    xlog('Getting last transaction_id');
    select max(creation_date) into l_last_creation_date from xxdl_mig_material_check;
  
    if l_last_creation_date is null then
      l_last_creation_date := to_timestamp('1-1-1900', 'dd-mm-yyyy');
    end if;
  
    -- To force dowbnloading all transactions
    --l_last_creation_date := to_timestamp('1-1-1900', 'dd-mm-yyyy');
  
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
                                <pub:name>p_creation_date</pub:name>
                                <pub:values>
                                    <pub:item>[P_CREATION_DATE]</pub:item>
                                </pub:values>
                            </pub:item>
                        </pub:parameterNameValues>
                        <pub:reportAbsolutePath>Custom/XXDL_INV_Integration/XXDL_MIG_MATERIAL_CHECK_REP.xdo</pub:reportAbsolutePath>
                        <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
                    </pub:reportRequest>
                    <pub:appParams></pub:appParams>
                </pub:runReport>
            </soap:Body>
        </soap:Envelope>';
  
    l_text := replace(l_text, '[P_CREATION_DATE]', timestamp_to_char(l_last_creation_date));
  
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
  
    xlog('l_ws_call_id: ' || l_ws_call_id);
  
    dbms_lob.freetemporary(l_soap_env);
  
    xlog('x_return_status: ' || l_return_status);
    if (l_return_status != 'S') then
      elog('Error getting data from BI report for Inventory transaction');
      elog('l_return_message: ' || l_return_message);
      elog('l_ws_call_id: ' || l_ws_call_id);
      raise e_processing_exception;
    end if;
  
    xlog('Extracting xml response');
  
    begin
      select response_xml into l_resp_xml from xxfn_ws_call_log_v where ws_call_id = l_ws_call_id;
    exception
      when no_data_found then
        elog('Error extracting xml from the response');
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
        elog('ws_call_id: ' || l_ws_call_id);
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
                                  organization_id number path 'ORGANIZATION_ID',
                                  subinventory_code varchar2(10) path 'SUBINVENTORY_CODE',
                                  transaction_type_id number path 'TRANSACTION_TYPE_ID',
                                  transaction_action_id number path 'TRANSACTION_ACTION_ID',
                                  transaction_source_type_id number path 'TRANSACTION_SOURCE_TYPE_ID',
                                  transaction_source_id number path 'TRANSACTION_SOURCE_ID',
                                  transaction_quantity number path 'TRANSACTION_QUANTITY',
                                  transaction_uom varchar2(3) path 'TRANSACTION_UOM',
                                  primary_quantity number path 'PRIMARY_QUANTITY',
                                  transaction_date varchar2(100) path 'TRANSACTION_DATE',
                                  transaction_reference varchar2(240) path 'TRANSACTION_REFERENCE',
                                  shipment_number varchar2(100) path 'SHIPMENT_NUMBER',
                                  receipt_num varchar2(100) path 'RECEIPT_NUM',
                                  transfer_organization_id number path 'TRANSFER_ORGANIZATION_ID',
                                  transfer_transaction_id number path 'TRANSFER_TRANSACTION_ID',
                                  rcv_transaction_id number path 'RCV_TRANSACTION_ID',
                                  parent_transaction_id number path 'PARENT_TRANSACTION_ID',
                                  po_number varchar2(100) path 'PO_NUMBER',
                                  po_approved_date varchar2(100) path 'PO_APPROVED_DATE',
                                  po_unit_price number path 'PO_UNIT_PRICE',
                                  po_party_site_number varchar2(100) path 'PO_PARTY_SITE_NUMBER',
                                  creation_date_char varchar2(100) path 'CREATION_DATE_CHAR',
                                  created_by varchar2(64) path 'CREATED_BY') xt
                   order by transaction_id) loop
    
      l_count := l_count + 1;
    
      xout(c_rec.transaction_id || ', ' || c_rec.transaction_quantity || ' ' || c_rec.transaction_uom);
    
      l_row.transaction_id             := c_rec.transaction_id;
      l_row.inventory_item_id          := c_rec.inventory_item_id;
      l_row.organization_id            := c_rec.organization_id;
      l_row.subinventory_code          := c_rec.subinventory_code;
      l_row.transaction_type_id        := c_rec.transaction_type_id;
      l_row.transaction_action_id      := c_rec.transaction_action_id;
      l_row.transaction_source_type_id := c_rec.transaction_source_type_id;
      l_row.transaction_source_id      := c_rec.transaction_source_id;
      l_row.transaction_quantity       := c_rec.transaction_quantity;
      l_row.transaction_uom            := c_rec.transaction_uom;
      l_row.primary_quantity           := c_rec.primary_quantity;
      l_row.transaction_date           := xml_char_to_date(c_rec.transaction_date);
      l_row.transaction_reference      := c_rec.transaction_reference;
      l_row.shipment_number            := c_rec.shipment_number;
      l_row.receipt_num                := c_rec.receipt_num;
      l_row.transfer_organization_id   := c_rec.transfer_organization_id;
      l_row.transfer_transaction_id    := c_rec.transfer_transaction_id;
      l_row.rcv_transaction_id         := c_rec.rcv_transaction_id;
      l_row.parent_transaction_id      := c_rec.parent_transaction_id;
      l_row.po_number                  := c_rec.po_number;
      l_row.po_approved_date           := xml_char_to_date(c_rec.po_approved_date);
      l_row.po_unit_price              := c_rec.po_unit_price;
      l_row.po_party_site_number       := c_rec.po_party_site_number;
      l_row.creation_date              := char_to_timestamp(c_rec.creation_date_char);
      l_row.created_by                 := c_rec.created_by;
      l_row.downloaded_date            := sysdate;
    
      select count(1) into l_count from xxdl_mig_material_check where transaction_id = l_row.transaction_id;
    
      if l_count = 0 then
        insert into xxdl_mig_material_check values l_row;
      end if;
      xout('Transactions downloaded: ' || l_count);
    
    end loop;
  
    -- Delete lobs after successful call
    xxfn_cloud_ws_pkg.delete_lobs_from_log(l_ws_call_id);
  
    xout('*** End of report ***');
  
    xlog('Procedure download_mig_transactions ended');
  
  exception
    when e_processing_exception then
      elog('e_processing_exception risen');
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
  procedure download_transactions(p_from_timestamp timestamp default null) is
  
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
  
    -- l_last_transaction_id number;
  
    l_last_creation_date timestamp;
  
  begin
  
    xlog('Procedure download_transactions started');
  
    xxdl_report_pkg.create_report(p_report_type => 'Download Fusion Table',
                                  p_report_name => 'Download Material Transactions',
                                  x_report_id   => g_report_id);
  
    xout('*** Download Material Transactions ***');
    xout('');
  
    xlog('Getting last transaction_id');
    select max(creation_date) into l_last_creation_date from xxdl_inv_material_txns;
  
    if l_last_creation_date is null then
      l_last_creation_date := to_timestamp('1-1-1900', 'dd-mm-yyyy');
    end if;
  
    if p_from_timestamp is not null then
      l_last_creation_date := p_from_timestamp;
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
                                <pub:name>p_creation_date</pub:name>
                                <pub:values>
                                    <pub:item>[P_CREATION_DATE]</pub:item>
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
  
    l_text := replace(l_text, '[P_CREATION_DATE]', timestamp_to_char(l_last_creation_date));
  
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
  
    xlog('l_ws_call_id: ' || l_ws_call_id);
  
    dbms_lob.freetemporary(l_soap_env);
  
    xlog('x_return_status: ' || l_return_status);
    if (l_return_status != 'S') then
      elog('Error getting data from BI report for Inventory transaction');
      elog('l_ws_call_id: ' || l_ws_call_id);
      elog('l_return_message: ' || l_return_message);
      raise e_processing_exception;
    end if;
  
    xlog('Extracting xml response');
  
    begin
      select response_xml into l_resp_xml from xxfn_ws_call_log_v where ws_call_id = l_ws_call_id;
    exception
      when no_data_found then
        elog('Error extracting xml from the response');
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
        elog('ws_call_id: ' || l_ws_call_id);
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
                                  organization_id number path 'ORGANIZATION_ID',
                                  subinventory_code varchar2(10) path 'SUBINVENTORY_CODE',
                                  transaction_type_id number path 'TRANSACTION_TYPE_ID',
                                  transaction_action_id number path 'TRANSACTION_ACTION_ID',
                                  transaction_source_type_id number path 'TRANSACTION_SOURCE_TYPE_ID',
                                  transaction_source_id number path 'TRANSACTION_SOURCE_ID',
                                  transaction_quantity number path 'TRANSACTION_QUANTITY',
                                  transaction_uom varchar2(3) path 'TRANSACTION_UOM',
                                  primary_quantity number path 'PRIMARY_QUANTITY',
                                  transaction_date varchar2(100) path 'TRANSACTION_DATE',
                                  transaction_reference varchar2(240) path 'TRANSACTION_REFERENCE',
                                  shipment_number varchar2(100) path 'SHIPMENT_NUMBER',
                                  receipt_num varchar2(100) path 'RECEIPT_NUM',
                                  transfer_organization_id number path 'TRANSFER_ORGANIZATION_ID',
                                  transfer_transaction_id number path 'TRANSFER_TRANSACTION_ID',
                                  rcv_transaction_id number path 'RCV_TRANSACTION_ID',
                                  parent_transaction_id number path 'PARENT_TRANSACTION_ID',
                                  po_number varchar2(100) path 'PO_NUMBER',
                                  po_approved_date varchar2(100) path 'PO_APPROVED_DATE',
                                  po_unit_price number path 'PO_UNIT_PRICE',
                                  po_party_site_number varchar2(100) path 'PO_PARTY_SITE_NUMBER',
                                  source_header_number varchar2(150) path 'SOURCE_HEADER_NUMBER',
                                  source_line_number varchar2(150) path 'SOURCE_LINE_NUMBER',
                                  creation_date_char varchar2(100) path 'CREATION_DATE_CHAR',
                                  created_by varchar2(64) path 'CREATED_BY') xt
                   order by transaction_id) loop
    
      l_count := l_count + 1;
    
      if l_count < 10 then
        xout(c_rec.transaction_id || ', ' || c_rec.transaction_quantity || ' ' || c_rec.transaction_uom);
      elsif l_count = 10 then
        xout('More records exists...');
      else
        null;
      end if;
    
      l_row.transaction_id             := c_rec.transaction_id;
      l_row.inventory_item_id          := c_rec.inventory_item_id;
      l_row.organization_id            := c_rec.organization_id;
      l_row.subinventory_code          := c_rec.subinventory_code;
      l_row.transaction_type_id        := c_rec.transaction_type_id;
      l_row.transaction_action_id      := c_rec.transaction_action_id;
      l_row.transaction_source_type_id := c_rec.transaction_source_type_id;
      l_row.transaction_source_id      := c_rec.transaction_source_id;
      l_row.transaction_quantity       := c_rec.transaction_quantity;
      l_row.transaction_uom            := c_rec.transaction_uom;
      l_row.primary_quantity           := c_rec.primary_quantity;
      l_row.transaction_date           := xml_char_to_date(c_rec.transaction_date);
      l_row.transaction_reference      := c_rec.transaction_reference;
      l_row.shipment_number            := c_rec.shipment_number;
      l_row.receipt_num                := c_rec.receipt_num;
      l_row.transfer_organization_id   := c_rec.transfer_organization_id;
      l_row.transfer_transaction_id    := c_rec.transfer_transaction_id;
      l_row.rcv_transaction_id         := c_rec.rcv_transaction_id;
      l_row.parent_transaction_id      := c_rec.parent_transaction_id;
      l_row.po_number                  := c_rec.po_number;
      l_row.po_approved_date           := xml_char_to_date(c_rec.po_approved_date);
      l_row.po_unit_price              := c_rec.po_unit_price;
      l_row.po_party_site_number       := c_rec.po_party_site_number;
      l_row.source_header_number       := c_rec.source_header_number;
      l_row.source_line_number         := c_rec.source_line_number;
      l_row.creation_date              := char_to_timestamp(c_rec.creation_date_char);
      l_row.created_by                 := c_rec.created_by;
      l_row.downloaded_date            := sysdate;
    
      select count(1) into l_count from xxdl_inv_material_txns where transaction_id = l_row.transaction_id;
    
      if l_count = 0 then
        insert into xxdl_inv_material_txns values l_row;
      end if;
    
    end loop;
  
    -- Delete lobs after successful call
    xxfn_cloud_ws_pkg.delete_lobs_from_log(l_ws_call_id);
  
    xout('Transactions downloaded: ' || l_count);
    xout('*** End of report ***');
  
    xlog('Procedure download_transactions ended');
  
  exception
    when e_processing_exception then
      elog('e_processing_exception risen');
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
  
    l_last_update_date timestamp;
  
  begin
  
    xlog('Procedure download_inv_orgs started');
  
    xxdl_report_pkg.create_report(p_report_type => 'Download Fusion Table',
                                  p_report_name => 'Download Inventory Organizations',
                                  x_report_id   => g_report_id);
  
    xout('*** Download Inventory Organizations ***');
    xout('');
  
    xlog('Getting last update date');
    select max(last_update_date) into l_last_update_date from xxdl_inv_organizations;
  
    if l_last_update_date is null then
      l_last_update_date := to_timestamp('01-01-1900', 'DD-MM-RRRR');
    end if;
    xlog('last_update_date:' || l_last_update_date);
  
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
  
    l_text := replace(l_text, '[P_LAST_UPDATE_DATE]', timestamp_to_char(l_last_update_date));
  
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
  
    xlog('l_ws_call_id: ' || l_ws_call_id);
  
    dbms_lob.freetemporary(l_soap_env);
  
    xlog('x_return_status: ' || l_return_status);
    if (l_return_status != 'S') then
      xlog('Error getting data from BI report for Inventory orgs');
      xlog('l_return_message: ' || l_return_message);
      raise e_processing_exception;
    end if;
  
    xlog('Extracting xml response');
  
    begin
      select response_xml into l_resp_xml from xxfn_ws_call_log_v where ws_call_id = l_ws_call_id;
    exception
      when no_data_found then
        elog('Error extracting xml from the response');
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
        elog('ws_call_id: ' || l_ws_call_id);
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
                                  last_update_date_char varchar2(100) path 'LAST_UPDATE_DATE_CHAR') xt) loop
    
      l_count := l_count + 1;
    
      xout(c_rec.organization_id || ', ' || c_rec.organization_code);
    
      l_row.organization_id   := c_rec.organization_id;
      l_row.organization_code := c_rec.organization_code;
      l_row.name              := c_rec.name;
      l_row.last_update_date  := char_to_timestamp(c_rec.last_update_date_char);
    
      l_row.downloaded_date := sysdate;
    
      delete from xxdl_inv_organizations where organization_id = c_rec.organization_id;
    
      insert into xxdl_inv_organizations values l_row;
    
    end loop;
  
    -- Delete lobs after successful call
    xxfn_cloud_ws_pkg.delete_lobs_from_log(l_ws_call_id);
  
    xout('Organizations downloaded: ' || l_count);
    xout('*** End of report ***');
  
    xlog('Procedure download_inv_orgs ended');
  
  exception
    when e_processing_exception then
      elog('e_processing_exception risen');
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
  procedure download_items(p_from_timestamp timestamp default null) is
  
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
  
    l_last_update_date timestamp;
  
  begin
  
    xlog('Procedure download_items started');
  
    xxdl_report_pkg.create_report(p_report_type => 'Download Fusion Table', p_report_name => 'Download Items', x_report_id => g_report_id);
  
    xout('*** Download Items ***');
    xout('');
  
    xlog('Getting last update date');
    select max(last_update_date) into l_last_update_date from xxdl_egp_system_items;
  
    if l_last_update_date is null then
      l_last_update_date := to_timestamp('01-01-1900', 'DD-MM-RRRR');
    end if;
    xlog('last_update_date:' || l_last_update_date);
  
    if p_from_timestamp is not null then
      l_last_update_date := p_from_timestamp;
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
  
    l_text := replace(l_text, '[P_LAST_UPDATE_DATE]', timestamp_to_char(l_last_update_date));
  
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
  
    xlog('l_ws_call_id: ' || l_ws_call_id);
  
    dbms_lob.freetemporary(l_soap_env);
  
    xlog('x_return_status: ' || l_return_status);
    if (l_return_status != 'S') then
      elog('Error getting data from BI report for Items');
      elog('l_return_message: ' || l_return_message);
      raise e_processing_exception;
    end if;
  
    xlog('Extracting xml response');
  
    begin
      select response_xml into l_resp_xml from xxfn_ws_call_log_v where ws_call_id = l_ws_call_id;
    exception
      when no_data_found then
        elog('Error extracting xml from the response');
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
        elog('ws_call_id: ' || l_ws_call_id);
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
                                  quality_code varchar2(100) path 'QUALITY_CODE',
                                  unit_weight varchar2(100) path 'UNIT_WEIGHT',
                                  last_update_date_char varchar2(100) path 'LAST_UPDATE_DATE_CHAR') xt) loop
    
      l_count := l_count + 1;
    
      if l_count < 10 then
        xout(c_rec.item_number || ', ' || c_rec.organization_id);
      elsif l_count = 10 then
        xout('More records exists...');
      else
        null;
      end if;
    
      l_row.organization_id     := c_rec.organization_id;
      l_row.inventory_item_id   := c_rec.inventory_item_id;
      l_row.item_number         := c_rec.item_number;
      l_row.description         := c_rec.description;
      l_row.primary_uom_code    := c_rec.primary_uom_code;
      l_row.inventory_item_flag := c_rec.inventory_item_flag;
      l_row.cost_category_code  := c_rec.cost_category_code;
      l_row.quality_code        := c_rec.quality_code;
      l_row.unit_weight         := c_rec.unit_weight;
      l_row.last_update_date    := char_to_timestamp(c_rec.last_update_date_char);
      l_row.downloaded_date     := sysdate;
    
      delete from xxdl_egp_system_items
       where organization_id = c_rec.organization_id
         and inventory_item_id = c_rec.inventory_item_id;
    
      insert into xxdl_egp_system_items values l_row;
    
    end loop;
  
    -- Delete lobs after successful call
    xxfn_cloud_ws_pkg.delete_lobs_from_log(l_ws_call_id);
  
    xout('Items downloaded: ' || l_count);
    xout('*** End of report ***');
  
    xlog('Procedure download_items ended');
  
  exception
    when e_processing_exception then
      elog('e_processing_exception risen');
      xxdl_report_pkg.set_has_errors(g_report_id);
    
    when others then
      xxdl_report_pkg.set_has_errors(g_report_id);
      elog('SQLERRM: ' || sqlerrm);
      elog('BACKTRACE: ' || dbms_utility.format_error_backtrace);
      raise;
  end;

  /*===========================================================================+
  Procedure   : process_transactions_int_job
  Description : Processes all transactions interface batches
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure process_transactions_int_all as
    cursor cur_batch is
      select distinct batch_id from xxdl_inv_material_txns_int where status = 'NEW' order by batch_id;
  begin
    xlog('process_transactions_int_job started');
    for c_batch in cur_batch loop
      process_transactions_interface(p_batch_id => c_batch.batch_id);
    end loop;
    xlog('process_transactions_int_job ended');
  
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
        from xxdl_inv_material_txns_int i
       where status = 'NEW'
         and batch_id = p_batch_id
       order by i.transaction_date;
  
    l_return_status       varchar2(10);
    l_return_message      varchar2(32000);
    l_ws_call_id          number;
    l_rest_env_template   varchar2(2000);
    l_rest_cost_template  varchar2(2000);
    l_rest_env            varchar2(2000);
    l_status              varchar2(10);
    l_fusion_interface_id number;
  
    l_use_current_cost_flag varchar2(10);
    l_org                   varchar2(2000);
  
    l_trans_error_message varchar2(2000);
    l_trans_status        varchar2(10);
    l_error_code          varchar2(100);
    l_error_explanation   varchar2(2000);
  
    l_response_clob clob;
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
          "TransactionReference": "[TransactionReference]",
          "TransactionMode": "1"[COST_TEMPLATE]         
      }';
  
    l_rest_cost_template := ',
          "TransactionCost": "[TransactionCost]",
          "TransactionCostIdentifier": "[TransactionCostIdentifier]",
          "costs": [
              {
                  "CostComponentCode": "ITEM_PRICE",
                  "Cost": [TransactionCost]
              }
          ]';
  
    xout(rpad('Trans. id', 10) || ' ' || rpad('Transaction type', 40) || ' ' || rpad('Status', 10) || 'Error message');
    xout(rpad('--------------', 10) || ' ' || rpad('----------------', 40) || ' ' || rpad('------', 10) || '-------------');
  
    for c_trans in cur_transactions loop
    
      begin
      
        xlog('c_trans.transaction_interface_id: ' || c_trans.transaction_interface_id);
      
        --Lock the record by setting the status
        update xxdl_inv_material_txns_int i
           set i.status = 'IN_PROGRESS', i.last_update_date = sysdate
         where i.transaction_interface_id = c_trans.transaction_interface_id
           and status = 'NEW';
      
        if sql%rowcount = 0 then
          xlog('Transaction processed already');
          continue;
        end if;
      
        commit;
      
        -- Default Transaction status is PROCESSED
        -- If error appeares it would change status end error message
        l_trans_status        := 'PROCESSED';
        l_trans_error_message := null;
      
        xlog('c_trans.transaction_interface_id: ' || c_trans.transaction_interface_id);
      
        if c_trans.use_current_cost_flag = 'Y' then
          l_use_current_cost_flag := 'true';
        else
          l_use_current_cost_flag := 'false';
        end if;
      
        ------------------------
        -- Custom validations --
        ------------------------
      
        -- Locatator specified?
        if c_trans.locator_name is null then
          elog('*** Locator is null');
          l_trans_status        := 'ERROR';
          l_trans_error_message := 'Please specify locator';
          raise e_processing_exception;
        end if;
      
        l_fusion_interface_id := xxdl_inv_material_txns_fus_s1.nextval;
      
        l_rest_env := l_rest_env_template;
      
        if c_trans.use_current_cost_flag = 'N' then
          l_rest_env := replace(l_rest_env, '[COST_TEMPLATE]', l_rest_cost_template);
        else
          l_rest_env := replace(l_rest_env, '[COST_TEMPLATE]', '');
        end if;
      
        l_rest_env := replace(l_rest_env, '[OrganizationName]', apex_escape.json(c_trans.organization_name));
        l_rest_env := replace(l_rest_env, '[ItemNumber]', apex_escape.json(c_trans.item_number));
        l_rest_env := replace(l_rest_env, '[TransactionTypeName]', apex_escape.json(c_trans.transaction_type_name));
        l_rest_env := replace(l_rest_env, '[TransactionQuantity]', format_number(c_trans.transaction_quantity));
        l_rest_env := replace(l_rest_env, '[TransactionUnitOfMeasure]', apex_escape.json(c_trans.transaction_uom));
        l_rest_env := replace(l_rest_env, '[TransactionInterfaceId]', apex_escape.json(l_fusion_interface_id));
        l_rest_env := replace(l_rest_env, '[TransactionDate]', xml_date_to_char(c_trans.transaction_date));
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
        l_rest_env := replace(l_rest_env, '[TransactionCost]', format_number(c_trans.transaction_cost));
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
        
          select response_clob into l_response_clob from xxfn_ws_call_log wc where wc.ws_call_id = l_ws_call_id;
        
          l_trans_status        := 'ERROR';
          l_trans_error_message := to_char(dbms_lob.substr(l_response_clob, 2000, 1));
          l_trans_error_message := l_trans_error_message || ' (ws_call_id: ' || l_ws_call_id || ')';
        
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
          elog('Error in json response');
          l_trans_error_message := l_error_code || ' ' || l_error_explanation;
          raise e_processing_exception;
        end if;
      
        l_trans_status := 'PROCESSED';
      
        -- Delete lobs after successful call
        xxfn_cloud_ws_pkg.delete_lobs_from_log(l_ws_call_id);
      
      exception
        when e_processing_exception then
          elog('e_processing_exception');
          l_trans_status := 'ERROR';
        
        when others then
          elog('When OTHERS reached at transaction level');
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

  /*===========================================================================+
  Procedure   : download_transaction_types
  Description : Downloads inventory transaction types from Fusion to XE
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure download_transaction_types is
  
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
  
    l_row xxdl_inv_transaction_types%rowtype;
  
    l_count number;
  
    l_last_update_date timestamp;
  
  begin
  
    xlog('Procedure download_inv_orgs started');
  
    xxdl_report_pkg.create_report(p_report_type => 'Download Fusion Table',
                                  p_report_name => 'Download Transaction Types',
                                  x_report_id   => g_report_id);
  
    xout('*** Download Inventory Transaction Types ***');
    xout('');
  
    xlog('Getting last update date');
    select max(last_update_date) into l_last_update_date from xxdl_inv_transaction_types;
  
    if l_last_update_date is null then
      l_last_update_date := to_timestamp('01-01-1900', 'DD-MM-RRRR');
    end if;
    xlog('last_update_date:' || l_last_update_date);
  
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
                        <pub:reportAbsolutePath>Custom/XXDL_INV_Integration/XXDL_INV_TRANSACTION_TYPES_REP.xdo</pub:reportAbsolutePath>
                        <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
                    </pub:reportRequest>
                    <pub:appParams></pub:appParams>
                </pub:runReport>
            </soap:Body>
        </soap:Envelope>';
  
    l_text := replace(l_text, '[P_LAST_UPDATE_DATE]', timestamp_to_char(l_last_update_date));
  
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
  
    xlog('l_ws_call_id: ' || l_ws_call_id);
  
    dbms_lob.freetemporary(l_soap_env);
  
    xlog('x_return_status: ' || l_return_status);
    if (l_return_status != 'S') then
      xlog('Error getting data from BI report for Inventory trx types');
      xlog('l_return_message: ' || l_return_message);
      raise e_processing_exception;
    end if;
  
    xlog('Extracting xml response');
  
    begin
      select response_xml into l_resp_xml from xxfn_ws_call_log_v where ws_call_id = l_ws_call_id;
    exception
      when no_data_found then
        elog('Error extracting xml from the response');
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
        elog('ws_call_id: ' || l_ws_call_id);
        raise e_processing_exception;
    end;
  
    l_result_clob_decode := xxfn_cloud_ws_pkg.decodebase64(l_result_clob);
  
    xlog(to_char(dbms_lob.substr(l_result_clob_decode, 1000, 1)));
  
    l_resp_xml_id := xmltype.createxml(l_result_clob_decode);
  
    xlog('Looping thru the  values');
  
    -- Loop thru the records
    xout(' ');
    for c_rec in (select xt.*
                    from xmltable('/DATA_DS/G_1' passing l_resp_xml_id columns
                                  
                                  transaction_type_id number path 'TRANSACTION_TYPE_ID',
                                  transaction_type_name_hr varchar2(80) path 'TRANSACTION_TYPE_NAME_HR',
                                  transaction_type_name_us varchar2(80) path 'TRANSACTION_TYPE_NAME_US',
                                  trans_type_code varchar2(240) path 'TRANS_TYPE_CODE',
                                  dlkv_code varchar2(240) path 'DLKV_CODE',
                                  last_update_date_char varchar2(100) path 'LAST_UPDATE_DATE_CHAR') xt) loop
    
      l_count := l_count + 1;
    
      xout(c_rec.transaction_type_id || ', ' || c_rec.transaction_type_name_hr);
    
      l_row.transaction_type_id      := c_rec.transaction_type_id;
      l_row.transaction_type_name_hr := c_rec.transaction_type_name_hr;
      l_row.transaction_type_name_us := c_rec.transaction_type_name_us;
      l_row.trans_type_code          := c_rec.trans_type_code;
      l_row.dlkv_code                := c_rec.dlkv_code;
      l_row.last_update_date         := char_to_timestamp(c_rec.last_update_date_char);
      l_row.downloaded_date          := sysdate;
    
      delete from xxdl_inv_transaction_types where transaction_type_id = c_rec.transaction_type_id;
    
      insert into xxdl_inv_transaction_types values l_row;
    
    end loop;
  
    -- Delete lobs after successful call
    xxfn_cloud_ws_pkg.delete_lobs_from_log(l_ws_call_id);
  
    xout('Transaction types downloaded: ' || l_count);
    xout('*** End of report ***');
  
    xlog('Procedure download_inv_orgs ended');
  
  exception
    when e_processing_exception then
      elog('e_processing_exception risen');
      xxdl_report_pkg.set_has_errors(g_report_id);
    
    when others then
      xxdl_report_pkg.set_has_errors(g_report_id);
      elog('SQLERRM: ' || sqlerrm);
      elog('BACKTRACE: ' || dbms_utility.format_error_backtrace);
      raise;
  end;

  /*===========================================================================+
  Procedure   : download_item_relations
  Description : Downloads inventory item relationships from Fusion to XE
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure download_item_relations(p_from_timestamp timestamp default null) is
  
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
  
    l_row xxdl_egp_item_relations%rowtype;
  
    l_count number;
  
    l_last_update_date timestamp;
  
  begin
  
    xlog('Procedure download_item_relations started');
  
    xxdl_report_pkg.create_report(p_report_type => 'Download Fusion Table',
                                  p_report_name => 'Download Item Relationships',
                                  x_report_id   => g_report_id);
  
    xout('*** Download Item Relationships ***');
    xout('');
  
    xlog('Getting last update date');
    select max(last_update_date) into l_last_update_date from xxdl_egp_item_relations;
  
    if l_last_update_date is null then
      l_last_update_date := to_timestamp('01-01-1900', 'DD-MM-RRRR');
    end if;
    xlog('last_update_date:' || l_last_update_date);
  
    if p_from_timestamp is not null then
      l_last_update_date := p_from_timestamp;
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
                        <pub:reportAbsolutePath>Custom/XXDL_INV_Integration/XXDL_EGP_ITEM_RELATIONS_REP.xdo</pub:reportAbsolutePath>
                        <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
                    </pub:reportRequest>
                    <pub:appParams></pub:appParams>
                </pub:runReport>
            </soap:Body>
        </soap:Envelope>';
  
    l_text := replace(l_text, '[P_LAST_UPDATE_DATE]', timestamp_to_char(l_last_update_date));
  
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
  
    xlog('l_ws_call_id: ' || l_ws_call_id);
  
    dbms_lob.freetemporary(l_soap_env);
  
    xlog('x_return_status: ' || l_return_status);
    if (l_return_status != 'S') then
      xlog('Error getting data from BI report for item relations');
      xlog('l_return_message: ' || l_return_message);
      raise e_processing_exception;
    end if;
  
    xlog('Extracting xml response');
  
    begin
      select response_xml into l_resp_xml from xxfn_ws_call_log_v where ws_call_id = l_ws_call_id;
    exception
      when no_data_found then
        elog('Error extracting xml from the response');
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
        elog('ws_call_id: ' || l_ws_call_id);
        raise e_processing_exception;
    end;
  
    l_result_clob_decode := xxfn_cloud_ws_pkg.decodebase64(l_result_clob);
  
    xlog(to_char(dbms_lob.substr(l_result_clob_decode, 1000, 1)));
  
    l_resp_xml_id := xmltype.createxml(l_result_clob_decode);
  
    xlog('Looping thru the  values');
  
    -- Loop thru the records
    xout(' ');
    for c_rec in (select xt.*
                    from xmltable('/DATA_DS/G_1' passing l_resp_xml_id columns
                                  
                                  item_relationship_id number path 'ITEM_RELATIONSHIP_ID',
                                  item_relationship_type varchar2(100) path 'ITEM_RELATIONSHIP_TYPE',
                                  inventory_item_id number path 'INVENTORY_ITEM_ID',
                                  organization_id number path 'ORGANIZATION_ID',
                                  sub_type varchar2(100) path 'SUB_TYPE',
                                  cross_reference varchar2(250) path 'CROSS_REFERENCE',
                                  master_organization_id number path 'MASTER_ORGANIZATION_ID',
                                  last_update_date_char varchar2(100) path 'LAST_UPDATE_DATE_CHAR'
                                  
                                  ) xt) loop
    
      l_count := l_count + 1;
    
      if l_count < 10 then
        xout(c_rec.item_relationship_id || ', ' || c_rec.cross_reference);
      elsif l_count = 10 then
        xout('More records exists...');
      else
        null;
      end if;
    
      l_row.item_relationship_id   := c_rec.item_relationship_id;
      l_row.item_relationship_type := c_rec.item_relationship_type;
      l_row.inventory_item_id      := c_rec.inventory_item_id;
      l_row.organization_id        := c_rec.organization_id;
      l_row.sub_type               := c_rec.sub_type;
      l_row.cross_reference        := c_rec.cross_reference;
      l_row.master_organization_id := c_rec.master_organization_id;
      l_row.last_update_date       := char_to_timestamp(c_rec.last_update_date_char);
      l_row.downloaded_date        := sysdate;
    
      delete from xxdl_egp_item_relations where item_relationship_id = c_rec.item_relationship_id;
    
      insert into xxdl_egp_item_relations values l_row;
    
    end loop;
  
    -- Delete lobs after successful call
    xxfn_cloud_ws_pkg.delete_lobs_from_log(l_ws_call_id);
  
    xout('Item relations downloaded: ' || l_count);
    xout('*** End of report ***');
  
    xlog('Procedure download_item_relations ended');
  
  exception
    when e_processing_exception then
      elog('e_processing_exception risen');
      xxdl_report_pkg.set_has_errors(g_report_id);
    
    when others then
      xxdl_report_pkg.set_has_errors(g_report_id);
      elog('SQLERRM: ' || sqlerrm);
      elog('BACKTRACE: ' || dbms_utility.format_error_backtrace);
      raise;
  end;

  /*===========================================================================+
  Procedure   : download_cst_accounting
  Description : Downloads material cost accounting from Fusion to XE
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure download_cst_accounting(p_from_timestamp timestamp default null) is
  
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
  
    l_row xxdl_cst_accounting%rowtype;
  
    l_count number;
  
    l_last_update_date timestamp;
  
  begin
  
    xlog('Procedure download_cst_accounting started');
  
    xxdl_report_pkg.create_report(p_report_type => 'Download Fusion Table', p_report_name => 'Download Cost Accouning', x_report_id => g_report_id);
  
    xout('*** Download Cost Accounting ***');
    xout('');
  
    xlog('Getting last update date');
    select max(last_update_date) into l_last_update_date from xxdl_cst_accounting;
  
    if l_last_update_date is null then
      l_last_update_date := to_timestamp('01-01-1900', 'DD-MM-RRRR');
    end if;
    xlog('last_update_date:' || l_last_update_date);
  
    if p_from_timestamp is not null then
      l_last_update_date := p_from_timestamp;
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
                        <pub:reportAbsolutePath>Custom/XXDL_INV_Integration/XXDL_CST_ACCOUNTING_REP.xdo</pub:reportAbsolutePath>
                        <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
                    </pub:reportRequest>
                    <pub:appParams></pub:appParams>
                </pub:runReport>
            </soap:Body>
        </soap:Envelope>';
  
    l_text := replace(l_text, '[P_LAST_UPDATE_DATE]', timestamp_to_char(l_last_update_date));
  
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
  
    xlog('l_ws_call_id: ' || l_ws_call_id);
  
    dbms_lob.freetemporary(l_soap_env);
  
    xlog('x_return_status: ' || l_return_status);
    if (l_return_status != 'S') then
      elog('Error getting data from BI report for CST accounting');
      elog('l_return_message: ' || l_return_message);
      raise e_processing_exception;
    end if;
  
    xlog('Extracting xml response');
  
    begin
      select response_xml into l_resp_xml from xxfn_ws_call_log_v where ws_call_id = l_ws_call_id;
    exception
      when no_data_found then
        elog('Error extracting xml from the response');
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
        elog('ws_call_id: ' || l_ws_call_id);
        raise e_processing_exception;
    end;
  
    l_result_clob_decode := xxfn_cloud_ws_pkg.decodebase64(l_result_clob);
  
    xlog(to_char(dbms_lob.substr(l_result_clob_decode, 1000, 1)));
  
    l_resp_xml_id := xmltype.createxml(l_result_clob_decode);
  
    xlog('Looping thru the  values');
  
    -- Loop thru the records
    xout(' ');
    for c_rec in (select xt.*
                    from xmltable('/DATA_DS/G_1' passing l_resp_xml_id columns
                                  
                                  distribution_line_id number path 'DISTRIBUTION_LINE_ID',
                                  inv_transaction_id number path 'INV_TRANSACTION_ID',
                                  cst_transaction_id number path 'CST_TRANSACTION_ID',
                                  inventory_item_id number path 'INVENTORY_ITEM_ID',
                                  inventory_org_id number path 'INVENTORY_ORG_ID',
                                  unit_cost number path 'UNIT_COST',
                                  seg1_company varchar2(30) path 'SEG1_COMPANY',
                                  seg2_account varchar2(30) path 'SEG2_ACCOUNT',
                                  seg3_cost_center varchar2(30) path 'SEG3_COST_CENTER',
                                  seg4_project varchar2(30) path 'SEG4_PROJECT',
                                  seg5_work_order varchar2(30) path 'SEG5_WORK_ORDER',
                                  seg6_sub_account varchar2(30) path 'SEG6_SUB_ACCOUNT',
                                  seg7_sales_order varchar2(30) path 'SEG7_SALES_ORDER',
                                  seg8_rel_company varchar2(30) path 'SEG8_REL_COMPANY',
                                  accounting_date varchar2(100) path 'ACCOUNTING_DATE',
                                  accounting_line_type varchar2(100) path 'ACCOUNTING_LINE_TYPE',
                                  cost_transaction_type varchar2(100) path 'COST_TRANSACTION_TYPE',
                                  ledger_amount number path 'LEDGER_AMOUNT',
                                  accounted_dr number path 'ACCOUNTED_DR',
                                  accounted_cr number path 'ACCOUNTED_CR',
                                  last_update_date_char varchar2(100) path 'LAST_UPDATE_DATE_CHAR'
                                  
                                  ) xt) loop
    
      l_count := l_count + 1;
    
      if l_count < 10 then
        xout(c_rec.distribution_line_id || ', ' || c_rec.distribution_line_id);
      elsif l_count = 10 then
        xout('More records exists...');
      else
        null;
      end if;
    
      l_row.distribution_line_id  := c_rec.distribution_line_id;
      l_row.inv_transaction_id    := c_rec.inv_transaction_id;
      l_row.cst_transaction_id    := c_rec.cst_transaction_id;
      l_row.inventory_item_id     := c_rec.inventory_item_id;
      l_row.inventory_org_id      := c_rec.inventory_org_id;
      l_row.unit_cost             := c_rec.unit_cost;
      l_row.seg1_company          := c_rec.seg1_company;
      l_row.seg2_account          := c_rec.seg2_account;
      l_row.seg3_cost_center      := c_rec.seg3_cost_center;
      l_row.seg4_project          := c_rec.seg4_project;
      l_row.seg5_work_order       := c_rec.seg5_work_order;
      l_row.seg6_sub_account      := c_rec.seg6_sub_account;
      l_row.seg7_sales_order      := c_rec.seg7_sales_order;
      l_row.seg8_rel_company      := c_rec.seg8_rel_company;
      l_row.accounting_date       := xml_char_to_date(c_rec.accounting_date);
      l_row.accounting_line_type  := c_rec.accounting_line_type;
      l_row.cost_transaction_type := c_rec.cost_transaction_type;
      l_row.ledger_amount         := c_rec.ledger_amount;
      l_row.accounted_dr          := c_rec.accounted_dr;
      l_row.accounted_cr          := c_rec.accounted_cr;
      l_row.last_update_date      := char_to_timestamp(c_rec.last_update_date_char);
      l_row.downloaded_date       := sysdate;
    
      xlog('Deleting from xxdl_cst_accounting...');
      delete from xxdl_cst_accounting where distribution_line_id = c_rec.distribution_line_id;
    
      xlog('Inserting into xxdl_cst_accounting...');
      insert into xxdl_cst_accounting values l_row;
    
    end loop;
  
    -- Delete lobs after successful call
    xxfn_cloud_ws_pkg.delete_lobs_from_log(l_ws_call_id);
  
    xout('Cost accounting lines downloaded: ' || l_count);
    xout('*** End of report ***');
  
    xlog('Procedure download_cst_accounting ended');
  
  exception
    when e_processing_exception then
      elog('e_processing_exception risen');
      xxdl_report_pkg.set_has_errors(g_report_id);
    
    when others then
      xxdl_report_pkg.set_has_errors(g_report_id);
      elog('SQLERRM: ' || sqlerrm);
      elog('BACKTRACE: ' || dbms_utility.format_error_backtrace);
      raise;
  end;

  /*===========================================================================+
  Procedure   : download_all_inv_tables
  Description : Downloads all Inventory tables from Fusion to XE
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure download_all_inv_tables as
  begin
  
    download_inv_orgs;
  
    download_transaction_types;
  
    download_items;
  
    download_item_relations;
  
    download_transactions;
  
    download_avg_item_cst;
  
    download_cst_accounting;
  
  end;

  /*===========================================================================+
  Procedure   : download_freq1_schedule
  Description : Entities to be downloaded frequently
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure download_freq1_schedule as
  begin
  
    download_items;
  
    download_item_relations;
  
    download_transactions;
  
  end;

end;
/
