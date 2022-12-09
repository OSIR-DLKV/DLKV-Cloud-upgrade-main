create or replace package XXFN_WS_PKG authid definer is
/* $Header $
============================================================================+
File Name   : XXFN_WS_PKG.pks
Description : Package for web service call utilities
History     :
v1.0 25.11.2022 Marko Sladoljev: Copy from XE db to Git
v1.1 25.11.2022 Marko Sladoljev: Removed scheme prefix
============================================================================+*/

type raw_table is table of raw(20000) index by binary_integer;

G_SOAP_ENVELOPE   clob;
G_REST_ENVELOPE   clob;
G_RETURN_STATUS   varchar2(10);
G_RETURN_MESSAGE  varchar2(10000);
G_WS_CALL_ID      number;

G_RAW_TABLE       raw_table;
G_RAW_TABLE_EMPTY raw_table;

/*===========================================================================+
Procedure   : BUILD_SOAP_ENVELOPE
Description : Builds G_SOAP_ENVELOPE global from chunks
Usage       : Call as many times as needed to transfer all data
Arguments   :
============================================================================+*/
procedure BUILD_SOAP_ENVELOPE(
    p_chunk   varchar2);

/*===========================================================================+
Procedure   : BUILD_SOAP_ENVELOPEB
Description : Adds chunks to G_RAW_TABLE global table that is used later for soap envelope
Usage       :
Arguments   :
============================================================================+*/
procedure BUILD_SOAP_ENVELOPEB(
    p_chunk   raw);

/*===========================================================================+
Procedure   : BUILD_REST_ENVELOPE
Description : Builds G_REST_ENVELOPE global from chunks
Usage       : Call as many times as needed to transfer all data
Arguments   :
============================================================================+*/
procedure BUILD_REST_ENVELOPE(
    p_chunk   varchar2);

/*===========================================================================+
Procedure   : BUILD_REST_ENVELOPEB
Description : Adds chunks to G_RAW_TABLE global table that is used later for soap envelope
Usage       :
Arguments   :
============================================================================+*/
procedure BUILD_REST_ENVELOPEB(
    p_chunk   raw);

/*===========================================================================+
Procedure   : BUILD_RETURN_MESSAGE
Description : Adds given text to G_RETURN_MESSAGE global
Usage       :
Arguments   :
============================================================================+*/
procedure BUILD_RETURN_MESSAGE(
    p_text   varchar2);

/*===========================================================================+
Function    : GET_RETURN_STATUS
Description : Returns and resets value of G_RETURN_STATUS global
Usage       : Call just once after WS_CALL
Arguments   :
============================================================================+*/
function GET_RETURN_STATUS return varchar2;

/*===========================================================================+
Function    : GET_RETURN_MESSAGE
Description : Returns and resets value of G_RETURN_MESSAGE global
Usage       : Call just once after WS_CALL
Arguments   :
============================================================================+*/
function GET_RETURN_MESSAGE return varchar2;

/*===========================================================================+
Function    : GET_WS_CALL_ID
Description : Returns and resets value of G_WS_CALL_ID global that contains the actual call's ID
Usage       : Call just once after WS_CALL
Arguments   :
============================================================================+*/
function GET_WS_CALL_ID return number;

/*===========================================================================+
Procedure   : WS_CALL
Description : Calls the given web service and writes log to XXFN_WS_CALL_LOG table
Usage       : If p_soap_envb is supplied the it is used for the call, otherwise p_soap_env is used
Arguments   :
============================================================================+*/
procedure WS_CALL(
    p_ws_url        in varchar2,
    p_soap_env      in clob,
    p_soap_envb     in blob default null,
    p_soap_act      in varchar2,
    p_content_type  in varchar2,
    p_cloud_user    in varchar2 default null,
    p_cloud_pass    in varchar2 default null,
    x_return_status out nocopy varchar2);

/*===========================================================================+
Procedure   : WS_CALL
Description : Overload for using through database link
Usage       : Call BUILD_SOAP_ENVELOPE or BUILD_SOAP_ENVELOPEB before this to compose the SOAP envelope
Arguments   :
============================================================================+*/
procedure WS_CALL(
    p_ws_url          in varchar2,
    p_soap_act        in varchar2,
    p_content_type    in varchar2,
    p_cloud_user      in varchar2 default null,
    p_cloud_pass      in varchar2 default null);

/*===========================================================================+
Procedure   : PURGE_OLD_LOG
Description : Deletes records from XXFN_WS_CALL_LOG table
Usage       : 
Arguments   : p_keep_days -> number of days to keep
============================================================================+*/
procedure PURGE_OLD_LOG(
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
Description : Calls REST API on PaaS
Usage       :
Arguments   :
============================================================================+*/
procedure WS_REST_CALL(
    p_ws_url        in varchar2,
    p_rest_env      in clob,
    p_rest_envb     in blob default null,
    p_rest_act      in varchar2,
    p_content_type  in varchar2,
    p_cloud_user    in varchar2 default null,
    p_cloud_pass    in varchar2 default null,
    x_return_status out nocopy varchar2);

/*===========================================================================+
Procedure   : WS_REST_CALL
Description : overloaded
Usage       :
Arguments   :
============================================================================+*/
procedure WS_REST_CALL(
    p_ws_url          in varchar2,
    p_rest_act        in varchar2,
    p_content_type    in varchar2,
    p_cloud_user      in varchar2 default null,
    p_cloud_pass      in varchar2 default null);

/*===========================================================================+
Procedure   : DELETE_LOBS_FROM_LOG
Description : Empties blob and xmltype columns for given row in XXFN_WS_CALL_LOG table
Usage       : 
Arguments   : p_ws_call_id -> web service call identifier
============================================================================+*/
procedure DELETE_LOBS_FROM_LOG(
    p_ws_call_id    in xxfn_ws_call_log.ws_call_id%type);

procedure insert_vendor(p_id number, p_name varchar2, p_addres varchar2);

end XXFN_WS_PKG;
/
