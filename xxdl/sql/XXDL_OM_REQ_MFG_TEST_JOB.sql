  /* $Header $
  ============================================================================+
  File Name   : XXDL_OM_REQ_MFG_TEST_JOB.sql
  Object      : XXDL_OM_REQ_MFG_TEST_JOB
  Description : Database job to migrate supply order for manufacturing from Cloud to XE
                To drop job, use:
                begin
                dbms_scheduler.drop_job(job_name => 'XXDL_OM_REQ_MFG_TEST_JOB');
                end;
  History     :
  v1.0 09.12.2022 Zoran Kovac: Initial creation
  ============================================================================+*/
begin
dbms_scheduler.create_job (
   job_name           =>  'XX_INTEGRATION_DEV.XXDL_OM_REQ_MFG_TEST_JOB',
   job_type           =>  'STORED_PROCEDURE',
   job_action         =>  'XXDL_OM_UTIL_PKG.get_om_mfq_info',
   number_of_arguments=> 2,
   start_date         =>  TO_DATE('2022/12/09 2:51:00', 'YYYY/MM/DD HH:MI:SS'),
   repeat_interval    =>  'FREQ=MINUTELY;INTERVAL=1'
   );

dbms_scheduler.set_job_argument_value(
    job_name => 'XX_INTEGRATION_DEV.XXDL_OM_REQ_MFG_TEST_JOB',
    argument_position => 1,
    argument_value => null
    );
dbms_scheduler.set_job_argument_value(
    job_name => 'XX_INTEGRATION_DEV.XXDL_OM_REQ_MFG_TEST_JOB',
    argument_position => 2,
    argument_value => null
    );


dbms_scheduler.enable('XX_INTEGRATION_DEV.XXDL_OM_REQ_MFG_TEST_JOB');
END;
/
EXIT;