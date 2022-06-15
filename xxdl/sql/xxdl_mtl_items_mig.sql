/* $Header: $
============================================================================+
File Name   : XXDL_CS_ITEMS_MIGRATE.sql
Description : Log table for items migration to cloud

History     :
v1.0 28.04.2022 ZKOVAC: Initial creation
============================================================================+*/
create table xxdl_mtl_system_items_mig
(
"SEGMENT1" VARCHAR2(40 BYTE), 
	"INVENTORY_ITEM_ID" NUMBER NOT NULL ENABLE, 
	"ORGANIZATION_ID" NUMBER NOT NULL ENABLE, 
	"ORGANIZATION_CODE" VARCHAR2(3 BYTE), 
	"DESCRIPTION" VARCHAR2(240 BYTE), 
	"PRIMARY_UOM_CODE" VARCHAR2(3 BYTE), 
	"PROCESS_FLAG" VARCHAR2(1 BYTE), 
	"ERROR_MSG" VARCHAR2(4000 BYTE), 
	"CREATION_DATE" DATE, 
	"LAST_UPDATE_DATE" DATE, 
	"CATEGORY" VARCHAR2(100 BYTE), 
	"ACCOUNT" VARCHAR2(10 BYTE),
	"CLOUD_ITEM_ID" NUMBER, 
	"CLOUD_ORG_ID" NUMBER)
;


  CREATE UNIQUE INDEX "XXDL_MTL_ITEMS1" ON "XXDL_MTL_SYSTEM_ITEMS_MIG" ("INVENTORY_ITEM_ID","ORGANIZATION_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS" ;

--create synonym apps.xxdl_cs_items_migrate for xxdl.xxdl_cs_items_migrate;

create table xxdl_mtl_items_tl_mig
(
inventory_item_id number
,organization_id number
,description varchar2(240)
,long_description varchar2(4000)
,source_lang varchar2(2)
,to_lang varchar2(2)
,process_flag varchar2(1)
,error_msg varchar2(4000)
,creation_date date
,last_update_date date)
;


  CREATE UNIQUE INDEX "XXDL_MTL_ITEMS_TL1" ON "XXDL_MTL_ITEMS_TL_MIG" ("INVENTORY_ITEM_ID, ORG_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS" ;

--create synonym apps.xxdl_cs_items_tl_migrate for xxdl.xxdl_cs_items_tl_migrate;

/
EXIT;

