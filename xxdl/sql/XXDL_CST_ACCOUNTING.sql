  /* $Header $
  ============================================================================+
  File Name   : XXDL_CST_ACCOUNTING.sql
  Object      : XXDL_CST_ACCOUNTING
  Description : Material transactions accounting from Fusion
  History     :
  v1.0 26.09.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/

drop table XXDL_CST_ACCOUNTING;

CREATE TABLE xxdl_cst_accounting(
     ae_header_id          NUMBER NOT NULL,
     ae_line_num           NUMBER NOT NULL,
     inv_transaction_id    NUMBER NOT NULL,
     cst_transaction_id    NUMBER NOT NULL,
     inventory_item_id     NUMBER NOT NULL,
     inventory_org_id      NUMBER NOT NULL,
     unit_cost             NUMBER,
     seg1_company          VARCHAR2(30) NOT NULL,
     seg2_account          VARCHAR2(30) NOT NULL,
     seg3_cost_center      VARCHAR2(30) NOT NULL,
     seg4_project          VARCHAR2(30) NOT NULL,
     seg5_work_order       VARCHAR2(30) NOT NULL,
     seg6_sub_account      VARCHAR2(30) NOT NULL,
     seg7_sales_order      VARCHAR2(30) NOT NULL,
     seg8_rel_company      VARCHAR2(30) NOT NULL,
     accounting_date       DATE NOT NULL,
     accounting_line_type  VARCHAR2(100) NOT NULL,
     cost_transaction_type VARCHAR2(100) NOT NULL,
     ledger_amount         NUMBER,
     accounted_dr          NUMBER,
     accounted_cr          NUMBER,
     last_update_date      TIMESTAMP NOT NULL,
     downloaded_date       DATE NOT NULL,
     CONSTRAINT xxdl_cst_accounting_pk PRIMARY KEY (ae_header_id, ae_line_num)
  ); 

CREATE INDEX xxdl_cst_accounting_n1 ON xxdl_cst_accounting(last_update_date);
