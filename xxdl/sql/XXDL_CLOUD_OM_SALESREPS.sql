/* $Header: $
============================================================================+
File Name   : XXDL_CLOUD_OM_SALESREPS.sql
Description : Log table for customer migration to cloud

History     :
v1.0 09.09.2022 ZKOVAC: Initial creation
============================================================================+*/
create table XXDL_CLOUD_OM_SALESREPS
(
    "RESOURCE_ID" NUMBER, 
	"RESOURCE_SALESREP_ID" NUMBER,
	"SALESREP_NUMBER" VARCHAR2(20 BYTE),
	"SALESREP_NAME" VARCHAR2(500 BYTE)
)
;

--create synonym apps.XXDL_CLOUD_OM_SALESREPS for xxdl.XXDL_CLOUD_OM_SALESREPS;

/
EXIT;

