  /* $Header $
  ============================================================================+
  File Name   : XXDL_OM_REQ_MFG_PROD_JOB.sql
  Object      : XXDL_OM_REQ_MFG_PROD_JOB
  Description : Database job to migrate supply order for manufacturing from Cloud to XE
                To drop job, use:
                begin
                dbms_scheduler.drop_job(job_name => 'XXDL_OM_REQ_MFG_PROD_JOB');
                end;
  History     :
  v1.0 09.12.2022 Zoran Kovac: Initial creation
  ============================================================================+*/
begin
dbms_scheduler.create_job (
   job_name           =>  'XX_INTEGRATION_PROD.XXDL_OM_REQ_MFG_PROD_JOB',
   job_type           =>  'STORED_PROCEDURE',
   job_action         =>  'XXDL_OM_UTIL_PKG.get_om_mfq_info',
   number_of_arguments=> 2,
   start_date         =>  TO_DATE('2023/01/19 9:10:00', 'YYYY/MM/DD HH:MI:SS'),
   repeat_interval    =>  'FREQ=MINUTELY;INTERVAL=1'
   );

dbms_scheduler.set_job_argument_value(
    job_name => 'XX_INTEGRATION_PROD.XXDL_OM_REQ_MFG_PROD_JOB',
    argument_position => 1,
    argument_value => null
    );
dbms_scheduler.set_job_argument_value(
    job_name => 'XX_INTEGRATION_PROD.XXDL_OM_REQ_MFG_PROD_JOB',
    argument_position => 2,
    argument_value => null
    );


dbms_scheduler.enable('XX_INTEGRATION_PROD.XXDL_OM_REQ_MFG_PROD_JOB');
END;
/
EXIT;