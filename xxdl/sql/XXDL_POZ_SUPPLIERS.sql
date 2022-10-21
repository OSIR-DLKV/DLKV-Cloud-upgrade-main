/*$Header: $
============================================================================+
File Name   : XXDL_POZ_SUPPLIERS.sql
Description : Table creation script            
History     :
V1.0 03.10.2022 - Zoran Kovac - initial creation
============================================================================+*/

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

PROMPT XXDL_POZ_SUPPLIERS;

CREATE
  TABLE "XXDL_POZ_SUPPLIERS"
  (
    "VENDOR_ID"            NUMBER NOT NULL ENABLE,
    "PARTY_ID"             NUMBER,
    "VENDOR_NAME"          VARCHAR2(1440 BYTE),
    "SUPPLIER_NUMBER"      VARCHAR2(120 BYTE),
    "VAT_NUMBER"           VARCHAR2(200 BYTE),
	"DUNS_NUMBER"		   VARCHAR2(200 BYTE),
	"TAXPAYER_ID"		   VARCHAR2(200 BYTE),
    "CREATION_DATE"        DATE,
    "LAST_UPDATE_DATE"     DATE,
    "TRANSF_CREATION_DATE" DATE,
    "TRANSF_LAST_UPDATE"   DATE,
    "INACTIVE_DATE"        DATE
  );
  
CREATE UNIQUE INDEX "XXDL_POZ_SUPPLIERS_U1" ON "XXDL_POZ_SUPPLIERS" ("VENDOR_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS" ;

EXIT;
/
