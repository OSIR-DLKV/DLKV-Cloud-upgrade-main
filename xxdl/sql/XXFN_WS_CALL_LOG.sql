  /* $Header $
  ============================================================================+
  File Name   : XXFN_WS_CALL_LOG.sql
  Object      : XXFN_WS_CALL_LOG
  Description : Web servicess call log table
  History     :
  v1.0 18.07.2022 Marko Sladoljev: Inicijalna verzija (response_json added)
  ============================================================================+*/
CREATE TABLE xxfn_ws_call_log2 (
     ws_call_id                NUMBER NOT NULL ENABLE,
     ws_call_timestamp         TIMESTAMP (6) NOT NULL ENABLE,
     ws_url                    VARCHAR2(1000),
     ws_soap_action            VARCHAR2(500),
     ws_payload                CLOB,
     ws_payload_xml            sys.XMLTYPE,
     response_status_code      VARCHAR2(500),
     response_reason_phrase    VARCHAR2(500),
     response_content_encoding VARCHAR2(250),
     response_xml              sys.XMLTYPE,
     response_json             CLOB,
     response_clob             CLOB,
     response_blob             BLOB,
     ws_response_timestamp     TIMESTAMP (6),
     batch_no                  NUMBER(*, 0),
     entity                    VARCHAR2(20),
     entity_id                 NUMBER(*, 0),
	 CONSTRAINT XXFN_WS_CALL_LOG_CHK2 CHECK (response_json is json) ENABLE
  ); 
