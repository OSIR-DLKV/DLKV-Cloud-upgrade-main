/* $Header: $
============================================================================+
File Name   : XXDL_HZ_PARTIES.sql
Description : Log table for customer migration to cloud

History     :
v1.0 09.09.2022 ZKOVAC: Initial creation
============================================================================+*/
create table xxdl_hz_parties
(
    "PARTY_NUMBER" VARCHAR2(40 BYTE), 
	"PARTY_ID" NUMBER NOT NULL ENABLE, 
    "PARTY_NAME" VARCHAR2(240 BYTE), 
	"TAXPAYER_ID" VARCHAR2(100 BYTE), 
	"DUNS_NUMBER" VARCHAR2(100 BYTE), 
    "PARTY_USAGE_CODE" VARCHAR2(100 BYTE),
	"PROCESS_FLAG" VARCHAR2(1 BYTE), 
	"ERROR_MSG" VARCHAR2(4000 BYTE), 
	"CREATION_DATE" DATE, 
	"LAST_UPDATE_DATE" DATE, 
	"CLOUD_PARTY_ID" NUMBER)
;


  CREATE UNIQUE INDEX "XXDL_HZ_PARTY_T1" ON "XXDL_HZ_PARTIES" ("PARTY_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS" ;

--create synonym apps.XXDL_HZ_PARTIES for xxdl.XXDL_HZ_PARTIES;

/
EXIT;

