/* $Header $
============================================================================+
File Name   : XXDL_INV_MATERIAL_TXNS_BAT_S1.sql
Description : Bartch id for XXDL_INV_MATERIAL_TXNS_INT table

History     :
v1.0 18.07.2022 - M.Sladoljev: Initial creation
============================================================================+*/
WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

CREATE SEQUENCE XXDL_INV_MATERIAL_TXNS_BAT_S1
 INCREMENT BY 1
 START WITH 1
 NOCYCLE
 NOCACHE;

exit;
