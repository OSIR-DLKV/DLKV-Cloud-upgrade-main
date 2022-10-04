  /* $Header $
  ============================================================================+
  File Name   : XXDL_INV_DOWNLOAD_ITEMS_JOB.sql
  Object      : XXDL_INV_DOWNLOAD_ITEMS_JOB
  Description : Database job to download items
                To drop job, use:
                
  History     :
  v1.0 27.09.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/
begin
--dbms_scheduler.drop_job(job_name => 'XXDL_INV_DOWNLOAD_ITEMS_JOB');
dbms_scheduler.create_job (
   job_name           =>  'XX_INTEGRATION_DEV.XXDL_INV_DOWNLOAD_ITEMS_JOB',
   job_type           =>  'STORED_PROCEDURE',
   job_action         =>  'XXDL_INV_INTEGRATION_PKG.download_items_schedule',
   start_date         =>  TRUNC(SYSDATE,'MI'),
   repeat_interval    =>  'FREQ=MINUTELY;INTERVAL=10',
   enabled            =>  TRUE);
END;
