  /* $Header $
  ============================================================================+
  File Name   : XXDL_SLA_MAP_SET_DEFINITION.sql
  Object      : XXDL_SLA_MAP_SET_DEFINITION
  Description : Mappings definition table
  History     :
  v1.0 27.05.2022 Marko Sladoljev: Inicijalna verzija
  v1.1 10.02.2023 Marko Sladoljev: Dodani bi_report_name i bi_src_column
  v1.2 08.03.2023 Marko Sladoljev: Promjene u definicijama zbog uvodenja posebnih reporta za sales order id
  ============================================================================+*/

drop table XXDL_SLA_MAP_SET_DEFINITION;

CREATE TABLE XXDL_SLA_MAP_SET_DEFINITION (
  mapping_set_code        varchar2(100) not null,
  application_name        varchar2(100) not null,
  out_segment             varchar2(100) not null,
  bi_report_name          varchar2(50)  not null,
  bi_src_column           varchar2(50)  not null,
  enabled                 varchar2(1)   not null,
  CONSTRAINT XXDL_SLA_MAP_SET_DEFINITION_PK PRIMARY KEY (mapping_set_code)
);

delete from XXDL_SLA_MAP_SET_DEFINITION;

insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_AR_OM_CM_REC_PROJ', 'Receivables', 'Projekt', 'Y', 'XXDL_PROJ_FROM_SALES_ORDER_REP', 'SOURCE_VALUE_1');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_AR_OM_REC_PROJ', 'Receivables', 'Projekt', 'Y', 'XXDL_PROJ_FROM_SALES_ORDER_REP', 'SOURCE_VALUE_1');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_CC_FROM_PJC_PROJ_TASK', 'Project Costing', 'Mjesto troska', 'Y', 'XXDL_CC_FROM_PROJ_TASK_REP', 'SOURCE_VALUE_2');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_AR_OM_CM_REC_CC', 'Receivables', 'Mjesto troska', 'Y', 'XXDL_CC_FROM_SALES_ORDER_REP', 'SOURCE_VALUE_1');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_AR_OM_KROVNI_NALOG', 'Receivables', 'Nalog prodaje', 'Y', 'XXDL_SO_PARENT_FROM_SALES_ORDER_REP', 'SOURCE_VALUE_1');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_AR_OM_CM_KROVNI_NALOG', 'Receivables', 'Nalog prodaje', 'Y', 'XXDL_SO_PARENT_FROM_SALES_ORDER_REP', 'SOURCE_VALUE_1');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_PROJ_FROM_SALES_ORDER', 'Cost Management', 'Projekt', 'Y', 'XXDL_PROJ_FROM_SALES_ORDER_ID_REP', 'SOURCE_VALUE_1');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_CC_FROM_AR_CM_PROJ', 'Receivables', 'Mjesto troska', 'Y', 'XXDL_CC_FROM_BILLABLE_PROJECT_REP', 'SOURCE_VALUE_2');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_CC_FROM_PROJECT_TASK', 'Cost Management', 'Mjesto troska', 'Y', 'XXDL_CC_FROM_PROJ_TASK_REP', 'SOURCE_VALUE_1');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_CC_FROM_REQ_PROJ_TASK', 'Purchasing', 'Mjesto troska', 'Y', 'XXDL_CC_FROM_PROJ_TASK_REP', 'SOURCE_VALUE_2');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_CC_FROM_SALES_ORDER', 'Cost Management', 'Mjesto troska', 'Y', 'XXDL_CC_FROM_SALES_ORDER_ID_REP', 'SOURCE_VALUE_1');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_CC_FROM_AR_INVOICE_PROJ', 'Receivables', 'Mjesto troska', 'Y', 'XXDL_CC_FROM_BILLABLE_PROJECT_REP', 'SOURCE_VALUE_2');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_SO_PARENT_FROM_SO', 'Cost Management', 'Nalog prodaje', 'Y', 'XXDL_SO_PARENT_FROM_SALES_ORDER_REP', 'SOURCE_VALUE_1');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_CC_FROM_SO_NUMBER', 'Purchasing', 'Mjesto troska', 'Y', 'XXDL_CC_FROM_SALES_ORDER_REP', 'SOURCE_VALUE_1');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_CC_FROM_AP_PROJ_TASK', 'Payables', 'Mjesto troska', 'Y', 'XXDL_CC_FROM_PROJ_TASK_REP', 'SOURCE_VALUE_2');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_CC_FROM_AR_INV_PJB', 'Receivables', 'Mjesto troska', 'Y', 'XXDL_CC_FROM_BILLABLE_PROJECT_REP', 'SOURCE_VALUE_1');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_CC_FROM_AR_INV_LINE_PJB', 'Receivables', 'Mjesto troska', 'Y', 'XXDL_CC_FROM_BILLABLE_PROJECT_REP', 'SOURCE_VALUE_1');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_PROJ_FROM_AR_INV_LINE_PJB', 'Receivables', 'Projekt', 'Y', 'XXDL_PROJECT_FROM_PROJECT_REP', 'SOURCE_VALUE_1');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_AR_OM_REC_CC', 'Receivables', 'Mjesto troska', 'Y', 'XXDL_CC_FROM_SALES_ORDER_REP', 'SOURCE_VALUE_1');
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_CC_FROM_PJC_PROJECT', 'Project Costing', 'Mjesto troska', 'Y', 'XXDL_CC_FROM_BILLABLE_PROJECT_REP', 'SOURCE_VALUE_1');
-- 24.03.2023
insert into XXDL_SLA_MAP_SET_DEFINITION (mapping_set_code, application_name, out_segment, enabled, bi_report_name, bi_src_column)
values ('XXDL_DISTR_ID_MAPP', 'Assets', 'Mjesto troska', 'Y', 'XXDL_CC_FROM_FA_DISTR_REP', 'SOURCE_VALUE_1');


