/* $Header $
============================================================================+
File Name   : XXDL_MIG_ONHAND1_JOB.sql
Object      : XXDL_MIG_ONHAND1_JOB
Description : 
              To drop job, use:
              dbms_scheduler.drop_job(job_name => 'XXDL_MIG_ONHAND1_JOB');
History     :
v1.0 25.11.2022 Marko Sladoljev: Inicijalna verzija
============================================================================+*/
declare

  l_job_name varchar2(100) := 'XXDL_MIG_ONHAND1_JOB';
  l_schema   varchar2(100) := 'XX_INTEGRATION_PROD';

begin

  --dbms_scheduler.drop_job(job_name => l_job_name);  

  dbms_scheduler.create_job(job_name   => l_schema || '.' || l_job_name,
                            job_type   => 'STORED_PROCEDURE',
                            job_action => 'xxdl_mig_inv_pkg.migrate_onhand_all',
                            start_date => sysdate, --to_date('13.12.2022 5:00', 'dd.mm.yyyy hh24:mi'),
                            enabled    => true,
                            auto_drop  => false,
                            comments   => 'Migracija zaliha');

end;
