  /* $Header $
  ============================================================================+
  File Name   : XXFN_WS_CALL_LOG_V.sql
  Object      : XXFN_WS_CALL_LOG_V
  Description : 
  History     :
  v1.0 25.11.2022 - Marko Sladoljev: Copy from XE db to Git, removed schema prefix
  ============================================================================+*/
create or replace view XXFN_WS_CALL_LOG_V as
select ws_call_id,
       ws_call_timestamp,
       ws_url,
       ws_soap_action,
       ws_payload_xml,
       response_status_code,
       response_reason_phrase,
       response_content_encoding,
       response_xml
from XXFN_WS_CALL_LOG;


  
