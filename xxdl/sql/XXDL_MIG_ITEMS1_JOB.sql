/* $Header $
============================================================================+
File Name   : XXDL_MIG_ITEMS1_JOB.sql
Object      : XXDL_MIG_ITEMS1_JOB
Description : 
              To drop job, use:
              dbms_scheduler.drop_job(job_name => 'XXDL_MIG_ITEMS1_JOB');
History     :
v1.0 25.11.2022 Marko Sladoljev: Inicijalna verzija
============================================================================+*/
declare

  l_job_name varchar2(100) := 'XXDL_MIG_ITEMS2_JOB';
  l_schema   varchar2(100) := 'XX_INTEGRATION_DEV';
  --l_schema varchar2(100) := 'XX_INTEGRATION_ENCC_T';

begin

  --dbms_scheduler.drop_job(job_name => l_job_name);  

  dbms_scheduler.create_job(job_name   => l_schema || '.' || l_job_name,
                            job_type   => 'STORED_PROCEDURE',
                            job_action => 'xxdl_mig_items_pkg.migrate_item_all',
                            start_date => to_date('13.12.2022 5:00', 'dd.mm.yyyy hh24:mi'),
                            enabled    => true,
                            auto_drop  => false,
                            comments   => 'Migracija itema');

  --dbms_scheduler.set_attribute(l_schema || '.' || l_job_name, 'RESTART_ON_RECOVERY', true);

end;
