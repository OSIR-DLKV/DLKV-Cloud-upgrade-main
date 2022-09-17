create or replace package XXDL_INV_INTEGRATION_PKG authid definer is
  /* $Header $
  ============================================================================+
  File Name   : XXDL_INV_INTEGRATION_PKG.pks
  Object      : XXDL_INV_INTEGRATION_PKG
  Description : Package to Inventory integrations 
  History     :
  v1.0 15.7.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/
  
  -- Download procedures
  
  procedure download_inv_orgs;

  procedure download_transactions;
  
  procedure download_avg_item_cst;
  
  procedure download_items;
  
  procedure download_transaction_types;
  
  procedure download_all_inv_tables;
  
  -- Other procedures
  
  procedure process_transactions_interface(p_batch_id number);

end XXDL_INV_INTEGRATION_PKG;
/
