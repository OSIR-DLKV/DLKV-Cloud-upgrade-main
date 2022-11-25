  /* $Header $
  ============================================================================+
  File Name   : XXDL_SLA_MAP_SET_DEFINITION.sql
  Object      : XXDL_SLA_MAP_SET_DEFINITION
  Description : Mappings definition table
  History     :
  v1.0 27.05.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/
CREATE TABLE XXDL_SLA_MAP_SET_DEFINITION (
  mapping_set_code        varchar2(100) not null,
  application_name        varchar2(100) not null,
  out_segment             varchar2(100) not null,
  enabled                 varchar2(1) not null,
  CONSTRAINT XXDL_SLA_MAP_SET_DEFINITION_PK PRIMARY KEY (mapping_set_code)
);

insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled)
values ('XXDL_CC_FROM_PROJECT_TASK', 'Cost Management', 'Mjesto troska', 'Y');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled)
values ('XXDL_CC_FROM_REQ_PROJ_TASK', 'Purchasing', 'Mjesto troska', 'Y');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled)
values ('XXDL_CC_FROM_SALES_ORDER', 'Cost Management', 'Mjesto troska', 'Y');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled)
values ('XXDL_CC_FROM_AR_INVOICE_PROJ', 'Receivables', 'Mjesto troska', 'Y');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled)
values ('XXDL_CC_FROM_SO_NUMBER', 'Purchasing', 'Mjesto troska', 'Y');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled)
values ('XXDL_CC_FROM_AP_PROJ_TASK', 'Payables', 'Mjesto troska', 'Y');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled)
values ('XXDL_CC_FROM_PJC_PROJ_TASK', 'Project Costing', 'Mjesto troska', 'Y');