  /* $Header $
  ============================================================================+
  File Name   : XXDL_REFRESH_MAPS_FREQ1_JOB.sql
  Object      : XXDL_REFRESH_MAPS_FREQ1_JOB
  Description : Database job to refresh mapping sets that requires frequent refresh
                Should be logged in as sysdba
                To drop job, use:
                dbms_scheduler.drop_job(job_name => 'XXDL_REFRESH_MAPS_FREQ1_JOB');
  History     :
  v1.1 15.05.2024 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/
begin
dbms_scheduler.create_job (
   job_name           =>  'XX_INTEGRATION_PROD.XXDL_REFRESH_MAPS_FREQ1_JOB',
   job_type           =>  'STORED_PROCEDURE',
   job_action         =>  'XXDL_SLA_MAPPINGS_PKG.refresh_maps_freq1',
   start_date         =>  systimestamp,
   repeat_interval    =>  'freq=hourly; byhour=8,10,12,14,16,18,20; byminute=0; bysecond=0;',
   enabled            =>  TRUE);
end;
