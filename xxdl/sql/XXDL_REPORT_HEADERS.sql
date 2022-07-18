/* $Header $
============================================================================+
File Name   : XXDL_REPORT_HEADERS.sql
Description : Reoirt headers 

History     :
v1.0 28.05.2022 - Marko Sladoljev: Initial creation	
============================================================================+*/

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

CREATE
  TABLE XXDL_REPORT_HEADERS(
    REPORT_ID           NUMBER        NOT NULL ENABLE,
    REPORT_TYPE         varchar2(250) not null enable,
    NAME                varchar2(250) not null enable,
    DATE_CREATED        DATE          NOT NULL ENABLE,
    CONSTRAINT XXDL_REPORT_HEADERS_PK PRIMARY KEY (REPORT_ID)
  );
  
exit;
