/* $Header: $
============================================================================+
File Name   : XXDL_BANK_BRANCHES.sql
Description : Log table for bank branches
History     :
v1.0 30.12.2022 ZKOVAC: Initial creation
============================================================================+*/
  CREATE TABLE "XXDL_BANK_BRANCHES" 
   (	
    "BANK_PARTY_ID" NUMBER, 
	"BANK_HOME_COUNTRY" VARCHAR2(3 BYTE), 
	"BRANCH_PARTY_ID" NUMBER, 
	"BANK_BRANCH_NAME" VARCHAR2(240 BYTE), 
	"BANK_PARTY_NUMBER" VARCHAR2(150 BYTE), 
	"BANK_NAME" VARCHAR2(240 BYTE), 
	"BANK_NUMBER" VARCHAR2(150 BYTE), 
	"BRANCH_PARTY_NUMBER" VARCHAR2(150 BYTE)
   ) SEGMENT CREATION IMMEDIATE 
  PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 
 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
  BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "USERS" ;


--create synonym apps.XXDL_CLOUD_REFERENCE_SETS for xxdl.XXDL_CLOUD_REFERENCE_SETS;

/
EXIT;
