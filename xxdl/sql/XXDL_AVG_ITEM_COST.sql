  /* $Header $
  ============================================================================+
  File Name   : XXDL_AVG_ITEM_COST.sql
  Object      : XXDL_AVG_ITEM_COST
  Description : Items costs from Fusion
  History     :
  v1.0 12.09.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/

drop table XXDL_AVG_ITEM_COST;

CREATE TABLE XXDL_AVG_ITEM_COST (
    inventory_item_id   NUMBER NOT NULL,
    val_unit_code       VARCHAR2(100) NOT NULL,     
    inv_organization_id NUMBER NOT NULL,
    cost_org_code       VARCHAR2(100) NOT NULL, 
    inv_org_code        VARCHAR2(100) NOT NULL, 
    project_number      VARCHAR2(100),   
    unit_cost_average   NUMBER,
    quantity_onhand     NUMBER,
    uom_code            VARCHAR2(30),
    last_update_date    TIMESTAMP NOT NULL,
    downloaded_date     DATE NOT NULL,
    CONSTRAINT XXDL_AVG_ITEM_COST_PK PRIMARY KEY (inventory_item_id, val_unit_code)
  ); 
  
CREATE INDEX XXDL_AVG_ITEM_COST_N1 ON XXDL_AVG_ITEM_COST(last_update_date);
