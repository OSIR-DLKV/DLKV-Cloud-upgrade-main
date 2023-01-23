/* $Header: $
============================================================================+
File Name   : XXDL_CLOUD_INTERNAL_BANK_ACCOUNTS.sql
Description : Log table for customer migration to cloud

History     :
v1.0 09.09.2022 ZKOVAC: Initial creation
============================================================================+*/
create table XXDL_CLOUD_INTERNAL_BANK_ACCOUNTS
(
    "BANK_ACCOUNT_ID" NUMBER, 
    "PARTY_NAME" VARCHAR2(1000 BYTE),
    "BANK_NAME" VARCHAR2(300 BYTE),
    "BANK_ACCOUNT_NAME" VARCHAR2(500 BYTE),
    "IBAN_NUMBER" VARCHAR2(100 BYTE),
    "FULL_NAME" VARCHAR2(4000 BYTE)
)
;

--create synonym apps.XXDL_CLOUD_INTERNAL_BANK_ACCOUNTS for xxdl.XXDL_CLOUD_INTERNAL_BANK_ACCOUNTS;

/
EXIT;

