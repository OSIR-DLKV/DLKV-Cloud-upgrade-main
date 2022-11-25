  /* $Header $
  ============================================================================+
  File Name   : XXDL_INV_TRANSACTION_TYPES.sql
  Object      : XXDL_INV_TRANSACTION_TYPES
  Description : Inventory Transaction Types from Fusion
  History     :
  v1.0 17.09.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/

drop table XXDL_INV_TRANSACTION_TYPES;

CREATE TABLE XXDL_INV_TRANSACTION_TYPES (
     transaction_type_id      NUMBER NOT NULL,
     transaction_type_name_hr VARCHAR2(80) NOT NULL,
     transaction_type_name_us VARCHAR2(80) NOT NULL,
     trans_type_code          VARCHAR2(240),
     dlkv_code                VARCHAR2(240),
     last_update_date         TIMESTAMP NOT NULL,
     downloaded_date          DATE NOT NULL,
     CONSTRAINT xxdl_inv_transaction_types_pk PRIMARY KEY (transaction_type_id)
  ); 
CREATE INDEX XXDL_INV_TRANSACTION_TYPES_N1 ON XXDL_INV_TRANSACTION_TYPES(last_update_date);
CREATE UNIQUE INDEX XXDL_INV_TRANSACTION_TYPES_U1 ON XXDL_INV_TRANSACTION_TYPES(transaction_type_name_hr);
CREATE UNIQUE INDEX XXDL_INV_TRANSACTION_TYPES_U2 ON XXDL_INV_TRANSACTION_TYPES(transaction_type_name_us);
