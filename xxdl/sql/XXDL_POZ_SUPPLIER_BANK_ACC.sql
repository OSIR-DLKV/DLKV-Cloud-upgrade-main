/* $Header: $
============================================================================+

File Name   : XXDL_POZ_SUPPLIER_BANK_ACC.sql
Description : Table creation script 


History     :
V1.0 19.07.2019 - Zoran Kovac - initial creation
============================================================================+*/

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

PROMPT XXDL_POZ_SUPPLIER_BANK_ACC;
--drop index XXDL_POZ_SUPPLIER_BANK_ACC_U1;
--drop table XXDL_POZ_SUPPLIER_BANK_ACC;

CREATE
  TABLE "XXDL_POZ_SUPPLIER_BANK_ACC"
  (
    EXT_BANK_ACCOUNT_ID NUMBER NOT NULL,
    BANK_NAME VARCHAR2(960),
    BANK_ADDRESS VARCHAR2(960),
    IBAN VARCHAR2(240),
    CURRENCY_CODE VARCHAR2(3),
    COUNTRY_CODE VARCHAR2(2),
    BANK_ACCOUNT_NUM VARCHAR2(240),
    START_DATE date,
    END_DATE	 date,
    SIWFT_CODE  VARCHAR2(35),
    VENDOR_ID  NUMBER ,
    PARTY_ID NUMBER ,
    VENDOR_NAME VARCHAR2(240),
    SUPPLIER_NUMBER VARCHAR2(100),
    CREATION_DATE date,
    LAST_UPDATE_DATE date,
    TRANSF_CREATION_DATE DATE,
    TRANSF_LAST_UPDATE   DATE,
    PARTY_SITE_ID NUMBER,
    SUPPLIER_SITE_ID NUMBER,
    CLOUD_PARTY_ID NUMBER,
    CLOUD_PARTY_SITE_ID NUMBER,
    CLOUD_SUPPLIER_SITE_ID NUMBER,
    CLOUD_EXT_PAYEE_ID NUMBER,
    CLOUD_OWNER_ID NUMBER,
    PROCESS_FLAG VARCHAR2(1),
    ERROR_MESSAGE VARCHAR2(4000),
    CLOUD_OWNER_SET VARCHAR2(1),
    CLOUD_ASSIGN VARCHAR2(1),
    BANK_ID NUMBER,
    BANK_BRANCH_ID NUMBER,
    CLOUD_BANK_ID NUMBER,
    CLOUD_BRANCH_ID NUMBER,
    cloud_payment_instrument_id number,
    PRIMARY_FLAG VARCHAR2(1)
   );
  
  
    CREATE UNIQUE INDEX "XXDL_POZ_SUPPLIER_BANK_ACC_U1" ON "XXDL_POZ_SUPPLIER_BANK_ACC" ("EXT_BANK_ACCOUNT_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS" ;

EXIT;

