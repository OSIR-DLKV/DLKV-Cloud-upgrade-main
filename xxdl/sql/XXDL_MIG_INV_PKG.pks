/* $Header $
============================================================================+
File Name   : XXDL_MIG_INV_PKG.pks
Description : Package for Inventory migrations

History     :
v1.0 28.07.2022 - Marko Sladoljev: Initial creation	
============================================================================+*/

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

create or replace package xxdl_mig_inv_pkg as

  procedure migrate_onhand_all; 

  procedure migrate_onhand(p_org_code varchar2 default null, p_item varchar2 default null);

  procedure export_onhand(p_org_code varchar2 default null, p_item varchar2 default null);
  
  function get_org_name(p_org_code varchar2) return varchar2;
  
  function get_company_segment1(p_org_code varchar2) return varchar2;

end xxdl_mig_inv_pkg;
/
