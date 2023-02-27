/* $Header $
============================================================================+

File Name   : XXDL_LOG.pkb
Description : Package for logging XXDL Apps

History     :
v1.0 28.05.2022 - Marko Sladoljev: Initial creation	
============================================================================+*/

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

create or replace package body xxdl_log_pkg as

  /*===========================================================================+
  Procedure   : log
  Description : inserts log line to xxdl_log table if debugging is enabled
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure log(p_module varchar, p_log_level varchar, p_message varchar2) as
    pragma autonomous_transaction;
  begin
    insert into xxdl_log (log_id, module, log_level, message, date_created) values (xxdl_log_s1.nextval, p_module, p_log_level, p_message, sysdate);
    commit;
  end;

  /*===========================================================================+
  Procedure   : purge_old_log
  Description : Deletes records older then 30 days
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure purge_old_log as
    pragma autonomous_transaction;
  begin
    delete from xxdl_log where date_created < sysdate - 31;
    commit;
  end;

end xxdl_log_pkg;
/
