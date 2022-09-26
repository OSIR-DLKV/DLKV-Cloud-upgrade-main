create or replace package xxdl_inv_integration_pkg authid definer is
  /* $Header $
  ============================================================================+
  File Name   : XXDL_INV_INTEGRATION_PKG.pks
  Object      : XXDL_INV_INTEGRATION_PKG
  Description : Package to Inventory integrations 
  History     :
  v1.0 15.7.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/

  -- Download procedures

  procedure download_all_inv_tables;

  procedure download_inv_orgs;

  procedure download_transactions;

  procedure download_avg_item_cst;

  procedure download_items;
  
  procedure download_item_relations;

  procedure download_transaction_types;
  
  procedure download_cst_accounting;

  -- Other procedures

  procedure process_transactions_interface(p_batch_id number);

end xxdl_inv_integration_pkg;
/
