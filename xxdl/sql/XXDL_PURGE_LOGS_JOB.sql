  /* $Header $
  ============================================================================+
  File Name   : XXDL_PURGE_LOGS_JOB.sql
  Object      : XXDL_PURGE_LOGS_JOB 
  Description : Database job to delete logs
                
  History     :
  v1.0 6.1.2023 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/
begin
--dbms_scheduler.drop_job(job_name => 'XXDL_PURGE_LOGS_JOB');
dbms_scheduler.create_job (
   job_name           =>  'XX_INTEGRATION_PROD.XXDL_PURGE_LOGS_JOB',
   job_type           =>  'STORED_PROCEDURE',
   job_action         =>  'XXDL_LOG_PKG.purge_old_log',
   start_date         =>  TRUNC(SYSDATE),
   repeat_interval    =>  'FREQ=HOURLY;INTERVAL=12',
   enabled            =>  TRUE);
END;
