/* $Header $
============================================================================+
File Name   : XXDL_REPORT_LINES.sql
Description : Log table 

History     :
v1.0 28.05.2022 - Marko Sladoljev: Initial creation  
============================================================================+*/

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

CREATE
  TABLE XXDL_REPORT_LINES(
    REPORT_ID           NUMBER NOT NULL ENABLE,
    REPORT_LINE_ID      NUMBER NOT NULL ENABLE,
    LINE VARCHAR2(2000),
    DATE_CREATED DATE NOT NULL ENABLE
  );
  
  CREATE INDEX XXDL_REPORT_LINES_N1 ON XXDL_REPORT_LINES (REPORT_ID);
  
exit;
