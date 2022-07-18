  /* $Header $
  ============================================================================+
  File Name   : XXDL_SLA_MAPPINGS_INTERFACE.sql
  Object      : XXDL_SLA_MAPPINGS_INTERFACE
  Description : Mappings interface table
  History     :
  v1.0 13.05.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/
CREATE TABLE XXDL_SLA_MAPPINGS_INTERFACE (
  batch_id               number not null,
  group_id               number,
  line_num               number not null,
  status                 varchar2(10) not null,
  application_name       varchar2(250) not null,
  mapping_short_name     varchar2(250) not null,
  out_chart_of_accounts  varchar2(250) not null,
  out_segment            varchar2(250),
  out_value              varchar2(250), 
  source_value_1         varchar2(250),
  source_reference_info  varchar2(250),
  file_name              varchar2(250),
  ess_job_request_id     number,
  creation_date          date not null,
  last_update_date       date not null,
  CONSTRAINT XXDL_SLA_MAPPINGS_INTERFACE_PK PRIMARY KEY (batch_id, line_num)
);

CREATE INDEX XXDL_SLA_MAPPINGS_INTERFACE_N1 ON XXDL_SLA_MAPPINGS_INTERFACE (batch_id);
CREATE INDEX XXDL_SLA_MAPPINGS_INTERFACE_N2 ON XXDL_SLA_MAPPINGS_INTERFACE (group_id);



