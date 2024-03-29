/* $Header $
============================================================================+
File Name   : XXDL_MIG_ONHAND.sql
Description : Onhand migration table
History     :
v1.0 25.07.2022 - Marko Sladoljev: Initial creation  
============================================================================+*/
CREATE TABLE XXDL_MIG_ONHAND (	
  MIG_ID number,
  ORGANIZATION_CODE_EBS VARCHAR2(9) NOT NULL, 
	ITEM VARCHAR2(120) NOT NULL, 
	SUBINVENTORY_CODE VARCHAR2(30) NOT NULL , 
	PROJECT_NUMBER VARCHAR2(75), 
	TASK_NUMBER VARCHAR2(75), 
	PRIMARY_TRANSACTION_QUANTITY NUMBER NOT NULL, 
	PRIMARY_UOM_CODE VARCHAR2(9) NOT NULL, 
	INVENTORY_ITEM_ID NUMBER NOT NULL ENABLE, 
	LOCATOR_ID NUMBER, 
	ORGANIZATION_ID NUMBER NOT NULL ENABLE, 
	MATERIAL_COST NUMBER NOT NULL,
  STATUS VARCHAR2(10) NOT NULL,
  ERROR_MESSAAGE VARCHAR2(2000),
  CREATION_DATE DATE NOT NULL,
  CONSTRAINT XXDL_MIG_ONHAND_PK PRIMARY KEY(MIG_ID)
  );

CREATE UNIQUE INDEX XXDL_MIG_ONHAND_U1
ON XXDL_MIG_ONHAND(ORGANIZATION_CODE_EBS, ITEM, SUBINVENTORY_CODE, PROJECT_NUMBER, TASK_NUMBER);