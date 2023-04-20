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
      p_party_id in varchar2
      ,p_cust_account_id in varchar2
      ,p_type in varchar2);

/*===========================================================================+
 -- Name    : update_supplier_tax_ref
 -- Desc    : Update supplier and supplier site tax profile
 -- Usage   : 
 -- Parameters
 ============================================================================+*/
 procedure update_supplier_tax_ref(
     p_supplier_number in varchar2);
 
/*===========================================================================+
 -- Name    : update_supplier_payment_method
 -- Desc    : Update supplier payment method
 -- Usage   : 
 -- Parameters
 ============================================================================+*/
 procedure update_supplier_payment_method(
        p_supplier_number in varchar2);

/*===========================================================================+
  -- Name    : update_cust_acc_profile
  -- Desc    : Update customer acct profile
  -- Usage   : 
  -- Parameters
============================================================================+*/
procedure update_cust_acc_profile(
    p_party_number in varchar2);

/*===========================================================================+
  Function   : DecodeBASE64
  Description : Decodes BASE64
  Usage       : 
  Arguments   : 
  Returns     :
============================================================================+*/
FUNCTION DecodeBASE64(InBase64Char IN OUT NOCOPY CLOB) RETURN CLOB;

/*===========================================================================+
Function   : get_suppliers
Description : Download suppliers, addresses, sites and contacts from cloud to EBS. Update existing records if there were changes after max(transfer creation_date)
Usage       :
Arguments   : p_entity - name of the entity we download, SUPPLIER,SUPPLIER_SITES, SUPPLIER_ADDRESSES, SUPPLIER_CONTACTS
              p_date - entities max date of creation of last_update_date
Remarks     :
============================================================================+*/
function get_suppliers(p_entity in varchar2,p_date in varchar2) return varchar2;

/*===========================================================================+
Function   : get_supplier_info
Description : retrieves all supplier (supplier, site, address, contact) info to a local EBS custom table
Usage       : Callin from DB scheduled job
Arguments   :
Remarks     :
============================================================================+*/
procedure get_supplier_info (errbuf out varchar2, retcode out varchar2);

/*===========================================================================+
  -- Name    : migrate_suppliers_cloud
  -- Desc    : Migrate supppliers based on imported customers
  -- Usage   : 
  -- Parameters
============================================================================+*/
procedure migrate_suppliers_cloud(
      p_party_number in varchar2);

/*===========================================================================+
  -- Name    : migrate_nuf_suppliers_cloud
  -- Desc    : Migrate supppliers only for NUF and SVENSKA
  -- Usage   : 
  -- Parameters
============================================================================+*/
procedure migrate_nuf_suppliers_cloud(
      p_party_number in varchar2);


/*===========================================================================+
-- Name    : reset_cust_mig
-- Desc    : Update customer acct profile
-- Usage   : 
-- Parameters
============================================================================+*/
procedure reset_cust_mig(p_party_number in varchar2);

/*===========================================================================+
-- Name    : reset_cust_mig
-- Desc    : Update customer acct profile
-- Usage   : 
-- Parameters
============================================================================+*/
procedure reset_sup_mig(p_supplier_number in varchar2);      


/*===========================================================================+
   -- Name    : update_sup_routing
   -- Desc    : Update supplier routing ids
   -- Usage   : 
   -- Parameters
============================================================================+*/
procedure update_sup_routing(
        p_vendor_id in number,
        p_vendor_site_id in number);


function parse_cs_response(p_ws_call_id in number) return varchar2;




end XXDL_AR_UTIL_PKG;
/
exit;