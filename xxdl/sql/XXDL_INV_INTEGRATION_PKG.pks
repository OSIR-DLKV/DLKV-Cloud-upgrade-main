create or replace package xxdl_inv_integration_pkg authid definer is
  /* $Header $
  ============================================================================+
  File Name   : XXDL_INV_INTEGRATION_PKG.pks
  Object      : XXDL_INV_INTEGRATION_PKG
  Description : Package to Inventory integrations 
  History     :
  v1.0 15.7.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/

  -- Download procedures - entities

  procedure download_inv_orgs;

  procedure download_transaction_types;

  procedure download_mig_transactions;

  procedure download_transactions(p_from_timestamp timestamp default null);

  procedure download_avg_item_cst(p_from_timestamp timestamp default null);

  procedure download_items(p_from_timestamp timestamp default null);

  procedure download_item_relations(p_from_timestamp timestamp default null);

  procedure download_cst_accounting(p_from_timestamp timestamp default null);

  -- Download procedures - grouping entities - for usage in jobs

  procedure download_all_inv_tables;

  procedure download_freq1_schedule;

  -- Other procedures

  procedure process_transactions_interface(p_batch_id number);

  procedure process_transactions_int_all;

end xxdl_inv_integration_pkg;
/
