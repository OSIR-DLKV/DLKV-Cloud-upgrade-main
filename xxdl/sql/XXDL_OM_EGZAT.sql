/* $Header: $
============================================================================+
File Name   : XXDL_OM_EGZAT.sql
Description : Headers from OM for manufacturing

History     :
v1.0 09.12.2022 ZKOVAC: Initial creation
============================================================================+*/
create table XXDL_OM_EGZAT
(
    "BRINZ" VARCHAR2(16 BYTE), 
	"BUGNA" VARCHAR2(16 BYTE), 
    "DUNNA" DATE, 
	"SKD" NUMBER, 
	"NAPNIZ" VARCHAR2(80 BYTE), 
    "OTNA" VARCHAR2(80 BYTE),
	"HEADER_ID_EBS" NUMBER, 
	"PROJEKT" number, 
	"TRG" varchar2(3 BYTE),
	"IZVOR_OM" varchar2(25 BYTE),
	"OPIS_OM" VARCHAR2(240 BYTE),
	"CREATION_DATE" DATE, 
	"LAST_UPDATE_DATE" DATE,
	"TRANSF_CREATION_DATE" DATE,
    "TRANSF_LAST_UPDATE"   DATE
	)
;


  CREATE UNIQUE INDEX "XXDL_OM_EGZAT_T1" ON "XXDL_OM_EGZAT" ("HEADER_ID_EBS","BUGNA") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS" ;

--create synonym apps.XXDL_OM_EGZAT for xxdl.XXDL_OM_EGZAT;

/
EXIT;

