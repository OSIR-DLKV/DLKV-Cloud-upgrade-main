/* $Header: $
============================================================================+
File Name   : XXDL_HZ_PARTY_SITES.sql
Description : Log table for customer sites migration to cloud

History     :
v1.0 09.09.2022 ZKOVAC: Initial creation
============================================================================+*/
create table XXDL_HZ_PARTY_SITES
(
    "PARTY_SITE_ID" NUMBER NOT NULL ENABLE, 
    "PARTY_ID" NUMBER NOT NULL ENABLE, 
    "LOCATION_ID" NUMBER NOT NULL ENABLE, 
	"PARTY_SITE_NUMBER" VARCHAR2(30 BYTE), 
	"IDENTIFYING_ADDRESS_FLAG" VARCHAR2(2 BYTE), 
	"STATUS" VARCHAR2(2 BYTE), 
	"PARTY_SITE_NAME" VARCHAR2(240 BYTE), 
	"LANGUAGE" VARCHAR2(3 BYTE), 
	"PROCESS_FLAG" VARCHAR2(1 BYTE), 
	"ERROR_MSG" VARCHAR2(4000 BYTE), 
	"CREATION_DATE" DATE, 
	"LAST_UPDATE_DATE" DATE, 
	"CLOUD_PARTY_SITE_ID" NUMBER,
	"CLOUD_PARTY_ID" NUMBER
)
;


  CREATE UNIQUE INDEX "XXDL_HZ_PARTY_SITE_T1" ON "XXDL_HZ_PARTY_SITES" ("PARTY_SITE_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS" ;

--create synonym apps.XXDL_HZ_PARTY_SITES for xxdl.XXDL_HZ_PARTY_SITES;

/
EXIT;

