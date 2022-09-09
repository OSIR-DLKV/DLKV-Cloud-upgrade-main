create or replace package body xxdl_config_pkg is
  /* $Header $
  ============================================================================+
  File Name   : XXDL_CONFIG_PKG.pks
  Object      : XXDL_CONFIG_PKG
  Description : Package to support configuration options around xx_configuration table
  History     :
  v1.0 16.05.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/

  c_prefix constant varchar2(30) := 'EwhaTest';

  function get_value(p_name varchar2) return varchar2 as
    l_value varchar2(250);
  begin
    begin
      select value into l_value from xx_configuration where name = p_name;
    exception
      when no_data_found then
        l_value := null;
    end;
    return l_value;
  end;

  function serviceusername return varchar2 as
  begin
    return get_value(c_prefix || 'ServiceUsername');
  end;
  function servicepassword return varchar2 as
  begin
    return get_value(c_prefix || 'ServicePassword');
  end;
  function servicerooturl return varchar2 as
  begin
    return get_value(c_prefix || 'ServiceRootURL');
  end;
  function soapurl return varchar2 as
  begin
    return get_value(c_prefix || 'SoapUrl');
  end;

end;
/
