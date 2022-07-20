  /* $Header $
  ============================================================================+
  File Name   : XXDL_INV_MATERIAL_TXNS_INT.sql
  Object      : XXDL_INV_MATERIAL_TXNS_INT
  Description : Material transactions to be interfaced to Fusion
  History     :
  v1.0 18.07.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/
-- drop table xxdl_inv_material_txns_int

CREATE TABLE xxdl_inv_material_txns_int (
     transaction_interface_id NUMBER NOT NULL,
     batch_id                 NUMBER NOT NULL,
     organization_name        VARCHAR2(300) NOT NULL,
     item_number              VARCHAR2(300) NOT NULL,
     transaction_type_name    VARCHAR2(80) NOT NULL,
     transaction_quantity     NUMBER NOT NULL,
     transaction_uom          VARCHAR2(3) NOT NULL,
     transaction_date         DATE NOT NULL,
     subinventory_code        VARCHAR2(10) NOT NULL,
     locator_name             VARCHAR2(255),
     inv_project_number       VARCHAR2(255),
     inv_task_number          VARCHAR2(255),
     account_combination      VARCHAR2(100) NOT NULL,
     source_code              VARCHAR2(30) NOT NULL,
     source_line_id           NUMBER NOT NULL,
     source_header_id         NUMBER NOT NULL,
     use_current_cost_flag    VARCHAR2(1) NOT NULL, -- Y|N
     transaction_cost         NUMBER,
     transaction_reference    VARCHAR2(240),
     status                   VARCHAR2(15) NOT NULL, -- NEW|PROCESSED|ERROR|IN_PROGRESS
     error_message            VARCHAR2(2000),
     creation_date            DATE NOT NULL,
     last_update_date         DATE NOT NULL,
     CONSTRAINT xxdl_inv_material_txns_int_pk PRIMARY KEY (transaction_interface_id)
  ); 
  
CREATE INDEX xxdl_inv_material_txns_int_N1 ON xxdl_inv_material_txns_int(status);



