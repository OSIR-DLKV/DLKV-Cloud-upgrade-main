  /* $Header $
  ============================================================================+
  File Name   : XXDL_MTL_ITEM_MIG_EWHW_TEST_JOB.sql
  Object      : XXDL_MTL_ITEM_MIG_EWHW_TEST_JOB
  Description : Database job to migrate items from PROD to TEST
                To drop job, use:
                begin
                dbms_scheduler.drop_job(job_name => 'XXDL_MTL_ITEM_MIG_EWHW_TEST_JOB');
                end;
  History     :
  v1.0 26.07.2022 Zoran Kovac: Initial creation
  ============================================================================+*/
begin
dbms_scheduler.create_job (
   job_name           =>  'XX_INTEGRATION_DEV.XXDL_MTL_ITEM_MIG_EWHW_TEST_JOB',
   job_type           =>  'STORED_PROCEDURE',
   job_action         =>  'XXDL_AR_UTIL_PKG.migrate_customers_cloud',
   number_of_arguments=> 4,
   start_date         =>  TO_DATE('2022/07/31 8:10:00', 'YYYY/MM/DD HH:MI:SS'),
   repeat_interval    =>  'FREQ=MINUTELY;INTERVAL=15'
   );

dbms_scheduler.set_job_argument_value(
    job_name => 'XX_INTEGRATION_DEV.XXDL_MTL_ITEM_MIG_EWHW_TEST_JOB',
    argument_position => 1,
    argument_value => null
    );
dbms_scheduler.set_job_argument_value(
    job_name => 'XX_INTEGRATION_DEV.XXDL_MTL_ITEM_MIG_EWHW_TEST_JOB',
    argument_position => 2,
    argument_value => 10
    );
dbms_scheduler.set_job_argument_value(
    job_name => 'XX_INTEGRATION_DEV.XXDL_MTL_ITEM_MIG_EWHW_TEST_JOB',
    argument_position => 3,
    argument_value => 'Y'
    );


dbms_scheduler.enable('XX_INTEGRATION_DEV.XXDL_MTL_ITEM_MIG_EWHA_TEST_JOB');
END;
/
EXIT;