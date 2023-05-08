create or replace PACKAGE      XXDL_EMP_CC_INTEGRATION_PKG AS
/* $Header $
============================================================================+
File Name   : XXDL_EMP_CC_INTEGRATION_PKG.pks
Object      : XXDL_EMP_CC_INTEGRATION_PKG
Description : Package for employee and cc integration
History     :
v1.0 09.05.2022 - 
============================================================================+*/

PROCEDURE PROCESS_RECORDS_SCHED;


PROCEDURE GET_DATA(P_CREATION_DATE IN VARCHAR2);
/*===========================================================================+
Procedure   : GET_PAY_INTER_ORG_UNITS
Description : Gets GET_PAY_INTER_ORG_UNITS
Usage       :
Arguments   : 
Remarks     :
============================================================================+*/
procedure PROCESS_RECORDS;



end XXDL_EMP_CC_INTEGRATION_PKG;