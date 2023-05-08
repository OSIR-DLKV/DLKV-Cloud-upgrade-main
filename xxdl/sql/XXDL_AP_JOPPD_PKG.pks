create or replace PACKAGE  XXDL_AP_JOPPD_PKG authid definer is
/* $Header $
============================================================================+
File Name   : XXDL_AP_JOPPD_PKG.pks
Object      : XXDL_AP_JOPPD_PKG
Description : 
History     :
v1.0 09.05.2020 - 
============================================================================+*/

PROCEDURE PROCESS_RECORDS_SCHED;


procedure get_data (p_period_name in varchar2, p_legal_entity_name in varchar2, p_status out varchar2, p_msg out varchar2);

procedure insert_data;


procedure get_pay_request_data (p_period_name in varchar2, p_legal_entity_name in varchar2, p_status out varchar2, p_msg out varchar2);

procedure insert_pay_request_data;

procedure create_payments;


end XXDL_AP_JOPPD_PKG;