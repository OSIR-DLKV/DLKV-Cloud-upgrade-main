/* $Header: $
============================================================================+
File Name   : XXDL_OM_ESZAT.sql
Description : Lines from OM for manufacturing

History     :
v1.0 09.12.2022 ZKOVAC: Initial creation
============================================================================+*/
create table XXDL_OM_ESZAT
(
    "BRINZ" VARCHAR2(16 BYTE), 
    "BUGNA" VARCHAR2(16 BYTE), 
	"DUNNA" DATE, 
    "RBS2" NUMBER,
    "SPROM" VARCHAR2(11 BYTE), 
	"OPPRO1" VARCHAR2(240 BYTE), 
	"NARKOL" NUMBER, 
	"DISP" DATE, 
    "HEADER_ID_EBS" NUMBER,
    "LINE_ID_EBS" NUMBER,
    "JMJ" VARCHAR2(3 BYTE),
    "PROJEKT" NUMBER,
	"TRG" VARCHAR2(3 BYTE), 
	"OM_VEZA_NP_LNUM" VARCHAR2(25 BYTE), 
	"OM_HID" VARCHAR2(150 BYTE), 
	"OM_LID" VARCHAR2(150 BYTE), 
	"CREATION_DATE" DATE, 
	"LAST_UPDATE_DATE" DATE, 
	"TRANSF_CREATION_DATE" DATE,
    "TRANSF_LAST_UPDATE"   DATE)
;


  CREATE UNIQUE INDEX "XXDL_OM_ESZAT_T1" ON "XXDL_OM_ESZAT" ("LINE_ID_EBS") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS" ;

--create synonym apps.XXDL_OM_ESZAT for xxdl.XXDL_OM_ESZAT;

/
EXIT;

