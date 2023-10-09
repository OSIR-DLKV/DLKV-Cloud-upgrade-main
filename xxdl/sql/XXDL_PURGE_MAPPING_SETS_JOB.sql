  /* $Header $
  ============================================================================+
  File Name   : XXDL_PURGE_MAPPING_SETS_JOB.sql
  Object      : XXDL_PURGE_MAPPING_SETS_JOB
  Description : Database job to purge mapping sets interface
                Should be logged in as sysdba
                To drop job, use:
                dbms_scheduler.drop_job(job_name => 'XXDL_PURGE_MAPPING_SETS_JOB');
  History     :
  v1.0 09.10.2023 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/
begin
dbms_scheduler.create_job (
   job_name           =>  'XX_INTEGRATION_PROD.XXDL_PURGE_MAPPING_SETS_JOB',
   job_type           =>  'STORED_PROCEDURE',
   job_action         =>  'XXDL_SLA_MAPPINGS_PKG.purge_local_map_interface',
   start_date         =>  TO_DATE('2023/10/10 22:15:00', 'YYYY/MM/DD HH24:MI:SS'),
   repeat_interval    =>  'FREQ=DAILY',
   enabled            =>  TRUE);
END;
