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

  l_job_name varchar2(100) := 'XXDL_MIG_ITEMS1_JOB';
  l_schema   varchar2(100) := 'XX_INTEGRATION_PROD';

begin

  --dbms_scheduler.drop_job(job_name => l_job_name);  

  dbms_scheduler.create_job(job_name   => l_schema || '.' || l_job_name,
                            job_type   => 'STORED_PROCEDURE',
                            job_action => 'xxdl_mig_items_pkg.migrate_item_all',
                            start_date => sysdate,
                            enabled    => true,
                            auto_drop  => false,
                            comments   => 'Migracija itema');

end;
