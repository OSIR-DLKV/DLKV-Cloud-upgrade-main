  /* $Header $
  ============================================================================+
  File Name   : XXDL_INV_DOWNLOAD_TABLES_JOB.sql
  Object      : XXDL_INV_DOWNLOAD_TABLES_JOB
  Description : Database job to download inventoiry tables
                To drop job, use:
                dbms_scheduler.drop_job(job_name => 'XXDL_INV_DOWNLOAD_TABLES_JOB');
  History     :
  v1.0 27.09.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/
begin
dbms_scheduler.create_job (
   job_name           =>  'XX_INTEGRATION_DEV.XXDL_INV_DOWNLOAD_TABLES_JOB',
   job_type           =>  'STORED_PROCEDURE',
   job_action         =>  'XXDL_INV_INTEGRATION_PKG.download_all_inv_tables',
   start_date         =>  TO_DATE('2022/09/28 04:00:00', 'YYYY/MM/DD HH:MI:SS'),
   repeat_interval    =>  'FREQ=DAILY',
   enabled            =>  TRUE);
END;
