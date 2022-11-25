/* $Header $
============================================================================+

File Name   : XXDL_REPORT_PKG.pkb
Description : Package for logging XXDL Apps

History     :
v1.0 28.05.2022 - Marko Sladoljev: Initial creation	
============================================================================+*/

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

create or replace package body xxdl_report_pkg as

  /*===========================================================================+
  Procedure   : create_report
  Description : inserts  line to xxdl_report_headers table 
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure create_report(p_report_type varchar, p_report_name varchar2, x_report_id out number) as
    pragma autonomous_transaction;
  begin
    x_report_id := xxdl_report_headers_s1.nextval;
    insert into xxdl_report_headers (report_id, report_type, name, date_created) values (x_report_id, p_report_type, p_report_name, sysdate);
    commit;
  end;

  /*===========================================================================+
  Procedure   : put_line
  Description : inserts log line to xxdl_report_lines table 
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure put_line(p_report_id number, p_line varchar2) as
    pragma autonomous_transaction;
  begin
    insert into xxdl_report_lines (report_id, report_line_id, line, date_created) values (p_report_id, xxdl_report_line_s1.nextval, p_line, sysdate);
    commit;
  end;

  /*===========================================================================+
  Procedure   : set_has_errors
  Description : Marks report as errored
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure set_has_errors(p_report_id number) as
    pragma autonomous_transaction;
  begin
    update xxdl_report_headers r set r.has_errors_flag = 'Y' where report_id = p_report_id;
    commit;
  end;

end xxdl_report_pkg;
/
