SET DEFINE OFF;
SET VERIFY OFF;
WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
WHENEVER OSERROR EXIT FAILURE ROLLBACK;
create or replace package XXDL_AR_UTIL_PKG as
  /*$Header: $
  =============================================================================
  -- Name        :  XXDL_AR_UTIL_PKG
  -- Author      :  Zoran Kovac
  -- Date        :  07-SEP-2022
  -- Version     :  120.00
  -- Description :  Cloud Utils package
  --
  -- -------- ------ ------------ -----------------------------------------------
  --   Date    Ver     Author     Description
  -- -------- ------ ------------ -----------------------------------------------
  -- 07-09-22 120.00 zkovac       Initial creation 
  --*/

  /*===========================================================================+
    Procedure   : get_config
    Description : Gets config value
    Usage       : Returnig config value
    Arguments   : p_service - text to output
============================================================================+*/
function get_config (p_service IN VARCHAR2) return varchar2;
  /*===========================================================================+
  -- Name    : migrate_customers_cloud
  -- Desc    : Procedure for migrating EBS customers to cloud
  -- Usage   : 
  -- Parameters
  --     - errbuff: Concurrent program message status
  --     - retcode: Concurrent execution status
============================================================================+*/
procedure migrate_customers_cloud (
      p_party_number in varchar2,
      p_rows in number,
      p_retry_error in varchar2);
      
  /*===========================================================================+
  -- Name    : update_customer_cloud
  -- Desc    : Procedure for updating cloud cusgtomers
  -- Usage   : 
  -- Parameters
  --     - errbuff: Concurrent program message status
  --     - retcode: Concurrent execution status
============================================================================+*/
procedure update_customer_cloud (
      p_party_number in varchar2,
      p_rows in number,
      p_retry_error in varchar2);

  /*===========================================================================+
  -- Name    : find_customer_cloud
  -- Desc    : Procedure to find customer in cloud
  -- Usage   : 
  -- Parameters
  --     p_item in varchar2,
  --    p_org in varchar
============================================================================+*/
procedure find_customer_cloud(
      p_party_number in varchar2,
      p_cloud_party_id out number,
      p_cloud_org_id out number);
 
  /*===========================================================================+
  -- Name    : find_address_cloud
  -- Desc    : Function to find customer address in cloud
  -- Usage   : 
  -- Parameters
  --    p_party_number in varchar2,
  --    p_org in varchar
============================================================================+*/
procedure find_address_cloud(
      p_party_number in varchar2,
      p_ws_call_id out number);
      
  /*===========================================================================+
  -- Name    : update_cust_site_tax_ref
  -- Desc    : Update customer acct site tax profile according to country
  -- Usage   : 
  -- Parameters
============================================================================+*/
procedure update_cust_site_tax_ref(
      p_party_number in varchar2);

      
function parse_cs_response(p_ws_call_id in number) return varchar2;




end XXDL_AR_UTIL_PKG;
/
exit;