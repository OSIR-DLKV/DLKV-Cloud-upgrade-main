  /* $Header $
  ============================================================================+
  File Name   : XXDL_AVG_ITEM_COST.sql
  Object      : XXDL_AVG_ITEM_COST
  Description : Items costs from Fusion
  History     :
  v1.0 12.09.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/

drop table XXDL_AVG_ITEM_COST;

CREATE TABLE xxdl_avg_item_cost (
     cost_org          VARCHAR2(100) NOT NULL,
     inventory_item_id NUMBER NOT NULL,
     item_number       VARCHAR2(100) NOT NULL,
     val_unit_code     VARCHAR2(100) NOT NULL,
     unit_cost_average NUMBER,
     quantity_onhand   NUMBER,
     uom_code          VARCHAR2(30),
     last_update_date  DATE NOT NULL,
     downloaded_date   DATE NOT NULL
  ); 
  
CREATE INDEX XXDL_AVG_ITEM_COST_N1 ON XXDL_AVG_ITEM_COST(last_update_date);