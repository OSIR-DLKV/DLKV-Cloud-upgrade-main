create or replace package body XXDL_AR_AVANS_PKG is

  -- global variables
  G_CREATE_INVOICE_URL CONSTANT VARCHAR2(255) := 'fscmRestApi/resources/11.13.18.05/receivablesInvoices';
  G_CREATE_RECEIPT_URL CONSTANT VARCHAR2(255) := 'fscmRestApi/resources/11.13.18.05/standardReceipts';
  G_ROOT_URL_EWHW VARCHAR2(255) := NULL;

  G_TRANSACTION_SOURCE VARCHAR2(100) := 'PS_Po\u010Detno_stanje';
  G_GL_DATE VARCHAR2(30) := '2022-12-31';
  G_FIX_HRK_EUR_RATE NUMBER := 1/7.53450;
  G_TRX_ID NUMBER;
  G_PREFIX VARCHAR2(10) := '';

/*===========================================================================+
Function    : table_log
Description :
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure table_log(p_text varchar2) is
pragma autonomous_transaction;

begin
insert into xxdl_ar_mig_log values (CURRENT_TIMESTAMP, xxdl_ar_mig_log_s1.nextval, G_TRX_ID, p_text);
commit;
end;


function check_acc_seg(p_value varchar2, p_vst varchar2) return number is

l_ret number;

begin
select count(1)
into l_ret
from xxdl_accseg_values x
where x.flex_value = p_value
and x.flex_value_set_name = p_vst;

return l_ret;

end;



/*===========================================================================+
Function    : log
Description :
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure log(p_text varchar2) is
  begin
  --dbms_output.put_line(p_text);
  table_log(p_text);
end;


function validate_acc_seg(p_seg1 varchar2,
                          p_seg2 varchar2,
                          p_seg3 varchar2,
                          p_seg4 varchar2,
                          p_seg5 varchar2,
                          p_seg6 varchar2,
                          p_seg7 varchar2,
                          p_bu_name varchar2) return varchar2 is

l_err_cnt number := 0;
l_return_msg varchar2(4000):= '';
l_exist number;
begin

l_return_msg := 'Non exiting segments: ';
-- seg1
l_exist := check_acc_seg(p_seg1, 'Poduzece ' || p_bu_name);
if l_exist = 0 then
   l_err_cnt := l_err_cnt + 1;
   l_return_msg := l_return_msg || '
   Value p_seg1 = ' || p_seg1 || ' dont exist in Poduzece ' || p_bu_name;
end if;

-- seg2
l_exist := check_acc_seg(p_seg2, 'Konto DALEKOVOD');
if l_exist = 0 then
   l_err_cnt := l_err_cnt + 1;
   l_return_msg := l_return_msg || '
   Value p_seg2 = ' || p_seg2 ||' dont exist in Konto ' || p_bu_name;
end if;


-- seg3
l_exist := check_acc_seg(p_seg3, 'Mjesto troska ' || p_bu_name);
if l_exist = 0 then
   l_err_cnt := l_err_cnt + 1;
   l_return_msg := l_return_msg || '
   Value p_seg3 = ' || p_seg3 ||' dont exist in Mjesto troska ' || p_bu_name;
end if;


-- seg4
l_exist := check_acc_seg(p_seg4, 'Projekt ' || p_bu_name);
if l_exist = 0 then
   l_err_cnt := l_err_cnt + 1;
   l_return_msg := l_return_msg || '
   Value p_seg4 = ' || p_seg4 ||' dont exist in Projekt ' || p_bu_name;
end if;


-- seg5
l_exist := check_acc_seg(p_seg5, 'Radni nalog ' || p_bu_name);
if l_exist = 0 then
   l_err_cnt := l_err_cnt + 1;
   l_return_msg := l_return_msg || '
   Value p_seg5 = ' || p_seg5 ||' dont exist in Radni nalog ' || p_bu_name;
end if;


-- seg6
l_exist := check_acc_seg(p_seg6, 'Podkonto ' || p_bu_name);
if l_exist = 0 then
   l_err_cnt := l_err_cnt + 1;
   l_return_msg := l_return_msg || '
   Value p_seg6 = ' || p_seg6 ||' dont exist in Podkonto ' || p_bu_name;
end if;


-- seg7
l_exist := check_acc_seg(p_seg7, 'Nalog prodaje ' || p_bu_name);
if l_exist = 0 then
   l_err_cnt := l_err_cnt + 1;
   l_return_msg := l_return_msg || '
   Value p_seg7 = ' || p_seg7 || ' dont exist in Nalog prodaje ' || p_bu_name;
end if;

if l_err_cnt = 0 then
 return 'S';
end if;

return l_return_msg;

end;







/*===========================================================================+
Function    : insert_interface
Description : retrieve data (open invoices from EBS) end insert into interface
              table XXDL_AR_INV_INT
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure insert_interface is

begin


update XXDL_AR_AVANS_XLSX x
set x.iznos = replace(x.iznos, ',','.')
, x.iznos_val = replace(x.iznos_val, ',','.')
, x.saldo_eur_migracija = replace(x.saldo_eur_migracija, ',','.')
;

INSERT INTO XXDL_AR_AVANS_INT
(
  CASH_RECEIPT_ID,
  ORG_ID,
  receipt_number,
  DOC_SEQUENCE_VALUE,
  TRX_CLASS,
  TRX_TYPE,
  TRX_DATE,
  GL_DATE,
  DUE_DATE,
  TERM_NAME,
  INVOICE_CURRENCY_CODE,
  EXCHANGE_DATE,
  EXCHANGE_RATE,
  AMOUNT_DUE_ORIGINAL,
  AMOUNT_DUE_REMAINING,
  ACCTD_AMOUNT_DUE_REMAINING,
  --
  BILL_TO_CUSTOMER_ID,
  BILL_TO_SITE_USE_ID,
  BILL_TO_CUSTMER_NAME,
  BILL_TO_ACCOUNT_NUMBER,
  BILL_TO_SITE_NUMBER,
  SOLD_TO_CUSTOMER_ID,
  SOLD_TO_SITE_USE_ID,
  SOLD_TO_CUSTMER_NAME,
  SOLD_TO_ACCOUNT_NUMBER,
  SOLD_TO_SITE_NUMBER,
  SHIP_TO_CUSTOMER_ID,
  SHIP_TO_SITE_USE_ID,
  SHIP_TO_CUT_ACCT_SITE_ID,
  SHIP_TO_CUSTMER_NAME,
  SHIP_TO_ACCOUNT_NUMBER,
  SHIP_TO_SITE_NUMBER,
  SHIP_TO_PARTY_NUMBER,
  REMIT_TO_ADDRESS_ID,
  REMIT_TO_ADDRESS,
  REC_ACCOUNT,
  REC_ACCOUNT_ID,
  PROJECT_NUMBER,
  --
  CODE_COMBINATION_ID,
  TRX_HDR_ID,
  CURRENCY,
  SIFRA_KUPCA,
  NAZIV,
  TIP,
  BROJ_DOKUMENTA,
  DATUM_DOKUMENTA,
  IZNOS,
  IZNOS_VAL,
  --SALDO_DOSPIJECE,
  --SALDO_DOSPIJECE_HRK,
  SALDO_EUR_MIGRACIJA,
  KONTO,
  --DOSPIJECE,
  SEGMENT1,
  SEGMENT2,
  SEGMENT3,
  SEGMENT4,
  SEGMENT5,
  SEGMENT6,
  SEGMENT7,
  SEGMENT8,
  --NOVI_IZNOS,
  --CONVERSION_RATE,
  --
  A_STATUS,
  A_MESSAGE,
  R_STATUS,
  R_MESSAGE,
  CREATION_DATE,
  LAST_UPDATE_DATE,
  C_CUSTOMER_TRX_ID
  ) select
  acr.cash_receipt_id,
  acr.org_id,
  acr.receipt_number,
  null,
  null as trx_class,
  x.tip as trx_type,
  x.datum_dokumenta,
  ps.gl_date,
  ps.due_date,
  tt.name,
  acr.currency_code,
  ps.exchange_date,
  ps.exchange_rate,
  ps.amount_due_original,
  ps.amount_due_remaining,
  ps.acctd_amount_due_remaining,
  -- customer
  b2c.cust_account_id as bill_to_customer_id,
  acr.customer_site_use_id as bill_to_site_use_id,
  nvl(b2c.party_name, b22c.party_name) bill_to_custmer_name,
  nvl(b2c.account_number,b22c.account_number) bill_to_acccount_number,
  b2c.party_site_number bill_to_site_number,
  null as sold_to_customer_id,
  null as sold_to_site_use_id,
  --nvl(s2c.party_name, s22c.party_name) sold_to_custmer_name,
  null as sold_to_custmer_name,
  --nvl(s2c.account_number, s22c.account_number) sold_to_acccount_number,
  null as sold_to_acccount_number,
  null as ship_to_site_number,
  null as ship_to_customer_id,
  null as ship_to_site_use_id,
  null as cust_acct_site_id,
  --nvl(sh2c.party_name, sh22c.party_name) ship_to_custmer_name,
  null as ship_to_custmer_name,
  --nvl(sh2c.account_number, sh22c.account_number) ship_to_acccount_number,
  null as ship_to_acccount_number,
  null as ship_to_site_number,
  null as ship_to_party_number,
  r2c.remit_to_address_id,
  r2c.remit_to_addres,
  gcc.concatenated_segments,
  gcc.code_combination_id,
  acr.attribute1,
  ---
  --
  x.CODE_COMBINATION_ID,
  x.TRX_HDR_ID,
  x.CURRENCY,
  x.SIFRA_KUPCA,
  x.NAZIV,
  x.TIP,
  x.BROJ_DOKUMENTA,
  x.DATUM_DOKUMENTA,
  to_number(x.IZNOS),
  to_number(x.IZNOS_VAL),
  --to_number(x.SALDO_DOSPIJECE),
  --to_number(x.SALDO_DOSPIJECE_HRK),
  to_number(x.SALDO_EUR_MIGRACIJA),
  x.KONTO,
  --x.DOSPIJECE,
  x.SEGMENT1,
  x.SEGMENT2,
  x.SEGMENT3,
  x.SEGMENT4,
  x.SEGMENT5,
  x.SEGMENT6,
  x.SEGMENT7,
  x.SEGMENT8,
  --to_number(x.NOVI_IZNOS),
  --to_number(x.CONVERSION_RATE),
  --
  -- end customer
  'P', -- STATUS PENDING
  'Interface Inserted', -- message
  'P', -- STATUS PENDING
  'Interface Inserted', -- message
  sysdate, -- creation_date,
  sysdate, -- last_update date
  null -- c_customer_trx_id
  from XXDL_AR_AVANS_XLSX x
  --join apps.ra_customer_trx_all@EBSPROD t on t.customer_trx_id = x.trx_hdr_id
  join  (select aps.cash_receipt_id, sum(aps.amount_due_original) as amount_due_original,
          sum(aps.amount_due_remaining) as amount_due_remaining,
          sum(aps.acctd_amount_due_remaining) as acctd_amount_due_remaining,
          max(aps.exchange_rate) as exchange_rate,
          max(aps.exchange_date) as exchange_date,
          max(aps.class) as class,
          count(distinct aps.exchange_rate) as dist_exchange_rate,
          count(distinct aps.gl_date) as dist_gl_date,
          count(distinct aps.due_date) as dist_due_date,
          min(aps.due_date) as due_date,
          min(aps.gl_date) as gl_date,
          count(1) as cnt
          from apps.ar_payment_schedules_all@EBSPROD aps
          where 1=1
          -- and aps.amount_due_remaining != 0
          --and aps.customer_trx_id is not null
          group by aps.cash_receipt_id
          --having count(1) = 1
          ) ps on ps.cash_receipt_id = x.trx_hdr_id
     join apps.ar_cash_receipts_all@ebsprod acr on acr.cash_receipt_id = ps.cash_receipt_id
     join apps.ra_terms_tl@EBSPROD tt on  tt.language = 'HR' and tt.name = 'ODMAH'
     left join xxdl_ar_cust_v b2c on b2c.site_use_id = acr.customer_site_use_id
     --left join xxdl_ar_cust_v s2c on 1 = -1
     --left join xxdl_ar_cust_v sh2c on 1 = -1
     left join xxdl_ar_cust2_v b22c on b22c.cust_account_id = b2c.cust_account_id
     --left join xxdl_ar_cust2_v s22c on 1 = -1
     --left join xxdl_ar_cust2_v sh22c on 1 = -1
     -- remit to
  left join xxdl_ar_remit_to_v r2c on r2c.remit_to_address_id = -1
  left join (select rcda.customer_trx_id, max(rcda.code_combination_id) as code_combination_id, count(1) as cnt
      from apps.ra_cust_trx_line_gl_dist_all@EBSPROD rcda
      where 1=2 --trunc(rcda.gl_date) <= P_AS_OF_DATE
      and rcda.account_class = 'REC'
      group by rcda.customer_trx_id) rec_acc on rec_acc.customer_trx_id = -1
  left join apps.gl_code_combinations_kfv@EBSPROD gcc on rec_acc.code_combination_id = gcc.code_combination_id
  where 1=1
  -- and ps.amount_due_remaining != 0
  --and ps.customer_trx_id is not null
  and acr.cash_receipt_id not in (select cash_receipt_id from xxdl_ar_avans_int)
  --and ps.class != 'CB'
  ;

  commit;

end;


/*===========================================================================+
Function    : get_json
Description : validate datea and get json for single invoice
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure get_json(p_avans xxdl_ar_avans_int%rowtype, p_out_json in out varchar2, p_return_status in out varchar2, p_return_msg in out varchar2) is

  l_json_text  varchar2(32000);
  l_err_cnt number := 0;
  l_return_msg varchar2(4000):= '';
  l_validate_seg varchar2(4000);

  -- inv inv
  l_trx_date date;
  l_due_date date;
  l_currency varchar2(3);
  l_term_name varchar2(40);
  l_trx_type_name varchar2(40);
  l_rec_account varchar2(500);
  l_business_unit_name varchar2(200);

  -- bill to
  l_cl_bill_to_cust_account_id number;
  l_cl_bill_to_account_number varchar2(30);
  l_cl_bill_to_site_use_id number;
  l_cl_bill_to_location varchar2(40);

  -- bill to
  l_cl_sold_to_cust_account_id number;
  l_cl_sold_to_account_number varchar2(30);
  l_cl_sold_to_site_use_id number;
  l_cl_sold_to_location varchar2(40);

  -- bill to
  l_cl_ship_to_cust_account_id number;
  l_cl_ship_to_party_number varchar2(30);
  l_cl_ship_to_site_use_id number;
  l_cl_ship_to_party_site_number varchar2(40);

  l_remit_to_address varchar2(240);
  l_amount number;

  --
  l_exchange_rate_type VARCHAR2(30);
  l_exchange_date DATE;
  l_exchange_rate NUMBER;

  l_doc_number varchar2(40);

  l_seg1 varchar2(150);
  l_seg2 varchar2(150);
  l_seg3 varchar2(150);
  l_seg4 varchar2(150);
  l_seg5 varchar2(150);
  l_seg6 varchar2(150);
  l_seg7 varchar2(150);

  l_acc_bu_name varchar2(100);

  l_project_id number;
  l_cl_project_number varchar2(30);


begin

    log('Start get_json');

    p_return_status := 'S';
    p_return_msg := 'Invoice validated.';
    l_return_msg := 'Trx id = ' || p_avans.cash_receipt_id;

    -- business unit
    begin
      select xcrs.business_unit_name,
      DECODE(trim(xcrs.business_unit_name),
         'Dalekovod', 'DALEKOVOD',
         'Dalekovod EMU', 'DALEKOVOD EMU',
         'Dalekovod Adria', 'DALEKOVOD ADRIA',
         'Proizvodnja OSO', 'PROIZVODNJA OSO',
         'Dalekovod Projekt', 'DALEKOVOD PROJEKT',
         'EL - RA', 'EL-RA',
         'Proizvodnja MK', 'PROIZVODNJA MK',
              'DALEKOVOD') as acc_bu
      into l_business_unit_name
      , l_acc_bu_name
      from xxdl_cloud_reference_sets xcrs
      where xcrs.ebs_org_id =  p_avans.org_id;
    exception
    when no_data_found then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) || 'No data found in xxdl_cloud_reference_sets for org_id = ' || p_avans.org_id;
    when too_many_rows then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) || 'Too many rows in xxdl_cloud_reference_sets for org_id = ' || p_avans.org_id;
    end;

    log('l_acc_bu_name = ' || l_acc_bu_name);

    -- transaction type
    begin
        select xtm.c_name
        into l_trx_type_name
        from xxdl_ar_type_map xtm
        where xtm.ebs_name = decode(p_avans.tip, 'PS AVANS HRK', 'AVANS HRK', p_avans.tip);
    exception
    when no_data_found then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  chr(10) ||  'No data found in xxdl_ar_type_map for ebx trx type  = ' || p_avans.tip;
    when too_many_rows then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'Too many rows in in xxdl_ar_type_map for ebx trx type  = ' || p_avans.tip;
    end;

    -- check if mapped trx type dont exist in cloud
    begin
        select ttc.name
        into l_trx_type_name
        from xxdl_ar_trx_types_cl ttc
        where ttc.name = l_trx_type_name;
    exception
    when no_data_found then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  chr(10) ||  'No data found in xxdl_ar_trx_types_cl for  trx type  = ' || l_trx_type_name;
    when too_many_rows then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'Too many rows in in xxdl_ar_trx_types_cl for  trx type  = ' || l_trx_type_name;
    end;


    begin
        select xatc.name
        into l_term_name
        from xxdl_ar_terms_cl xatc
        where xatc.name = p_avans.term_name
        and xatc.language = 'HR';
      exception
      when no_data_found then
           l_err_cnt := l_err_cnt + 1;
           l_return_msg := l_return_msg || chr(10) ||  chr(10) ||  'No data found in xxdl_ar_terms_cl for term = ' || p_avans.term_name;
      when too_many_rows then
           l_err_cnt := l_err_cnt + 1;
           l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_ar_terms_cl for term = ' || p_avans.term_name;
      end;


    -- bill to customer
    begin
      select xa.cloud_cust_account_id, p_avans.bill_to_account_number
      into l_cl_bill_to_cust_account_id, l_cl_bill_to_account_number
      from xxdl_hz_cust_accounts xa
      where xa.cust_account_id = p_avans.bill_to_customer_id;
    exception
    when no_data_found then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_hz_cust_accounts for bill_to_customer_id = ' || p_avans.bill_to_customer_id;
    when too_many_rows then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_hz_cust_accounts for bill_to_customer_id = ' || p_avans.bill_to_customer_id;
    end;


    begin
      select max(xc.account_number)
      into l_cl_bill_to_account_number
      from xxdl_ar_cust_cl xc
      where xc.cust_account_id = l_cl_bill_to_cust_account_id;
    exception
    when no_data_found then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_ar_cust_cl for l_cl_bill_to_cust_account_id = ' || l_cl_bill_to_cust_account_id;
    when too_many_rows then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_ar_cust_cl for l_cl_bill_to_cust_account_id = ' || l_cl_bill_to_cust_account_id;
    end;

    begin
      select xc.cloud_site_use_id, xc.cloud_location_id
      into l_cl_bill_to_site_use_id, l_cl_bill_to_location
      from xxdl_hz_cust_acct_site_uses xc
      where xc.site_use_id = p_avans.bill_to_site_use_id;
    exception
    when no_data_found then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_hz_cust_acct_site_uses for bill_to_site_use_id = ' || p_avans.bill_to_site_use_id;
    when too_many_rows then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_hz_cust_acct_site_uses for bill_to_site_use_id = ' || p_avans.bill_to_site_use_id;
    end;

    /*if l_cl_bill_to_location is null then
           l_return_msg := l_return_msg  || chr(10) || 'Bill To Customer Site: Cloud location is null in xxdl_hz_cust_acct_site_uses  for bill_to_site_use_id = ' || p_inv.bill_to_site_use_id;
    end if;*/

    begin
      select max(xc.location)
      into l_cl_bill_to_location
      from xxdl_ar_cust_cl xc
      where xc.site_use_id = l_cl_bill_to_site_use_id;
    exception
    when no_data_found then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_ar_cust_cl for l_cl_bill_to_site_use_id = ' || l_cl_bill_to_site_use_id;
    when too_many_rows then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_ar_cust_cl for l_cl_bill_to_site_use_id = ' || l_cl_bill_to_site_use_id;
    end;


    -- sold to customer
    if 1=2 then -------------------- skip sold to and ship to customer
    if p_avans.sold_to_customer_id is not null then
      begin
        select xa.cloud_cust_account_id,  p_avans.sold_to_account_number
        into l_cl_sold_to_cust_account_id, l_cl_sold_to_account_number
        from xxdl_hz_cust_accounts xa
        where xa.cust_account_id = p_avans.sold_to_customer_id;
      exception
      when no_data_found then
           l_err_cnt := l_err_cnt + 1;
           l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_hz_cust_accounts for sold_to_customer_id = ' || p_avans.sold_to_customer_id;
      when too_many_rows then
           l_err_cnt := l_err_cnt + 1;
           l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_hz_cust_accounts for sold_to_customer_id = ' || p_avans.sold_to_customer_id;
      end;

      begin
        select max(xc.account_number)
        into l_cl_sold_to_account_number
        from xxdl_ar_cust_cl xc
        where xc.cust_account_id = l_cl_sold_to_cust_account_id;
      exception
      when no_data_found then
           l_err_cnt := l_err_cnt + 1;
           l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_ar_cust_cl for l_cl_sold_to_cust_account_id = ' || l_cl_sold_to_cust_account_id;
      when too_many_rows then
           l_err_cnt := l_err_cnt + 1;
           l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_ar_cust_cl for l_cl_sold_to_cust_account_id = ' || l_cl_sold_to_cust_account_id;
      end;


      if p_avans.sold_to_site_use_id is not null then
        begin
          select xc.Cloud_Site_Use_Id, xc.cloud_location_id
          into l_cl_sold_to_site_use_id, l_cl_sold_to_location
          from xxdl_hz_cust_acct_site_uses xc
          where xc.site_use_id = p_avans.sold_to_site_use_id;
        exception
        when no_data_found then
             l_err_cnt := l_err_cnt + 1;
             l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_hz_cust_acct_site_uses for sold_to_site_use_id = ' || p_avans.sold_to_site_use_id;
        when too_many_rows then
             l_err_cnt := l_err_cnt + 1;
             l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_hz_cust_acct_site_uses for sold_to_site_use_id = ' || p_avans.sold_to_site_use_id;
        end;

       /* if l_cl_sold_to_location is null then
           l_return_msg := l_return_msg  || chr(10) || 'Paying Customer Site: Cloud location is null in xxdl_hz_cust_acct_site_uses  for sold_to_site_use_id = ' || p_inv.sold_to_site_use_id;
        end if;*/

        begin
          select max(xc.location)
          into l_cl_sold_to_location
          from xxdl_ar_cust_cl xc
          where xc.site_use_id = l_cl_sold_to_site_use_id;
        exception
        when no_data_found then
             l_err_cnt := l_err_cnt + 1;
             l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_ar_cust_cl for l_cl_bill_to_site_use_id = ' || l_cl_sold_to_site_use_id;
        when too_many_rows then
             l_err_cnt := l_err_cnt + 1;
             l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_ar_cust_cl for l_cl_bill_to_site_use_id = ' || l_cl_sold_to_site_use_id;
        end;
      end if; -- sold sit use id
    end if; -- sold to customer


    -- ship to customer
    if p_avans.ship_to_customer_id is not null then
      begin
        select xa.cloud_cust_account_id, p_avans.ship_to_party_number
        into l_cl_ship_to_cust_account_id, l_cl_ship_to_party_number
        from xxdl_hz_cust_accounts xa
        where xa.cust_account_id = p_avans.ship_to_customer_id;
      exception
      when no_data_found then
           l_err_cnt := l_err_cnt + 1;
           l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_hz_cust_accounts for ship_to_customer_id = ' || p_avans.ship_to_customer_id;
      when too_many_rows then
           l_err_cnt := l_err_cnt + 1;
           l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_hz_cust_accounts for ship_to_customer_id = ' || p_avans.ship_to_customer_id;
      end;

      begin
        select max(xc.party_number)
        into l_cl_ship_to_party_number
        from xxdl_ar_cust_cl xc
        where xc.cust_account_id = l_cl_ship_to_cust_account_id;
      exception
      when no_data_found then
           l_err_cnt := l_err_cnt + 1;
           l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_ar_cust_cl for l_cl_ship_to_cust_account_id = ' || l_cl_ship_to_cust_account_id;
      when too_many_rows then
           l_err_cnt := l_err_cnt + 1;
           l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_ar_cust_cl for l_cl_ship_to_cust_account_id = ' || l_cl_ship_to_cust_account_id;
      end;


      if p_avans.ship_to_site_use_id is not null then
        begin
          select  xc.cloud_party_site_number
          into l_cl_ship_to_party_site_number
          from xxdl_hz_cust_acct_sites xc
          where xc.cust_acct_site_id = p_avans.ship_to_cut_acct_site_id;
        exception
        when no_data_found then
             l_err_cnt := l_err_cnt + 1;
             l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_hz_cust_acct_sites for ship_to_cut_acct_site_id = ' || p_avans.ship_to_cut_acct_site_id;
        when too_many_rows then
             l_err_cnt := l_err_cnt + 1;
             l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_hz_cust_acct_sites for ship_to_cut_acct_site_id = ' || p_avans.ship_to_cut_acct_site_id;
        end;

        /*if l_cl_ship_to_party_site_number is null then
           l_return_msg := l_return_msg  || chr(10) || 'Ship to Party Site: Cloud party site number is null in xxdl_hz_cust_acct_sites  for ship_to_cut_acct_site_id = ' || p_inv.ship_to_cut_acct_site_id;
        end if;*/

        begin
          select max(xc.party_site_number)
          into l_cl_ship_to_party_site_number
          from xxdl_ar_cust_cl xc
          where xc.site_use_id = l_cl_ship_to_site_use_id;
        exception
        when no_data_found then
             l_err_cnt := l_err_cnt + 1;
             l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_ar_cust_cl for l_cl_ship_to_site_use_id = ' || l_cl_ship_to_site_use_id;
        when too_many_rows then
             l_err_cnt := l_err_cnt + 1;
             l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_ar_cust_cl for l_cl_ship_to_site_use_id = ' || l_cl_ship_to_site_use_id;
        end;
      end if; -- sold sit use id
    end if; -- sold to customer

    end if; -------------------- skip sold to and ship to customer

    /*if p_avans.trx_class = 'CB' then
        select
        max(customer_trx_id) keep(dense_rank FIRST order by hier_level desc) as customer_trx_id
        into l_rel_customer_trx_id
        from
        (select
        aa.customer_trx_id,
        aa.chargeback_customer_trx_id,
        SYS_CONNECT_BY_PATH(aa.chargeback_customer_trx_id|| '-' || aa.customer_trx_id, '/') path,
        level as hier_level
        from apps.ar_adjustments_all@ebsprod aa
        start with aa.chargeback_customer_trx_id = p_inv.customer_trx_id
        connect by prior  aa.customer_trx_id = aa.chargeback_customer_trx_id
        );
    end if;

    select --x.org_id, x.trx_number, x.trx_number, p.project_status_code, x.trx_class, x.trx_type, l.interface_line_context, x.customer_trx_id
        max(p.project_id)
        into l_project_id
        from apps.RA_CUSTOMER_TRX_LINES_ALL@ebsprod l
        join apps.pa_projects_all@ebsprod p on l.interface_line_attribute1 = p.segment1
        where 1=1
        and l.interface_line_context = 'PROJECTS INVOICES'
        and p.project_status_code = 'APPROVED'
        and l.customer_trx_id = nvl(l_rel_customer_trx_id, p_avans.customer_trx_id);*/

    begin
    select ppa.project_id
    into l_project_id
    from apps.ar_cash_receipts_all@EBSPROD acr
    join apps.pa_projects_all@EBSPROD ppa on acr.attribute1 = ppa.segment1
    where 1=1
    and acr.cash_receipt_id = p_avans.cash_receipt_id;
    exception
    when no_data_found then
         null;
    when too_many_rows then
             l_err_cnt := l_err_cnt + 1;
             l_return_msg := l_return_msg || chr(10) ||  'Too many rows in when getting project_id from  p_avans.cash_receipt_id = ' || p_avans.cash_receipt_id;
    end;


    if l_project_id is not null then
       begin
          select xp.c_project_num
          into l_cl_project_number
          from xxdl_projects_int xp
          where xp.project_id = l_project_id;
        exception
        when no_data_found then
             l_err_cnt := l_err_cnt + 1;
             l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_projects_int for l_project_id = ' || l_project_id;
        when too_many_rows then
             l_err_cnt := l_err_cnt + 1;
             l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_projects_int for l_project_id = ' || l_project_id;
        end;

        if l_cl_project_number is null then
             l_err_cnt := l_err_cnt + 1;
             l_return_msg := l_return_msg || chr(10) ||  'Cloud project id is null  for l_project_id = ' || l_project_id;
        end if;

    end if;


    select
    decode(length(p_avans.segment1), 1, '0' || p_avans.segment1, p_avans.segment1), -- seg1
           p_avans.segment2,
           decode(p_avans.segment3, '0', '000000', p_avans.segment3),
           decode(p_avans.segment4, '0', '000000', p_avans.segment4),
           decode(p_avans.segment5, '0', '000000', p_avans.segment5),
           decode(p_avans.segment6, '0', '0000000',p_avans.segment6),
           decode(p_avans.segment6, '0', '000000',p_avans.segment7)
    into  l_seg1,
           l_seg2,
           l_seg3,
           l_seg4,
           l_seg5,
           l_seg6,
           l_seg7
    from dual;

    select decode(l_seg3, '631300','244000', l_seg3)
    into l_seg3 from dual;



    l_validate_seg:= validate_acc_seg(l_seg1,
                     l_seg2,
                     l_seg3,
                     l_seg4,
                     l_seg5,
                     l_seg6,
                     l_seg7,
                     l_acc_bu_name);

    if l_validate_seg != 'S' then
             l_err_cnt := l_err_cnt + 1;
             l_return_msg := l_return_msg || chr(10) || l_validate_seg;
    end if;

    -- receivable account
    select l_seg1 || '.' ||
           l_seg2 || '.' ||
           l_seg3 || '.' ||
           l_seg4 || '.' ||
           l_seg5 || '.' ||
           l_seg6 || '.' ||
           l_seg7 || '.' ||
           '00.000000.000000'
    into l_rec_account
    from dual;


    /*select 'Ul. Marijana \u010Cavi\u0107a 4'
    --apex_escape.json(p_inv.remit_to_address)
    into l_remit_to_address from dual;
    */
    begin
      -- remit to addres
      select r2a.cloud_address
      into l_remit_to_address
      from xxdl_ar_r2addrs r2a
      where r2a.ebs_org_id = p_avans.org_id;
    exception
    when no_data_found then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_ar_r2addrs for p_inv.org_id= ' || p_avans.org_id;
    when too_many_rows then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_ar_r2addrs for p_inv.org_id= ' || p_avans.org_id;
    end;

    if l_remit_to_address is null then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'l_remit_to_address is null for p_inv.org_id= ' || p_avans.org_id;
    end if;

    select decode(p_avans.doc_sequence_value,
      null, G_PREFIX || to_char(p_avans.receipt_number),
      G_PREFIX || to_char(p_avans.doc_sequence_value)
      )
    into l_doc_number from dual;



    select decode(p_avans.currency, 'HRK', 'EUR', p_avans.invoice_currency_code),
    /*case
    when p_inv.segment2 = '121000' then p_inv.invoice_amount_eur_preracunato
    when p_inv.currency = 'HRK' then p_inv.invoice_amount_eur_preracunato
    else p_inv.saldo_dospijece
    end amount,*/
    --p_inv.SALDO_EUR_MIGRACIJA,
    p_avans.SALDO_EUR_MIGRACIJA,
    p_avans.datum_dokumenta,
    null
    --p_inv.conversion_rate,
    --p_inv.exchange_date
    into l_currency,
    l_amount,
    l_trx_date,
    l_due_date
    --l_exchange_rate,
    --l_exchange_date
    from dual;

    if l_amount = 0 then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'Amount = 0';
    end if;


    if p_avans.currency not in ('HRK','EUR') then
         select
         'User',
         to_date('31.12.2022', 'dd.mm.yyyy'),
         --x.conversion_rate * G_FIX_HRK_EUR_RATE
         round(X.Saldo_Eur_Migracija/X.iznos_val, 6),
         x.iznos_val
         --t.exchange_rate
         into
          l_exchange_rate_type,
          l_exchange_date,
          l_exchange_rate,
          l_amount
         from xxdl_ar_avans_int x
         where x.cash_receipt_id = p_avans.cash_receipt_id;

    end if;




    -- PS DOMACI
    l_json_text := '{
     "TransactionDate" : "' || to_char(l_trx_date, 'yyyy-mm-dd') || '",
     "AccountingDate" : "' || G_GL_DATE || '",
     "TransactionNumber" : "' || substrb(G_PREFIX || p_avans.receipt_number,1,20) || '",
     "BusinessUnit" : "' || l_business_unit_name || '",
     "TransactionSource" : "' || G_TRANSACTION_SOURCE || '",
     "TransactionType" : "' || apex_escape.json(l_trx_type_name) || '",
     "InvoiceCurrencyCode" : "' || l_currency || '",
     "BillToCustomerNumber" : "' || l_cl_bill_to_account_number || '",
     "BillToSite" : "' || l_cl_bill_to_location || '",';

     -- paying customer
     if l_term_name is not null then
       l_json_text := l_json_text || '
       "PaymentTerms" : "' || apex_escape.json(l_term_name) || '",';
     end if;

     -- paying customer
     l_doc_number := p_avans.cash_receipt_id;
     if l_doc_number is not null then
       l_json_text := l_json_text || '
       "DocumentNumber" : "' || l_doc_number || '",';
     end if;

     -- paying customer
     if l_cl_sold_to_account_number is not null then
       l_json_text := l_json_text || '
       "PayingCustomerAccount" : "' || l_cl_sold_to_account_number || '",';
     end if;

     -- paying customer site
     if l_cl_sold_to_location is not null then
       l_json_text := l_json_text || '
       "PayingCustomerSite" : "' || l_cl_sold_to_location || '",';
     end if;

     -- ship to
     if l_cl_ship_to_party_number is not null then
       l_json_text := l_json_text || '
       "ShipToCustomerNumber" : "' || l_cl_ship_to_party_number || '",';
     end if;

     -- ship to site
     if l_cl_ship_to_party_site_number is not null then
       l_json_text := l_json_text || '
       "ShipToSite" : "' || l_cl_ship_to_party_site_number || '",';
     end if;

     -- ship to site
     if l_cl_project_number is not null then
       l_json_text := l_json_text || '
       "receivablesInvoiceDFF" :[{
	                      "idprojektamigr": '|| l_cl_project_number ||'
			   }],';
     end if;



     -- EXHANGE RATE
     if l_exchange_rate is not null then
       l_json_text := l_json_text || '
       "ConversionDate" : "' || to_char(l_exchange_date, 'YYYY-MM-DD') || '",
       "ConversionRate" : "' || l_exchange_rate || '",
       "ConversionRateType" : "' || 'User' || '",';
     end if;

     l_json_text := l_json_text || '
     "RemitToAddress" : "' || l_remit_to_address || '",
     "receivablesInvoiceLines" :
      [
        {
          "Description" : "' || apex_escape.json('PS Migracija') || '",
          "LineNumber" : 1,
          "Quantity" : 1,
          "UnitSellingPrice" : "' || to_char(l_amount) || '"
        }
      ]
    }';


     if l_err_cnt > 0 then
         p_return_status := 'E';
         p_return_msg := l_return_msg;
         log(l_return_msg);
    end if;



    p_out_json := l_json_text;

    log('End get_json, ' || p_return_msg);

end;


/*===========================================================================+
Function    : create_event
Description : create event calling web service
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure create_avans(p_avans xxdl_ar_avans_int%rowtype, p_validate_only number, p_status in out varchar2) is

  l_return_status varchar2(500);
  l_return_message varchar2(32000);
  l_msg varchar2(4000);
  l_ws_call_id number;
  l_response_clob clob;
  l_create_url varchar2(2000);
  l_rest_env clob;
  l_json_text varchar2(32000);
  l_invoice_id number;

  begin

  log('Start create_invoice ...p_validate_only = ' || p_validate_only);

  p_status := 'S';
  l_msg := 'Invoice Created.';

  get_json(p_avans, l_json_text, l_return_status, l_return_message);

  if l_return_status = 'E' then
         p_status := 'E';
         update xxdl_ar_avans_int x
         set x.a_status = 'E'
         , x.a_message = substrb(l_return_message, 1, 4000)
         , x.a_json_text = l_json_text
         , x.last_update_date = sysdate
         where 1=1
         and x.cash_receipt_id = p_avans.cash_receipt_id;
         return;
   end if;

   if p_validate_only = 1 then
         p_status := 'S';
         update xxdl_ar_avans_int x
         set x.a_message = l_return_message
         , x.a_json_text = l_json_text
         , x.last_update_date = sysdate
         where 1=1
         and x.cash_receipt_id = p_avans.cash_receipt_id;
         log('p_validate_only = 1 -> return');
         return;
   end if;

  l_rest_env := to_clob(l_json_text);

  select G_ROOT_URL_EWHW || G_CREATE_INVOICE_URL
    into l_create_url from dual;

  log('Create Invoice, url = ' || l_create_url);

  --- REST CALL
  xxdl_ar_mig_pkg.rest_call(p_url => l_create_url,
                    p_method => 'POST',
                    p_rest_env => l_rest_env,
                    P_content_type => 'application/json;charset="UTF-8"',
                    p_ws_call_id => l_ws_call_id,
                    p_response_clob => l_response_clob,
                    p_return_status => l_return_status,
                    p_return_msg => l_return_message);

  log('After call xxdl_ar_mig_pkg.rest_call l_return_status = ' || l_return_status);

  if l_return_status = 'S' then
   SELECT trx_id
     into l_invoice_id
     FROM
     JSON_TABLE(l_response_clob, '$'
          COLUMNS (trx_id                 NUMBER            PATH '$.CustomerTransactionId')
              ) t;

     log('Invoice created, l_invoice_id = ' || l_invoice_id);
   end if;

   select
   decode(l_return_status,
   'S', 'Invoice Created, ' || substr(l_return_message,1,3950),
   substrb('API ' || l_return_message, 1,4000)),
   l_return_status
   into
   l_msg,
   p_status
   from dual;


   update xxdl_ar_avans_int x
   set x.a_status = p_status
       , x.a_message = l_msg
       , x.a_ws_call_id = l_ws_call_id
       , x.a_json_text = l_json_text
       , x.last_update_date = sysdate
       , x.c_customer_trx_id = l_invoice_id
    where 1=1
         and x.cash_receipt_id = p_avans.cash_receipt_id;

exception
when others then
   l_msg := 'Unexpectd exception...' || substrb(sqlcode || '-' || sqlerrm || '' || dbms_utility.format_error_backtrace, 1,3900);
   p_status := 'E';
   update xxdl_ar_avans_int x
   set x.r_status = p_status
       , x.r_message = l_msg
       , x.r_ws_call_id = l_ws_call_id
       , x.r_json_text = l_json_text
       , x.last_update_date = sysdate
    where 1=1
         and x.cash_receipt_id = p_avans.cash_receipt_id;

end create_avans;



/*===========================================================================+
Function    : get_json
Description : validate datea and get json for single invoice
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure create_receipt_get_json(p_avans xxdl_ar_avans_int%rowtype, p_out_json in out varchar2, p_return_status in out varchar2, p_return_msg in out varchar2) is

  l_json_text  varchar2(32000);
  l_err_cnt number := 0;
  l_return_msg varchar2(4000):= '';
  l_business_unit_name varchar2(200);
  -- bill to
  l_cl_bill_to_cust_account_id number;
  l_cl_bill_to_account_number varchar2(30);
  l_cl_bill_to_site_use_id number;
  l_cl_bill_to_location varchar2(40);
  l_bank_account varchar2(40);

  l_currency varchar2(3);
    l_amount number;
    l_trx_date date;

   --
  l_exchange_rate_type VARCHAR2(30);
  l_exchange_date DATE;
  l_exchange_rate NUMBER;

  l_contract_num varchar2(30);

begin

    log('Start get_json');

    p_return_status := 'S';
    p_return_msg := 'Receipt validated.';
    l_return_msg := 'Cash Receipt Id = ' || p_avans.cash_receipt_id;


    begin
      select xcrs.business_unit_name
      into l_business_unit_name
      from xxdl_cloud_reference_sets xcrs
      where xcrs.ebs_org_id =  p_avans.org_id;
    exception
    when no_data_found then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) || 'No data found in xxdl_cloud_reference_sets for org_id = ' || p_avans.org_id;
    when too_many_rows then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) || 'Too many rows in xxdl_cloud_reference_sets for org_id = ' || p_avans.org_id;
    end;


    -- bill to customer
    begin
      select xa.cloud_cust_account_id, p_avans.bill_to_account_number
      into l_cl_bill_to_cust_account_id, l_cl_bill_to_account_number
      from xxdl_hz_cust_accounts xa
      where xa.cust_account_id = p_avans.bill_to_customer_id;
    exception
    when no_data_found then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_hz_cust_accounts for bill_to_customer_id = ' || p_avans.bill_to_customer_id;
    when too_many_rows then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_hz_cust_accounts for bill_to_customer_id = ' || p_avans.bill_to_customer_id;
    end;


    begin
      select max(xc.account_number)
      into l_cl_bill_to_account_number
      from xxdl_ar_cust_cl xc
      where xc.cust_account_id = l_cl_bill_to_cust_account_id;
    exception
    when no_data_found then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_ar_cust_cl for l_cl_bill_to_cust_account_id = ' || l_cl_bill_to_cust_account_id;
    when too_many_rows then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_ar_cust_cl for l_cl_bill_to_cust_account_id = ' || l_cl_bill_to_cust_account_id;
    end;

    begin
      select xc.cloud_site_use_id, xc.cloud_location_id
      into l_cl_bill_to_site_use_id, l_cl_bill_to_location
      from xxdl_hz_cust_acct_site_uses xc
      where xc.site_use_id = p_avans.bill_to_site_use_id;
    exception
    when no_data_found then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'No data found in xxdl_hz_cust_acct_site_uses for bill_to_site_use_id = ' || p_avans.bill_to_site_use_id;
    when too_many_rows then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'Too many rows in xxdl_hz_cust_acct_site_uses for bill_to_site_use_id = ' || p_avans.bill_to_site_use_id;
    end;

    select case
    when l_business_unit_name = 'Dalekovod' then 'MIGRACIJA DL'
    when l_business_unit_name = 'Proizvodnja MK' then 'MIGRACIJA MK'
    when l_business_unit_name = 'Dalekovod Projekt' then 'MIGRACIJA DP'
    when l_business_unit_name = 'Proizvodnja OSO' and p_avans.currency in ('EUR', 'HRK') then 'MIGRACIJA OSO'
    when l_business_unit_name = 'Proizvodnja OSO' and p_avans.currency = 'USD' then 'MIGRACIJA OSO USD'
    else null end
    into l_bank_account
    from dual;

    if l_bank_account is null then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'Bank account is null';
    end if;


    select decode(p_avans.currency, 'HRK', 'EUR', p_avans.currency),
    p_avans.SALDO_EUR_MIGRACIJA,
    p_avans.datum_dokumenta
    into l_currency,
    l_amount,
    l_trx_date
    from dual;

    if l_amount = 0 then
         l_err_cnt := l_err_cnt + 1;
         l_return_msg := l_return_msg || chr(10) ||  'Amount = 0';
    end if;

    if p_avans.currency not in ('HRK','EUR') then
         select
         'User',
         to_date('31.12.2022', 'dd.mm.yyyy'),
         --x.conversion_rate * G_FIX_HRK_EUR_RATE
         round(X.Saldo_Eur_Migracija/X.iznos_val, 6),
         x.iznos_val
         --t.exchange_rate
         into
          l_exchange_rate_type,
          l_exchange_date,
          l_exchange_rate,
          l_amount
         from xxdl_ar_avans_int x
         where x.cash_receipt_id = p_avans.cash_receipt_id;

    end if;

    -- contract
    if p_avans.project_number is not null then
      begin
        SELECT
        xc.c_contract_num
        into l_contract_num
        from xxdl_projects_int xp
        left join xxdl_contracts_int xc on xc.project_id = xp.project_id
        where xp.project_number = p_avans.project_number;

      exception
      when no_data_found then
           null;
       end;
    end if;



    l_json_text := '{
    "ReceiptNumber": "' || apex_escape.json(substr(G_PREFIX || p_avans.broj_dokumenta, 1,30)) ||'",
    "ReceiptDate": "' || to_char(p_avans.datum_dokumenta, 'YYYY-MM-DD') || '",
    "AccountingDate": "' || G_GL_DATE || '",
    "ReceiptMethod": "PS Avansi",
    "BusinessUnit": "' || l_business_unit_name ||'",
    "CustomerAccountNumber" : "' || l_cl_bill_to_account_number || '",
    "CustomerSite" : "' || l_cl_bill_to_location || '",
    "RemittanceBankAccountNumber" : "'|| l_bank_account ||'",
    "Amount" : "' || l_amount || '",
    "Currency" : "' || l_currency || '",';


    -- EXHANGE RATE
     if l_exchange_rate is not null then
       l_json_text := l_json_text || '
       "ConversionDate" : "' || to_char(l_exchange_date, 'YYYY-MM-DD') || '",
       "ConversionRate" : "' || l_exchange_rate || '",
       "ConversionRateType" : "' || 'User' || '",';
     end if;

     -- DFF
     l_json_text := l_json_text || '
     "standardReceiptDFF" :[{
	             "avans": "DA"';

     if l_contract_num is not null then
      l_json_text := l_json_text || ',
      "projectContract_Display" : "'|| l_contract_num ||'"';
     end if;

     l_json_text := l_json_text || '
		}],';

     l_json_text := l_json_text || '
     "RemittanceBankAccountNumber" : "'|| l_bank_account ||'"
     }';


    if l_err_cnt > 0 then
         p_return_status := 'E';
         p_return_msg := l_return_msg;
         log(l_return_msg);
     end if;

     p_out_json := l_json_text;

    log('End get_json, ' || p_return_msg);

end;

 /*===========================================================================+
Function    : update_annex
Description : create project calling web service
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure create_receipt(p_rec xxdl_ar_avans_int%rowtype, p_validate_only number, p_status in out varchar2) is

  l_return_status varchar2(500);
  l_return_message varchar2(32000);
  l_msg varchar2(4000);
  l_ws_call_id number;
  l_response_clob clob;
  l_create_receipt_url varchar2(2000);
  l_rest_env clob;
  l_c_receipt_id number;
  l_json_text varchar2(32000);
  l_customer_trx_id number;
  l_avans_status varchar2(1);

  begin

  log('Start create receipt ... p_validate_only = ' || p_validate_only);

  p_status := 'S';
  l_msg := 'Receipt Created.';

  create_receipt_get_json(p_rec, l_json_text, l_return_status, l_return_message);

  if l_return_status = 'E' then
         p_status := 'E';
         update xxdl_ar_avans_int x
         set x.r_status = 'E'
         , x.r_message = substrb(l_return_message, 1, 4000)
         , x.r_json_text = l_json_text
         , x.last_update_date = sysdate
         where 1=1
         and x.cash_receipt_id = p_rec.cash_receipt_id;
         return;
   end if;

   if p_validate_only = 1 then
         p_status := 'S';
         update xxdl_ar_avans_int x
         set x.r_message = l_return_message
         , x.r_json_text = l_json_text
         , x.last_update_date = sysdate
         where 1=1
         and x.cash_receipt_id = p_rec.cash_receipt_id;
         log('p_validate_only = 1 -> return');
         return;
   end if;

  select  x.a_status
  into  l_avans_status
  from xxdl_ar_avans_int x
  where 1=1
  and x.cash_receipt_id = p_rec.cash_receipt_id;

  if l_avans_status != 'S' then
     log('avans status != S -> return');
     return;
  end if;

  l_rest_env := to_clob(l_json_text);

  -- get contract id
  begin
    select x.c_customer_trx_id
    into l_customer_trx_id
    from xxdl_ar_avans_int x
    where 1=1
    and x.cash_receipt_id = p_rec.cash_receipt_id;
  exception
  when no_data_found then
         p_status := 'E';
         l_msg := 'Avans doesnt exist in xxdl_ar_avans_int  p_rec.cash_receipt_id = ' || p_rec.cash_receipt_id;
         GOTO create_receipt_status;
   when too_many_rows then
         p_status := 'E';
         l_msg :=  'Too many rows in xxdl_ar_avans_int for   p_rec.cash_receipt_id = ' || p_rec.cash_receipt_id;
         GOTO create_receipt_status;
   end;

    if l_customer_trx_id is null then
         p_status := 'E';
         l_msg :=  'Cloud c_customer_trx_id id is null in xxdl_ar_avans_int,  cash_receipt_id = ' || p_rec.cash_receipt_id;
         GOTO create_receipt_status;
   end if;

  select G_ROOT_URL_EWHW || G_CREATE_RECEIPT_URL
  into l_create_receipt_url from dual;

  log('Create Receipt, url = ' || l_create_receipt_url);

  --- REST CALL
  xxdl_ar_mig_pkg.rest_call(p_url => l_create_receipt_url,
                    p_method => 'POST',
                    p_rest_env => l_rest_env,
                    P_content_type => 'application/json;charset="UTF-8"',
                    p_ws_call_id => l_ws_call_id,
                    p_response_clob => l_response_clob,
                    p_return_status => l_return_status,
                    p_return_msg => l_return_message);

  log('After call xxdl_ar_mig_pkg.rest_call l_return_status = ' || l_return_status);

  if l_return_status = 'S' then
      SELECT standard_receipt_id
     into l_c_receipt_id
     FROM
     JSON_TABLE(l_response_clob, '$'
          COLUMNS (standard_receipt_id                 NUMBER            PATH '$.StandardReceiptId')
              ) t;

     log('End update annex data, l_c_receipt_id = ' || l_c_receipt_id);
   end if;

   select
   decode(l_return_status,
   'S', 'Receipt Created' || substrb(l_return_message, 1, 3950),
   l_return_message),
   l_return_status
   into
   l_msg,
   p_status
   from dual;


   <<create_receipt_status>>
   update xxdl_ar_avans_int x
   set x.r_status = p_status
       , x.r_message = l_msg
       , x.r_ws_call_id = l_ws_call_id
       , x.r_json_text = l_json_text
       , x.last_update_date = sysdate
       , x.c_receipt_id = l_c_receipt_id
  where 1=1
  and x.cash_receipt_id = p_rec.cash_receipt_id;
    commit;
exception
when others then
   l_msg := 'Unexpectd exception...' || substrb(sqlcode || '-' || sqlerrm || '' || dbms_utility.format_error_backtrace, 1,3900);
   p_status := 'E';
   update xxdl_ar_avans_int x
   set x.r_status = p_status
       , x.r_message = l_msg
       , x.r_ws_call_id = l_ws_call_id
       , x.last_update_date = sysdate
       , x.r_json_text = l_json_text
    where 1=1
  and x.cash_receipt_id = p_rec.cash_receipt_id;

end create_receipt;


procedure dupli is

begin



for r_dupli in (select X.ROWID,
      X.TRX_NUMBER,
      X.TERM_NAME,
       row_number() OVER(PARTITION BY X.TRX_NUMBER
      ORDER BY x.dospijece, x.rowid) AS  row_num,
      X.CUSTOMER_TRX_ID,
      x.due_date,
      x.saldo_eur_migracija,
      x.dupli_saldo
      from xxdl_ar_inv_int x
      where 1=1
    -- testing
    --and x.segment1 = '01'
    --and x.message  like '%Invoice validated%'
    --and x.invoice_amount_eur_preracunato != 0
    and (abs(x.customer_trx_id)  in (select abs(ii.customer_trx_id) from xxdl_ar_inv_int ii group by abs(ii.customer_trx_id) having count(1)>1)
    or x.term_name  in ('30 70 akr', '50 60', '10 45', '50 50', '50 50-30', '30%70%-60', '10% 90%', '20 70 5 5', '30 70'))
    order by x.trx_number, x.dospijece, x.rowid
    ) loop


    if r_dupli.row_num = 1 then
       update xxdl_ar_inv_int x
      set x.dupli_saldo = (select sum(xx.saldo_eur_migracija) from  xxdl_ar_inv_int xx where abs(xx.customer_trx_id) = r_dupli.customer_trx_id)
      where x.rowid =  r_dupli.rowid;
    else
        update xxdl_ar_inv_int x
       set x.status =  'S',
       x.customer_trx_id = x.customer_trx_id *-1,
       x.message = 'Invoice Created - Rucno installment'
       where x.rowid = r_dupli.rowid;
    end if;


end loop;


update xxdl_ar_inv_int x
set x.dupli_saldo = (select sum(x.saldo_eur_migracija) from  xxdl_ar_inv_int xx where abs(xx.customer_trx_id) = x.customer_trx_id)
where x.customer_trx_id in(select distinct customer_trx_id from xxdl_ar_inv_int x
    where 1=1
    -- testing
    --and x.segment1 = '01'
    --and x.message  like '%Invoice validated%'
    --and x.invoice_amount_eur_preracunato != 0
    and x.customer_trx_id  in (select ii.customer_trx_id from xxdl_ar_inv_int ii group by ii.customer_trx_id having count(1)>1)
    and x.term_name  in ('30 70 akr', '50 60', '10 45', '50 50', '50 50-30', '30%70%-60', '10% 90%', '20 70 5 5', '30 70')
    );

end;


/*===========================================================================+
Function    : import_invoices
Description : main procedure
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure main(p_trx_id number, p_validate_only number default 1) is



  l_cnt  number;
  l_return_status varchar2(1);
  l_validate_only number;
  l_run_id number;

  begin

  DBMS_OUTPUT.ENABLE(1000000);

  select xc.value
    into G_ROOT_URL_EWHW
    from xx_configuration xc
    where xc.name = 'ServiceRootURL';

  log('G_ROOT_URL_EWHW = ' || G_ROOT_URL_EWHW);

  if G_ROOT_URL_EWHW is null then
     return;
  end if;

  select xxdl_ar_mig_s1.nextval
  into l_run_id from dual;

  log('Start import_avans ... l_run_id = ' || l_run_id);

  select nvl(p_validate_only, 1)
  into l_validate_only from dual;

  -- loop error or/and pending invoices
  l_cnt := 0;
  log('Loop invoices');
  for r_avans in (
    select *
    from xxdl_ar_avans_int x
    where 1=1
    and (x.a_status IN ('P', 'E') or
         x.r_status IN ('P', 'E'))
    and (x.cash_receipt_id = p_trx_id or p_trx_id is null)

    -- testing
  -- and x.message like '%was already assigned to another%'
    --and x.segment1 = '01'
    --and x.message  like '%Invoice validated%'
    --and x.invoice_amount_eur_preracunato != 0
  --  and x.customer_trx_id not in (select ii.customer_trx_id from xxdl_ar_inv_int ii group by ii.customer_trx_id having count(1)>1)
  --  and x.term_name not in ('30 70 akr', '50 60', '10 45', '50 50', '50 50-30', '30%70%-60', '10% 90%', '20 70 5 5', '30 70')
  -- and x.message  like '%was already assigned to another documen%'
   --and x.segment1 = '9'
   -- and x.currency  not in ('EUR', 'HRK')
   -- and x.status = 'P'
   -- and x.status = 'E'
    --and x.trx_type != 'Projects Invoice'

    --and x.message not like '%Amount = 0%'
    --and x.message not like '%API The customer bill-to site you entered does%'
    -- end testing
  ) loop

    update xxdl_ar_avans_int x
    set run_id = l_run_id
    where x.cash_receipt_id = r_avans.cash_receipt_id;

    G_TRX_ID := r_avans.cash_receipt_id;
    l_cnt := l_cnt + 1;
    log(' - ' || l_cnt || '. Trx number: ' || r_avans.receipt_number || ', ' || r_avans.trx_class  || ' - ' || r_avans.trx_type);


    -- CREATE ANNEX
    if r_avans.a_status in ('P','E') then
        create_avans(r_avans, l_validate_only, l_return_status);
    end if;


     -- UPDATE ANNEX DATA
     --if l_validate_only =
    if r_avans.r_status in ('P','E') then
         create_receipt(r_avans, l_validate_only, l_return_status);
    end if;
    commit;
    if l_cnt > 9 then -- testing
      log('exit l_cnt = ' || l_cnt);
       exit;
    end if;

  end loop;

  if l_cnt = 0 then
     log('No data in interface to process ');
  end if;

  commit;

end main;


end XXDL_AR_AVANS_PKG;
