/* $Header: $
============================================================================+
File Name   : XXDL_HZ_LOCATIONS.sql
Description : Log table for customer location migration to cloud

History     :
v1.0 09.09.2022 ZKOVAC: Initial creation
============================================================================+*/
create table XXDL_HZ_LOCATIONS
(
    "LOCATION_ID" NUMBER NOT NULL ENABLE, 
	"ADDRESS_TYPE" VARCHAR2(100 BYTE), 
	"ADDRESS1" VARCHAR2(240 BYTE), 
	"ADDRESS2" VARCHAR2(240 BYTE), 
	"ADDRESS3" VARCHAR2(240 BYTE), 
	"ADDRESS4" VARCHAR2(240 BYTE), 
	"CITY" VARCHAR2(60 BYTE), 
	"COUNTRY" VARCHAR2(60 BYTE), 
	"COUNTY" VARCHAR2(60 BYTE), 
	"POSTAL_CODE" VARCHAR2(60 BYTE), 
	"POSTAL_PLUS4_CODE" VARCHAR2(100 BYTE), 
	"STATE" VARCHAR2(60 BYTE), 
	"PROCESS_FLAG" VARCHAR2(1 BYTE), 
	"ERROR_MSG" VARCHAR2(4000 BYTE), 
	"CREATION_DATE" DATE, 
	"LAST_UPDATE_DATE" DATE, 
	"CLOUD_LOCATION_ID" NUMBER
)
;


  CREATE UNIQUE INDEX "XXDL_HZ_LOCATION_T1" ON "XXDL_HZ_LOCATIONS" ("LOCATION_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS" ;

--create synonym apps.XXDL_HZ_LOCATIONS for xxdl.XXDL_HZ_LOCATIONS;

/
EXIT;

