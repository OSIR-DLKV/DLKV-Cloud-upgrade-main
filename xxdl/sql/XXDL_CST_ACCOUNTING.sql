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
     distribution_line_id  NUMBER NOT NULL,
     inv_transaction_id    NUMBER NOT NULL,
     cst_transaction_id    NUMBER NOT NULL,
     inventory_item_id     NUMBER NOT NULL,
     inventory_org_id      NUMBER NOT NULL,
     unit_cost             NUMBER,
     seg1_company          VARCHAR2(30),
     seg2_account          VARCHAR2(30),
     seg3_cost_center      VARCHAR2(30),
     seg4_project          VARCHAR2(30),
     seg5_work_order       VARCHAR2(30),
     seg6_sub_account      VARCHAR2(30),
     seg7_sales_order      VARCHAR2(30),
     seg8_rel_company      VARCHAR2(30),
     accounting_date       DATE,
     accounting_line_type  VARCHAR2(100),
     cost_transaction_type VARCHAR2(100),
     ledger_amount         NUMBER,
     accounted_dr          NUMBER,
     accounted_cr          NUMBER,
     last_update_date      TIMESTAMP NOT NULL,
     downloaded_date       DATE NOT NULL,
     CONSTRAINT xxdl_cst_accounting_pk PRIMARY KEY (distribution_line_id)
  ); 

CREATE INDEX xxdl_cst_accounting_n1 ON xxdl_cst_accounting(last_update_date);

CREATE INDEX xxdl_cst_accounting_n2 ON xxdl_cst_accounting(inv_transaction_id);


