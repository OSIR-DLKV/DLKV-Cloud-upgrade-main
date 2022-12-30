SET DEFINE OFF;
SET VERIFY OFF;
WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
WHENEVER OSERROR EXIT FAILURE ROLLBACK;
create or replace package XXDL_OM_UTIL_PKG as
  /*$Header: $
  =============================================================================
  -- Name        :  XXDL_OM_UTIL_PKG
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
  Function   : DecodeBASE64
  Description : Decodes BASE64
  Usage       : 
  Arguments   : 
  Returns     :
============================================================================+*/
FUNCTION DecodeBASE64(InBase64Char IN OUT NOCOPY CLOB) RETURN CLOB;
  
/*===========================================================================+
  Function   : get_om_mfg_req
  Description : Download supply req for mfg from OM
  Usage       :
  Arguments   : p_entity - name of the entity we download, SUPPLY_HEADERS, SUPPLY_LINES
              p_date - entities max date of creation of last_update_date
  Remarks     :
============================================================================+*/
function get_om_mfg_req(p_entity in varchar2,p_date in varchar2) return varchar2;
  
/*===========================================================================+
  Function   : get_om_mfq_info
  Description : retrieves all mfg for om info to a local EBS custom table
  Usage       : 
  Arguments   :
  Remarks     :
============================================================================+*/
procedure get_om_mfq_info (errbuf out varchar2, retcode out varchar2);

function parse_cs_response(p_ws_call_id in number) return varchar2;

end XXDL_OM_UTIL_PKG;
/
exit;