/* $Header $
============================================================================+
File Name   : XXDL_SYNC_STATUS.sql
Description : Sysnc status table
History     :
v1.0 25.07.2022 - Marko Sladoljev: Initial creation  
============================================================================+*/
CREATE TABLE XXDL_SYNC_STATUSES (
     entity_type       VARCHAR2(50) NOT NULL ENABLE,
     id1               VARCHAR2(50) NOT NULL ENABLE,
     id2               VARCHAR2(50) NOT NULL ENABLE,
	   sync_status       VARCHAR2(10) NOT NULL ENABLE,
     creation_date     DATE NOT NULL,
     last_update_date  DATE NOT NULL,
     CONSTRAINT XXDL_SYNC_STATUS_PK1 PRIMARY KEY (entity_type, id1, id2)
  ); 
  
exit;
