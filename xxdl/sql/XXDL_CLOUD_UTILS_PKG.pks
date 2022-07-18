create or replace package xxdl_cloud_utils_pkg authid definer is
  /* $Header $
  ============================================================================+
  File Name   : XXDL_CLOUD_UTILS_PKG.pks
  Object      : XXDL_CLOUD_UTILS_PKG
  Description : Package to provide common cloud utility procedures
  History     :
  v1.0 24.05.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/

  procedure submit_ess_create_accounting;

  procedure submit_ess_job(p_job_name in varchar2, p_definition_name in varchar2, p_params in varchar2, x_ws_call_id out number);

  procedure wait_for_ess_job(p_ess_req_id number, x_job_status out varchar2, p_max_minutes_to_wait number default 10);

end xxdl_cloud_utils_pkg;
/
