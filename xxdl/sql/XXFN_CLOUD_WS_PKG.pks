create or replace package XXFN_CLOUD_WS_PKG authid definer is
/* $Header $
============================================================================+
File Name   : XXFN_CLOUD_WS_PKG.pks
Object      : XXFN_CLOUD_WS_PKG
Description : Mirror for Cloud package XXFN_WS_PKG, used for web service calls
              Endpoint for web service calls
History     :
v1.0 25.11.2022 Marko Sladoljev: Copy from XE db to Git
============================================================================+*/

/*===========================================================================+
Procedure   : WS_CALL
Description :
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure WS_CALL(
    p_ws_url          varchar2,
    p_soap_env        clob,
    p_soap_act        varchar2,
    p_content_type    varchar2,
    x_return_status   out nocopy varchar2,
    x_return_message  out nocopy varchar2,
    x_ws_call_id      out nocopy number);

/*===========================================================================+
Procedure   : WS_CALL
Description :
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure WS_CALL_D(
    p_ws_url          varchar2,
    p_soap_env        clob,
    p_soap_act        varchar2,
    p_content_type    varchar2,
    x_return_status   out nocopy varchar2,
    x_return_message  out nocopy varchar2,
    x_ws_call_id      out nocopy number);


/*===========================================================================+
Procedure   : PURGE_OLD_LOG
Description : Deletes records from XXFN_WS_CALL_LOG table
Usage       : 
Arguments   : p_keep_days -> number of days to keep
============================================================================+*/
procedure PURGE_OLD_LOG(
            p_errbuf       out nocopy varchar2,
            p_retcode      out nocopy number,
            p_keep_days    in number);

/*===========================================================================+
Function   : get_tinyurl
Description : calls tinyurl via http call and gets tinyurl of provided p_url
Usage       : 
Arguments   : p_url ->original url
Return      : tinyurl
============================================================================+*/    
function get_tinyurl(p_url in varchar2) return varchar2;

/*===========================================================================+
Procedure   : WS_REST_CALL
Description : Performs REST API call 
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure WS_REST_CALL(
    p_ws_url          varchar2,
    p_rest_env        clob,
    p_rest_act        varchar2,
    p_content_type    varchar2,
    x_return_status   out nocopy varchar2,
    x_return_message  out nocopy varchar2,
    x_ws_call_id      out nocopy number);
    
    /*===========================================================================+
Procedure   : WS_REST_CALL
Description : Performs REST API call 
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure WS_REST_CALL_D(
    p_ws_url          varchar2,
    p_rest_env        clob,
    p_rest_act        varchar2,
    p_content_type    varchar2,
    x_return_status   out nocopy varchar2,
    x_return_message  out nocopy varchar2,
    x_ws_call_id      out nocopy number);

/*===========================================================================+
Procedure   : DELETE_LOBS_FROM_LOG
Description : Empties blob and xmltype columns for given row in XXFN_WS_CALL_LOG table
Usage       : 
Arguments   : p_ws_call_id -> web service call identifier
============================================================================+*/
procedure DELETE_LOBS_FROM_LOG(
    p_ws_call_id    in xxfn_ws_call_log_v.ws_call_id%type);

/*===========================================================================+
Procedure   : BLOB_TO_CLOB
Description : Converts blob to clob
Usage       : 
Arguments   : p_data in blob
============================================================================+*/   
function blob_to_clob(b blob) return clob;

/*===========================================================================+
Procedure   : CLOB_TO_BLOB
Description : Converts clob to blob
Usage       : 
Arguments   : p_data in clob
============================================================================+*/
FUNCTION clob_to_blob (p_data  IN  CLOB) RETURN BLOB;

/*===========================================================================+
  Function   : DecodeBASE64
  Description : Decodes BASE64
  Usage       :
  Arguments   :
  Returns     :
============================================================================+*/
FUNCTION DecodeBASE64(InBase64Char IN OUT NOCOPY CLOB) RETURN CLOB;

/*===========================================================================+
  Function   : send_csv_to_cloud
  Description : 
  Usage       :
  Arguments   :
  Returns     :
============================================================================+*/
procedure send_csv_to_cloud(p_document      in varchar2,
                              p_doc_name      in varchar2,
                              p_doc_type      in varchar2,
                              p_author        in varchar2,
                              p_app_account   in varchar2,
                              p_job_name      in varchar2,
                              p_job_option    in varchar2,
                              p_wsdl_link     in varchar2,
                              p_wsdl_method   in varchar2,
                              x_return_status out varchar2,
                              x_msg           out varchar2,
                              x_ws_call_id out number);

  /*===========================================================================+
  Procedure   : submit_ess_job
  Description : Submit ESS job on Cloud (concurrent)
  Usage       : 
  Arguments   : p_job_name          - path of the ESS job
                p_definition_name   - name of the job
                p_params            - list of parameters delimited with comma
                x_ws_call_id        - ID of ws call
  ============================================================================+*/
  procedure submit_ess_job(p_job_name in varchar2,
                           p_definition_name in varchar2,
                           p_params in varchar2,
                           x_ws_call_id out number);

/*===========================================================================+
  Function   : parse_params
  Description : Exploder params sent as a string
  Usage       : 
  Arguments   : p_params        - list of parameters delimited with comma
  Return      : Return list of parameters in xml definition
  ============================================================================+*/
  function parse_params(p_params in varchar2) return varchar2;

end XXFN_CLOUD_WS_PKG;
