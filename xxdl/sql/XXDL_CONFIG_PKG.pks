create or replace package xxdl_config_pkg authid definer is
  /* $Header $
  ============================================================================+
  File Name   : XXDL_CONFIG_PKG.pks
  Object      : XXDL_CONFIG_PKG
  Description : Package to support configuration options
  History     :
  v1.0 16.05.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/

  function get_value(p_name varchar2) return varchar2;

  function serviceusername return varchar2;
  function servicepassword return varchar2;
  function servicerooturl return varchar2;
  function soapurl return varchar2;

end xxdl_config_pkg;
/
