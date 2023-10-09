create or replace PACKAGE      XXDL_OA_PLACE_PKG AS
/* $Header $
============================================================================+
File Name   : XXDL_OA_PLACE_PKG.pks
Object      : XXDL_OA_PLACE_PKG
Description : Package for project/task sync
History     :
v1.0 09.05.2022 - 
============================================================================+*/

PROCEDURE PROCESS_RECORDS_SCHED;


PROCEDURE GET_DATA(P_PROJECT_DATE IN VARCHAR2, P_TASK_DATE IN VARCHAR2);


end XXDL_OA_PLACE_PKG;