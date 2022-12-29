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
  --g_log_level constant varchar2(10) := xxdl_log_pkg.g_level_statement; -- Use for detailed logging
  g_log_level    constant varchar2(10) := xxdl_log_pkg.g_level_error; -- Regular production error only logging

  -- Constants
  g_account               constant varchar2(100) := '100970'; --- konto
  g_transaction_date      constant date := to_date('1-JUL-2022', 'DD-MON-YYYY');
  g_transaction_type_name constant varchar2(250) := unistr('Migracija po\010Detnih stanja ulaz');
  c_eur_rate              constant number := 7.5345;

  g_last_message varchar2(2000);
  g_report_id    number := -1;

  e_processing_exception exception;
  g_error_message        varchar2(2000);

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
  Procedure   : get_company_segment1
  Description : Accounting KFF seg1 
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  function get_company_segment1(p_org_code varchar2) return varchar2 as
    l_seg1 varchar2(250);
  begin
    -- Dalekovod   
    if p_org_code in ('DLK', 'I10', 'GRA', 'I01', 'I02', 'I04', 'I05', 'T01') then
      l_seg1 := '01';
      -- Proizvodnja MK
    elsif p_org_code in ('MK1', 'MP1', 'MS1', 'SO1', 'MTR', 'OA3', 'MT1', 'MPR', 'GDP', 'PMK') then
      l_seg1 := '02';
    elsif p_org_code in ('PRO') then
      -- Dalekovod Projekt
      l_seg1 := '04';
      -- Dalekovod EMU
    elsif p_org_code in ('EMU', 'ES1', 'ET1') then
      l_seg1 := '06';
      -- Dalekovod NUF
    elsif p_org_code in ('NUF', 'GDN') then
      l_seg1 := '11';
      -- Proizvodnja OSO
    elsif p_org_code in ('AO1', 'AO2', 'AO3', 'KO1', 'OO1', 'OO2', 'POS', 'SP1', 'SPR', 'SS1', 'ST1', 'STR') then
      l_seg1 := '13';
    else
      -- Not mapped
      l_seg1 := null;
    end if;
   
    if l_seg1 is null then
      g_error_message := 'Org code ' || p_org_code || ' not mapped to company segment 1';
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
  
    select name into l_name from xxdl_inv_organizations where organization_code = p_org_code;
  
    return l_name;
  
  exception
    when no_data_found then
      g_error_message := 'Org code ' || p_org_code || ' not found in xxdl_inv_organizations';
      raise e_processing_exception;
  end;

  /*===========================================================================+
  Procedure   : get_locator
  Description : 
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  function get_locator(p_org_code varchar2) return varchar2 as
    l_locator varchar2(250);
  begin
  
    if p_org_code in ('ES1', 'ET1') then
      l_locator := '00';
    else
      l_locator := '00-00-00-00-00';
    end if;
  
    return l_locator;
  end;

  /*===========================================================================+
  Procedure   : get_subinventory
  Description : 
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  function get_subinventory(p_org_code varchar2) return varchar2 as
    l_locator varchar2(250);
  begin
  
    if p_org_code in ('ET1') then
      l_locator := 'Zalihe2'; -- TODO: Za produkciju Zalihe
    else
      l_locator := 'Zalihe';
    end if;
  
    return l_locator;
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
    l_error_message varchar2(2000);
  
    l_batch_id number;
  
    l_row xxdl_inv_material_txns_int%rowtype;
  
    l_seg1 varchar2(10);
  
    l_locator varchar2(100);
  
    l_subinventory varchar2(20);
  
  begin
  
    xlog('Procedure migrate_onhand started');
  
    for c_exp in cur_exp loop
      begin
      
        l_batch_id := xxdl_inv_material_txns_bat_s1.nextval;
      
        xlog('Inserting into xxdl_inv_material_txns_int l_batch_id: ' || l_batch_id);
      
        l_seg1 := get_company_segment1(c_exp.organization_code_ebs);
      
        l_locator := get_locator(c_exp.organization_code_ebs);
      
        l_row.transaction_interface_id := xxdl_inv_material_txns_int_s1.nextval;
        l_row.batch_id                 := l_batch_id;
        l_row.organization_name        := get_org_name(c_exp.organization_code_ebs);
        l_row.item_number              := c_exp.item;
        l_row.transaction_type_name    := g_transaction_type_name;
        l_row.transaction_quantity     := c_exp.primary_transaction_quantity;
        l_row.transaction_uom          := c_exp.primary_uom_code;
        l_row.transaction_date         := g_transaction_date;
        l_row.subinventory_code        := get_subinventory(c_exp.organization_code_ebs);
        l_row.locator_name             := l_locator;
        l_row.inv_project_number       := null; --c_exp.project_number; --Prema dogovoru, zalihu na projektu ne migriramo
        l_row.inv_task_number          := null; -- c_exp.task_number;
        l_row.account_combination      := l_seg1 || '.' || g_account || '.000000.000000.000000.0000000.000000.0.000000.000000';
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
      
        xlog('Deleting from xxdl_inv_material_txns_int if exists from prevous errored transactions');
        delete from xxdl_inv_material_txns_int
         where organization_name = l_row.organization_name
           and item_number = l_row.item_number
           and transaction_type_name = l_row.transaction_type_name
           and nvl(locator_name, 'X') = nvl(l_row.locator_name, 'X')
           and nvl(inv_project_number, 'X') = nvl(l_row.inv_project_number, 'X')
           and nvl(inv_task_number, 'X') = nvl(l_row.inv_task_number, 'X');
        xlog('Deleted: ' || sql%rowcount);
      
        insert into xxdl_inv_material_txns_int values l_row;
      
        -- process_transactions_interface is autonomous, commit is required
        commit;
      
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
          l_status        := 'ERROR';
          l_error_message := g_error_message;
        
      end;
    
      update xxdl_mig_onhand oh set oh.status = l_status, oh.error_messaage = l_error_message where oh.mig_id = c_exp.mig_id;
      commit;
    
    end loop;
  
    xlog('Procedure migrate_onhand ended');
  
  end;

  /*===========================================================================+
  Procedure   : migrate_onhand_all
  Description : Migrates all exported onhand, for usage in a scheduled job
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure migrate_onhand_all as
  begin
  
    xxdl_mig_inv_pkg.migrate_onhand(p_org_code => null, p_item => null);
  
  end;

  /*===========================================================================+
  Procedure   : export_onhand
  Description : 
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure export_onhand(p_org_code varchar2 default null, p_item varchar2 default null) as
  
    cursor cur_onh is
      select mtp.organization_code            organization_code_ebs,
             msi.segment1                     item,
             onh.subinventory_code,
             p.segment1                       project_number,
             t.task_number,
             onh.primary_transaction_quantity,
             uom.unit_of_measure_tl           uom,
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
             apps.pa_tasks@ebsprod t,
             apps.mtl_units_of_measure_tl@ebsprod uom
       where onh.organization_id = mtp.organization_id
         and onh.inventory_item_id = msi.inventory_item_id
         and onh.organization_id = msi.organization_id
         and onh.locator_id = loc.inventory_location_id(+)
         and clay.cost_group_id(+) = onh.cost_group_id
         and clay.inventory_item_id(+) = onh.inventory_item_id
         and clay.organization_id(+) = onh.organization_id
         and onh.project_id = p.project_id(+)
         and onh.task_id = t.task_id(+)
         and uom.language = 'US'
         and uom.uom_code = msi.primary_uom_code
         and onh.subinventory_code in ('Zalihe', 'Projekt')
         and mtp.organization_code in ('AO3',
                                       'I04',
                                       'SS1',
                                       'OA3',
                                       --'NU1', -- poslan mail 25.10 Marijani da se izbacije iz migracije zaliha
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
            -- Not exported already
         and not exists (select 1
                from xxdl_mig_onhand mig
               where mig.organization_code_ebs = mtp.organization_code
                 and mig.item = msi.segment1
                 and mig.subinventory_code = mig.subinventory_code
                 and nvl(mig.project_number, 'X') = nvl(p.segment1, 'X')
                 and nvl(mig.task_number, 'X') = nvl(t.task_number, 'X')
                 and nvl(mig.locator_id, -1) = nvl(onh.locator_id, -1))
      
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
      l_row.primary_uom_code             := c_onh.uom;
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
