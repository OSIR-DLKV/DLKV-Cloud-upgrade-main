create or replace package xxdl_sla_mappings_pkg authid definer is
  /* $Header $
  ============================================================================+
  File Name   : XXDL_SLA_MAPPINGS_PKG.pks
  Object      : XXDL_SLA_MAPPINGS_PKG
  Description : Package to support mappings generation
  History     :
  v1.0 13.05.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/

  procedure refresh_mapping_set(p_mapping_set_code varchar2);

  procedure refresh_all_mapping_sets;
  
  procedure referesh_work_orders_mappings;
  
  procedure purge_mappings_interface;

end xxdl_sla_mappings_pkg;
/
