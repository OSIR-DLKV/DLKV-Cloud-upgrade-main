/* $Header $
============================================================================+

File Name   : XXDL_REPORT.pks
Description : Package for logging XXDL Apps

History     :
v1.0 28.05.2022 - Marko Sladoljev: Initial creation	
============================================================================+*/

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

create or replace package xxdl_report_pkg as

  procedure create_report(p_report_type varchar, p_report_name varchar2, x_report_id out number);

  procedure put_line(p_report_id number, p_line varchar2);

end xxdl_report_pkg;
/
