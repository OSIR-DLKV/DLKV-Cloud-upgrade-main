/* $Header $
============================================================================+

File Name   : XXDL_MIG_ITEMS_FIXED_LIST_ALL.sql
Description : Log table 

History     :
v1.0 28.05.2022 - Marko Sladoljev: Initial creation	2
============================================================================+*/

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

-- drop table XXDL_MIG_ITEMS_FIXED_LIST_ALLORGS;

CREATE
  TABLE XXDL_MIG_ITEMS_FIXED_LIST_ALL(
    SEGMENT1 varchar2(100),
	CONSTRAINT XXDL_MIG_ITEMS_FIC_LIS_ALL_PK PRIMARY KEY (SEGMENT1)
  );
  
exit;
