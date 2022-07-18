/* $Header $
============================================================================+

File Name   : XXDL_LOG.sql
Description : Log table 

History     :
v1.0 28.05.2022 - Marko Sladoljev: Initial creation	
============================================================================+*/

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

CREATE
  TABLE XXDL_LOG(
    LOG_ID      NUMBER NOT NULL ENABLE,
    MODULE      VARCHAR2(200) NOT NULL ENABLE,
    LOG_LEVEL       VARCHAR2(10) NOT NULL ENABLE,
    MESSAGE VARCHAR2(2000) NOT NULL ENABLE,
    DATE_CREATED DATE NOT NULL ENABLE
  );
  
exit;
