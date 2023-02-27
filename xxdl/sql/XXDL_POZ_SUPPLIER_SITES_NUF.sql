/* $Header: $
============================================================================+

File Name   : XXDL_POZ_SUPPLIER_SITES_NUF.sql
Description : Table creation script 


History     :
V1.0 15.02.2023 - Zoran Kovac - initial creation
============================================================================+*/

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

PROMPT XXDL_POZ_SUPPLIER_SITES_NUF;
--drop index XXDL_POZ_SUPPLIER_BANK_ACC_U1;
--drop table XXDL_POZ_SUPPLIER_BANK_ACC;

CREATE
  TABLE "XXDL_POZ_SUPPLIER_SITES_NUF"
  (
  "VENDOR_ID" NUMBER, 
	"VENDOR_SITE_ID" NUMBER, 
	"VENDOR_SITE_CODE" VARCHAR2(60 BYTE), 
	"PARTY_SITE_ID" NUMBER, 
    "NEW_VENDOR_SITE_ID" NUMBER,
    "BU_NAME" VARCHAR2(100),
	"CREATION_DATE" DATE, 
	"LAST_UPDATE_DATE" DATE
   );
  
  
  CREATE UNIQUE INDEX "XXDL_POZ_SUPPLIER_SITES_NUF_U1" ON "XXDL_POZ_SUPPLIER_SITES_NUF" ("VENDOR_SITE_ID","BU_NAME") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS" ;

EXIT;
/

