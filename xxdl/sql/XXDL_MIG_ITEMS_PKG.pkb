create or replace package body xxdl_mig_items_pkg as
  /*$Header:  $
  =============================================================================
   -- Name        :  XXDL_MIG_ITEMS_PKG
   -- Author      :  Marko Sladoljev
   -- Date        :  18-10-2022
   -- Description :  Items migration package
   --                !!! VAZNO !!!
   --                Prereq: Tablica xxdl_inv_organizations treba imai downloadane cloud organizacije 
                             jer se koristi za validaciju
   --
   -- -------- ------ ------------ -----------------------------------------------
   --   Date    Ver     Author     Description
   -- -------- ------ ------------ -----------------------------------------------
   -- 28-04-22 120.00 zkovac       Initial creation 
   -- 18-10-22 1.1    msladoljev   New package XXDL_MIG_ITEMS_PKG  
   --
  =============================================================================*/
  --c_log_module constant varchar2(300) := $$plsql_unit;
  e_processing_exception exception;
  c_eur_rate constant number := 7.5345;

  /*===========================================================================+
      Procedure   : log
      Description : Puts the p_text variable to output file
      Usage       : Writing the output of the request
      Arguments   : p_text - text to output
  ============================================================================+*/
  procedure xlog(p_text in varchar2) as
  begin
    dbms_output.put_line(p_text);
    null;
  
  end;

  /*===========================================================================+
      Procedure   : get_organization_code
      Description : Gets organization_code based on ebs org code
  ============================================================================+*/
  function get_organization_code(p_organization_code_ebs in varchar2) return varchar2 as
    l_organization_code varchar2(10);
  begin
  
    if p_organization_code_ebs = 'CIN' then
      l_organization_code := 'PMK';
    else
      l_organization_code := p_organization_code_ebs;
    end if;
  
    return l_organization_code;
  
  end;

  /*===========================================================================+
      Procedure   : get_organization_name
      Description : Gets org name based on org code
  ============================================================================+*/
  function get_organization_name(p_organization_code in varchar2) return varchar2 as
    l_organization_name varchar2(200);
  begin
  
    select org.name into l_organization_name from xxdl_inv_organizations org where organization_code = p_organization_code;
  
    return l_organization_name;
  
  end;

  /*===========================================================================+
      Procedure   : format_number
      Description : formats number for XML
  ============================================================================+*/
  function format_number(p_number number) return varchar2 is
  begin
    return to_char(p_number, 'FM999999999999999999990.0999999999999');
  end;
  /*===========================================================================+
      Procedure   : cdata
      Description : Puts CDATA tag around string for escaping special characters
  ============================================================================+*/
  function cdata(p_text varchar2) return varchar2 is
  begin
    return '<![CDATA[' || p_text || ']]>';
  end;
  /*===========================================================================+
      Procedure   : get_list_price
      Description : Calculates list price
  ============================================================================+*/
  function get_list_price(p_list_price number) return number is
    l_result number;
  begin
  
    if p_list_price is null then
      l_result := null;
    elsif p_list_price = 0 then
      l_result := 0;
    else
      l_result := round(p_list_price / c_eur_rate, 2);
      if l_result < 0.01 then
        l_result := 0.01;
      end if;
    end if;
  
    return l_result;
  
  end;

  /*===========================================================================+
      Procedure   : get_item_template
      Description : Gets item template based on item data
  ============================================================================+*/
  function get_item_template(p_inventory_item_id number) return varchar2 as
    l_template varchar2(30);
    l_count    number;
  
    cursor cur_itm is
      select msi.segment1,
             msi.item_type,
             msi.purchasing_item_flag
        from apps.mtl_system_items_b@ebsprod msi,
             apps.mtl_parameters@ebsprod     mtp
       where mtp.organization_id = msi.organization_id
         and msi.inventory_item_id = p_inventory_item_id
         and mtp.organization_code = 'DLK';
  
    c_itm cur_itm%rowtype;
  begin
  
    l_template := null;
  
    open cur_itm;
  
    fetch cur_itm
      into c_itm;
  
    if c_itm.segment1 is null then
      return null;
    end if;
  
    close cur_itm;
  
    if c_itm.segment1 like 'U%' then
    
      --------------------------
      --- Template za usluge ---
      --------------------------
    
      select count(1) into l_count from xxdl_item_mig_proizv_usluge@ebsprod where item = c_itm.segment1;
    
      if l_count > 0 then
        l_template := 'XXDL_Usluga-Nabava';
      
      else
        if c_itm.purchasing_item_flag = 'Y' then
          l_template := 'XXDL_Usluga-Prodaja i nabava';
        else
          l_template := 'XXDL_Usluga-Prodaja';
        end if;
      end if;
    
    else
      -----------------------------
      --- Template za materijal ---
      -----------------------------
    
      if c_itm.item_type = 'XXDL_AUTOGUME' then
        l_template := 'XXDL_Autogume';
      elsif c_itm.item_type = 'XXDL_GORIVOXXDL_GORIVO' then
        l_template := 'XXDL_Gorivo';
      elsif c_itm.item_type = 'XXDL_HTZ' then
        l_template := 'XXDL_HTZ';
      elsif c_itm.item_type = 'XXDL_HRANA' then
        l_template := 'XXDL_Hrana';
      elsif c_itm.item_type = 'XXDL_OS_NAB' then
        l_template := 'XXDL_OS-Nabava';
      elsif c_itm.item_type = 'XXDL_OS_PRO' then
        l_template := 'XXDL_OS-Proizvod';
      elsif c_itm.item_type = 'XXDL_OS_PRO' then
        l_template := 'XXDL_OS-Prodaja'; -- EBS ima XXDL_OS_Prodaja
      elsif c_itm.item_type = 'XXDL_ODREZ' then
        l_template := 'XXDL_Odrez';
      elsif c_itm.item_type = 'XXDL_OTPAD' then
        l_template := 'XXDL_Otpad';
      elsif c_itm.item_type = 'FRT' then
        l_template := 'XXDL_Prijevoz';
      elsif c_itm.item_type = 'XXDL_PROIZVOD' then
        l_template := 'XXDL_Proizvod';
      elsif c_itm.item_type = 'XXDL_REZ_DIJEL' then
        l_template := 'XXDL_Rezervni dijelovi';
      elsif c_itm.item_type = 'P' then
        l_template := 'XXDL_Roba';
      elsif c_itm.item_type = 'XXDL_SI_ALAT_NAB' then
        l_template := 'XXDL_SI-Alati-Nabava';
      elsif c_itm.item_type = 'XXDL_SI_ALAT_PRO' then
        l_template := 'XXDL_SI-Alati-Proizvod';
      elsif c_itm.item_type = 'XXDL_AMBALAZA' then
        l_template := 'XXDL_SI-Ambalaza';
      elsif c_itm.item_type = 'XXDL_SI_OSTALO_NAB' then
        l_template := 'XXDL_SI-Ostalo-Nabava';
      elsif c_itm.item_type = 'XXDL_SI_OSTALO_PRO' then
        l_template := 'XXDL_SI-Ostalo-Proizvod';
      elsif c_itm.item_type = 'XXDL_SI_TK_NAB' then
        l_template := 'XXDL_SI-TK-Nabava';
      elsif c_itm.item_type = 'XXDL_UREDSKI_MAT' then
        l_template := 'XXDL_Uredski materijal';
      
      else
        l_template := null;
      end if;
    
    end if; -- End if materijal
  
    return l_template;
  
  end;

  --/*-----------------------------------------------------------------------------
  -- Name    :update_item_description
  -- Desc    :Updates item description in cloud
  -------------------------------------------------------------------------------*/
  procedure update_item_description(p_inventory_item_id number,
                                    p_organization_id   number,
                                    p_cloud_item_id     number,
                                    x_return_status     out varchar2,
                                    x_return_message    out varchar2) as
  
    cursor cur_desc is
      select msit_hr.description      description_hr,
             msit_hr.long_description long_description_hr,
             msit_us.description      description_us,
             msit_us.long_description long_description_us
        from apps.mtl_system_items_b@ebsprod  msi,
             apps.mtl_parameters@ebsprod      mtp,
             apps.mtl_system_items_tl@ebsprod msit_hr,
             apps.mtl_system_items_tl@ebsprod msit_us
       where msi.inventory_item_id = msit_hr.inventory_item_id
         and msi.organization_id = msit_hr.organization_id
         and msi.inventory_item_id = msit_us.inventory_item_id
         and msi.organization_id = msit_us.organization_id
         and mtp.organization_id = msi.organization_id
         and mtp.organization_id = msi.organization_id
         and mtp.organization_code = 'DLK'
         and msit_hr.language = 'HR'
         and msit_us.language = 'US'
         and msi.inventory_item_id = p_inventory_item_id
         and msi.organization_id = p_organization_id;
  
    c_desc cur_desc%rowtype;
  
    l_app_url          varchar2(100);
    l_item_xml         varchar2(32000);
    l_text             varchar2(32000);
    l_dlk_cloud_org_id number;
    l_soap_env         clob;
    l_ws_call_id       number;
  
    l_fault_code   varchar2(4000);
    l_fault_string varchar2(4000);
  begin
    open cur_desc;
  
    fetch cur_desc
      into c_desc;
  
    if nvl(c_desc.description_hr, 'X') != nvl(c_desc.description_us, 'X') or
       nvl(c_desc.long_description_hr, 'X') != nvl(c_desc.long_description_us, 'X') then
      xlog('Item description has different translations, updating description');
    
      select organization_id into l_dlk_cloud_org_id from xxdl_inv_organizations where organization_code = 'DLK';
    
      l_app_url  := xxdl_config_pkg.servicerooturl;
      l_item_xml := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/" xmlns:item="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/" xmlns:cat="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/itemSupplier/categories/" xmlns:item1="http://xmlns.oracle.com/apps/scm/productModel/items/flex/itemRevision/" xmlns:cat1="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/itemRevision/categories/" xmlns:cat2="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/item/categories/" xmlns:item2="http://xmlns.oracle.com/apps/scm/productModel/items/flex/item/" xmlns:item3="http://xmlns.oracle.com/apps/scm/productModel/items/flex/itemGdf/" xmlns:mod="http://xmlns.oracle.com/apps/flex/fnd/applcore/attachments/model/">
                   <soapenv:Header/>
                   <soapenv:Body>
                      <typ:updateItem>
                         <typ:item>
                            <item:ItemId>[ITEM_ID]</item:ItemId>
                            <item:OrganizationId>[ORGANIZATION_ID]</item:OrganizationId>
                            <item:ItemTranslation>
                                    <item:ItemDescription>[DESCRIPTION_HR]</item:ItemDescription>
                                    <item:LongDescription>[LONG_DESCRIPTION_HR]</item:LongDescription>
                                    <item:Language>HR</item:Language>
                                    <item:SourceLanguage>HR</item:SourceLanguage>
                            </item:ItemTranslation>
                            <item:ItemTranslation>
                                    <item:ItemDescription>[DESCRIPTION_US]</item:ItemDescription>
                                    <item:LongDescription>[LONG_DESCRIPTION_US]</item:LongDescription>
                                    <item:Language>US</item:Language>
                                    <item:SourceLanguage>US</item:SourceLanguage>
                            </item:ItemTranslation>                            
                         </typ:item>
                      </typ:updateItem>
                   </soapenv:Body>
                </soapenv:Envelope>';
    
      l_text := l_item_xml;
      l_text := replace(l_text, '[ITEM_ID]', p_cloud_item_id);
      l_text := replace(l_text, '[ORGANIZATION_ID]', l_dlk_cloud_org_id);
      l_text := replace(l_text, '[DESCRIPTION_HR]', c_desc.description_hr);
      l_text := replace(l_text, '[LONG_DESCRIPTION_HR]', c_desc.long_description_hr);
      l_text := replace(l_text, '[DESCRIPTION_US]', c_desc.description_us);
      l_text := replace(l_text, '[LONG_DESCRIPTION_US]', c_desc.long_description_us);
    
      l_soap_env := l_soap_env || to_clob(l_text);
      l_text     := '';
    
      xlog('   Calling web service.');
    
      xxfn_cloud_ws_pkg.ws_call(p_ws_url         => l_app_url || 'fscmService/ItemServiceV2?WSDL',
                                p_soap_env       => l_soap_env,
                                p_soap_act       => 'update Item',
                                p_content_type   => 'text/xml;charset="UTF-8"',
                                x_return_status  => x_return_status,
                                x_return_message => x_return_message,
                                x_ws_call_id     => l_ws_call_id);
    
      --dbms_lob.freetemporary(l_soap_env);
      xlog('ws_call_id (Update Description):' || l_ws_call_id);
      if x_return_status = 'S' then
        x_return_message := '';
      else
        xlog('Error updating description');
      
        -- Get error message
        begin
          select xt.faultstring
            into l_fault_string
            from xxfn_ws_call_log x,
                 xmltable(xmlnamespaces('http://schemas.xmlsoap.org/soap/envelope/' as "env"),
                          './/env:Fault' passing x.response_xml columns faultcode varchar2(4000) path '.',
                          faultstring varchar2(4000) path '.') xt
           where x.ws_call_id = l_ws_call_id;
        
        exception
          when no_data_found then
            begin
              select nvl(x.response_status_code, 'ERROR'),
                     x.response_reason_phrase
                into l_fault_code,
                     l_fault_string
                from xxfn_ws_call_log x
               where x.ws_call_id = l_ws_call_id;
            
            exception
              when others then
                l_fault_string := 'Cannot find env:Fault in ws call results. for ws_call_id ' || l_ws_call_id;
            end;
        end;
      
        x_return_message := l_fault_string;
      
      end if;
    
    else
      xlog('No need for description update');
      x_return_status  := 'S';
      x_return_message := '';
    end if;
  
  end;

  --/*-----------------------------------------------------------------------------
  -- Name    : migrate_cross_references
  -- Desc    : Migrate cross-references for the item
  -------------------------------------------------------------------------------*/
  procedure migrate_cross_references(p_inventory_item_id number,
                                     p_cloud_item_number varchar,
                                     x_return_status     out varchar2,
                                     x_return_message    out varchar2) as
  
    cursor cur_xref is
    
      select trim(cross_reference) cross_reference,
             cross_reference_type
        from apps.mtl_cross_references@ebsprod xref,
             apps.mtl_system_items_b@ebsprod   msi,
             apps.mtl_parameters@ebsprod       mtp
       where xref.inventory_item_id = msi.inventory_item_id
         and mtp.organization_id = msi.organization_id
         and mtp.organization_code = 'DLK'
         and (xref.cross_reference_type like 'Katalo%ki broj' or xref.cross_reference_type = 'Tarifni broj')
         and msi.inventory_item_id = p_inventory_item_id;
  
    l_app_url          varchar2(100);
    l_xref_json        varchar2(32000);
    l_text             varchar2(32000);
    l_dlk_cloud_org_id number;
    l_rest_env         clob;
    l_ws_call_id       number;
  
    l_fault_code   varchar2(4000);
    l_fault_string varchar2(4000);
  
    l_return_status  varchar2(10);
    l_return_message varchar2(32000);
  
  begin
    select organization_id into l_dlk_cloud_org_id from xxdl_inv_organizations where organization_code = 'DLK';
    l_app_url := xxdl_config_pkg.servicerooturl;
  
    x_return_status  := 'S';
    x_return_message := '';
  
    for c_xref in cur_xref loop
    
      l_xref_json := '{
        "MasterOrganizationCode"     : "DLK",
        "ApplicableOrganizationId"   : [APPLICABLE_ORGANIZATION_ID],
        "Item"                       : "[ITEM_NUMBER]",
        "CrossReferenceType"         : "[CROSS_REFERENCE_TYPE]",
        "CrossReference"             : "[CROSS_REFERENCE]",
        "ApplyToAllOrganizationFlag" : false
        }';
    
      l_text := l_xref_json;
      l_text := replace(l_text, '[APPLICABLE_ORGANIZATION_ID]', l_dlk_cloud_org_id);
      l_text := replace(l_text, '[ITEM_NUMBER]', p_cloud_item_number);
      l_text := replace(l_text, '[CROSS_REFERENCE_TYPE]', apex_escape.json(c_xref.cross_reference_type));
      l_text := replace(l_text, '[CROSS_REFERENCE]', apex_escape.json(c_xref.cross_reference));
    
      l_rest_env := l_rest_env || to_clob(l_text);
      l_text     := '';
    
      xlog('   Calling web service.');
    
      xxfn_cloud_ws_pkg.ws_rest_call(p_ws_url         => l_app_url || '/fscmRestApi/resources/11.13.18.05/crossReferenceRelationships',
                                     p_rest_env       => l_rest_env,
                                     p_rest_act       => 'POST',
                                     p_content_type   => 'application/json;charset="UTF-8"',
                                     x_return_status  => l_return_status,
                                     x_return_message => l_return_message,
                                     x_ws_call_id     => l_ws_call_id);
    
      xlog('l_ws_call_id (POST crossReferenceRelationships):     ' || l_ws_call_id);
      xlog('l_return_status:  ' || l_return_status);
    
      if l_return_status != 'S' then
        xlog('*** Error creating cross-reference');
        xlog('l_return_message: ' || l_return_message);
        xlog('l_ws_call_id: ' || l_ws_call_id);
      
        x_return_status  := 'E';
        x_return_message := 'Error during REST API Call. l_ws_call_id: ' || l_ws_call_id || ' l_return_message: ' ||
                            substr(l_return_message, 1, 1800);
        return;
      
      end if;
    
    end loop;
    x_return_status  := 'S';
    x_return_message := '';
  
  end;

  --/*-----------------------------------------------------------------------------
  -- Name    :shoud_migrate_item
  -- Desc    :Checks whether item should be migrated
  -------------------------------------------------------------------------------*/

  function should_migrate_item(p_inventory_item_id number, p_organization_id number) return varchar2 as
  
    l_count             number;
    l_organization_code varchar2(10);
    l_dlk_org_id        number;
    
    l_result varchar2(1);
  
    cursor cur_itm is
      select msi.segment1,
             mtp.organization_code organization_code_ebs,
             msi.purchasing_enabled_flag
        from apps.mtl_system_items_b@ebsprod msi,
             apps.mtl_parameters@ebsprod     mtp
       where mtp.organization_id = msi.organization_id
         and msi.inventory_item_id = p_inventory_item_id
         and msi.organization_id = p_organization_id;
  
  begin
  
    for c_itm in cur_itm loop
    
      l_organization_code := get_organization_code(c_itm.organization_code_ebs);
    
      -- Org check   
      select count(1)
        into l_count
        from xxdl_inv_organizations
       where organization_code = l_organization_code
         and rownum = 1;
    
      if l_count = 0 then
        -- xlog('Org ' || l_organization_code || ' not exists in xxdl_inv_organizations');
        return 'N';
      end if;
    
      if c_itm.segment1 like 'U%' then
      
        ------------------
        ----- Usluge -----
        ------------------
      
        -- Check xxdl_item_mig_proizv_usluge  
        select count(1)
          into l_count
          from xxdl.xxdl_item_mig_proizv_usluge@ebsprod
         where item = c_itm.segment1
           and rownum = 1;
      
        if l_count > 0 then
          --  xlog('Item has XXDL_ITEM_MIG_PROIZV_USLUGE record');
          return 'Y';
        end if;
      
        -- Check prodajne usluge - oe_order_lines_all
        select count(1)
          into l_count
          from apps.oe_order_lines_all@ebsprod oeol,
               apps.mtl_parameters@ebsprod     mtp
         where oeol.creation_date >= to_date('01.08.2021', 'DD.MM.YYYY')
           and oeol.ordered_item = c_itm.segment1
           and (oeol.ship_from_org_id = mtp.organization_id or mtp.organization_code = 'DLK');
      
        if l_count > 0 then
          -- xlog('Item has oe_order_lines_all record');
          return 'Y';
        end if;
      
      else
        ----------------------
        ----- Materijal ------
        ----------------------
      
        -- MMT check
        select count(1)
          into l_count
          from apps.mtl_material_transactions@ebsprod mmt
         where mmt.inventory_item_id = p_inventory_item_id
           and (mmt.organization_id = p_organization_id or l_organization_code = 'DLK')
           and mmt.transaction_date >= to_date('01.01.2019', 'DD.MM.YYYY')
           and rownum = 1;
      
        if l_count > 0 then
          -- xlog('Item has MMT record');
          return 'Y';
        end if;
      
        -- RCT check
        select count(1)
          into l_count
          from apps.rcv_transactions@ebsprod rt,
               apps.po_lines_all@ebsprod     pol
         where rt.po_line_id = pol.po_line_id
           and pol.item_id = p_inventory_item_id
           and (rt.organization_id = p_organization_id or l_organization_code = 'DLK')
           and rt.transaction_date > to_date('01.01.2019', 'DD.MM.YYYY')
           and rownum = 1;
      
        if l_count > 0 then
          -- xlog('Item has RCT record');
          return 'Y';
        end if;
      
        -- Onhand check
        select count(1)
          into l_count
          from apps.mtl_onhand_quantities@ebsprod onh
         where onh.inventory_item_id = p_inventory_item_id
           and (onh.organization_id = p_organization_id or l_organization_code = 'DLK')
           and rownum = 1;
      
        if l_count > 0 then
          -- xlog('Item has Onhand record');
          return 'Y';
        end if;
      
        -- Source org check
        select count(1)
          into l_count
          from apps.mtl_system_items_b@ebsprod msi
         where msi.inventory_item_id = p_inventory_item_id
           and msi.source_organization_id = p_organization_id;
      
        if l_count > 0 then
          -- xlog('Item has org as source org');
          return 'Y';
        end if;
      
      end if; -- End materijal
    
      -- Dodatno, ako je validating org, onda se purchaseable itemi dodaju tamo ako se migriraju i na DLK
      if l_organization_code in ('PMK', 'POS', 'EMU', 'NUF') and c_itm.purchasing_enabled_flag = 'Y' then
      
        -- get l_dlk_org_id
        select organization_id into l_dlk_org_id from apps.mtl_parameters@ebsprod where organization_code = 'DLK';
      
        l_result := should_migrate_item(p_inventory_item_id => p_inventory_item_id, p_organization_id => l_dlk_org_id);
        
        --xlog('should_migrate_item for DLK returned: ' || l_result);
        
        return l_result;
      
      end if;
    
    end loop;
  
    return 'N';
  
  end;

  --/*-----------------------------------------------------------------------------
  -- Name    : migrate_items_cloud
  -- Desc    : Procedure for migrating EBS items to cloud ewha-test
  -- Usage   : 
  -- Parameters 
  --       - p_item_seg: item number in EBS
  --       - p_rows: number of rows to process, default 1000
  --     - p_retry_error: should we process records that ended in error
  -------------------------------------------------------------------------------*/
  procedure migrate_items_cloud(p_item_seg in varchar2, p_rows in number, p_retry_error in varchar2, p_suffix in varchar2) is
  
    ---------
    -- Items
    ---------
    cursor c_items is
      select msi.segment1,
             msi.description description,
             msi.long_description,
             muom.unit_of_measure_tl primary_uom_code,
             msi.list_price_per_unit,
             msi.unit_weight,
             msi.inventory_item_id,
             msi.organization_id,
             (select segment1 || '-' || segment2 || '-' || segment3
                from apps.fa_categories_b@ebsprod fac
               where fac.category_id = msi.asset_category_id) asset_category,
             mp.organization_code organization_code_ebs,
             msi.attribute5 dff_standard,
             msi.attribute6 dff_oznaka_kvalitete,
             msi.attribute7 dff_posto_cinka,
             msi.attribute8 dff_usluga_cincanja,
             decode(msi.source_type, 1, 'Organization', 2, 'Supplier', 3, 'Subinventory', null) source_type_value,
             (select organization_code from apps.mtl_parameters@ebsprod where organization_id = msi.source_organization_id) source_organization_code,
             msi.source_subinventory,
             msi.min_minmax_quantity,
             msi.max_minmax_quantity,
             decode(msi.inventory_planning_code, 2, 'Min-max planning', null) inventory_planning_value
        from apps.mtl_system_items_vl@ebsprod     msi,
             apps.mtl_parameters@ebsprod          mp,
             apps.mtl_units_of_measure_tl@ebsprod muom
       where msi.organization_id = mp.organization_id
         and msi.segment1 = nvl(p_item_seg, msi.segment1)
         and msi.primary_uom_code = muom.uom_code
         and muom.language = 'US'
         and not exists (select 1
                from xxdl_mtl_system_items_mig xx
               where xx.inventory_item_id = msi.inventory_item_id
                 and xx.organization_id = msi.organization_id
                 and xx.process_flag = 'S') -- Ne postoje uspjesno procesirani
         and not exists (select 1
                from xxdl_mtl_system_items_mig xx
               where xx.inventory_item_id = msi.inventory_item_id
                 and xx.organization_id = msi.organization_id
                 and xx.process_flag = 'E'
                 and p_retry_error = 'N') -- error recordi se procesiraju ako je tra�eno 
       order by segment1,
                case
                  when organization_code_ebs = 'DLK' then
                   1
                  when organization_code_ebs = 'CIN' then -- translated to PMK
                   2
                  when organization_code_ebs = 'POS' then
                   3
                  else
                   decode(msi.source_organization_id, null, 4, 5) -- orgs with referenced source org should be migrated latest
                end;
  
    -------------
    -- Languages
    -------------
    cursor c_items_lang(c_item_id in number, c_org_id in number) is
      select '<![CDATA[' || msit.description || ']]>' description_escaped,
             '<![CDATA[' || msit.long_description || ']]>' long_description_esc,
             msit.description description,
             msit.long_description long_description,
             msit.language,
             msit.source_lang
        from apps.mtl_system_items_tl@ebsprod msit
       where msit.inventory_item_id = c_item_id
         and msit.organization_id = c_org_id
         and msit.language = 'HR';
  
    --------------
    -- Categories
    ---------------
    cursor c_item_categories(c_item_id in number, c_org_id in number) is
      select distinct case
                        when mic.category_set_name = 'XXDL kategorizacija' then
                         '<![CDATA[Nabavne kategorije]]>'
                        when mic.category_set_name = 'XXDL PLA' then
                         '<![CDATA[Racunovodstvena kategorija]]>'
                        else
                         mic.category_set_name
                      end category_set_name,
                      case
                        when mic.category_set_name = 'XXDL kategorizacija' then
                         mic.segment1 || '.' || mic.segment2
                        when mic.category_set_name = 'XXDL PLA' then
                         mic.segment1
                        else
                         mic.segment1
                      end category_code,
                      mic.category_set_name orig_category_set_name
        from (select mic.inventory_item_id,
                     mic.organization_id,
                     mic.category_set_id,
                     mic.category_id,
                     mcst.category_set_name,
                     mcst.description,
                     mcb.segment1,
                     mcb.segment2
                from apps.mtl_item_categories@ebsprod  mic,
                     apps.mtl_category_sets_tl@ebsprod mcst,
                     apps.mtl_category_sets_b@ebsprod  mcs,
                     apps.mtl_categories_b@ebsprod     mcb
               where mic.category_set_id = mcs.category_set_id
                 and mcs.category_set_id = mcst.category_set_id
                 and mcst.language = 'HR'
                 and mcst.category_set_name in ('XXDL kategorizacija', 'XXDL PLA')
                 and mic.category_id = mcb.category_id) mic
       where mic.inventory_item_id = c_item_id
         and mic.organization_id = c_org_id;
  
    l_item_rec        xxdl_mtl_system_items_mig%rowtype;
    l_item_empty      xxdl_mtl_system_items_mig%rowtype;
    l_fault_code      varchar2(4000);
    l_fault_string    varchar2(4000);
    l_soap_env        clob;
    l_empty_clob      clob;
    l_text            varchar2(32000);
    l_text_categories varchar2(32000);
    x_return_status   varchar2(500);
    x_return_message  varchar2(32000);
    x_ws_call_id      number;
    l_cnt             number := 0;
    l_item_count      number := 0;
  
    l_prev_item_id number := -1;
  
    l_organization_code varchar2(10);
    l_list_price        number;
  
    l_app_url varchar2(100);
  
    l_cloud_item number;
    l_cloud_org  number;
  
    l_segment1 varchar2(100);
    l_template varchar2(30);
  
    l_category_xml varchar2(32000);
    l_item_xml     varchar2(32000);
  
    l_source_organization_name varchar2(200);
  
  begin
  
    xlog('Starting to import items:');
  
    l_app_url := xxdl_config_pkg.servicerooturl;
  
    l_category_xml := '<item:ItemCategory>
                     <item:ItemCatalog>[CATEGORY_SET_NAME]</item:ItemCatalog>               
                     <item:CategoryCode>[CATEGORY_CODE]</item:CategoryCode>
                  </item:ItemCategory>';
  
    l_item_xml := ' <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/" xmlns:item="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/" xmlns:cat="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/itemSupplier/categories/" xmlns:item1="http://xmlns.oracle.com/apps/scm/productModel/items/flex/itemRevision/" xmlns:cat1="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/itemRevision/categories/" xmlns:cat2="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/item/categories/" xmlns:item2="http://xmlns.oracle.com/apps/scm/productModel/items/flex/item/" xmlns:item3="http://xmlns.oracle.com/apps/scm/productModel/items/flex/itemGdf/" xmlns:mod="http://xmlns.oracle.com/apps/flex/fnd/applcore/attachments/model/">
      <soapenv:Header/>
      <soapenv:Body>
          <typ:createItem>
              <typ:item xmlns:ns2="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/">
                  <item:OrganizationCode>[ORGANIZATION_CODE]</item:OrganizationCode>
                  <item:Template>[TEMPLATE]</item:Template>
                  <item:ItemNumber>[ITEM_NUMBER]</item:ItemNumber>
                  <item:ItemClass>Root Item Class</item:ItemClass>
                  <item:ItemDescription>[DESCRIPTION]</item:ItemDescription>
                  <item:LongDescription>[LONG_DESCRIPTION]</item:LongDescription>
                  <item:PrimaryUOMValue>[PRIMARY_UOM_VALUE]</item:PrimaryUOMValue>
                  <item:ListPrice>[LIST_PRICE]</item:ListPrice>
                  <item:UnitWeightQuantity>[UNIT_WEIGHT_QUANTITY]</item:UnitWeightQuantity>
                  <item:WeightUOMValue>[WEIGHT_UOM]</item:WeightUOMValue>
                  <item:AssetCategoryValue>[ASSET_CATEGORY]</item:AssetCategoryValue>                  
                  <item:ItemStatusValue>Active</item:ItemStatusValue>
                  <item:LifecyclePhaseValue>Production</item:LifecyclePhaseValue>
                  <item:ReplenishmentType>[REPLENISHMENT_TYPE]</item:ReplenishmentType>                  
                  <item:SourceOrganizationValue>[SOURCE_ORGANIZATION_VALUE]</item:SourceOrganizationValue>
                  <item:SourceSubinventoryOrganizationValue>[SOURCE_SUBINVENTORY_ORGANIZATION_VALUE]</item:SourceSubinventoryOrganizationValue>
                  <item:SourceSubinventoryValue>[SOURCE_SUBINVENTORY_VALUE]</item:SourceSubinventoryValue>
                  <item:InventoryPlanningMethodValue>[INVENTORY_PLANNINGMETHOD_VALUE]</item:InventoryPlanningMethodValue>
                  <item:MinimumMinmaxQuantity>[MINIMUM_MINMAX_QUANTITY]</item:MinimumMinmaxQuantity>
                  <item:MaximumMinmaxQuantity>[MAXIMUM_MINMAX_QUANTITY]</item:MaximumMinmaxQuantity> 
                  <ns2:ItemDFF xmlns:ns15="http://xmlns.oracle.com/apps/scm/productModel/items/flex/item/">
                      <ns15:standard>[DFF_STANDARD]</ns15:standard>
                      <ns15:oznakaKvalitete>[DFF_OZNAKA_KVALITETE]</ns15:oznakaKvalitete>
                      <ns15:cinka>[DFF_POSTO_CINKA]</ns15:cinka>
                      <ns15:dlkUslugaCincanja>[DFF_USLUGA_CINCANJA]</ns15:dlkUslugaCincanja>
                  </ns2:ItemDFF>                  
                  [CATEGORIES_XML]
                </typ:item>
          </typ:createItem>
      </soapenv:Body>
   </soapenv:Envelope>';
  
    for c_i in c_items loop
    
      l_segment1 := c_i.segment1 || p_suffix;
    
      l_organization_code := get_organization_code(c_i.organization_code_ebs);
    
      if should_migrate_item(c_i.inventory_item_id, c_i.organization_id) = 'N' then
        xlog(c_i.segment1 || ', (' || l_organization_code || '): item should not be migrated');
        continue;
      end if;
    
      xlog('   -----------------------------');
      xlog('   Import item: ' || l_segment1);
      xlog('   Org        : ' || l_organization_code);
    
      xlog('   Checking if already exists in cloud!');
    
      find_item_cloud(l_segment1, l_organization_code, l_cloud_item, l_cloud_org);
    
      xlog('   Cloud item id:' || l_cloud_item);
    
      l_item_rec.inventory_item_id := c_i.inventory_item_id;
      l_item_rec.organization_id   := c_i.organization_id;
      l_item_rec.segment1          := l_segment1;
      l_item_rec.organization_code := l_organization_code;
      l_item_rec.description       := c_i.description;
      l_item_rec.primary_uom_code  := c_i.primary_uom_code;
      l_item_rec.process_flag      := x_return_status;
      l_item_rec.creation_date     := sysdate;
      l_item_rec.last_update_date  := sysdate;
    
      -- Item jos ne postoji
      if l_cloud_item = 0 then
        begin
        
          -- Get template
          if l_organization_code = 'DLK' then
            l_template := get_item_template(c_i.inventory_item_id);
            xlog('l_template: ' || l_template);
            if l_template is null then
              l_item_rec.error_msg := 'Cannot find template for item';
              raise e_processing_exception;
            end if;
          else
            l_template := null;
          end if;
        
          -- Get list price
          l_list_price := get_list_price(c_i.list_price_per_unit);
        
          if c_i.source_organization_code is null then
            l_source_organization_name := null;
          else
            l_source_organization_name := get_organization_name(get_organization_code(c_i.source_organization_code));
          end if;
        
          xlog('Creating item...');
        
          l_text := l_item_xml;
          l_text := replace(l_text, '[ORGANIZATION_CODE]', l_organization_code);
          l_text := replace(l_text, '[TEMPLATE]', l_template);
          l_text := replace(l_text, '[ITEM_NUMBER]', l_segment1);
          l_text := replace(l_text, '[DESCRIPTION]', cdata(c_i.description));
          l_text := replace(l_text, '[LONG_DESCRIPTION]', cdata(c_i.long_description));
          l_text := replace(l_text, '[PRIMARY_UOM_VALUE]', c_i.primary_uom_code);
          l_text := replace(l_text, '[LIST_PRICE]', format_number(l_list_price));
          l_text := replace(l_text, '[UNIT_WEIGHT_QUANTITY]', format_number(c_i.unit_weight));
          l_text := replace(l_text, '[WEIGHT_UOM]', 'kg');
          l_text := replace(l_text, '[ASSET_CATEGORY]', c_i.asset_category);
          l_text := replace(l_text, '[DFF_STANDARD]', cdata(c_i.dff_standard));
          l_text := replace(l_text, '[DFF_OZNAKA_KVALITETE]', cdata(c_i.dff_oznaka_kvalitete));
          l_text := replace(l_text, '[DFF_POSTO_CINKA]', c_i.dff_posto_cinka);
          l_text := replace(l_text, '[DFF_USLUGA_CINCANJA]', c_i.dff_usluga_cincanja);
          l_text := replace(l_text, '[REPLENISHMENT_TYPE]', c_i.source_type_value);
          l_text := replace(l_text, '[SOURCE_ORGANIZATION_VALUE]', l_source_organization_name);
          l_text := replace(l_text, '[SOURCE_SUBINVENTORY_ORGANIZATION_VALUE]', null);
          l_text := replace(l_text, '[SOURCE_SUBINVENTORY_VALUE]', c_i.source_subinventory);
          l_text := replace(l_text, '[INVENTORY_PLANNINGMETHOD_VALUE]', c_i.inventory_planning_value);
          l_text := replace(l_text, '[MINIMUM_MINMAX_QUANTITY]', format_number(c_i.min_minmax_quantity));
          l_text := replace(l_text, '[MAXIMUM_MINMAX_QUANTITY]', format_number(c_i.max_minmax_quantity));
          -- Master level attributes
          if l_organization_code = 'DLK' then
            null;
          else
            null;
          end if;
        
          l_text_categories := '';
        
          for c_i_cat in c_item_categories(c_i.inventory_item_id, c_i.organization_id) loop
          
            if c_i_cat.orig_category_set_name = 'XXDL kategorizacija' then
              l_item_rec.category := c_i_cat.category_code;
            end if;
          
            if c_i_cat.orig_category_set_name = 'XXDL PLA' then
              l_item_rec.account := c_i_cat.category_code;
            end if;
          
            if l_organization_code = 'DLK' and c_i_cat.orig_category_set_name = 'XXDL kategorizacija' then
              l_text_categories := l_text_categories || l_category_xml;
              l_text_categories := replace(l_text_categories, '[CATEGORY_SET_NAME]', c_i_cat.category_set_name);
              l_text_categories := replace(l_text_categories, '[CATEGORY_CODE]', c_i_cat.category_code);
            end if;
          
            if c_i_cat.orig_category_set_name = 'XXDL PLA' then
              l_text_categories := l_text_categories || l_category_xml;
              l_text_categories := replace(l_text_categories, '[CATEGORY_SET_NAME]', c_i_cat.category_set_name);
              l_text_categories := replace(l_text_categories, '[CATEGORY_CODE]', c_i_cat.category_code);
            end if;
          end loop;
        
          l_text := replace(l_text, '[CATEGORIES_XML]', l_text_categories);
        
          l_soap_env := l_soap_env || to_clob(l_text);
          l_text     := '';
        
          xlog('   Envelope built!');
        
          xlog('   Calling web service.');
          xlog('   Url:' || l_app_url || 'fscmService/ItemServiceV2?WSDL');
          xxfn_cloud_ws_pkg.ws_call(p_ws_url         => l_app_url || 'fscmService/ItemServiceV2?WSDL',
                                    p_soap_env       => l_soap_env,
                                    p_soap_act       => 'createItem',
                                    p_content_type   => 'text/xml;charset="UTF-8"',
                                    x_return_status  => x_return_status,
                                    x_return_message => x_return_message,
                                    x_ws_call_id     => x_ws_call_id);
        
          --log(l_text);
          --dbms_lob.freetemporary(l_soap_env);
          xlog('   ws_call_id (Create Item):' || x_ws_call_id);
        
          if x_return_status = 'S' then
          
            xlog('   Item migrated!');
            l_item_rec.process_flag := x_return_status;
          
            begin
              -- Get cloud id
              select xt.cloud_item_id,
                     xt.cloud_org_id
                into l_item_rec.cloud_item_id,
                     l_item_rec.cloud_org_id
                from xxfn_ws_call_log x,
                     xmltable(xmlnamespaces('http://schemas.xmlsoap.org/soap/envelope/' as "env",
                                            'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/' as "ns0",
                                            'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/' as "ns2",
                                            'http://xmlns.oracle.com/adf/svc/types/' as "val",
                                            'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/' as "ns1"),
                              '/env:Envelope/env:Body/ns0:createItemResponse/ns2:result/val:Value' passing x.response_xml columns cloud_item_id
                              varchar2(4000) path './ns1:ItemId',
                              cloud_org_id varchar2(4000) path './ns1:OrganizationId') xt
               where x.ws_call_id = x_ws_call_id;
            
            exception
              when no_data_found then
                l_item_rec.cloud_item_id := null;
                l_item_rec.cloud_org_id  := null;
            end;
          
            /*update xxfn_ws_call_log xx 
            set xx.response_xml = null
            ,xx.response_clob = null
            ,xx.response_blob = null
            ,xx.ws_payload_xml = null
            where ws_call_id = x_ws_call_id;
            */
          
          else
            xlog('   Error! Item not migrated!');
          
            -- Get error message
            begin
              select xt.faultcode,
                     xt.faultstring
                into l_fault_code,
                     l_fault_string
                from xxfn_ws_call_log x,
                     xmltable(xmlnamespaces('http://schemas.xmlsoap.org/soap/envelope/' as "env"),
                              './/env:Fault' passing x.response_xml columns faultcode varchar2(4000) path '.',
                              faultstring varchar2(4000) path '.') xt
               where x.ws_call_id = x_ws_call_id;
            
            exception
              when no_data_found then
                begin
                  select nvl(x.response_status_code, 'ERROR'),
                         x.response_reason_phrase
                    into l_fault_code,
                         l_fault_string
                    from xxfn_ws_call_log x
                   where x.ws_call_id = x_ws_call_id;
                
                exception
                  when others then
                    l_item_rec.error_msg := 'Cannot find env:Fault in ws call results.';
                end;
            end;
          
            if l_fault_code is not null or l_fault_string is not null then
              l_item_rec.error_msg    := substr('   Greska => Code:' || l_fault_code || ' Text:' || l_fault_string, 1, 1000);
              l_item_rec.process_flag := 'E';
            end if;
            xlog('   ' || l_item_rec.error_msg);
          end if;
        
        exception
          when e_processing_exception then
            l_item_rec.process_flag := 'E';
            xlog('*** Error in processing item');
            xlog(l_item_rec.error_msg);
        end;
      
      else
        xlog('  Cloud Item already exists!');
      
        l_item_rec.cloud_item_id := l_cloud_item;
        l_item_rec.cloud_org_id  := l_cloud_org;
        l_item_rec.process_flag  := 'S';
        l_item_rec.error_msg     := null;
      
      end if; -- end if already exists
    
      -- Save resullts to xxdl_mtl_system_items_mig
      begin
        insert into xxdl_mtl_system_items_mig values l_item_rec;
      
      exception
        when dup_val_on_index then
          l_item_rec.last_update_date := sysdate;
          update xxdl_mtl_system_items_mig xx
             set row = l_item_rec
           where xx.inventory_item_id = l_item_rec.inventory_item_id
             and xx.organization_id = l_item_rec.organization_id;
        
      end;
    
      commit; -- Comit after WS call
    
      -- Migrate translations for master org
      if l_organization_code = 'DLK' and l_item_rec.process_flag = 'S' then
        update_item_description(l_item_rec.inventory_item_id,
                                l_item_rec.organization_id,
                                l_item_rec.cloud_item_id,
                                x_return_status,
                                x_return_message);
      
        l_item_rec.process_flag     := x_return_status;
        l_item_rec.error_msg        := x_return_message;
        l_item_rec.last_update_date := sysdate;
      
        update xxdl_mtl_system_items_mig xx
           set row = l_item_rec
         where xx.inventory_item_id = l_item_rec.inventory_item_id
           and xx.organization_id = l_item_rec.organization_id;
      
      end if;
    
      -- Migrate Cross References for master org
      if l_organization_code = 'DLK' and l_item_rec.process_flag = 'S' then
        migrate_cross_references(l_item_rec.inventory_item_id, l_segment1, x_return_status, x_return_message);
      
        l_item_rec.process_flag     := x_return_status;
        l_item_rec.error_msg        := x_return_message;
        l_item_rec.last_update_date := sysdate;
      
        update xxdl_mtl_system_items_mig xx
           set row = l_item_rec
         where xx.inventory_item_id = l_item_rec.inventory_item_id
           and xx.organization_id = l_item_rec.organization_id;
      
      end if;
    
      l_cnt := l_cnt + 1;
    
      if l_prev_item_id != l_item_rec.inventory_item_id then
        l_item_count := l_item_count + 1;
      end if;
      l_prev_item_id := l_item_rec.inventory_item_id;
    
      if l_item_count > nvl(p_rows, -1) then
        exit;
      end if;
    
      l_item_rec := l_item_empty;
      l_soap_env := l_empty_clob;
    
      commit;
    
    end loop;
  
    xlog('Finished item import!');
    xlog('Record count:' || l_cnt);
    xlog('Items  count:' || l_item_count);
  
  exception
  
    when others then
      xlog('   Unexpected error! SQLCODE:' || sqlcode || ' SQLERRM:' || sqlerrm);
      xlog('   Error_Stack...' || chr(10) || dbms_utility.format_error_stack() || ' Error_Backtrace...' || chr(10) ||
           dbms_utility.format_error_backtrace());
    
  end migrate_items_cloud;

  --/*-----------------------------------------------------------------------------
  -- Name    : find_item_cloud
  -- Desc    : Function to find item in cloud
  -- Usage   : 
  -- Parameters
  --     p_item in varchar2,
  --    p_org in varchar
  -------------------------------------------------------------------------------*/
  procedure find_item_cloud(p_item in varchar2, p_org in varchar2, p_cloud_item out number, p_cloud_org out number) is
  
    l_item_rec        xxdl_mtl_system_items_mig%rowtype;
    l_item_empty      xxdl_mtl_system_items_mig%rowtype;
    l_fault_code      varchar2(4000);
    l_fault_string    varchar2(4000);
    l_soap_env        clob;
    l_empty_clob      clob;
    l_text            varchar2(32000);
    l_find_text       varchar2(32000);
    x_return_status   varchar2(500);
    x_return_message  varchar2(32000);
    x_ws_call_id      number;
    l_cnt             number := 0;
    l_item_id         number;
    l_organization_id number;
    l_app_url         varchar2(300);
  begin
  
    l_app_url := xxdl_config_pkg.servicerooturl;
  
    xlog('   Building find item envelope!');
  
    l_find_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/" xmlns:typ1="http://xmlns.oracle.com/adf/svc/types/">
                   <soapenv:Header/>
                   <soapenv:Body>
                      <typ:findItem>
                         <typ:findCriteria>
                            <typ1:fetchStart>0</typ1:fetchStart>
                            <typ1:fetchSize>-1</typ1:fetchSize>
                            <!--Optional:-->
                            <typ1:filter>
                               <typ1:group>
                                  <!--Optional:-->
                                  <typ1:conjunction></typ1:conjunction>
                                  <typ1:upperCaseCompare>false</typ1:upperCaseCompare>
                                  <!--1 or more repetitions:-->
                                  <typ1:item>
                                     <!--Optional:-->
                                     <typ1:conjunction></typ1:conjunction>
                                     <typ1:upperCaseCompare>false</typ1:upperCaseCompare>
                                     <typ1:attribute>ItemNumber</typ1:attribute>
                                     <typ1:operator>=</typ1:operator>
                                     <!--You have a CHOICE of the next 2 items at this level-->
                                     <!--Zero or more repetitions:-->
                                     <typ1:value>' || p_item || '</typ1:value>                                     
                                  </typ1:item>
                                  <typ1:item>
                                     <!--Optional:-->
                                     <typ1:conjunction></typ1:conjunction>
                                     <typ1:upperCaseCompare>false</typ1:upperCaseCompare>
                                     <typ1:attribute>OrganizationCode</typ1:attribute>
                                     <typ1:operator>=</typ1:operator>
                                     <!--You have a CHOICE of the next 2 items at this level-->
                                     <!--Zero or more repetitions:-->
                                     <typ1:value>' || p_org || '</typ1:value>                                     
                                  </typ1:item>
                               </typ1:group>
                               <!--Zero or more repetitions:-->
                               <typ1:nested/>
                            </typ1:filter>
                            <!--Optional:-->
                            <!--Zero or more repetitions:-->
                           <typ1:excludeAttribute>false</typ1:excludeAttribute>
                         </typ:findCriteria>
                         <typ:findControl>
                            <typ1:retrieveAllTranslations>false</typ1:retrieveAllTranslations>
                         </typ:findControl>
                      </typ:findItem>
                   </soapenv:Body>
                </soapenv:Envelope>';
  
    l_soap_env  := l_soap_env || to_clob(l_find_text);
    l_find_text := '';
  
    xlog('   Envelope built!');
  
    xlog('   Calling web service.');
    xxfn_cloud_ws_pkg.ws_call(p_ws_url         => l_app_url || 'fscmService/ItemServiceV2?WSDL',
                              p_soap_env       => l_soap_env,
                              p_soap_act       => 'findItem',
                              p_content_type   => 'text/xml;charset="UTF-8"',
                              x_return_status  => x_return_status,
                              x_return_message => x_return_message,
                              x_ws_call_id     => x_ws_call_id);
  
    xlog('ws_call_id (find Item):' || x_ws_call_id);
  
    xlog('Parsing ws_call to get item cloud id..');
  
    begin
      select to_number(xt.itemid),
             to_number(xt.organizationid)
        into p_cloud_item,
             p_cloud_org
        from xxfn_ws_call_log x,
             xmltable(xmlnamespaces('http://schemas.xmlsoap.org/soap/envelope/' as "env",
                                    'http://www.w3.org/2005/08/addressing' as "wsa",
                                    'http://xmlns.oracle.com/adf/svc/types/' as "ns0",
                                    'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/' as "ns1",
                                    'http://xmlns.oracle.com/adf/svc/errors/' as "tns",
                                    'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/' as "ns2",
                                    'http://www.w3.org/2001/XMLSchema-instance' as "xsi"),
                      './/ns0:Value' passing x.response_xml columns itemid number path 'ns1:ItemId',
                      organizationid varchar2(4000) path 'ns1:OrganizationId') xt
       where x.ws_call_id = x_ws_call_id;
    
    exception
      when no_data_found then
        p_cloud_item := 0;
        p_cloud_org  := 0;
    end;
  
    xlog('Cloud ItemId: ' || p_cloud_item);
    xlog('Cloud OrganizationId: ' || p_cloud_org);
  
  exception
    when others then
      p_cloud_item := 0;
      p_cloud_org  := 0;
  end;

  function parse_cs_response(p_ws_call_id in number) return varchar2 is
  
    l_head_code  varchar2(4000);
    l_head_error varchar2(32767);
    l_line_error varchar2(4000);
    l_line_code  varchar2(32767);
    l_msg_body   varchar2(32767);
  begin
  
    --get header error
  
    for cur_rec in (select xt.code,
                           substr(xt.message, instr(xt.message, '<', 1, 1), length(xt.message)) message
                      from xxfn_ws_call_log x,
                           xmltable(xmlnamespaces('http://xmlns.oracle.com/adf/svc/errors/' as "tns",
                                                  'http://schemas.xmlsoap.org/soap/envelope/' as "env"),
                                    '/env:Envelope/env:Body/env:Fault/detail/tns:ServiceErrorMessage/tns:detail' passing x.response_xml columns code
                                    varchar2(4000) path 'tns:code',
                                    message varchar2(4000) path 'tns:message') xt
                     where x.ws_call_id = p_ws_call_id) loop
    
      select code,
             text
        into l_head_code,
             l_head_error
        from xmltable('/MESSAGE' passing(cur_rec.message) columns text varchar2(4000) path 'TEXT', code varchar2(4000) path 'CODE');
      if nvl(l_head_error, 'X') != 'X' then
        l_msg_body := 'Greska.' || chr(10);
        l_msg_body := 'Kod:' || l_head_code || chr(10);
        l_msg_body := 'Tekst:' || l_head_error || chr(10);
      end if;
    end loop;
  
    --get lines error
  
    for cur_rec in (select xt.code,
                           substr(xt.message, instr(xt.message, '<', 1, 1), length(xt.message)) message
                      from xxfn_ws_call_log x,
                           xmltable(xmlnamespaces('http://xmlns.oracle.com/adf/svc/errors/' as "tns",
                                                  'http://schemas.xmlsoap.org/soap/envelope/' as "env"),
                                    '/env:Envelope/env:Body/env:Fault/detail/tns:ServiceErrorMessage/tns:detail/tns:detail' passing(x.response_xml)
                                    columns code varchar2(4000) path 'tns:code',
                                    message varchar2(4000) path 'tns:message') xt
                     where x.ws_call_id = p_ws_call_id) loop
    
      if nvl(l_line_error, 'X') != 'X' then
        l_msg_body := 'Greska' || chr(10);
        l_msg_body := 'Kod:' || l_line_code || chr(10);
        l_msg_body := 'Tekst:' || l_line_error || chr(10);
      end if;
    end loop;
    return l_msg_body;
  end;

end xxdl_mig_items_pkg;
/
