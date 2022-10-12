create or replace package XXDL_INV_UTIL_PKG as
  /*$Header: $
  =============================================================================
  -- Name        :  XXDL_INV_UTIL_PKG
  -- Author      :  Zoran Kovac
  -- Date        :  28-APR-2022
  -- Version     :  120.00
  -- Description :  Cloud Utils package
  --
  -- -------- ------ ------------ -----------------------------------------------
  --   Date    Ver     Author     Description
  -- -------- ------ ------------ -----------------------------------------------
  -- 28-04-22 120.00 zkovac       Initial creation 
  --*/

  /*===========================================================================+
    Procedure   : get_config
    Description : Gets config value
    Usage       : Returnig config value
    Arguments   : p_service - text to output
============================================================================+*/
function get_config (p_service IN VARCHAR2) return varchar2;
  --/*-----------------------------------------------------------------------------
  -- Name    : migrate_items_cloud
  -- Desc    : Procedure for migrating EBS items to cloud
  -- Usage   : 
  -- Parameters
  --     - errbuff: Concurrent program message status
  --     - retcode: Concurrent execution status
  -------------------------------------------------------------------------------*/
procedure migrate_items_cloud (
      p_item_seg in varchar2,
      p_rows in number,
      p_year in varchar2,
      p_retry_error in varchar2);
      
  --/*-----------------------------------------------------------------------------
  -- Name    : migrate_items_cloud
  -- Desc    : Procedure for migrating EBS items to cloud
  -- Usage   : 
  -- Parameters
  --     - errbuff: Concurrent program message status
  --     - retcode: Concurrent execution status
  -------------------------------------------------------------------------------*/
procedure migrate_items_cloud_ewha_test (
      p_item_seg in varchar2,
      p_rows in number,
      p_year in varchar2,
      p_retry_error in varchar2,
      p_suffix in varchar2);


  --/*-----------------------------------------------------------------------------
  -- Name    : update_items_cloud
  -- Desc    : Procedure for migrating EBS items to cloud
  -- Usage   : 
  -- Parameters
  --     - errbuff: Concurrent program message status
  --     - retcode: Concurrent execution status
  -------------------------------------------------------------------------------*/
procedure update_items_cloud (
      p_item_seg in varchar2,
      p_rows in number,
      p_year in varchar2,
      p_retry_error in varchar2);

 --/*-----------------------------------------------------------------------------
  -- Name    : find_item_cloud
  -- Desc    : Procedzure to find item in cloud
  -- Usage   : 
  -- Parameters
  --     p_item in varchar2,
  --    p_org in varchar
  -------------------------------------------------------------------------------*/
procedure find_item_cloud (
      p_item in varchar2,
      p_org in varchar2,
      p_cloud_item out number,
      p_cloud_org out number);
      
  --/*-----------------------------------------------------------------------------
  -- Name    : update_items_cloud
  -- Desc    : Procedure for migrating EBS items to cloud
  -- Usage   : 
  -- Parameters
  --     - errbuff: Concurrent program message status
  --     - retcode: Concurrent execution status
  --------------------------------------------------------------------------------*/
procedure update_items_cloud_ewha_test  (
      p_item_seg in varchar2,
      p_rows in number,
      p_year in varchar2,
      p_retry_error in varchar2);

 --/*-----------------------------------------------------------------------------
  -- Name    : find_item_cloud
  -- Desc    : Procedzure to find item in cloud
  -- Usage   : 
  -- Parameters
  --     p_item in varchar2,
  --    p_org in varchar
  -------------------------------------------------------------------------------*/
procedure find_item_cloud_ewha_test  (
      p_item in varchar2,
      p_org in varchar2,
      p_cloud_item out number,
      p_cloud_org out number);

function parse_cs_response(p_ws_call_id in number) return varchar2;


end XXDL_INV_UTIL_PKG;
/
