/* $Header $
============================================================================+

File Name   : XXDL_LOG.pks
Description : Package for logging XXDL Apps

History     :
v1.0 28.05.2022 - Marko Sladoljev: Initial creation	
============================================================================+*/

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

create or replace package xxdl_log_pkg as

  g_level_statement varchar2(10) := 'STATEMENT';
  g_level_error     varchar2(10) := 'ERROR';

  procedure log(p_module varchar, p_log_level varchar, p_message varchar2);

  procedure purge_old_log;

end xxdl_log_pkg;
/
