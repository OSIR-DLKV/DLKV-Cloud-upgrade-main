  /* $Header $
  ============================================================================+
  File Name   : XXDL_MIG_ITEMS_FIXED_LIST.sql
  Object      : XXDL_MIG_ITEMS_FIXED_LIST
  Description : 
  History     :
  v1.0 18.01.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/
  drop table XXDL_MIG_ITEMS_FIXED_LIST;
  
CREATE TABLE XXDL_MIG_ITEMS_FIXED_LIST (
  item_number              varchar2(100) not null,
  organization_code        varchar2(10) not null,
  CONSTRAINT XXDL_MIG_ITEMS_FIXED_LIST_PK PRIMARY KEY (item_number, organization_code)
);

