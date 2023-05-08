
  CREATE TABLE "XX_INTEGRATION_DEV"."XXDL_WO_CC_INTEGRATION" 
   (	"ID" NUMBER NOT NULL ENABLE, 
	"COMPANY" VARCHAR2(50 BYTE), 
	"WORK_ORDER_NUMBER" VARCHAR2(600 BYTE), 
	"WORK_ORDER_DESCRIPTION" VARCHAR2(960 BYTE), 
	"COST_CENTER" VARCHAR2(600 BYTE), 
	"COST_CENTER_DESCRIPTION" VARCHAR2(960 BYTE), 
	"FUSION_VALUE_SET_ID" NUMBER, 
	"STATUS" VARCHAR2(15 BYTE), 
	"MESSAGE" VARCHAR2(2000 BYTE), 
	"LAST_WS_CALL_ID" NUMBER, 
	"CREATION_DATE" DATE, 
	"LAST_UPDATE_DATE" DATE
   ) SEGMENT CREATION IMMEDIATE 
  PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 
 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
  BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "USERS" ;

