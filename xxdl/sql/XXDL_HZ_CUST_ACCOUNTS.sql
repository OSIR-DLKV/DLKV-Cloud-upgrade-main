/* $Header: $
============================================================================+
File Name   : XXDL_HZ_CUST_ACCOUNTS.sql
Description : Log table for customer accounts migration to cloud

History     :
v1.0 09.09.2022 ZKOVAC: Initial creation
============================================================================+*/
create table XXDL_HZ_CUST_ACCOUNTS
(
    "CUST_ACCOUNT_ID" NUMBER NOT NULL ENABLE, 
    "PARTY_ID" NUMBER NOT NULL ENABLE, 
	"ACCOUNT_NAME" VARCHAR2(240 BYTE), 
	"ACCOUNT_NUMBER" VARCHAR2(30 BYTE), 
	"STATUS" VARCHAR2(2 BYTE), 
	"CUSTOMER_TYPE" VARCHAR2(30 BYTE), 
	"PROCESS_FLAG" VARCHAR2(1 BYTE), 
	"ERROR_MSG" VARCHAR2(4000 BYTE), 
	"CREATION_DATE" DATE, 
	"LAST_UPDATE_DATE" DATE, 
	"CLOUD_CUST_ACCOUNT_ID" NUMBER,
	"CLOUD_PARTY_ID" NUMBER
)
;


  CREATE UNIQUE INDEX "XXDL_HZ_CUST_ACCOUNT_T1" ON "XXDL_HZ_CUST_ACCOUNTS" ("CUST_ACCOUNT_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS" ;

--create synonym apps.XXDL_HZ_CUST_ACCOUNTS for xxdl.XXDL_HZ_CUST_ACCOUNTS;

/
EXIT;

