/* $Header: $
============================================================================+
File Name   : XXDL_CLOUD_OM_ORDER_TYPES.sql
Description : Log table for customer migration to cloud

History     :
v1.0 09.09.2022 ZKOVAC: Initial creation
============================================================================+*/
create table XXDL_CLOUD_OM_ORDER_TYPES
(
    "TRANSACTION_TYPE_ID" NUMBER, 
	"NAME" VARCHAR2(300),
	"CLOUD_CODE" VARCHAR2(500 BYTE)
)
;

--create synonym apps.XXDL_CLOUD_OM_ORDER_TYPES for xxdl.XXDL_CLOUD_OM_ORDER_TYPES;

/
EXIT;

