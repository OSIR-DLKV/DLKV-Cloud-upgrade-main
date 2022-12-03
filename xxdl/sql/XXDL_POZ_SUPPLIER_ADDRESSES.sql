/* $Header:  $
============================================================================+

File Name   : XXDL_POZ_SUPPLIER_ADDRESSES.sql
Description : Table creation script 
              for CEMLI829

History     :
V1.0 03.10.2022 - Zoran Kovac - initial creation
============================================================================+*/

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

PROMPT XXDL_POZ_SUPPLIER_ADDRESSES;

CREATE
  TABLE "XXDL_POZ_SUPPLIER_ADDRESSES"
  (
    "VENDOR_ID"            NUMBER,
    "VENDOR_SITE_ID"       NUMBER,
    "PARTY_SITE_ID"        NUMBER,
    "LOCATION_ID"          NUMBER,
    "ADDRESS_NAME"         VARCHAR2(400 BYTE),
    "ADDRESS"              VARCHAR2(4000 BYTE),
    "ADDRESS1"             VARCHAR2(960 BYTE),
    "ADDRESS2"             VARCHAR2(960 BYTE),
    "ADDRESS3"             VARCHAR2(960 BYTE),
    "ADDRESS4"             VARCHAR2(960 BYTE),
    "CITY"                 VARCHAR2(240 BYTE),
    "COUNTRY"                 VARCHAR2(240 BYTE),
    "POSTAL_CODE"          VARCHAR2(240 BYTE),
    "CLOUD_IMPORTED"       VARCHAR2(1 BYTE),
    "CLOUD_IMPORT_MESSAGE" VARCHAR2(4000 byte),
    "CREATION_DATE"        DATE,
    "LAST_UPDATE_DATE"     DATE,
    "TRANSF_CREATION_DATE" DATE,
    "TRANSF_LAST_UPDATE"   DATE,
    "INACTIVE_DATE"        DATE
  );

CREATE UNIQUE INDEX "XXDL_POZ_SUPPLIER_ADDRESSES_U1" ON "XXDL_POZ_SUPPLIER_ADDRESSES" ("LOCATION_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS" ;

EXIT;
/

