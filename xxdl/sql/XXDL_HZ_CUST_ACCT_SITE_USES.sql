/* $Header: $
============================================================================+
File Name   : XXDL_HZ_CUST_ACCT_SITE_USES.sql
Description : Log table for customer account site uses migration to cloud

History     :
v1.0 09.09.2022 ZKOVAC: Initial creation
============================================================================+*/
create table XXDL_HZ_CUST_ACCT_SITE_USES
(
    "CUST_ACCT_SITE_ID" NUMBER NOT NULL ENABLE, 
    "SITE_USE_ID" NUMBER NOT NULL ENABLE, 
    "PARTY_SITE_ID" NUMBER NOT NULL ENABLE, 
    "BILL_TO_SITE_USE_ID" NUMBER, 
    "SITE_USE_CODE" VARCHAR2(30),
	"PRIMARY_FLAG" VARCHAR2(1 BYTE), 
	"LOCATION" NUMBER, 
	"STATUS" VARCHAR2(2 BYTE), 
	"ATTRIBUTE25" VARCHAR2(2 BYTE), 
	"ORG_ID" NUMBER,    
	"CLOUD_SET_ID" NUMBER, 
	"PROCESS_FLAG" VARCHAR2(1 BYTE), 
	"ERROR_MSG" VARCHAR2(4000 BYTE), 
	"CREATION_DATE" DATE, 
	"LAST_UPDATE_DATE" DATE, 
	"CLOUD_SITE_USE_ID" NUMBER,
	"CLOUD_CUST_ACCT_SITE_ID" NUMBER,
	"CLOUD_PARTY_SITE_ID" NUMBER,
	"CLOUD_BILL_TO_SITE_USE_ID" NUMBER

)
;


  CREATE UNIQUE INDEX "XXDL_HZ_CUST_ACCT_SITE_USE_T1" ON "XXDL_HZ_CUST_ACCT_SITE_USES" ("SITE_USE_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS" ;

--create synonym apps.XXDL_HZ_CUST_ACCT_SITE_USES for xxdl.XXDL_HZ_CUST_ACCT_SITE_USES;

/
EXIT;

