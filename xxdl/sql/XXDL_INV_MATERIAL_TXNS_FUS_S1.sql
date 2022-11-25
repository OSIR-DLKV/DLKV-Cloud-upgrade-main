/* $Header $
============================================================================+
File Name   : XXDL_INV_MATERIAL_TXNS_FUS_S1.sql
Description : Transaction id for Fusion interface table

History     :
v1.0 18.07.2022 - M.Sladoljev: Initial creation
============================================================================+*/
WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

CREATE SEQUENCE XXDL_INV_MATERIAL_TXNS_FUS_S1
 INCREMENT BY 1
 START WITH 10000
 NOCYCLE
 NOCACHE;

exit;
