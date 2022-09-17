  /* $Header $
  ============================================================================+
  File Name   : XXDL_EGP_SYSTEM_ITEMS.sql
  Object      : XXDL_EGP_SYSTEM_ITEMS
  Description : Items from Fusion
  History     :
  v1.0 16.09.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/

drop table XXDL_EGP_SYSTEM_ITEMS;

CREATE TABLE XXDL_EGP_SYSTEM_ITEMS (
    organization_id     NUMBER  NOT NULL,
    inventory_item_id   NUMBER  NOT NULL,
    item_number         VARCHAR2(100) NOT NULL,
    description         VARCHAR2(500) NOT NULL,  
    primary_uom_code    VARCHAR2(100) NOT NULL, 
    inventory_item_flag VARCHAR2(1) NOT NULL,   
    cost_category_code  VARCHAR2(30) NOT NULL,   
    last_update_date    TIMESTAMP NOT NULL,
    downloaded_date     DATE NOT NULL,
    CONSTRAINT XXDL_EGP_SYSTEM_ITEMS_PK PRIMARY KEY (organization_id, inventory_item_id)
  ); 
  
CREATE INDEX XXDL_EGP_SYSTEM_ITEMS_N1 ON XXDL_EGP_SYSTEM_ITEMS(last_update_date);
