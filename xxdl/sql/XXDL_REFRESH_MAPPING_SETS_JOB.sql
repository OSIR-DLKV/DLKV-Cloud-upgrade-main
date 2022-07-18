  /* $Header $
  ============================================================================+
  File Name   : XXDL_REFRESH_MAPPING_SETS_JOB.sql
  Object      : XXDL_REFRESH_MAPPING_SETS_JOB
  Description : Database job to refresh mapping sets
                Should be logged in as sysdba
                To drop job, use:
                dbms_scheduler.drop_job(job_name => 'XXDL_REFRESH_MAPPING_SETS_JOB');
  History     :
  v1.0 28.05.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/
begin
dbms_scheduler.create_job (
   job_name           =>  'XX_INTEGRATION_DEV.XXDL_REFRESH_MAPPING_SETS_JOB',
   job_type           =>  'STORED_PROCEDURE',
   job_action         =>  'XXDL_SLA_MAPPINGS_PKG.refresh_all_mapping_sets',
   start_date         =>  TO_DATE('2022/05/31 02:00:00', 'YYYY/MM/DD HH:MI:SS'),
   repeat_interval    =>  'FREQ=DAILY',
   enabled            =>  TRUE);
END;
