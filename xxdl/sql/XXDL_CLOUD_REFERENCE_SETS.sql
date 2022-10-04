/* $Header: $
============================================================================+
File Name   : XXDL_CLOUD_REFERENCE_SETS.sql
Description : Log table for customer migration to cloud

History     :
v1.0 09.09.2022 ZKOVAC: Initial creation
============================================================================+*/
create table XXDL_CLOUD_REFERENCE_SETS
(
    "REFERENCE_DATA_SET_CODE" VARCHAR2(40 BYTE), 
    "REFERENCE_DATA_SET_ID" NUMBER, 
	"EBS_ORG_ID" NUMBER NOT NULL ENABLE,
	"BUSINESS_UNIT_NAME" VARCHAR2(200 BYTE),
	"BUSINESS_UNIT_ID" NUMBER, 
	"CREATION_DATE" DATE, 
	"LAST_UPDATE_DATE" DATE
)
;

--create synonym apps.XXDL_CLOUD_REFERENCE_SETS for xxdl.XXDL_CLOUD_REFERENCE_SETS;

/
EXIT;

