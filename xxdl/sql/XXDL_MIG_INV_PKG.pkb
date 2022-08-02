/* $Header $
============================================================================+
File Name   : XXDL_MIG_INV_PKG.pkb
Description : Package for Inventory migrations

History     :
v1.0 28.07.2022 - Marko Sladoljev: Initial creation	
============================================================================+*/
create or replace package body xxdl_mig_inv_pkg as

  -- Log variables
  c_module    constant varchar2(100) := 'XXDL_MIG_INV_PKG';
  g_log_level constant varchar2(10) := xxdl_log_pkg.g_level_statement; -- Use for detailed logging
  --g_log_level    constant varchar2(10) := xxdl_log_pkg.g_level_error; -- Regular error only logging

  -- Constants
  g_account               constant varchar2(100) := '590310'; --- konto
  g_subinventory_code     constant varchar2(100) := 'Zalihe'; -- sve ide na isti subinventory
  g_locator               constant varchar2(100) := '00-00-00-00';
  g_transaction_date      constant date := to_date('1-JUL-2022', 'DD-MON-YYYY');
  g_transaction_type_name constant varchar2(250) := unistr('Migracija po\010Detnih stanja ulaz');

  g_last_message varchar2(2000);
  g_report_id    number := -1;

  e_processing_exception exception;
  g_error_message        varchar2(2000);

  c_eur_rate constant number := 7.5345;

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
  Procedure   : get_company_segment1
  Description : Accounting KFF seg1 
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  function get_company_segment1(p_org_code varchar2) return varchar2 as
    l_seg1 varchar2(250);
  begin
    select decode(p_org_code,
                  'I10',
                  '01',
                  'GDP',
                  '02',
                  'I04',
                  '01',
                  'R01',
                  '01',
                  'I02',
                  '01',
                  'I05',
                  '01',
                  'NUF',
                  '11',
                  'X04',
                  '01',
                  'I04',
                  '01',
                  'T01',
                  '01',
                  'T01',
                  '01',
                  'X01',
                  '01',
                  'I01',
                  '01',
                  'NU1',
                  '11',
                  'MS1',
                  '02',
                  'MP1',
                  '02',
                  'SO1',
                  '02',
                  'MPR',
                  '02',
                  'OA3',
                  '02',
                  'SO2',
                  '02',
                  'SS1',
                  '13',
                  'SWE',
                  '11',
                  'MT1',
                  '02',
                  null)
      into l_seg1
      from dual;
  
    if l_seg1 is null then
      g_error_message := 'Org code ' || p_org_code || 'Not mapped to seg1';
      raise e_processing_exception;
    end if;
  
    return l_seg1;
  
  end;

  /*===========================================================================+
  Procedure   : get_org_name
  Description : Org name org code mapping
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  function get_org_name(p_org_code varchar2) return varchar2 as
    l_name varchar2(250);
  begin
  
    -- Ime je dobiveno  asciistr(ou.name) iz BI Inventory orgs
    select decode(p_org_code,
                  'I10',
                  'I10 - Skladi\0161te rez. dije. za strojeve i vozila, gorivo',
                  'GDP',
                  'GDP - Gradili\0161te DLKV Proizvodnje',
                  'I04',
                  --'I04 - Skladi\0161te elektromaterijala i opreme', -- prod
                  'I-04 - Skladi\0161te elektromaterijala i opreme', -- stari test
                  'R01',
                  'R01-Skladi\0161te-Reexport Dalekovod d.d.',
                  'I02',
                  'I02 - Skladi\0161te SI i HTZ',
                  'I05',
                  'I05 - Skladi\0161te proizvoda izgradnje (NN ormari\0107i) i IKT opreme',
                  'NUF',
                  'Dalekovod NUF',
                  'DLK',
                  'DLK',
                  'X04',
                  'X04 - Skladi\0161te elektromaterijala i opreme',
                  'T01',
                  --'T01 - Skladi\0161te trgova\010Dke robe', --stari test, -- prod
                  'T-01 - Skladi\0161te trgova\010Dke robe', --stari test
                  'GDN',
                  'GDN - Gradili\0161te Dalekovod NUF',
                  'X01',
                  'X01-Skladi\0161te trgova\010Dke robe',
                  'GRA',
                  'GRA-Gradili\0161te',
                  'I01',
                  'I01 - Skladi\0161te potro\0161nog materijala',
                  'NU1',
                  'NU1 - Skladi\0161te podru\017Enice Dalekovod NUF',
                  'MS1',
                  'MS1 - Skladi\0161te sirovina MK',
                  'MP1',
                  'MP1 - Skladi\0161te poluproizvoda i proizvoda MK',
                  'SO1',
                  'SO1 - Skladi\0161te odr\017Eavanja-materijali',
                  'MPR',
                  'MPR - Skladi\0161te prodaje MK',
                  'OA3',
                  'OA3 - Skladi\0161te alata, SI i HTZ opreme',
                  'GDS',
                  'GDS - Gradiliste Dalekovod Svedska',
                  'SO2',
                  'SO2 - Skladi\0161te odr\017Eavanja i energetike',
                  'SS1',
                  'SS1- Skladi\0161te sirovina OSO',
                  'SWE',
                  'Svedska',
                  'MT1',
                  'MT1 - Skladi\0161te trgova\010Dke robe MK',
                  null)
      into l_name
      from dual;
  
    if l_name is null then
      g_error_message := 'Org code ' || p_org_code || ' not mapped to Org name';
      raise e_processing_exception;
    end if;
  
    return unistr(l_name);
  
  end;

  /*===========================================================================+
  Procedure   : migrate_onhand
  Description : 
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure migrate_onhand(p_org_code varchar2 default null, p_item varchar2 default null) as
    cursor cur_exp is
      select *
        from xxdl_mig_onhand x
       where x.organization_code_ebs = nvl(p_org_code, x.organization_code_ebs)
         and x.item = nvl(p_item, x.item)
         and x.status in ('NEW', 'ERROR');
  
    l_status        varchar2(10);
    l_error_message varchar2(10);
  
    l_batch_id number;
  
    l_row xxdl_inv_material_txns_int%rowtype;
  
    l_seg1 varchar2(10);
  
  begin
  
    for c_exp in cur_exp loop
      begin
      
        l_batch_id := xxdl_inv_material_txns_bat_s1.nextval;
      
        l_seg1 := get_company_segment1(c_exp.organization_code_ebs);
      
        l_row.transaction_interface_id := xxdl_inv_material_txns_int_s1.nextval;
        l_row.batch_id                 := l_batch_id;
        l_row.organization_name        := get_org_name(c_exp.organization_code_ebs);
        l_row.item_number              := c_exp.item;
        l_row.transaction_type_name    := g_transaction_type_name;
        l_row.transaction_quantity     := c_exp.primary_transaction_quantity;
        l_row.transaction_uom          := c_exp.primary_uom_code;
        l_row.transaction_date         := g_transaction_date;
        l_row.subinventory_code        := g_subinventory_code;
        l_row.locator_name             := g_locator;
        l_row.inv_project_number       := c_exp.project_number;
        l_row.inv_task_number          := c_exp.task_number;
        l_row.account_combination      := l_seg1 || '.' || g_account || '.000000.000000.000000.0000000.000000.00.000000.000000';
        l_row.source_code              := 'DLKV';
        l_row.source_line_id           := 1;
        l_row.source_header_id         := 1;
        l_row.use_current_cost_flag    := 'N';
        l_row.transaction_cost         := c_exp.material_cost / c_eur_rate;
        l_row.transaction_reference    := 'Mig id: ' || c_exp.mig_id;
        l_row.status                   := 'NEW';
        l_row.error_message            := null;
        l_row.creation_date            := sysdate;
        l_row.last_update_date         := sysdate;
      
        insert into xxdl_inv_material_txns_int values l_row;
      
        xxdl_inv_integration_pkg.process_transactions_interface(p_batch_id => l_batch_id);
      
        select * into l_row from xxdl_inv_material_txns_int where transaction_interface_id = l_row.transaction_interface_id;
      
        if l_row.status != 'PROCESSED' then
          g_error_message := l_row.error_message;
          raise e_processing_exception;
        end if;
      
        l_status        := 'SUCCESS';
        l_error_message := null;
      
      exception
        when e_processing_exception then
          l_status        := 'ERORR';
          l_error_message := g_error_message;
        
      end;
    
      update xxdl_mig_onhand oh set oh.status = l_status, oh.error_messaage = l_error_message where oh.mig_id = c_exp.mig_id;
      commit;
    
    end loop;
  
  end;
  /*===========================================================================+
  Procedure   : export_onhand
  Description : 
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure export_onhand(p_org_code varchar2 default null, p_item varchar2 default null) as
  
    cursor cur_onh is
      select mtp.organization_code organization_code_ebs,
             
             msi.segment1                     item,
             onh.subinventory_code,
             p.segment1                       project_number,
             t.task_number,
             onh.primary_transaction_quantity,
             msi.primary_uom_code,
             msi.inventory_item_id,
             onh.locator_id,
             onh.organization_id,
             clay.material_cost
        from (select onh1.inventory_item_id,
                     onh1.organization_id,
                     onh1.locator_id,
                     onh1.subinventory_code,
                     onh1.lot_number,
                     onh1.cost_group_id,
                     onh1.revision,
                     onh1.is_consigned,
                     onh1.owning_organization_id,
                     onh1.owning_tp_type,
                     onh1.project_id,
                     onh1.task_id,
                     sum(onh1.primary_transaction_quantity) primary_transaction_quantity
                from apps.mtl_onhand_quantities_detail@ebsprod onh1
               group by onh1.inventory_item_id,
                        onh1.organization_id,
                        onh1.locator_id,
                        onh1.subinventory_code,
                        onh1.lot_number,
                        onh1.cost_group_id,
                        onh1.revision,
                        onh1.is_consigned,
                        onh1.owning_organization_id,
                        onh1.owning_tp_type,
                        onh1.project_id,
                        onh1.task_id) onh,
             apps.mtl_parameters@ebsprod mtp,
             apps.mtl_system_items_b@ebsprod msi,
             apps.mtl_item_locations@ebsprod loc,
             apps.cst_quantity_layers@ebsprod clay,
             apps.pa_projects_all@ebsprod p,
             apps.pa_tasks@ebsprod t
       where onh.organization_id = mtp.organization_id
         and onh.inventory_item_id = msi.inventory_item_id
         and onh.organization_id = msi.organization_id
         and onh.locator_id = loc.inventory_location_id(+)
         and clay.cost_group_id(+) = onh.cost_group_id
         and clay.inventory_item_id(+) = onh.inventory_item_id
         and clay.organization_id(+) = onh.organization_id
         and onh.project_id = p.project_id(+)
         and onh.task_id = t.task_id(+)
         and onh.subinventory_code in ('Zalihe', 'Projekt')
         and mtp.organization_code in ('AO3',
                                       'I04',
                                       'SS1',
                                       'OA3',
                                       'NU1',
                                       'AO2',
                                       'T01',
                                       'I10',
                                       'ST1',
                                       'SO1',
                                       'MTR',
                                       'SPR',
                                       'I05',
                                       'ES1',
                                       'I01',
                                       'SP1',
                                       'MP1',
                                       'AO1',
                                       'MPR',
                                       'I02',
                                       'MT1',
                                       'MS1',
                                       'OO1',
                                       'GDP',
                                       'ET1')
         and mtp.organization_code = nvl(p_org_code, mtp.organization_code)
         and msi.segment1 = nvl(p_item, msi.segment1)
       order by mtp.organization_code,
                msi.segment1,
                onh.subinventory_code;
    l_mig_id number;
    l_row    xxdl_mig_onhand%rowtype;
  
  begin
  
    xlog('export_onhand started');
    for c_onh in cur_onh loop
      l_mig_id := xxdl_mig_id_s1.nextval;
    
      l_row.mig_id                       := l_mig_id;
      l_row.organization_code_ebs        := c_onh.organization_code_ebs;
      l_row.item                         := c_onh.item;
      l_row.subinventory_code            := c_onh.subinventory_code;
      l_row.project_number               := c_onh.project_number;
      l_row.task_number                  := c_onh.task_number;
      l_row.primary_transaction_quantity := c_onh.primary_transaction_quantity;
      l_row.primary_uom_code             := c_onh.primary_uom_code;
      l_row.inventory_item_id            := c_onh.inventory_item_id;
      l_row.locator_id                   := c_onh.locator_id;
      l_row.organization_id              := c_onh.organization_id;
      l_row.material_cost                := c_onh.material_cost;
      l_row.status                       := 'NEW';
      l_row.error_messaage               := null;
      l_row.creation_date                := sysdate;
    
      insert into xxdl_mig_onhand values l_row;
    
    end loop;
  
    xlog('export_onhand ended');
  
  end;

end xxdl_mig_inv_pkg;
/