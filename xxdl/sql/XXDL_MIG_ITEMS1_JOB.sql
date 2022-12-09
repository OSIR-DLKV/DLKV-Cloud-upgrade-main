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
begin

  --dbms_scheduler.drop_job(job_name => 'XXDL_MIG_ITEMS1_JOB');  


-- Check schema !!!
  dbms_scheduler.create_job(job_name   => 'XX_INTEGRATION_ENCC_T.XXDL_MIG_ITEMS1_JOB',
                            job_type   => 'STORED_PROCEDURE',
                            job_action => 'xxdl_mig_items_pkg.migrate_item_all',
                            start_date => trunc(sysdate)+1 + 2/24,
                            enabled    => true,
                            auto_drop  => false,
                            comments   => 'Jednokratna migracija itema');
                            
                            
end;
