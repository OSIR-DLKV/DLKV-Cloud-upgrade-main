/* $Header: $
============================================================================+

File Name   : XXDL_POZ_SUPPLIER_SITES.sql
Description : Table creation script 


History     :
V1.0 03.10.2022 - Zoran Kovac - initial creation
============================================================================+*/

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

PROMPT XXDL_POZ_SUPPLIER_SITES;
--drop index XXDL_POZ_SUPPLIER_BANK_ACC_U1;
--drop table XXDL_POZ_SUPPLIER_BANK_ACC;

CREATE
  TABLE "XXDL_POZ_SUPPLIER_SITES"
  (
  "VENDOR_ID" NUMBER, 
	"VENDOR_SITE_ID" NUMBER, 
	"VENDOR_SITE_CODE" VARCHAR2(60 BYTE), 
	"PARTY_SITE_ID" NUMBER, 
	"CREATION_DATE" DATE, 
	"LAST_UPDATE_DATE" DATE, 
	"TRANSF_CREATION_DATE" DATE, 
	"TRANSF_LAST_UPDATE" DATE, 
	"INACTIVE_DATE" DATE, 
	"BU_NAME" VARCHAR2(100 BYTE), 
	"CLOUD_IMPORTED" VARCHAR2(1 BYTE), 
	"CLOUD_IMPORT_MESSAGE" VARCHAR2(4000 BYTE), 
	"CLOUD_SITE_ASSIGNMENT" VARCHAR2(1 BYTE)
   );
  
  
  CREATE UNIQUE INDEX "XX_INTEGRATION_DEV"."XXXDL_POZ_SUPPLIER_SITES_U1" ON "XX_INTEGRATION_DEV"."XXDL_POZ_SUPPLIER_SITES" ("VENDOR_SITE_ID", "BU_NAME") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS" ;

EXIT;
/

