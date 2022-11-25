  /* $Header $
  ============================================================================+
  File Name   : XXDL_CST_ACCOUNTING_V.sql
  Object      : XXDL_CST_ACCOUNTING_V
  Description : Costing transactions accounting
  History     :
  v1.0 27.09.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/
create or replace view  XXDL_CST_ACCOUNTING_V as
select acc.inv_transaction_id,
       acc.inventory_item_id,
       acc.inventory_org_id,
       acc.unit_cost,
       acc.seg1_company,
       acc.seg2_account,
       acc.seg3_cost_center,
       acc.seg4_project,
       acc.seg5_work_order,
       acc.seg6_sub_account,
       acc.seg7_sales_order,
       acc.seg8_rel_company,
       acc.accounting_date,
       acc.accounting_line_type,
       acc.cost_transaction_type,
       sum(acc.accounted_dr) accounted_dr,
       sum(acc.accounted_cr) accounted_cr
  from xxdl_cst_accounting acc
group by acc.inv_transaction_id,
       acc.inventory_item_id,
       acc.inventory_org_id,
       acc.unit_cost,
       acc.seg1_company,
       acc.seg2_account,
       acc.seg3_cost_center,
       acc.seg4_project,
       acc.seg5_work_order,
       acc.seg6_sub_account,
       acc.seg7_sales_order,
       acc.seg8_rel_company,
       acc.accounting_date,
       acc.accounting_line_type,
       acc.cost_transaction_type;

  
