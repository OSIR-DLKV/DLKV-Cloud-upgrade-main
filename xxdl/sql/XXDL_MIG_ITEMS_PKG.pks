create or replace package xxdl_mig_items_pkg as
  /*$Header: $
  =============================================================================
  -- Name        :  XXDL_MIG_ITEMS_PKG
  -- Author      :  Marko Sladoljev
  -- Date        :  18-10-2022
  -- Description :  Cloud Utils package
  --
  -- -------- ------ ------------ -----------------------------------------------
  --   Date    Ver     Author     Description
  -- -------- ------ ------------ -----------------------------------------------
  -- 28-04-22 120.00 zkovac       Initial creation 
  -- 18-10-22 1.1    msladoljev   New package XXDL_MIG_ITEMS_PKG
  --*/

  /*===========================================================================+
      Procedure   : should_migrate_item
      Description : Decides whether item should be migrated for the org
  ============================================================================+*/
  function should_migrate_item(p_inventory_item_id number, p_organization_id number) return varchar2;

  --/*-----------------------------------------------------------------------------
  -- Name    : migrate_items_cloud
  -- Desc    : Procedure for migrating EBS items to cloud
  -- Usage   : 
  -- Parameters
  --     - errbuff: Concurrent program message status
  --     - retcode: Concurrent execution status
  -------------------------------------------------------------------------------*/
  procedure migrate_items_cloud(p_item_seg in varchar2, p_rows in number, p_retry_error in varchar2, p_suffix in varchar2);

  --/*-----------------------------------------------------------------------------
  -- Name    : find_item_cloud
  -- Desc    : Procedure to find item in cloud
  -- Usage   : 
  -- Parameters
  --     p_item in varchar2,
  --    p_org in varchar
  -------------------------------------------------------------------------------*/
  procedure find_item_cloud(p_item in varchar2, p_org in varchar2, p_cloud_item out number, p_cloud_org out number);
  
  procedure migrate_item_batch(p_batch_size number, p_retry_error in varchar2);
  
  procedure migrate_item_all;

  function parse_cs_response(p_ws_call_id in number) return varchar2;

end xxdl_mig_items_pkg;
/
