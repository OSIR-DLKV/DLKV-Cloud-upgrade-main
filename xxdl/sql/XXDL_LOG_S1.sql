/* $Header $
============================================================================+

File Name   : DDXL_LOG_S1.sql
Description : Log sequence XXDL_LOG table

History     :
v1.0 28.05.2022 - M.Sladoljev: Initial creation
============================================================================+*/
WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

CREATE SEQUENCE XXDL_LOG_S1
 INCREMENT BY 1
 START WITH 1
 NOCYCLE
 NOCACHE;

exit;
