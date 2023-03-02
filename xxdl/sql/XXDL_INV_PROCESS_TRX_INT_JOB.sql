/* $Header $
============================================================================+
File Name   : XXDL_INV_PROCESS_TRX_INT_JOB.sql
Object      : XXDL_INV_PROCESS_TRX_INT_JOB
Description : Database job process all transactions in interface
              
History     :
v1.0 27.02.2023 Marko Sladoljev: Inicijalna verzija
============================================================================+*/

begin

  --dbms_scheduler.drop_job(job_name => 'XX_INTEGRATION_PROD.XXDL_INV_PROCESS_TRX_INT_JOB');

  dbms_scheduler.create_job(job_name        => 'XX_INTEGRATION_PROD.XXDL_INV_PROCESS_TRX_INT_JOB',
                            job_type        => 'STORED_PROCEDURE',
                            job_action      => 'XXDL_INV_INTEGRATION_PKG.process_transactions_int_all',
                            start_date      => trunc(sysdate),
                            repeat_interval => 'FREQ=MINUTELY;INTERVAL=1',
                            enabled         => true);

end;
