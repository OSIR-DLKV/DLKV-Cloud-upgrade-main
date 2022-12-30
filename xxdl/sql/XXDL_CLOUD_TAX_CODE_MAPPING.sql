/* $Header: $
============================================================================+
File Name   : XXDL_CLOUD_TAX_CODE_MAPPING.sql
Description : Log table for customer migration to cloud

History     :
v1.0 09.09.2022 ZKOVAC: Initial creation
============================================================================+*/
create table XXDL_CLOUD_TAX_CODE_MAPPING
(
    "EBS_TAX_CODE" VARCHAR2(300 BYTE), 
    "CLOUD_TAX_CODE" VARCHAR2(300 BYTE)
)
;

--create synonym apps.XXDL_CLOUD_TAX_CODE_MAPPING for xxdl.XXDL_CLOUD_TAX_CODE_MAPPING;

/
EXIT;

