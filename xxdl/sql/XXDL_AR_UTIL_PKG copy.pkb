SET DEFINE OFF;
SET VERIFY OFF;
WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
WHENEVER OSERROR EXIT FAILURE ROLLBACK;
create or replace package body XXDL_AR_UTIL_PKG as
 /*$Header:  $
 =============================================================================
  -- Name        :  XXDL_AR_UTIL_PKG
  -- Author      :  Zoran Kovac
  -- Date        :  07-SEP-2022
  -- Version     :  120.00
  -- Description :  Cloud Utils package
  --
  -- -------- ------ ------------ -----------------------------------------------
  --   Date    Ver     Author     Description
  -- -------- ------ ------------ -----------------------------------------------
  -- 07-09-22 120.00 zkovac       Initial creation 
  --*/
c_log_module   CONSTANT VARCHAR2(300) := $$PLSQL_UNIT;
g_prod_url VARCHAR2(300) := 'https://fa-encc-test-saasfaprod1.fa.ocs.oraclecloud.com/';
g_dev_url VARCHAR2(300) := 'https://fa-encc-test-saasfaprod1.fa.ocs.oraclecloud.com/';

/*===========================================================================+
    Procedure   : log
    Description : Puts the p_text variable to output file
    Usage       : Writing the output of the request
    Arguments   : p_text - text to output
============================================================================+*/
PROCEDURE LOG (p_text IN VARCHAR2)
   IS
   BEGIN
       DBMS_OUTPUT.put_line (p_text);
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
END;



/*===========================================================================+
    Procedure   : get_ws_err_msg
    Description : Gets REST call error_msg
    Usage       : Writing the output of the request
    Arguments   : p_ws_call_id - ws call id
============================================================================+*/
function get_ws_err_msg (p_ws_call_id IN number) return varchar2
is
l_text xxfn_ws_call_log.response_clob%TYPE;

BEGIN
       begin 
       select xx.response_clob into l_text 
       from
       xxfn_ws_call_log xx
       where xx.ws_call_id = p_ws_call_id;
       exception
         when no_data_found then
           l_text:=null;
       end;

       return l_text;    

   EXCEPTION
      WHEN others
      THEN
         NULL;
END;

/*===========================================================================+
    Procedure   : get_config
    Description : Gets config value
    Usage       : Returnig config value
    Arguments   : p_service - text to output
============================================================================+*/
function get_config (p_service IN VARCHAR2) return varchar2
   IS
   l_value VARCHAR2(1000);
   BEGIN
       select xx.value into l_value
       from
       xx_configuration xx
       where xx.name = p_service;

       return l_value;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
END;

  /*===========================================================================+
  -- Name    : migrate_customers_cloud
  -- Desc    : Procedure for migrating EBS items to cloud
  -- Usage   : 
  -- Parameters	
--       - p_party_number: party number in EBS
--       - p_rows: number of rows to process, default 1000
--		 - p_retry_error: should we process records that ended in error
============================================================================+*/
procedure migrate_customers_cloud (
      p_party_number in varchar2,
      p_rows in number,
      p_retry_error in varchar2
)
is

cursor c_party is
select 
hp.party_name party_name
,hp.party_number party_number
,hp.jgzz_fiscal_code TAXPAYER_ID
,hp.party_id
,hp.duns_number
,hp.party_type party_usage_code
,hp.country
from
apps.hz_parties@ebstest hp
where hp.party_number like nvl(p_party_number,'%')
and hp.party_type = 'ORGANIZATION'
and hp.party_id > 0
and rownum <= nvl(p_rows,10)
and not exists (select 1 from xxdl_hz_parties xx
                    where xx.party_number = hp.party_number
                    and nvl(xx.process_flag,'X') in ('S',decode(p_retry_error,'Y','N','E'))
                    )
;

cursor c_locations(c_party_number in number) is 
select 
a.*
,count(*) over () - rownum as c
from
(
    select distinct
    hl.location_id
    ,hps.party_site_id
    ,nvl(hps.party_site_name,hl.city) party_site_name
    ,hl.address1
    ,hl.address2
    ,hl.address3
    ,hl.address4
    ,hl.city
    ,hl.country
    ,hl.county
    ,hl.postal_code
    ,hl.POSTAL_PLUS4_CODE
    ,hl.state
    from
    apps.hz_parties@ebstest hp
    ,apps.hz_party_sites@ebstest hps
    ,apps.hz_cust_accounts@ebstest hca
    ,apps.HZ_CUST_ACCT_SITES_ALL@ebstest HCASA
    ,apps.HZ_CUST_SITE_USES_all@ebstest hcsu
    ,apps.hz_locations@ebstest hl
    where 1=1
    and hp.party_id = hca.party_id(+)
    and hp.party_id = hps.party_id(+)
    and hca.cust_account_id = hcasa.cust_account_id
    and hps.party_site_id = hcasa.party_site_id(+)
    and hcasa.cust_acct_site_id = hcsu.cust_acct_site_id(+)
    and hps.location_id = hl.location_id(+)
    and hcsu.site_use_code is not null
    and hp.party_number = c_party_number
) a;

cursor c_rest(c_ws_call_id in number) is
select 
jt.ws_call_id
,jt.cloud_party_id
,jt.cloud_party_number
,jt.address_id
,jt.source_address_id
,jt.source_party_id
from
(
select
cloud_party_id
,cloud_party_number
,address_id
,address_type
,source_address_id
,source_party_id
,xx.ws_call_id
from
xxfn_ws_call_log xx,
json_table(xx.response_json,'$'
    columns(
                    cloud_party_id number path '$.PartyId',
                    cloud_party_number varchar2(100) path '$.PartyNumber',
                    address_id number path '$.AddressId',
                    address_type varchar2(30) path '$.AddressType',
                    source_address_id varchar2(240) path '$.SourceSystemReferenceValue',
                    source_party_id number path '$.PartySourceSystemReferenceValue'))
where xx.ws_call_id = c_ws_call_id
and address_id is not null
union all
select
cloud_party_id
,cloud_party_number
,address_id
,address_type
,source_address_id
,source_party_id
,xx.ws_call_id
from
xxfn_ws_call_log xx,
json_table(xx.response_json, '$'
    columns(nested path '$.Address[*]'
                columns(
                    cloud_party_id number path '$.PartyId',
                    cloud_party_number varchar2(100) path '$.PartyNumber',
                    address_id number path '$.AddressId',
                    address_type varchar2(30) path '$.AddressType',
                    source_address_id varchar2(240) path '$.SourceSystemReferenceValue',
                    source_party_id number path '$.PartySourceSystemReferenceValue')))                   
where xx.ws_call_id = c_ws_call_id
)  jt
where
jt.cloud_party_id is not null
group by 
jt.ws_call_id
,jt.cloud_party_id
,jt.cloud_party_number
,jt.address_id
,jt.source_address_id
,jt.source_party_id
;

cursor c_rest_find(c_ws_call_id in number) is
select 
jt.ws_call_id
,jt.cloud_party_id
,jt.cloud_party_number
,jt.address_id
,jt.source_address_id
,jt.source_party_id
from
(
select
cloud_party_id
,cloud_party_number
,address_id
,address_type
,source_address_id
,source_party_id
,xx.ws_call_id
from
xxfn_ws_call_log xx,
json_table(xx.response_json,'$'
    columns(
                    cloud_party_id number path '$.PartyId',
                    cloud_party_number varchar2(100) path '$.PartyNumber',
                    address_id number path '$.AddressId',
                    address_type varchar2(30) path '$.AddressType',
                    source_address_id varchar2(240) path '$.SourceSystemReferenceValue',
                    source_party_id number path '$.PartySourceSystemReferenceValue'))
where xx.ws_call_id = c_ws_call_id
union all
select
cloud_party_id
,cloud_party_number
,address_id
,address_type
,source_address_id
,source_party_id
,xx.ws_call_id
from
xxfn_ws_call_log xx,
json_table(xx.response_json, '$'
    columns(nested path '$.items[*]'
                columns(
                    cloud_party_id number path '$.PartyId',
                    cloud_party_number varchar2(100) path '$.PartyNumber',
                    address_id number path '$.AddressId',
                    address_type varchar2(30) path '$.AddressType',
                    source_address_id varchar2(240) path '$.SourceSystemReferenceValue',
                    source_party_id number path '$.PartySourceSystemReferenceValue')))                   
where xx.ws_call_id = c_ws_call_id
) jt
where jt.address_id is not null
group by 
jt.ws_call_id
,jt.cloud_party_id
,jt.cloud_party_number
,jt.address_id
,jt.source_address_id
,jt.source_party_id
;

cursor c_accounts(c_party_id in number) is
   select distinct
    hca.account_number
    ,hca.account_name
    ,hca.customer_type
    ,hca.account_activation_date   
    ,hca.cust_account_id
    ,hca.status
    from
    apps.hz_parties@ebstest hp
    ,apps.hz_party_sites@ebstest hps
    ,apps.hz_cust_accounts@ebstest hca
    ,apps.HZ_CUST_ACCT_SITES_ALL@ebstest HCASA
    ,apps.HZ_CUST_SITE_USES_all@ebstest hcsu
    ,apps.hz_locations@ebstest hl
    where 1=1
    and hp.party_id = hca.party_id(+)
    and hp.party_id = hps.party_id(+)
    and hca.cust_account_id = hcasa.cust_account_id
    and hps.party_site_id = hcasa.party_site_id(+)
    and hcasa.cust_acct_site_id = hcsu.cust_acct_site_id(+)
    and hps.location_id = hl.location_id(+)
    and hcsu.site_use_code is not null
    and hcasa.org_id in (102,531,2068,2288)
    and hp.party_id = c_party_id
    and not exists (select 1 from xxdl_hz_cust_accounts xxhca 
                        where xxhca.cust_account_id = hca.cust_account_id
                        and nvl(xxhca.process_flag,'X') = 'S')
    ;

    
    cursor c_account_sites(c_cust_account_id in number,c_ws_call_id in number) is
   select distinct
    hps.party_site_id
    ,hcsa.cust_acct_site_id
    ,xx_set.reference_data_set_code cloud_set_code
    ,xx_set.reference_data_set_id cloud_set_id
    ,hcsa.org_id
    ,hcsu.primary_flag
    ,hcsa.BILL_TO_FLAG
    ,hcsa.SHIP_TO_FLAG
    ,hcsa.STATUS
    --,hcsu.location
    ,hca.cust_account_id
    ,jt.address_id cloud_address_id
    ,hl.language
    from
    apps.hz_parties@ebstest hp
    ,apps.hz_party_sites@ebstest hps
    ,apps.hz_cust_accounts@ebstest hca
    ,apps.HZ_CUST_ACCT_SITES_ALL@ebstest HCSA
    ,apps.HZ_CUST_SITE_USES_all@ebstest hcsu
    ,apps.hz_locations@ebstest hl
    ,xxdl_cloud_reference_sets xx_set
    ,(
    select
    cloud_party_id
    ,cloud_party_number
    ,address_id
    ,address_type
    ,source_address_id
    ,source_party_id
    ,xx.ws_call_id
    from
    xxfn_ws_call_log xx,
    json_table(xx.response_json,'$'
        columns(
                        cloud_party_id number path '$.PartyId',
                        cloud_party_number varchar2(100) path '$.PartyNumber',
                        address_id number path '$.AddressId',
                        address_type varchar2(30) path '$.AddressType',
                        source_address_id varchar2(240) path '$.SourceSystemReferenceValue',
                        source_party_id number path '$.PartySourceSystemReferenceValue'))
    where xx.ws_call_id = c_ws_call_id
    union all
    select
    cloud_party_id
    ,cloud_party_number
    ,address_id
    ,address_type
    ,source_address_id
    ,source_party_id
    ,xx.ws_call_id
    from
    xxfn_ws_call_log xx,
    json_table(xx.response_json, '$'
        columns(nested path '$.items[*]'
                    columns(
                        cloud_party_id number path '$.PartyId',
                        cloud_party_number varchar2(100) path '$.PartyNumber',
                        address_id number path '$.AddressId',
                        address_type varchar2(30) path '$.AddressType',
                        source_address_id varchar2(240) path '$.SourceSystemReferenceValue',
                        source_party_id number path '$.PartySourceSystemReferenceValue')))                   
    where xx.ws_call_id = c_ws_call_id
    union all
    select
    cloud_party_id
    ,cloud_party_number
    ,address_id
    ,address_type
    ,source_address_id
    ,source_party_id
    ,xx.ws_call_id
    from
    xxfn_ws_call_log xx,
    json_table(xx.response_json, '$'
        columns(nested path '$.Address[*]'
                    columns(
                        cloud_party_id number path '$.PartyId',
                        cloud_party_number varchar2(100) path '$.PartyNumber',
                        address_id number path '$.AddressId',
                        address_type varchar2(30) path '$.AddressType',
                        source_address_id varchar2(240) path '$.SourceSystemReferenceValue',
                        source_party_id number path '$.PartySourceSystemReferenceValue')))                   
    where xx.ws_call_id = c_ws_call_id
    ) jt
    where 1=1
    and hp.party_id = hca.party_id(+)
    and hp.party_id = hps.party_id(+)
    and hca.cust_account_id = hcsa.cust_account_id
    and hps.party_site_id = hcsa.party_site_id(+)
    and hcsa.cust_acct_site_id = hcsu.cust_acct_site_id(+)
    and hps.location_id = hl.location_id(+)
    and hcsu.site_use_code is not null
    and hca.cust_account_id = c_cust_account_id
    and hl.location_id = substr(jt.source_address_id,instr(jt.source_address_id,';',1,1)+1,length(jt.source_address_id))
    and hps.party_site_id = substr(jt.source_address_id,1,instr(jt.source_address_id,';',1,1)-1)
    and hcsa.org_id =  xx_set.ebs_org_id(+)
    and hcsa.org_id in (102,531,2068,2288)
    and jt.ws_call_id = c_ws_call_id
    and not exists (select 1 from XXDL_HZ_CUST_ACCT_SITES xxhca 
                        where xxhca.cust_acct_site_id = hcsa.cust_acct_site_id
                        and nvl(xxhca.process_flag,'X') = 'S')
    ;
    

    cursor c_account_site_use(c_cust_acct_site_id in number,c_ws_call_id in number) is
   select distinct
    hcsu.site_use_id
    ,hcsu.site_use_code
    ,hps.party_site_id
    ,hcsu.BILL_TO_SITE_USE_ID
    ,hcsu.primary_flag
    ,hcsu.location
    ,hcsa.status
    ,hcsu.org_id
    ,xx_set.reference_data_set_id cloud_set_id
    ,jt.address_id cloud_address_id
    ,jt.location_id cloud_location_id
    from
    apps.hz_parties@ebstest hp
    ,apps.hz_party_sites@ebstest hps
    ,apps.hz_cust_accounts@ebstest hca
    ,apps.HZ_CUST_ACCT_SITES_ALL@ebstest HCSA
    ,apps.HZ_CUST_SITE_USES_all@ebstest hcsu
    ,apps.hz_locations@ebstest hl
    ,xxdl_cloud_reference_sets xx_set
    ,(
    select
    cloud_party_id
    ,cloud_party_number
    ,address_id
    ,address_type
    ,source_address_id
    ,source_party_id
    ,location_id
    ,xx.ws_call_id
    from
    xxfn_ws_call_log xx,
    json_table(xx.response_json,'$'
        columns(
                        cloud_party_id number path '$.PartyId',
                        cloud_party_number varchar2(100) path '$.PartyNumber',
                        address_id number path '$.AddressId',
                        address_type varchar2(30) path '$.AddressType',
                        source_address_id varchar2(240) path '$.SourceSystemReferenceValue',
                        source_party_id number path '$.PartySourceSystemReferenceValue',
                        location_id number path '$.LocationId'))
    where xx.ws_call_id = c_ws_call_id
    union all
    select
    cloud_party_id
    ,cloud_party_number
    ,address_id
    ,address_type
    ,source_address_id
    ,source_party_id
    ,location_id
    ,xx.ws_call_id
    from
    xxfn_ws_call_log xx,
    json_table(xx.response_json, '$'
        columns(nested path '$.items[*]'
                    columns(
                        cloud_party_id number path '$.PartyId',
                        cloud_party_number varchar2(100) path '$.PartyNumber',
                        address_id number path '$.AddressId',
                        address_type varchar2(30) path '$.AddressType',
                        source_address_id varchar2(240) path '$.SourceSystemReferenceValue',
                        source_party_id number path '$.PartySourceSystemReferenceValue',
                        location_id number path '$.LocationId')))                   
    where xx.ws_call_id = c_ws_call_id
    union all
    select
    cloud_party_id
    ,cloud_party_number
    ,address_id
    ,address_type
    ,source_address_id
    ,source_party_id
    ,location_id
    ,xx.ws_call_id
    from
    xxfn_ws_call_log xx,
    json_table(xx.response_json, '$'
        columns(nested path '$.Address[*]'
                    columns(
                        cloud_party_id number path '$.PartyId',
                        cloud_party_number varchar2(100) path '$.PartyNumber',
                        address_id number path '$.AddressId',
                        address_type varchar2(30) path '$.AddressType',
                        source_address_id varchar2(240) path '$.SourceSystemReferenceValue',
                        source_party_id number path '$.PartySourceSystemReferenceValue',
                        location_id number path '$.LocationId')))                   
    where xx.ws_call_id = c_ws_call_id
    ) jt
    where 1=1
    and hp.party_id = hca.party_id(+)
    and hp.party_id = hps.party_id(+)
    and hca.cust_account_id = hcsa.cust_account_id
    and hps.party_site_id = hcsa.party_site_id(+)
    and hcsa.cust_acct_site_id = hcsu.cust_acct_site_id(+)
    and hps.location_id = hl.location_id(+)
    and hcsu.site_use_code is not null
    and hcsa.cust_acct_site_id = c_cust_acct_site_id
    and hl.location_id = substr(jt.source_address_id,instr(jt.source_address_id,';',1,1)+1,length(jt.source_address_id))
    and hps.party_site_id = substr(jt.source_address_id,1,instr(jt.source_address_id,';',1,1)-1)
    and hcsa.org_id =  xx_set.ebs_org_id(+)
    and hcsa.org_id in (102,531,2068,2288)
    and jt.ws_call_id = c_ws_call_id
    and not exists (select 1 from XXDL_HZ_CUST_ACCT_SITE_USES xxhca 
                        where xxhca.site_use_id = hcsu.site_use_id
                        and nvl(xxhca.process_flag,'X') = 'S')
    ;


l_party_rec XXDL_HZ_PARTIES%ROWTYPE;
l_party_rec_empty XXDL_HZ_PARTIES%ROWTYPE;
l_loc_rec XXDL_HZ_LOCATIONS%ROWTYPE;
l_loc_rec_empty XXDL_HZ_LOCATIONS%ROWTYPE;
l_cust_acct_rec XXDL_HZ_CUST_ACCOUNTS%ROWTYPE;
l_cust_acct_rec_empty XXDL_HZ_CUST_ACCOUNTS%ROWTYPE;
l_cust_acct_site_rec XXDL_HZ_CUST_ACCT_SITES%ROWTYPE;
l_cust_acct_site_rec_empty XXDL_HZ_CUST_ACCT_SITES%ROWTYPE;
l_cust_acct_site_use_rec XXDL_HZ_CUST_ACCT_SITE_USES%ROWTYPE;
l_cust_acct_site_use_rec_empty XXDL_HZ_CUST_ACCT_SITE_USES%ROWTYPE;


l_rest_env clob;

l_fault_code          varchar2(4000);
l_fault_string        varchar2(4000); 
l_error_message        varchar2(4000); 
l_soap_env clob;
l_empty_clob clob;
l_text varchar2(32000);
l_bill_text varchar2(32000);
x_return_status varchar2(500);
x_return_message varchar2(32000);
xb_return_status varchar2(500);
xb_return_message varchar2(32000);
x_ws_call_id number;
xb_ws_call_id number;
xr_ws_call_id number;
l_cnt number := 0;
l_app_url           varchar2(100);
l_username          varchar2(100);
l_password           varchar2(100);
l_cloud_party_id number;
l_cloud_party_site_id number;
l_cloud_cust_account_id number;
l_cloud_cust_acct_site_id number;
l_cloud_site_use_id number;
l_cloud_set_id number;
l_cloud_address_id number;
l_cloud_bill_use_id number;

l_count_address number := 1;

XX_USER exception;
XX_APP exception;
XX_PASS exception;
begin


log('Starting to import customer:');

l_app_url := get_config('ServiceRootURL');
--l_app_url := get_config('SoapUrl'); --encc
l_username := get_config('ServiceUsername');
l_password := get_config('ServicePassword');

if l_app_url is null then
    raise XX_APP;
end if;

if l_username is null then
    raise XX_USER;
end if;

if l_password is null then
    raise XX_PASS;
end if;

for c_p in c_party loop

    log('   Import customer: '||c_p.party_name);
    log('   Party number: '||c_p.party_number);

    log('   Checking if already exists in cloud!');

    find_customer_cloud(c_p.party_number,l_cloud_party_id,l_cloud_set_id);

    log('   Cloud party id:'||l_cloud_party_id);

    l_party_rec.party_id := c_p.party_id;
    l_party_rec.party_number := c_p.party_number;
    l_party_rec.party_name := c_p.party_name;
    l_party_rec.TAXPAYER_ID := c_p.TAXPAYER_ID;
    l_party_rec.duns_number := c_p.duns_number;
    l_party_rec.PARTY_USAGE_CODE := c_p.PARTY_USAGE_CODE;
    l_party_rec.process_flag := x_return_status;
    l_party_rec.cloud_party_id := l_cloud_party_id;
    l_party_rec.creation_date := sysdate;

    if l_cloud_party_id > 0 then
        
        log('       Party already in cloud!');

        log('       Get address information for party:'||c_p.party_number);

        find_address_cloud(c_p.party_number,xr_ws_call_id);

        begin
          with json_response as
            (
            (
                select
                cloud_party_id
                ,cloud_party_number
                ,address_id
                ,address_type
                ,source_address_id
                ,source_party_id
                from
                xxfn_ws_call_log xx,
                json_table(xx.response_json,'$'
                    columns(
                                    cloud_party_id number path '$.PartyId',
                                    cloud_party_number varchar2(100) path '$.PartyNumber',
                                    address_id number path '$.AddressId',
                                    address_type varchar2(30) path '$.AddressType',
                                    source_address_id varchar2(240) path '$.SourceSystemReferenceValue',
                                    source_party_id number path '$.PartySourceSystemReferenceValue'))
                where xx.ws_call_id = xr_ws_call_id
                union all
                select
                cloud_party_id
                ,cloud_party_number
                ,address_id
                ,address_type
                ,source_address_id
                ,source_party_id
                from
                xxfn_ws_call_log xx,
                json_table(xx.response_json, '$'
                    columns(nested path '$.items[*]'
                                columns(
                                    cloud_party_id number path '$.PartyId',
                                    cloud_party_number varchar2(100) path '$.PartyNumber',
                                    address_id number path '$.AddressId',
                                    address_type varchar2(30) path '$.AddressType',
                                    source_address_id varchar2(240) path '$.SourceSystemReferenceValue',
                                    source_party_id number path '$.PartySourceSystemReferenceValue')))                   
                where xx.ws_call_id = xr_ws_call_id
                )
            )
            select
            nvl(jt.address_id,0)
            into l_cloud_address_id
            from
            json_response jt
            where rownum = 1
            and jt.cloud_party_id is not null;

            exception
              when no_data_found then
                l_cloud_address_id := 0;

        end;

        log('       Cloud address id:'||l_cloud_address_id);

        if l_cloud_address_id = 0 then

            log('       There is no address in cloud for this party!');

            log('       Finding locations:');
            for c_l in c_locations(c_p.party_number) loop
                log('       Found location!');
                log('       Importing location!');

                

                l_text := l_text || '{
                            "Address1": "'||c_l.address1||'",
                            "Address2": "'||c_l.address2||'",
                            "Address3": "'||c_l.address3||'",
                            "Address4": "'||c_l.address4||'",
                            "City": "'||c_l.city||'",
                            "Country": "'||c_l.country||'",
                            "County": "'||c_l.county||'",
                            "PostalCode": "'||c_l.postal_code||'",
                            "PostalPlus4Code": "'||c_l.postal_plus4_code||'",
                            "State": "'||c_l.state||'",
                            "PartySiteName":"'||c_l.party_site_name||'",
                            "SourceSystem": "EBSR11",
                            "SourceSystemReferenceValue": "'||c_l.party_site_id||';'||c_l.location_id||'"
                        }';
 
                l_rest_env := l_rest_env|| to_clob(l_text);
                l_text := '';

                log('   REST payload built!');

                log('   Calling REST web service.');
                log('   Url:'||l_app_url||'crmRestApi/resources/11.13.18.05/hubOrganizations/'||c_p.party_number||'/child/Address');
                XXFN_CLOUD_WS_PKG.WS_REST_CALL(
                p_ws_url => l_app_url||'crmRestApi/resources/11.13.18.05/hubOrganizations/'||c_p.party_number||'/child/Address',
                p_rest_env => l_rest_env,
                p_rest_act => 'POST',
                p_content_type => 'application/json;charset="UTF-8"',
                x_return_status => x_return_status,
                x_return_message => x_return_message,
                x_ws_call_id => x_ws_call_id);

                log('   Web service finished! ws_call_id:'||x_ws_call_id);

                log('   After call XXFN_CLOUD_WS_PKG.WS_REST_CALL');

                dbms_lob.freetemporary(l_rest_env);

                if x_return_status = 'S' then

                    log('       Mapping this address create ws call to cursor!');
                    xr_ws_call_id := x_ws_call_id;

                else

                    log('       Cannot create an address!');
                    x_return_message := get_ws_err_msg(x_ws_call_id);
                    log('     Web service message:'||x_return_message);
                    exit;

                end if;

                l_rest_env := l_empty_clob;
                

                l_count_address:= l_count_address + 1;

            end loop;

             
            


        end if;

        --update_cust_cloud_ref(c_p.party_number,c_p.party_id,xr_ws_call_id);
        log('           Getting addresses again!');
        find_address_cloud(c_p.party_number,xr_ws_call_id);


        log('        Address ws_call_id:'||xr_ws_call_id);


        --find res payload loop
        for c_r in c_rest_find(xr_ws_call_id) loop
              
              log('         First fetching the rest payload!');
              log('         Found cloud party id:'||c_r.cloud_party_id);
              log('         Found cloud party number:'||c_r.cloud_party_number);
              log('         Found cloud address id:'||c_r.address_id);
              log('         Found source party id:'||c_p.party_id||' for finding cust account!');
              
              l_text := '';
            
                for c_a in c_accounts(c_p.party_id) loop
                    log('           Now finding customer accounts!');
                    log('           Customer account number:'||c_a.account_number);
                    log('           Customer account_name:'||c_a.account_name);
                    log('           Account_activation_date:'||c_a.account_activation_date);
                    log('           Customer account_id:'||c_a.cust_account_id);

                    l_cust_acct_rec.party_id := c_p.party_id;
                    l_cust_acct_rec.account_number := c_a.account_number;
                    l_cust_acct_rec.account_name := c_a.account_name;
                    l_cust_acct_rec.cust_account_id := c_a.cust_account_id;
                    l_cust_acct_rec.account_number := c_a.account_number;
                    l_cust_acct_rec.status := c_a.status;
                    l_cust_acct_rec.creation_date := sysdate;

                    begin
                        insert into XXDL_HZ_CUST_ACCOUNTS values l_cust_acct_rec;
                        exception
                          when dup_val_on_index then
                            l_cust_acct_rec.last_update_date := sysdate;
                            update XXDL_HZ_CUST_ACCOUNTS xx
                            set row = l_cust_acct_rec
                            where xx.cust_account_id = c_a.cust_account_id;
                        end;

                    l_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/applicationModule/types/" xmlns:cus="http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/" xmlns:cus1="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountContactRole/" xmlns:par="http://xmlns.oracle.com/apps/cdm/foundation/parties/partyService/" xmlns:sour="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/sourceSystemRef/" xmlns:cus2="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountContact/" xmlns:cus3="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountRel/" xmlns:cus4="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountSiteUse/" xmlns:cus5="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountSite/" xmlns:cus6="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccount/">
                            <soapenv:Header/>
                            <soapenv:Body>
                                <typ:createCustomerAccount>                                    
                                    <typ:customerAccount>
                                        <cus:PartyId>'||c_r.cloud_party_id||'</cus:PartyId>
                                        <cus:AccountName>'||c_a.account_name||'</cus:AccountName>    
                                        <cus:AccountNumber>'||c_a.account_number||'</cus:AccountNumber>
                                        <cus:CustomerType>'||c_a.account_name||'</cus:CustomerType>
                                        <cus:AccountEstablishedDate>'||c_a.account_activation_date||'</cus:AccountEstablishedDate>
                                        <cus:CreatedByModule>HZ_WS</cus:CreatedByModule>
                                        <cus:OrigSystem>EBSR11</cus:OrigSystem>
                                        <cus:OrigSystemReference>'||c_a.cust_account_id||'</cus:OrigSystemReference>';

                    for c_as in c_account_sites(c_a.cust_account_id, xr_ws_call_id) loop
                        log('               Now adding account sites!');
                        log('               Now finding customer accounts!');
                        log('               Customer CUST_ACCT_SITE_ID:'||c_as.CUST_ACCT_SITE_ID);
                        log('               Customer CUST_ACCOUNT_ID:'||c_a.cust_account_id);
                        log('               Customer PARTY_SITE_ID:'||c_as.PARTY_SITE_ID);
                        log('               Customer PRIMARY_FLAG:'||c_as.PRIMARY_FLAG);
                        --log('               Customer LOCATION:'||c_as.LOCATION);
                        log('               Customer set_code:'||c_as.cloud_set_code);
                        log('               Customer set_id:'||c_as.cloud_set_id);

                        l_cust_acct_site_rec.cust_acct_site_id := c_as.cust_acct_site_id;
                        l_cust_acct_site_rec.CUST_ACCOUNT_ID := c_as.CUST_ACCOUNT_ID;
                        l_cust_acct_site_rec.PARTY_SITE_ID := c_as.PARTY_SITE_ID;
                        l_cust_acct_site_rec.BILL_TO_FLAG := c_as.BILL_TO_FLAG;
                        l_cust_acct_site_rec.SHIP_TO_FLAG := c_as.SHIP_TO_FLAG;
                        l_cust_acct_site_rec.STATUS := c_as.STATUS ;
                        l_cust_acct_site_rec.ORG_ID := c_as.ORG_ID;
                        l_cust_acct_site_rec.CLOUD_SET_ID := c_as.CLOUD_SET_ID;
                        l_cust_acct_site_rec.creation_date := sysdate;

                         begin
                            insert into XXDL_HZ_CUST_ACCT_SITES values l_cust_acct_site_rec;
                            exception
                            when dup_val_on_index then
                                l_cust_acct_site_rec.last_update_date := sysdate;
                                update XXDL_HZ_CUST_ACCT_SITES xx
                                set row = l_cust_acct_site_rec
                                where xx.cust_acct_site_id = c_as.cust_acct_site_id;
                            end;

                        l_text := l_text ||'    
                                        <cus:CustomerAccountSite>
                                            <cus:PartySiteId>'||c_as.cloud_address_id||'</cus:PartySiteId>
                                            <cus:CreatedByModule>HZ_WS</cus:CreatedByModule>
                                            <cus:SetId>'||c_as.cloud_set_id||'</cus:SetId>
                                            <cus:StartDate>'||to_char(sysdate,'YYYY-MM-DD')||'</cus:StartDate>
                                            <cus:Language></cus:Language>
                                            <cus:OrigSystem>EBSR11</cus:OrigSystem>
                                            <cus:OrigSystemReference>'||c_as.cust_acct_site_id||'</cus:OrigSystemReference>';

                        for c_asu in c_account_site_use(c_as.cust_acct_site_id,xr_ws_call_id) loop
                            log('                   Now adding account sites use!');
                            log('                   Now finding customer accounts uses!');
                            log('                   Customer CUST_ACCT_SITE_ID:'||c_as.CUST_ACCT_SITE_ID);
                            log('                   Customer SITE_USE_ID:'||c_asu.SITE_USE_ID);
                            log('                   Customer PARTY_SITE_ID:'||c_asu.PARTY_SITE_ID);
                            log('                   Customer BILL_TO_SITE_USE_ID:'||c_asu.BILL_TO_SITE_USE_ID);
                            log('                   Customer SITE_USE_CODE:'||c_asu.SITE_USE_CODE);
                            log('                   Customer PRIMARY_FLAG:'||c_asu.PRIMARY_FLAG);
                            log('                   Customer LOCATION:'||c_asu.LOCATION);
                            log('                   Customer STATUS:'||c_asu.STATUS  );
                            log('                   Customer ORG_ID:'||c_asu.ORG_ID);
                            log('                   Customer CLOUD_SET_ID:'||c_asu.CLOUD_SET_ID);
                            l_cust_acct_site_use_rec:=l_cust_acct_site_use_rec_empty;

                            l_cust_acct_site_use_rec.cust_acct_site_id := c_as.cust_acct_site_id;
                            l_cust_acct_site_use_rec.site_use_id := c_asu.site_use_id;
                            l_cust_acct_site_use_rec.party_site_id := c_asu.party_site_id;
                            l_cust_acct_site_use_rec.BILL_TO_SITE_USE_ID := c_asu.BILL_TO_SITE_USE_ID;
                            l_cust_acct_site_use_rec.PRIMARY_FLAG := c_asu.PRIMARY_FLAG;
                            l_cust_acct_site_use_rec.SITE_USE_CODE := c_asu.SITE_USE_CODE;
                            l_cust_acct_site_use_rec.LOCATION := c_asu.LOCATION;
                            l_cust_acct_site_use_rec.ORG_ID := c_asu.ORG_ID;
                            l_cust_acct_site_use_rec.CLOUD_SET_ID := c_asu.CLOUD_SET_ID;
                            l_cust_acct_site_use_rec.creation_date := sysdate;

                            begin
                            log('                   inserting SITE_USE_ID:'||l_cust_acct_site_use_rec.SITE_USE_ID);
                          
                              insert into XXDL_HZ_CUST_ACCT_SITE_USES values l_cust_acct_site_use_rec;
                            exception
                              when dup_val_on_index then
                                  update XXDL_HZ_CUST_ACCT_SITE_USES xx
                                  SET row = l_cust_acct_site_use_rec
                                  where xx.site_use_id = c_asu.site_use_id;
                                    log('                    SITE_USE_ID već postoji u logu:'||l_cust_acct_site_use_rec.SITE_USE_ID);
                            end;        

                            l_text := l_text ||'  
                                            <cus:CustomerAccountSiteUse>
                                                    <cus:SiteUseCode>'||c_asu.site_use_code||'</cus:SiteUseCode>
                                                    <cus:Location>'||c_asu.cloud_location_id||'</cus:Location>
                                                    <cus:CreatedByModule>HZ_WS</cus:CreatedByModule>
                                                    <cus:OrigSystem>EBSR11</cus:OrigSystem>
                                                    <cus:OrigSystemReference>'||c_asu.site_use_id||'</cus:OrigSystemReference>
                                                                    </cus:CustomerAccountSiteUse>';


                        end loop;

                        l_text := l_text || '
                                            </cus:CustomerAccountSite>
                       '; 
                    end loop;       
                    l_text := l_text || '</typ:customerAccount>
                                ';
        
                end loop;

                l_text := l_text || '</typ:createCustomerAccount>
                                </soapenv:Body>
                                </soapenv:Envelope>';
                l_soap_env := l_empty_clob;
                l_soap_env := l_soap_env || to_clob(l_text);
                l_text := '';

                log('   Soap envelope ready!');

                log('   Calling webservice!');
                log('   Url:'||l_app_url||'crmService/CustomerAccountService?WSDL');

                XXFN_CLOUD_WS_PKG.WS_CALL(
                p_ws_url => l_app_url||'crmService/CustomerAccountService?WSDL',
                p_soap_env => l_soap_env,
                p_soap_act => 'createCustomerAccount',
                p_content_type => 'text/xml;charset="UTF-8"',
                x_return_status => x_return_status,
                x_return_message => x_return_message,
                x_ws_call_id => x_ws_call_id);

                log('   Web service finished! ws_call_id:'||x_ws_call_id);

                log('   After call XXFN_CLOUD_WS_PKG.WS_CALL');

                dbms_lob.freetemporary(l_soap_env);

                if x_return_status = 'S' then

                    log('   Customer account created!');
                    

                    --account loop
                    for c_r in (select
                                x_acc.party_id
                                ,x_acc.cust_account_id
                                ,x_acc.account_number
                                ,x_acc.source_account_id
                                from
                                xxfn_ws_call_log xx
                                ,xmltable(
                                    xmlnamespaces('http://schemas.xmlsoap.org/soap/envelope/' as "env"
                                    ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/applicationModule/types/' as "ns0"
                                    ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/' as "ns2"),
                                    '/env:Envelope/env:Body/ns0:createCustomerAccountResponse/ns0:result/ns2:Value' passing xx.response_xml columns
                                    party_id number path './ns2:PartyId'
                                    ,cust_account_id number path './ns2:CustomerAccountId'
                                    ,account_number number path './ns2:AccountNumber'
                                    ,source_account_id number path './ns2:OrigSystemReference') x_acc                               
                                where xx.ws_call_id = x_ws_call_id
                                ) loop

                        log('       Customer account is being stored in log!');                        

                    
                        update XXDL_HZ_CUST_ACCOUNTS xx
                        set xx.CLOUD_CUST_ACCOUNT_ID = c_r.cust_account_id
                        ,xx.CLOUD_PARTY_ID = c_r.party_id
                        ,xx.process_flag = x_return_status
                        ,xx.last_update_date = sysdate
                        where xx.cust_account_id = c_r.source_account_id;

                        
                        --account site loop
                        for c_as in (select
                                x_acc_site.cust_acct_site_id
                                ,x_acc_site.party_site_id
                                ,x_acc_site.source_cust_acct_site_id
                                ,x_acc_site.cust_account_id
                                from
                                xxfn_ws_call_log xx
                                ,xmltable(
                                    xmlnamespaces('http://schemas.xmlsoap.org/soap/envelope/' as "env"
                                    ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/applicationModule/types/' as "ns0"
                                    ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/' as "ns2"),
                                    '/env:Envelope/env:Body/ns0:createCustomerAccountResponse/ns0:result/ns2:Value/ns2:CustomerAccountSite' passing xx.response_xml columns
                                    party_site_id number path './ns2:PartySiteId'
                                    ,cust_account_id number path './ns2:CustomerAccountId'                                    
                                    ,cust_acct_site_id number path './ns2:CustomerAccountSiteId'
                                    ,source_cust_acct_site_id number path './ns2:OrigSystemReference') x_acc_site                                
                                where xx.ws_call_id = x_ws_call_id
                                and x_acc_site.cust_account_id = c_r.cust_account_id
                                ) loop
                            
                            log('       Customer account site is being stored in log!');               
                                                        
                            update XXDL_HZ_CUST_ACCT_SITES xx
                            set xx.process_flag = x_return_status            
                            ,xx.cloud_party_site_id = c_as.party_site_id
                            ,xx.cloud_cust_acct_site_id = c_as.cust_acct_site_id
                            ,xx.CLOUD_CUST_ACCOUNT_ID = c_as.cust_account_id  
                            where xx.cust_acct_site_id = c_as.source_cust_acct_site_id;                              

                                                             
                            --account site use loop
                            for c_asu in (select                               
                                    x_site_use.cust_acct_site_id
                                    ,x_site_use.cust_acct_site_use_id
                                    ,x_site_use.site_use_code
                                    ,x_site_use.set_id
                                    ,x_site_use.bill_site_to_use_id
                                    ,x_site_use.source_acct_site_use_id
                                    from
                                    xxfn_ws_call_log xx
                                    ,xmltable(
                                        xmlnamespaces('http://schemas.xmlsoap.org/soap/envelope/' as "env"
                                        ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/applicationModule/types/' as "ns0"
                                        ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/' as "ns2"),
                                        '/env:Envelope/env:Body/ns0:createCustomerAccountResponse/ns0:result/ns2:Value/ns2:CustomerAccountSite/ns2:CustomerAccountSiteUse' passing xx.response_xml columns
                                        cust_acct_site_id number path './ns2:CustomerAccountSiteId'
                                        ,cust_acct_site_use_id number path './ns2:SiteUseId'
                                        ,site_use_code varchar2(30) path './ns2:SiteUseCode'
                                        ,set_id number path './ns2:SetId'
                                        ,bill_site_to_use_id number path './ns2:BillToSiteUseId'
                                        ,source_acct_site_use_id number path './ns2:OrigSystemReference') x_site_use
                                    where xx.ws_call_id = x_ws_call_id
                                    and x_site_use.cust_acct_site_id = c_as.cust_acct_site_id
                                    ) loop
                        
                                log('           Customer account site use is being stored in log!');           
                                log('           For account site use:'||c_asu.source_acct_site_use_id||' cloud id is:'||c_asu.cust_acct_site_use_id);           

                                update XXDL_HZ_CUST_ACCT_SITE_USES xx
                                set xx.CLOUD_SITE_USE_ID = c_asu.cust_acct_site_use_id
                                ,xx.CLOUD_CUST_ACCT_SITE_ID= c_asu.cust_acct_site_id
                                ,xx.CLOUD_PARTY_SITE_ID= c_as.party_site_id
                                ,xx.CLOUD_SET_ID= c_asu.set_id
                                ,xx.CLOUD_BILL_TO_SITE_USE_ID= c_asu.bill_site_to_use_id
                                ,xx.process_flag = 'S'
                                where xx.site_use_id = c_asu.source_acct_site_use_id;

                                --start ship_to bill_to mapping
                                if c_asu.site_use_code = 'SHIP_TO' and c_asu.bill_site_to_use_id is null then
                                
                                    log('               Found SHIP_TO site use! Need to update bill_to_site_use_id!');  
                                    l_cloud_bill_use_id := null;                     

                                    log('               Searching BILL_TO for acct site id:'||c_asu.cust_acct_site_id);

                                    begin
                                    select x_site_use.cust_acct_site_use_id into l_cloud_bill_use_id
                                            from
                                            xxfn_ws_call_log xx
                                            ,xmltable(
                                                xmlnamespaces('http://schemas.xmlsoap.org/soap/envelope/' as "env"
                                                ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/applicationModule/types/' as "ns0"
                                                ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/' as "ns2"),
                                                '/env:Envelope/env:Body/ns0:createCustomerAccountResponse/ns0:result/ns2:Value/ns2:CustomerAccountSite/ns2:CustomerAccountSiteUse' passing xx.response_xml columns
                                                cust_acct_site_id number path './ns2:CustomerAccountSiteId'
                                                ,cust_acct_site_use_id number path './ns2:SiteUseId'
                                                ,site_use_code varchar2(30) path './ns2:SiteUseCode'
                                                ,set_id number path './ns2:SetId'
                                                ,bill_site_to_use_id number path './ns2:BillToSiteUseId'
                                                ,source_acct_site_use_id number path './ns2:OrigSystemReference') x_site_use
                                            where xx.ws_call_id = x_ws_call_id
                                            and x_site_use.cust_acct_site_id = c_asu.cust_acct_site_id
                                            and x_site_use.site_use_code = 'BILL_TO';
                                    exception
                                    when no_data_found then
                                        l_cloud_bill_use_id := null;
                                    end;        
                            
                                    log('               Bill to site use id:'||l_cloud_bill_use_id);                        
                    
                                    --start bill_use_id update
                                    if nvl(l_cloud_bill_use_id,0) != 0 then

                                        log('                   Preparing to call SOAP to update bill to use id!');
                                        l_soap_env := l_empty_clob;

                                        l_bill_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                                                    xmlns:typ="http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/applicationModule/types/"
                                                    xmlns:cus="http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/"
                                                    xmlns:cus1="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountContactRole/"
                                                    xmlns:par="http://xmlns.oracle.com/apps/cdm/foundation/parties/partyService/"
                                                    xmlns:sour="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/sourceSystemRef/"
                                                    xmlns:cus2="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountContact/"
                                                    xmlns:cus3="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountRel/"
                                                    xmlns:cus4="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountSiteUse/"
                                                    xmlns:cus5="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountSite/"
                                                    xmlns:cus6="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccount/">
                                                    <soapenv:Header/>
                                                    <soapenv:Body>
                                                        <typ:updateCustomerAccount>
                                                            <typ:customerAccount>
                                                                <cus:CustomerAccountId>'||c_r.cust_account_id||'</cus:CustomerAccountId>
                                                                <cus:PartyId>'||c_r.party_id||'</cus:PartyId>
                                                                <cus:AccountNumber>'||c_r.account_number||'</cus:AccountNumber>
                                                                <cus:CustomerAccountSite>
                                                                    <cus:CustomerAccountSiteId>'||c_as.cust_acct_site_id||'</cus:CustomerAccountSiteId>
                                                                    <cus:CustomerAccountId>'||c_as.cust_account_id||'</cus:CustomerAccountId>
                                                                    <cus:PartySiteId>'||c_as.party_site_id||'</cus:PartySiteId>
                                                                    <cus:CustomerAccountSiteUse>
                                                                        <cus:SiteUseId>'||c_asu.cust_acct_site_use_id||'</cus:SiteUseId>
                                                                        <cus:CustomerAccountSiteId>'||c_asu.cust_acct_site_id||'</cus:CustomerAccountSiteId>
                                                                        <cus:SiteUseCode>SHIP_TO</cus:SiteUseCode>
                                                                        <cus:BillToSiteUseId>'||l_cloud_bill_use_id||'</cus:BillToSiteUseId>
                                                                        <cus:SetId>'||c_asu.set_id||'</cus:SetId>
                                                                    </cus:CustomerAccountSiteUse>

                                                                </cus:CustomerAccountSite>
                                                            </typ:customerAccount>
                                                        </typ:updateCustomerAccount>
                                                    </soapenv:Body>
                                                </soapenv:Envelope>';

                                        log('                       Soap envelope for bill to use is built!');

                                        
                                        l_soap_env := l_empty_clob;
                                        l_soap_env := l_soap_env || to_clob(l_bill_text);

                                        XXFN_CLOUD_WS_PKG.WS_CALL(
                                        p_ws_url => l_app_url||'crmService/CustomerAccountService?WSDL',
                                        p_soap_env => l_soap_env,
                                        p_soap_act => 'createCustomerAccount',
                                        p_content_type => 'text/xml;charset="UTF-8"',
                                        x_return_status => xb_return_status,
                                        x_return_message => xb_return_message,
                                        x_ws_call_id => xb_ws_call_id);

                                        log('                           Web service finished! ws_call_id:'||xb_ws_call_id);  
                                        dbms_lob.freetemporary(l_soap_env);

                                        

                                        if xb_return_status = 'S' then

                                            log('                       Bill to site use id migrated!');

                                            begin
                                            select x_site_use.bill_site_to_use_id into l_cloud_bill_use_id
                                                    from
                                                    xxfn_ws_call_log xx
                                                    ,xmltable(
                                                        xmlnamespaces('http://schemas.xmlsoap.org/soap/envelope/' as "env"
                                                        ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/applicationModule/types/' as "ns0"
                                                        ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/' as "ns2"),
                                                        '/env:Envelope/env:Body/ns0:updateCustomerAccountResponse/ns0:result/ns2:Value/ns2:CustomerAccountSite/ns2:CustomerAccountSiteUse' passing xx.response_xml columns
                                                        cust_acct_site_id number path './ns2:CustomerAccountSiteId'
                                                        ,cust_acct_site_use_id number path './ns2:SiteUseId'
                                                        ,site_use_code varchar2(30) path './ns2:SiteUseCode'
                                                        ,set_id number path './ns2:SetId'
                                                        ,bill_site_to_use_id number path './ns2:BillToSiteUseId'
                                                        ,source_acct_site_use_id number path './ns2:OrigSystemReference') x_site_use
                                                    where xx.ws_call_id = xb_ws_call_id
                                                    and x_site_use.cust_acct_site_id = c_asu.cust_acct_site_id
                                                    and x_site_use.site_use_code = 'SHIP_TO';
                                            exception
                                            when no_data_found then
                                                l_cloud_bill_use_id := null;
                                            end;    

                                            log('                       Bill to site use id:'||l_cloud_bill_use_id);

                                            update XXDL_HZ_CUST_ACCT_SITE_USES xx
                                            set xx.CLOUD_BILL_TO_SITE_USE_ID = l_cloud_bill_use_id
                                            ,xx.process_flag = 'S'
                                            where xx.cloud_site_use_id = c_asu.cust_acct_site_use_id;    

                                        else

                                            log('                       Bill to site use id not migrated!');

                                            BEGIN
                                                SELECT
                                                    xt.faultcode,
                                                    xt.faultstring
                                                INTO
                                                    l_fault_code,
                                                    l_fault_string
                                                FROM
                                                    xxfn_ws_call_log x,
                                                    XMLTABLE ( XMLNAMESPACES ( 'http://schemas.xmlsoap.org/soap/envelope/' AS "env" ), './/env:Fault' PASSING x.response_xml COLUMNS
                                                    faultcode VARCHAR2(4000) PATH '.', faultstring VARCHAR2(4000) PATH '.' ) xt
                                                WHERE
                                                    x.ws_call_id = xb_ws_call_id;

                                            EXCEPTION
                                                WHEN no_data_found THEN
                                                    BEGIN
                                                        SELECT
                                                            nvl(x.response_status_code, 'ERROR'),
                                                            x.response_reason_phrase
                                                        INTO
                                                            l_fault_code,
                                                            l_fault_string
                                                        FROM
                                                            xxfn_ws_call_log x
                                                        WHERE
                                                            x.ws_call_id = xb_ws_call_id;

                                                    EXCEPTION
                                                        WHEN OTHERS THEN
                                                            l_cust_acct_site_use_rec.error_msg := 'Cannot find env:Fault in ws call results.';
                                                    END;
                                            END;             

                                            if l_fault_code is not null or l_fault_string is not null then
                                                l_error_message := substr( '   Greska => Code:'||l_fault_code||' Text:'||l_fault_string,1,1000);        
                                            end if;
                                            log('   '||l_error_message);

                                            update XXDL_HZ_CUST_ACCT_SITE_USES xx
                                            set xx.ERROR_MSG = l_error_message
                                            ,xx.process_flag = 'E'
                                            where xx.cloud_site_use_id = c_asu.cust_acct_site_use_id;   

                                        end if;

                                    end if;
                                    --end bill_use_id update

                                end if;
                                --end ship_to bill_to mapping    

                            end loop;    
                            --end account site use loop

                        end loop;
                        --end account site loop         

                    end loop;    
                    --end account loop                                  
                else

                    log('           Customer account not migrated!');

                    BEGIN
                        SELECT
                            xt.faultcode,
                            xt.faultstring
                        INTO
                           l_fault_code,
                            l_fault_string
                        FROM
                        xxfn_ws_call_log x,
                        XMLTABLE ( XMLNAMESPACES ( 'http://schemas.xmlsoap.org/soap/envelope/' AS "env" ), './/env:Fault' PASSING x.response_xml COLUMNS
                        faultcode VARCHAR2(4000) PATH '.', faultstring VARCHAR2(4000) PATH '.' ) xt
                        WHERE
                            x.ws_call_id = x_ws_call_id;

                    EXCEPTION
                        WHEN no_data_found THEN
                            BEGIN
                                SELECT
                                    nvl(x.response_status_code, 'ERROR'),
                                    x.response_reason_phrase
                                INTO
                                    l_fault_code,
                                    l_fault_string
                                FROM
                                    xxfn_ws_call_log x
                                WHERE
                                    x.ws_call_id = x_ws_call_id;
                           EXCEPTION
                                WHEN OTHERS THEN
                                    l_cust_acct_rec.error_msg := 'Cannot find env:Fault in ws call results.';
                            END;
                    END;             

                     if l_fault_code is not null or l_fault_string is not null then
                         l_error_message := substr( '   Greska => Code:'||l_fault_code||' Text:'||l_fault_string,1,1000);        
                     end if;
                     log('   '||l_error_message);

                     update XXDL_HZ_CUST_ACCOUNTS xx
                     set xx.ERROR_MSG = l_error_message
                     ,xx.process_flag = 'E'
                     where xx.cust_account_id = l_cust_acct_rec.cust_account_id;                    
                                       
                  
                end if;


            end loop;
            --end find rest payload loop
        
        
    end if;

    if l_cloud_party_id = 0 then
        log('   Creating customer!');
        log('   Building REST paylod!');
        l_text := '{
                    "PartyNumber": "'||c_p.party_number||'",
                    "TaxpayerIdentificationNumber":"'||c_p.TAXPAYER_ID||'",
                    "SourceSystemReference": [
                        {
                            "SourceSystem": "EBSR11",
                            "SourceSystemReferenceValue": "'||c_p.party_id||'"
                        }
                    ],
                    "OrganizationName": "'||c_p.party_name||'",
                    "PartyUsageCode": "'||c_p.party_usage_code||'",
                    "DUNSNumber": "'||c_p.duns_number||'",
                    "Address": [
                    ';

        
        for c_l in c_locations(p_party_number) loop
            log('       Found location!');
            log('       Importing location!');

            l_text := l_text || '{
                        "Address1": "'||c_l.address1||'",
                        "Address2": "'||c_l.address2||'",
                        "Address3": "'||c_l.address3||'",
                        "Address4": "'||c_l.address4||'",
                        "City": "'||c_l.city||'",
                        "Country": "'||c_l.country||'",
                        "County": "'||c_l.county||'",
                        "PostalCode": "'||c_l.postal_code||'",
                        "PostalPlus4Code": "'||c_l.postal_plus4_code||'",
                        "State": "'||c_l.state||'",
                        "PartySiteName":"'||c_l.party_site_name||'",
                        "SourceSystem": "EBSR11",
                        "SourceSystemReferenceValue": "'||c_l.party_site_id||';'||c_l.location_id||'"
                    }';
            if c_l.c > 0 then
            l_text := l_text ||',';
            end if;
            

            l_count_address:= l_count_address + 1;

        end loop;


        l_text := l_text || ']}';

        --log('   Rest payload:');
        --log(l_text);

        l_rest_env := l_soap_env|| to_clob(l_text);
        l_text := '';

        log('   REST payload built!');

        log('   Calling REST web service.');
        log('   Url:'||l_app_url||'crmRestApi/resources/11.13.18.05/hubOrganizations');
        XXFN_CLOUD_WS_PKG.WS_REST_CALL(
        p_ws_url => l_app_url||'crmRestApi/resources/11.13.18.05/hubOrganizations',
        p_rest_env => l_rest_env,
        p_rest_act => 'POST',
        p_content_type => 'application/json;charset="UTF-8"',
        x_return_status => x_return_status,
        x_return_message => x_return_message,
        x_ws_call_id => x_ws_call_id);

        log('   Web service finished! ws_call_id:'||x_ws_call_id);

        log('   After call XXFN_CLOUD_WS_PKG.WS_REST_CALL');

        dbms_lob.freetemporary(l_rest_env);


       --log(l_text);
       --dbms_lob.freetemporary(l_soap_env);
        log('   ws_call_id:'||x_ws_call_id);

        if x_return_status = 'S' then

            log('   Customer migrated!');
            l_party_rec.process_flag := x_return_status;

            
            BEGIN
 
            with json_response AS
            (select treat(xx.response_clob as JSON) json_data
            from xxfn_ws_call_log xx
            where xx.ws_call_id = x_ws_call_id)
            select
            jr.json_data.PartyId
            into l_cloud_party_id
            from
            json_response jr;                   

            EXCEPTION
                WHEN no_data_found THEN
                    l_party_rec.cloud_party_id := null;
            END;             

            log('       Now we need to migrate customer account and sites');
                
            --rest payload loop    
            for c_r in c_rest(x_ws_call_id) loop
              
              log('         First fetching the rest payload!');
              log('         Found cloud party id:'||c_r.cloud_party_id);
              log('         Found cloud party number:'||c_r.cloud_party_number);
              log('         Found cloud address id:'||c_r.address_id);
              
              l_text := '';
            
                for c_a in c_accounts(c_r.source_party_id) loop
                    log('           Now finding customer accounts!');
                    log('           Customer account number:'||c_a.account_number);
                    log('           Customer account_name:'||c_a.account_name);
                    log('           Account_activation_date:'||c_a.account_activation_date);
                    log('           Customer account_id:'||c_a.cust_account_id);

                    l_cust_acct_rec.party_id := c_r.source_party_id;
                    l_cust_acct_rec.account_number := c_a.account_number;
                    l_cust_acct_rec.account_name := c_a.account_name;
                    l_cust_acct_rec.cust_account_id := c_a.cust_account_id;
                    l_cust_acct_rec.account_number := c_a.account_number;
                    l_cust_acct_rec.status := c_a.status;
                    l_cust_acct_rec.creation_date := sysdate;

                    begin
                        insert into XXDL_HZ_CUST_ACCOUNTS values l_cust_acct_rec;
                        exception
                          when dup_val_on_index then
                            l_cust_acct_rec.last_update_date := sysdate;
                            update XXDL_HZ_CUST_ACCOUNTS xx
                            set row = l_cust_acct_rec
                            where xx.cust_account_id = c_a.cust_account_id;
                        end;

                    l_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/applicationModule/types/" xmlns:cus="http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/" xmlns:cus1="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountContactRole/" xmlns:par="http://xmlns.oracle.com/apps/cdm/foundation/parties/partyService/" xmlns:sour="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/sourceSystemRef/" xmlns:cus2="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountContact/" xmlns:cus3="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountRel/" xmlns:cus4="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountSiteUse/" xmlns:cus5="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountSite/" xmlns:cus6="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccount/">
                            <soapenv:Header/>
                            <soapenv:Body>
                                <typ:createCustomerAccount>                                    
                                    <typ:customerAccount>
                                        <cus:PartyId>'||c_r.cloud_party_id||'</cus:PartyId>
                                        <cus:AccountName>'||c_a.account_name||'</cus:AccountName>    
                                        <cus:AccountNumber>'||c_a.account_number||'</cus:AccountNumber>
                                        <cus:CustomerType>'||c_a.account_name||'</cus:CustomerType>
                                        <cus:AccountEstablishedDate>'||c_a.account_activation_date||'</cus:AccountEstablishedDate>
                                        <cus:CreatedByModule>HZ_WS</cus:CreatedByModule>
                                        <cus:OrigSystem>EBSR11</cus:OrigSystem>
                                        <cus:OrigSystemReference>'||c_a.cust_account_id||'</cus:OrigSystemReference>';

                    for c_as in c_account_sites(c_a.cust_account_id, x_ws_call_id) loop
                        log('               Now adding account sites!');
                        log('               Now finding customer accounts!');
                        log('               Customer CUST_ACCT_SITE_ID:'||c_as.CUST_ACCT_SITE_ID);
                        log('               Customer CUST_ACCOUNT_ID:'||c_a.cust_account_id);
                        log('               Customer PARTY_SITE_ID:'||c_as.PARTY_SITE_ID);
                        log('               Customer PRIMARY_FLAG:'||c_as.PRIMARY_FLAG);
                        --log('               Customer LOCATION:'||c_as.LOCATION);
                        log('               Customer set_code:'||c_as.cloud_set_code);
                        log('               Customer set_id:'||c_as.cloud_set_id);

                        l_cust_acct_site_rec.cust_acct_site_id := c_as.cust_acct_site_id;
                        l_cust_acct_site_rec.CUST_ACCOUNT_ID := c_as.CUST_ACCOUNT_ID;
                        l_cust_acct_site_rec.PARTY_SITE_ID := c_as.PARTY_SITE_ID;
                        l_cust_acct_site_rec.BILL_TO_FLAG := c_as.BILL_TO_FLAG;
                        l_cust_acct_site_rec.SHIP_TO_FLAG := c_as.SHIP_TO_FLAG;
                        l_cust_acct_site_rec.STATUS := c_as.STATUS ;
                        l_cust_acct_site_rec.ORG_ID := c_as.ORG_ID;
                        l_cust_acct_site_rec.CLOUD_SET_ID := c_as.CLOUD_SET_ID;
                        l_cust_acct_site_rec.creation_date := sysdate;

                         begin
                            insert into XXDL_HZ_CUST_ACCT_SITES values l_cust_acct_site_rec;
                            exception
                            when dup_val_on_index then
                                l_cust_acct_site_rec.last_update_date := sysdate;
                                update XXDL_HZ_CUST_ACCT_SITES xx
                                set row = l_cust_acct_site_rec
                                where xx.cust_acct_site_id = c_as.cust_acct_site_id;
                            end;

                        l_text := l_text ||'    
                                        <cus:CustomerAccountSite>
                                            <cus:PartySiteId>'||c_as.cloud_address_id||'</cus:PartySiteId>
                                            <cus:CreatedByModule>HZ_WS</cus:CreatedByModule>
                                            <cus:SetId>'||c_as.cloud_set_id||'</cus:SetId>
                                            <cus:StartDate>'||to_char(sysdate,'YYYY-MM-DD')||'</cus:StartDate>
                                            <cus:OrigSystem>EBSR11</cus:OrigSystem>
                                            <cus:OrigSystemReference>'||c_as.cust_acct_site_id||'</cus:OrigSystemReference>';

                        for c_asu in c_account_site_use(c_as.cust_acct_site_id,x_ws_call_id) loop
                            log('                   Now adding account sites use!');
                            log('                   Now finding customer accounts uses!');
                            log('                   Customer CUST_ACCT_SITE_ID:'||c_as.CUST_ACCT_SITE_ID);
                            log('                   Customer SITE_USE_ID:'||c_asu.SITE_USE_ID);
                            log('                   Customer PARTY_SITE_ID:'||c_asu.PARTY_SITE_ID);
                            log('                   Customer BILL_TO_SITE_USE_ID:'||c_asu.BILL_TO_SITE_USE_ID);
                            log('                   Customer SITE_USE_CODE:'||c_asu.SITE_USE_CODE);
                            log('                   Customer PRIMARY_FLAG:'||c_asu.PRIMARY_FLAG);
                            log('                   Customer LOCATION:'||c_asu.LOCATION);
                            log('                   Customer STATUS:'||c_asu.STATUS  );
                            log('                   Customer ORG_ID:'||c_asu.ORG_ID);
                            log('                   Customer CLOUD_SET_ID:'||c_asu.CLOUD_SET_ID);
                            l_cust_acct_site_use_rec:=l_cust_acct_site_use_rec_empty;

                            l_cust_acct_site_use_rec.cust_acct_site_id := c_as.cust_acct_site_id;
                            l_cust_acct_site_use_rec.site_use_id := c_asu.site_use_id;
                            l_cust_acct_site_use_rec.party_site_id := c_asu.party_site_id;
                            l_cust_acct_site_use_rec.BILL_TO_SITE_USE_ID := c_asu.BILL_TO_SITE_USE_ID;
                            l_cust_acct_site_use_rec.PRIMARY_FLAG := c_asu.PRIMARY_FLAG;
                            l_cust_acct_site_use_rec.SITE_USE_CODE := c_asu.SITE_USE_CODE;
                            l_cust_acct_site_use_rec.LOCATION := c_asu.LOCATION;
                            l_cust_acct_site_use_rec.ORG_ID := c_asu.ORG_ID;
                            l_cust_acct_site_use_rec.CLOUD_SET_ID := c_asu.CLOUD_SET_ID;
                            l_cust_acct_site_use_rec.creation_date := sysdate;

                            begin
                            log('                   inserting SITE_USE_ID:'||l_cust_acct_site_use_rec.SITE_USE_ID);
                          
                              insert into XXDL_HZ_CUST_ACCT_SITE_USES values l_cust_acct_site_use_rec;
                            exception
                              when dup_val_on_index then
                                  update XXDL_HZ_CUST_ACCT_SITE_USES xx
                                  SET row = l_cust_acct_site_use_rec
                                  where xx.site_use_id = c_asu.site_use_id;
                                    log('                    SITE_USE_ID već postoji u logu:'||l_cust_acct_site_use_rec.SITE_USE_ID);
                            end;        
                            --primary_flag stavljeno na Yes jer se inače ne vidi u OM
                            l_text := l_text ||'  
                                            <cus:CustomerAccountSiteUse>
                                                    <cus:SiteUseCode>'||c_asu.site_use_code||'</cus:SiteUseCode>
                                                    <cus:Location>'||c_asu.cloud_location_id||'</cus:Location>
                                                    <cus:CreatedByModule>HZ_WS</cus:CreatedByModule>
                                                    <cus:OrigSystem>EBSR11</cus:OrigSystem>
                                                    <cus:PrimaryFlag>EBSR11</cus:PrimaryFlag>                                                    
                                                    <cus:OrigSystemReference>'||c_asu.site_use_id||'</cus:OrigSystemReference>
                                                                    </cus:CustomerAccountSiteUse>';


                        end loop;

                        l_text := l_text || '
                                            </cus:CustomerAccountSite>
                       '; 
                    end loop;       
                    l_text := l_text || '</typ:customerAccount>
                                ';
        
                end loop;

                l_text := l_text || '</typ:createCustomerAccount>
                                </soapenv:Body>
                                </soapenv:Envelope>';
                l_soap_env := l_empty_clob;
                l_soap_env := l_soap_env || to_clob(l_text);
                l_text := '';

                log('   Soap envelope ready!');

                log('   Calling webservice!');
                log('   Url:'||l_app_url||'crmService/CustomerAccountService?WSDL');

                XXFN_CLOUD_WS_PKG.WS_CALL(
                p_ws_url => l_app_url||'crmService/CustomerAccountService?WSDL',
                p_soap_env => l_soap_env,
                p_soap_act => 'createCustomerAccount',
                p_content_type => 'text/xml;charset="UTF-8"',
                x_return_status => x_return_status,
                x_return_message => x_return_message,
                x_ws_call_id => x_ws_call_id);

                log('   Web service finished! ws_call_id:'||x_ws_call_id);

                log('   After call XXFN_CLOUD_WS_PKG.WS_CALL');

                dbms_lob.freetemporary(l_soap_env);

                if x_return_status = 'S' then

                    log('   Customer account created!');
                    

                    --account loop
                    for c_r in (select
                                x_acc.party_id
                                ,x_acc.cust_account_id
                                ,x_acc.account_number
                                ,x_acc.source_account_id
                                from
                                xxfn_ws_call_log xx
                                ,xmltable(
                                    xmlnamespaces('http://schemas.xmlsoap.org/soap/envelope/' as "env"
                                    ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/applicationModule/types/' as "ns0"
                                    ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/' as "ns2"),
                                    '/env:Envelope/env:Body/ns0:createCustomerAccountResponse/ns0:result/ns2:Value' passing xx.response_xml columns
                                    party_id number path './ns2:PartyId'
                                    ,cust_account_id number path './ns2:CustomerAccountId'
                                    ,account_number number path './ns2:AccountNumber'
                                    ,source_account_id number path './ns2:OrigSystemReference') x_acc                               
                                where xx.ws_call_id = x_ws_call_id
                                ) loop

                        log('       Customer account is being stored in log!');                        

                    
                        update XXDL_HZ_CUST_ACCOUNTS xx
                        set xx.CLOUD_CUST_ACCOUNT_ID = c_r.cust_account_id
                        ,xx.CLOUD_PARTY_ID = c_r.party_id
                        ,xx.process_flag = x_return_status
                        ,xx.last_update_date = sysdate
                        where xx.cust_account_id = c_r.source_account_id;

                        
                        --account site loop
                        for c_as in (select
                                x_acc_site.cust_acct_site_id
                                ,x_acc_site.party_site_id
                                ,x_acc_site.source_cust_acct_site_id
                                ,x_acc_site.cust_account_id
                                from
                                xxfn_ws_call_log xx
                                ,xmltable(
                                    xmlnamespaces('http://schemas.xmlsoap.org/soap/envelope/' as "env"
                                    ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/applicationModule/types/' as "ns0"
                                    ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/' as "ns2"),
                                    '/env:Envelope/env:Body/ns0:createCustomerAccountResponse/ns0:result/ns2:Value/ns2:CustomerAccountSite' passing xx.response_xml columns
                                    party_site_id number path './ns2:PartySiteId'
                                    ,cust_account_id number path './ns2:CustomerAccountId'                                    
                                    ,cust_acct_site_id number path './ns2:CustomerAccountSiteId'
                                    ,source_cust_acct_site_id number path './ns2:OrigSystemReference') x_acc_site                                
                                where xx.ws_call_id = x_ws_call_id
                                and x_acc_site.cust_account_id = c_r.cust_account_id
                                ) loop
                            
                            log('       Customer account site is being stored in log!');               
                                                        
                            update XXDL_HZ_CUST_ACCT_SITES xx
                            set xx.process_flag = x_return_status            
                            ,xx.cloud_party_site_id = c_as.party_site_id
                            ,xx.cloud_cust_acct_site_id = c_as.cust_acct_site_id
                            ,xx.CLOUD_CUST_ACCOUNT_ID = c_as.cust_account_id  
                            where xx.cust_acct_site_id = c_as.source_cust_acct_site_id;                              

                                                             
                            --account site use loop
                            for c_asu in (select                               
                                    x_site_use.cust_acct_site_id
                                    ,x_site_use.cust_acct_site_use_id
                                    ,x_site_use.site_use_code
                                    ,x_site_use.set_id
                                    ,x_site_use.bill_site_to_use_id
                                    ,x_site_use.source_acct_site_use_id
                                    from
                                    xxfn_ws_call_log xx
                                    ,xmltable(
                                        xmlnamespaces('http://schemas.xmlsoap.org/soap/envelope/' as "env"
                                        ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/applicationModule/types/' as "ns0"
                                        ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/' as "ns2"),
                                        '/env:Envelope/env:Body/ns0:createCustomerAccountResponse/ns0:result/ns2:Value/ns2:CustomerAccountSite/ns2:CustomerAccountSiteUse' passing xx.response_xml columns
                                        cust_acct_site_id number path './ns2:CustomerAccountSiteId'
                                        ,cust_acct_site_use_id number path './ns2:SiteUseId'
                                        ,site_use_code varchar2(30) path './ns2:SiteUseCode'
                                        ,set_id number path './ns2:SetId'
                                        ,bill_site_to_use_id number path './ns2:BillToSiteUseId'
                                        ,source_acct_site_use_id number path './ns2:OrigSystemReference') x_site_use
                                    where xx.ws_call_id = x_ws_call_id
                                    and x_site_use.cust_acct_site_id = c_as.cust_acct_site_id
                                    ) loop
                        
                                log('           Customer account site use is being stored in log!');           
                                log('           For account site use:'||c_asu.source_acct_site_use_id||' cloud id is:'||c_asu.cust_acct_site_use_id);           

                                update XXDL_HZ_CUST_ACCT_SITE_USES xx
                                set xx.CLOUD_SITE_USE_ID = c_asu.cust_acct_site_use_id
                                ,xx.CLOUD_CUST_ACCT_SITE_ID= c_asu.cust_acct_site_id
                                ,xx.CLOUD_PARTY_SITE_ID= c_as.party_site_id
                                ,xx.CLOUD_SET_ID= c_asu.set_id
                                ,xx.CLOUD_BILL_TO_SITE_USE_ID= c_asu.bill_site_to_use_id
                                ,xx.process_flag = 'S'
                                where xx.site_use_id = c_asu.source_acct_site_use_id;

                                --start ship_to bill_to mapping
                                if c_asu.site_use_code = 'SHIP_TO' and c_asu.bill_site_to_use_id is null then
                                
                                    log('               Found SHIP_TO site use! Need to update bill_to_site_use_id!');  
                                    l_cloud_bill_use_id := null;                     

                                    log('               Searching BILL_TO for acct site id:'||c_asu.cust_acct_site_id);

                                    begin
                                    select x_site_use.cust_acct_site_use_id into l_cloud_bill_use_id
                                            from
                                            xxfn_ws_call_log xx
                                            ,xmltable(
                                                xmlnamespaces('http://schemas.xmlsoap.org/soap/envelope/' as "env"
                                                ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/applicationModule/types/' as "ns0"
                                                ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/' as "ns2"),
                                                '/env:Envelope/env:Body/ns0:createCustomerAccountResponse/ns0:result/ns2:Value/ns2:CustomerAccountSite/ns2:CustomerAccountSiteUse' passing xx.response_xml columns
                                                cust_acct_site_id number path './ns2:CustomerAccountSiteId'
                                                ,cust_acct_site_use_id number path './ns2:SiteUseId'
                                                ,site_use_code varchar2(30) path './ns2:SiteUseCode'
                                                ,set_id number path './ns2:SetId'
                                                ,bill_site_to_use_id number path './ns2:BillToSiteUseId'
                                                ,source_acct_site_use_id number path './ns2:OrigSystemReference') x_site_use
                                            where xx.ws_call_id = x_ws_call_id
                                            and x_site_use.cust_acct_site_id = c_asu.cust_acct_site_id
                                            and x_site_use.site_use_code = 'BILL_TO';
                                    exception
                                    when no_data_found then
                                        l_cloud_bill_use_id := null;
                                    end;        
                            
                                    log('               Bill to site use id:'||l_cloud_bill_use_id);                        
                    
                                    --start bill_use_id update
                                    if nvl(l_cloud_bill_use_id,0) != 0 then

                                        log('                   Preparing to call SOAP to update bill to use id!');
                                        l_soap_env := l_empty_clob;

                                        l_bill_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                                                    xmlns:typ="http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/applicationModule/types/"
                                                    xmlns:cus="http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/"
                                                    xmlns:cus1="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountContactRole/"
                                                    xmlns:par="http://xmlns.oracle.com/apps/cdm/foundation/parties/partyService/"
                                                    xmlns:sour="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/sourceSystemRef/"
                                                    xmlns:cus2="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountContact/"
                                                    xmlns:cus3="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountRel/"
                                                    xmlns:cus4="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountSiteUse/"
                                                    xmlns:cus5="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccountSite/"
                                                    xmlns:cus6="http://xmlns.oracle.com/apps/cdm/foundation/parties/flex/custAccount/">
                                                    <soapenv:Header/>
                                                    <soapenv:Body>
                                                        <typ:updateCustomerAccount>
                                                            <typ:customerAccount>
                                                                <cus:CustomerAccountId>'||c_r.cust_account_id||'</cus:CustomerAccountId>
                                                                <cus:PartyId>'||c_r.party_id||'</cus:PartyId>
                                                                <cus:AccountNumber>'||c_r.account_number||'</cus:AccountNumber>
                                                                <cus:CustomerAccountSite>
                                                                    <cus:CustomerAccountSiteId>'||c_as.cust_acct_site_id||'</cus:CustomerAccountSiteId>
                                                                    <cus:CustomerAccountId>'||c_as.cust_account_id||'</cus:CustomerAccountId>
                                                                    <cus:PartySiteId>'||c_as.party_site_id||'</cus:PartySiteId>
                                                                    <cus:CustomerAccountSiteUse>
                                                                        <cus:SiteUseId>'||c_asu.cust_acct_site_use_id||'</cus:SiteUseId>
                                                                        <cus:CustomerAccountSiteId>'||c_asu.cust_acct_site_id||'</cus:CustomerAccountSiteId>
                                                                        <cus:SiteUseCode>SHIP_TO</cus:SiteUseCode>
                                                                        <cus:BillToSiteUseId>'||l_cloud_bill_use_id||'</cus:BillToSiteUseId>
                                                                        <cus:SetId>'||c_asu.set_id||'</cus:SetId>
                                                                    </cus:CustomerAccountSiteUse>

                                                                </cus:CustomerAccountSite>
                                                            </typ:customerAccount>
                                                        </typ:updateCustomerAccount>
                                                    </soapenv:Body>
                                                </soapenv:Envelope>';

                                        log('                       Soap envelope for bill to use is built!');

                                        
                                        l_soap_env := l_empty_clob;
                                        l_soap_env := l_soap_env || to_clob(l_bill_text);

                                        XXFN_CLOUD_WS_PKG.WS_CALL(
                                        p_ws_url => l_app_url||'crmService/CustomerAccountService?WSDL',
                                        p_soap_env => l_soap_env,
                                        p_soap_act => 'createCustomerAccount',
                                        p_content_type => 'text/xml;charset="UTF-8"',
                                        x_return_status => xb_return_status,
                                        x_return_message => xb_return_message,
                                        x_ws_call_id => xb_ws_call_id);

                                        log('                           Web service finished! ws_call_id:'||xb_ws_call_id);  
                                        dbms_lob.freetemporary(l_soap_env);

                                        

                                        if xb_return_status = 'S' then

                                            log('                       Bill to site use id migrated!');

                                            begin
                                            select x_site_use.bill_site_to_use_id into l_cloud_bill_use_id
                                                    from
                                                    xxfn_ws_call_log xx
                                                    ,xmltable(
                                                        xmlnamespaces('http://schemas.xmlsoap.org/soap/envelope/' as "env"
                                                        ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/applicationModule/types/' as "ns0"
                                                        ,'http://xmlns.oracle.com/apps/cdm/foundation/parties/customerAccountService/' as "ns2"),
                                                        '/env:Envelope/env:Body/ns0:updateCustomerAccountResponse/ns0:result/ns2:Value/ns2:CustomerAccountSite/ns2:CustomerAccountSiteUse' passing xx.response_xml columns
                                                        cust_acct_site_id number path './ns2:CustomerAccountSiteId'
                                                        ,cust_acct_site_use_id number path './ns2:SiteUseId'
                                                        ,site_use_code varchar2(30) path './ns2:SiteUseCode'
                                                        ,set_id number path './ns2:SetId'
                                                        ,bill_site_to_use_id number path './ns2:BillToSiteUseId'
                                                        ,source_acct_site_use_id number path './ns2:OrigSystemReference') x_site_use
                                                    where xx.ws_call_id = xb_ws_call_id
                                                    and x_site_use.cust_acct_site_id = c_asu.cust_acct_site_id
                                                    and x_site_use.site_use_code = 'SHIP_TO';
                                            exception
                                            when no_data_found then
                                                l_cloud_bill_use_id := null;
                                            end;    

                                            log('                       Bill to site use id:'||l_cloud_bill_use_id);

                                            update XXDL_HZ_CUST_ACCT_SITE_USES xx
                                            set xx.CLOUD_BILL_TO_SITE_USE_ID = l_cloud_bill_use_id
                                            ,xx.process_flag = 'S'
                                            where xx.cloud_site_use_id = c_asu.cust_acct_site_use_id;    

                                        else

                                            log('                       Bill to site use id not migrated!');

                                            BEGIN
                                                SELECT
                                                    xt.faultcode,
                                                    xt.faultstring
                                                INTO
                                                    l_fault_code,
                                                    l_fault_string
                                                FROM
                                                    xxfn_ws_call_log x,
                                                    XMLTABLE ( XMLNAMESPACES ( 'http://schemas.xmlsoap.org/soap/envelope/' AS "env" ), './/env:Fault' PASSING x.response_xml COLUMNS
                                                    faultcode VARCHAR2(4000) PATH '.', faultstring VARCHAR2(4000) PATH '.' ) xt
                                                WHERE
                                                    x.ws_call_id = xb_ws_call_id;

                                            EXCEPTION
                                                WHEN no_data_found THEN
                                                    BEGIN
                                                        SELECT
                                                            nvl(x.response_status_code, 'ERROR'),
                                                            x.response_reason_phrase
                                                        INTO
                                                            l_fault_code,
                                                            l_fault_string
                                                        FROM
                                                            xxfn_ws_call_log x
                                                        WHERE
                                                            x.ws_call_id = xb_ws_call_id;

                                                    EXCEPTION
                                                        WHEN OTHERS THEN
                                                            l_cust_acct_site_use_rec.error_msg := 'Cannot find env:Fault in ws call results.';
                                                    END;
                                            END;             

                                            if l_fault_code is not null or l_fault_string is not null then
                                                l_error_message := substr( '   Greska => Code:'||l_fault_code||' Text:'||l_fault_string,1,1000);        
                                            end if;
                                            log('   '||l_error_message);

                                            update XXDL_HZ_CUST_ACCT_SITE_USES xx
                                            set xx.ERROR_MSG = l_error_message
                                            ,xx.process_flag = 'E'
                                            where xx.cloud_site_use_id = c_asu.cust_acct_site_use_id;   

                                        end if;

                                    end if;
                                    --end bill_use_id update

                                end if;
                                --end ship_to bill_to mapping    

                            end loop;    
                            --end account site use loop

                        end loop;
                        --end account site loop         

                    end loop;    
                    --end account loop                                  
                else

                    log('           Customer account not migrated!');

                    BEGIN
                        SELECT
                            xt.faultcode,
                            xt.faultstring
                        INTO
                           l_fault_code,
                            l_fault_string
                        FROM
                        xxfn_ws_call_log x,
                        XMLTABLE ( XMLNAMESPACES ( 'http://schemas.xmlsoap.org/soap/envelope/' AS "env" ), './/env:Fault' PASSING x.response_xml COLUMNS
                        faultcode VARCHAR2(4000) PATH '.', faultstring VARCHAR2(4000) PATH '.' ) xt
                        WHERE
                            x.ws_call_id = x_ws_call_id;

                    EXCEPTION
                        WHEN no_data_found THEN
                            BEGIN
                                SELECT
                                    nvl(x.response_status_code, 'ERROR'),
                                    x.response_reason_phrase
                                INTO
                                    l_fault_code,
                                    l_fault_string
                                FROM
                                    xxfn_ws_call_log x
                                WHERE
                                    x.ws_call_id = x_ws_call_id;
                           EXCEPTION
                                WHEN OTHERS THEN
                                    l_cust_acct_rec.error_msg := 'Cannot find env:Fault in ws call results.';
                            END;
                    END;             

                     if l_fault_code is not null or l_fault_string is not null then
                         l_error_message := substr( '   Greska => Code:'||l_fault_code||' Text:'||l_fault_string,1,1000);        
                     end if;
                     log('   '||l_error_message);

                     update XXDL_HZ_CUST_ACCOUNTS xx
                     set xx.ERROR_MSG = l_error_message
                     ,xx.process_flag = 'E'
                     where xx.cust_account_id = l_cust_acct_rec.cust_account_id;                    
                                       
                  
                end if;


            end loop;


            /*update xxfn_ws_call_log xx 
            set xx.response_xml = null
            ,xx.response_clob = null
            ,xx.response_blob = null
            ,xx.ws_payload_xml = null
            where ws_call_id = x_ws_call_id;*/
            
            
            log('   Soap payload:');
            log(l_text);
            

        else
            log('   Error! Customer not migrated!');

            select xx.response_json into l_party_rec.error_msg
            from xxfn_ws_call_log xx
            where xx.ws_call_id = x_ws_call_id;

            log('   '||l_party_rec.error_msg);        
        end if;

        BEGIN
            INSERT INTO xxdl_hz_parties VALUES l_party_rec;

            EXCEPTION
            WHEN dup_val_on_index THEN
                l_party_rec.last_update_date := SYSDATE;
                UPDATE xxdl_hz_parties xx
                SET
                    row = l_party_rec
                WHERE
                    xx.party_id = l_party_rec.party_id;

        END;


    else
        log('   Already exists!');

        BEGIN
            INSERT INTO xxdl_hz_parties VALUES l_party_rec;

        EXCEPTION
            WHEN dup_val_on_index THEN
                l_party_rec.last_update_date := SYSDATE;
                UPDATE xxdl_hz_parties xx
                SET
                    row = l_party_rec
                WHERE
                    xx.party_id = l_party_rec.party_id;

        END;

        update xxdl_hz_parties xx
        SET xx.cloud_party_id = l_cloud_party_id
        ,xx.process_flag = 'S'
        ,xx.error_msg = null
        WHERE
            xx.party_id = l_party_rec.party_id;

    end if;

    l_party_rec := l_party_rec_empty;
    l_soap_env := l_empty_clob;
    l_cnt := l_cnt + 1;

end loop;

log('Finished customer import!');
log('Record count:'||l_cnt);

exception
    when XX_APP then
        log('   No cloud url found!');
    when XX_USER then
        log('   No cloud user found!');
    when XX_PASS then
        log('   No cloud password found!');
    when others then
        log('   Unexpected error! SQLCODE:'||SQLCODE||' SQLERRM:'||SQLERRM);
        log('   Error_Stack...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_STACK()||' Error_Backtrace...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE());

end migrate_customers_cloud;


  /*===========================================================================+
  -- Name    : update_customer_cloud
  -- Desc    : Procedure for updating cloud cusgtomers
  -- Usage   : Concurrent Program XXUN Migrate items to cloud.
  -- Parameters	
--       - p_party_number: party number in EBS
--       - p_rows: number of rows to process, default 1000
--		 - p_retry_error: should we process records that ended in error
============================================================================+*/

procedure update_customer_cloud (
      p_party_number in varchar2,
      p_rows in number,
      p_retry_error in varchar2
)
is
begin
  null;
end update_customer_cloud;

  /*===========================================================================+
  -- Name    : find_customer_cloud
  -- Desc    : Function to find customer in cloud
  -- Usage   : 
  -- Parameters
  --    p_party_number in varchar2,
  --    p_org in varchar
============================================================================+*/
procedure find_customer_cloud(
      p_party_number in varchar2,
      p_cloud_party_id out number,
      p_cloud_org_id out number) is

    l_item_rec XXDL_MTL_SYSTEM_ITEMS_MIG%ROWTYPE;
    l_item_empty XXDL_MTL_SYSTEM_ITEMS_MIG%ROWTYPE;
    l_fault_code          varchar2(4000);
    l_fault_string        varchar2(4000); 
    l_soap_env clob;
    l_empty_clob clob;
    l_text varchar2(32000);
    l_find_text varchar2(32000);
    x_return_status varchar2(500);
    x_return_message varchar2(32000);
    x_ws_call_id number;
    l_cnt number := 0;
    l_cloud_party_id number:=0;     
l_app_url varchar2(300);
begin


l_app_url := get_config('ServiceRootURL');

    log('   Building find customer call!');

    l_find_text := ' ';  

    l_soap_env := l_soap_env|| to_clob(l_find_text);
    l_find_text := '';    
--    l_soap_env := l_soap_env|| to_clob(l_text);
--    l_text := '';

    log('   Calling web service.');
    XXFN_CLOUD_WS_PKG.WS_REST_CALL(
      p_ws_url => l_app_url||'crmRestApi/resources/11.13.18.05/hubOrganizations/?q=PartyNumber='||p_party_number,
      p_rest_env => l_soap_env,
      p_rest_act => 'GET',
      p_content_type => 'application/json;charset="UTF-8"',
      x_return_status => x_return_status,
      x_return_message => x_return_message,
      x_ws_call_id => x_ws_call_id);

      log(' Web service to find customer finished! ws_call_id:'||x_ws_call_id);

      if x_return_status = 'S' then

        log('Parsing ws_call to get customer cloud id..');

        BEGIN
            with json_response AS
            (select jt.*
            from xxfn_ws_call_log xx
            ,json_table(xx.response_json,'$' 
                        columns(nested path '$.items[*]'
                            columns(
                                cloud_party_id number path '$.PartyId'))) jt
            where xx.ws_call_id = x_ws_call_id)
            select
            nvl(jr.cloud_party_id,0)
            into l_cloud_party_id
            from
            json_response jr;
        
            EXCEPTION
                WHEN no_data_found THEN
                    p_cloud_party_id :=0;
                    p_cloud_org_id :=0;
            END;

            log('   Cloud customer Id: '||p_cloud_party_id);
        else
            log('   Customer does not exists in cloud!');
            l_cloud_party_id := 0;
        end if;

        p_cloud_party_id:= l_cloud_party_id;


exception
  when others then
    p_cloud_party_id := 0;
    p_cloud_org_id := 0;
end;

 /*===========================================================================+
  -- Name    : find_address_cloud
  -- Desc    : Function to find customer address in cloud
  -- Usage   : 
  -- Parameters
  --    p_party_number in varchar2,
  --    p_org in varchar
============================================================================+*/
procedure find_address_cloud(
      p_party_number in varchar2,
      p_ws_call_id out number) is

    l_item_rec XXDL_MTL_SYSTEM_ITEMS_MIG%ROWTYPE;
    l_item_empty XXDL_MTL_SYSTEM_ITEMS_MIG%ROWTYPE;
    l_fault_code          varchar2(4000);
    l_fault_string        varchar2(4000); 
    l_soap_env clob;
    l_empty_clob clob;
    l_text varchar2(32000);
    l_find_text varchar2(32000);
    x_return_status varchar2(500);
    x_return_message varchar2(32000);
    x_ws_call_id number;
    l_cnt number := 0;
    l_cloud_party_id number:=0;     
l_app_url varchar2(300);
begin


l_app_url := get_config('ServiceRootURL');

    log('   Building find customer address call!');

    l_find_text := ' ';  

    l_soap_env := l_soap_env|| to_clob(l_find_text);
    l_find_text := '';    
--    l_soap_env := l_soap_env|| to_clob(l_text);
--    l_text := '';

    log('   Calling web service.');
    XXFN_CLOUD_WS_PKG.WS_REST_CALL(
      p_ws_url => l_app_url||'crmRestApi/resources/11.13.18.05/hubOrganizations/'||p_party_number||'/child/Address',
      p_rest_env => l_soap_env,
      p_rest_act => 'GET',
      p_content_type => 'application/json;charset="UTF-8"',
      x_return_status => x_return_status,
      x_return_message => x_return_message,
      x_ws_call_id => x_ws_call_id);

      log('         Web service to find customer address finished! ws_call_id:'||x_ws_call_id);

      if x_return_status = 'S' then

        p_ws_call_id := x_ws_call_id;
      else
          log('     Customer address does not exists in cloud!');
          p_ws_call_id := 0;
      end if;

exception
  when others then
    p_ws_call_id := 0;
end;

       
  /*===========================================================================+
  -- Name    : update_cust_site_tax_ref
  -- Desc    : Update customer acct site tax profile according to country
  -- Usage   : 
  -- Parameters
============================================================================+*/
procedure update_cust_site_tax_ref(
      p_party_number in varchar2) is

    l_fault_code          varchar2(4000);
    l_fault_string        varchar2(4000); 
    l_soap_env clob;
    l_empty_clob clob;
    l_text varchar2(32000);
    l_find_text varchar2(32000);
    x_return_status varchar2(500);
    x_return_message varchar2(32000);
    x_ws_call_id number;
    xt_ws_call_id number;
    xf_ws_call_id number;
    l_cnt number := 0;
    l_cloud_party_id number:=0;     
    l_app_url varchar2(300);
    
    cursor c_sites is 
    select distinct
    xx.cloud_party_site_id
    ,hp.party_name
    ,hp.party_number
    ,hps.party_site_number
    ,hl.country
    ,eu.territory_code
    ,hcas.cust_account_id
    ,case
        when hl.country = 'HR' then
            'DOMACI'
        when (nvl(eu.territory_code,'X') != 'HR' and nvl(eu.territory_code,'X') = 'X') then
            'TRECE_ZEMLJE'
        else 'EU'
        end class_code,xx_hca.cloud_party_id
    from
    xxdl_hz_cust_acct_sites xx
    ,apps.hz_cust_acct_sites_all@ebstest hcas
    ,apps.hz_party_sites@ebstest hps
    ,apps.hz_parties@ebstest hp
    ,apps.hz_locations@ebstest hl
    ,(select * from apps.MTL_COUNTRY_ASSIGNMENTS_V@ebstest 
    WHERE (ZONE_CODE='EC')
        and nvl(end_date,sysdate) >= sysdate) eu
    ,xxdl_hz_cust_accounts xx_hca
    where xx.process_flag = 'S'
    and xx.cloud_party_site_id > 0
    and xx.cust_acct_site_id = hcas.cust_acct_site_id
    and xx.party_site_id = hps.party_site_id
    and hps.party_id = hp.party_id
    and hp.party_number like nvl(p_party_number,'%')
    and hps.location_id = hl.location_id
    and hl.country = eu.territory_code(+)
    and xx.cust_account_id = xx_hca.cust_account_id;


begin


l_app_url := get_config('ServiceRootURL');


for c_s in c_sites loop
  
  log(' Found party number:'||c_s.party_number);

  log(' Getting cloud adresses!');

  l_find_text := ' '; --dummy, empty for get REST call

  l_soap_env := l_soap_env||to_clob(l_find_text);

  log ('    Calling web service:');

  XXFN_CLOUD_WS_PKG.WS_REST_CALL(
      p_ws_url => l_app_url||'crmRestApi/resources/11.13.18.05/hubOrganizations/'||p_party_number||'/child/Address',
      p_rest_env => l_soap_env,
      p_rest_act => 'GET',
      p_content_type => 'application/json;charset="UTF-8"',
      x_return_status => x_return_status,
      x_return_message => x_return_message,
      x_ws_call_id => x_ws_call_id);
      
  log('     Web service status:'||x_return_status);
  log('     Web service call:'||x_ws_call_id);

  dbms_lob.freetemporary(l_soap_env);

  if x_return_status = 'S' then

    for c_a in (   
        select distinct
            hps.party_site_id
            ,jt.address_id cloud_address_id
            ,jt.address_number
            from
            apps.hz_parties@ebstest hp
            ,apps.hz_party_sites@ebstest hps
            ,apps.hz_cust_accounts@ebstest hca
            ,apps.HZ_CUST_ACCT_SITES_ALL@ebstest HCSA
            ,apps.HZ_CUST_SITE_USES_all@ebstest hcsu
            ,apps.hz_locations@ebstest hl
            ,(
            select
            cloud_party_id
            ,cloud_party_number
            ,address_id
            ,address_type
            ,address_number
            ,source_address_id
            ,source_party_id
            ,xx.ws_call_id
            from
            xxfn_ws_call_log xx,
            json_table(xx.response_json,'$'
                columns(
                                cloud_party_id number path '$.PartyId',
                                cloud_party_number varchar2(100) path '$.PartyNumber',
                                address_id number path '$.AddressId',
                                address_type varchar2(30) path '$.AddressType',
                                address_number varchar2(100) path '$.AddressNumber',
                                source_address_id varchar2(240) path '$.SourceSystemReferenceValue',
                                source_party_id number path '$.PartySourceSystemReferenceValue'))
            where xx.ws_call_id = x_ws_call_id
            union all
            select
            cloud_party_id
            ,cloud_party_number
            ,address_id
            ,address_type
            ,address_number
            ,source_address_id
            ,source_party_id
            ,xx.ws_call_id
            from
            xxfn_ws_call_log xx,
            json_table(xx.response_json, '$'
                columns(nested path '$.items[*]'
                            columns(
                                cloud_party_id number path '$.PartyId',
                                cloud_party_number varchar2(100) path '$.PartyNumber',
                                address_id number path '$.AddressId',
                                address_type varchar2(30) path '$.AddressType',
                                address_number varchar2(100) path '$.AddressNumber',
                                source_address_id varchar2(240) path '$.PartySourceSystemReferenceValue',
                                source_party_id number path '$.PartySourceSystemReferenceValue')))                   
            where xx.ws_call_id = x_ws_call_id
            ) jt
            where 1=1
            and hp.party_id = hca.party_id(+)
            and hp.party_id = hps.party_id(+)
            and hca.cust_account_id = hcsa.cust_account_id
            and hps.party_site_id = hcsa.party_site_id(+)
            and hcsa.cust_acct_site_id = hcsu.cust_acct_site_id(+)
            and hps.location_id = hl.location_id(+)
            and hcsu.site_use_code is not null
            and hca.cust_account_id = c_s.cust_account_id
            and hl.location_id = substr(jt.source_address_id,instr(jt.source_address_id,';',1,1)+1,length(jt.source_address_id))
            and hps.party_site_id = substr(jt.source_address_id,1,instr(jt.source_address_id,';',1,1)-1)
            and hcsa.org_id in (102,531,2068,2288)
            and jt.ws_call_id = x_ws_call_id) loop

        log('	    Found address number:'||c_a.address_number);

        l_soap_env := l_empty_clob;

        l_text := '{
            "ClassificationCode": "XXDL_TIP_PARTNERA",
            "ClassTypeCode": "XXDL TIP PARTNERA",
            "ClassCode": "'||c_s.class_code||'",
            "StartDateActive": "'||to_char(sysdate,'YYYY-MM-DD')||'",
            "PartyNumber": "'||c_s.party_number||'",
            "PartySiteNumber": "'||c_a.address_number||'"
        }';

        l_soap_env := l_soap_env||to_clob(l_text);       

        log('       Calling web service to create classification');

        XXFN_CLOUD_WS_PKG.WS_REST_CALL(
            p_ws_url => l_app_url||'fscmRestApi/resources/11.13.18.05/thirdPartySiteFiscalClassifications',
            p_rest_env => l_soap_env,
            p_rest_act => 'POST',
            p_content_type => 'application/json;charset="UTF-8"',
            x_return_status => x_return_status,
            x_return_message => x_return_message,
            x_ws_call_id => xt_ws_call_id);         
        
        log('       Web service status:'||x_return_status);
        log('       Web service call:'||xt_ws_call_id);

        dbms_lob.freetemporary(l_soap_env);   

        l_text:=l_text; 

        if x_return_status = 'S' then

             log('   Classification update updated!');

             update xxdl_hz_cust_acct_sites
             set CLOUD_PARTY_FISCAL_CODE = c_s.class_code
             where cloud_party_site_id = c_s.cloud_party_site_id;

        else
            log('   Classification update failed!');
        end if;

       
         
    end loop;
  else
    log('   Get adress request failed!');
  end if;

    l_find_text:='';
end loop;

exception
    when others then
        log('   Unexpected error! SQLCODE:'||SQLCODE||' SQLERRM:'||SQLERRM);
        log('   Error_Stack...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_STACK()||' Error_Backtrace...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE());
end update_cust_site_tax_ref;

 /*===========================================================================+
  -- Name    : update_cust_acc_profile
  -- Desc    : Update customer acct profile
  -- Usage   : 
  -- Parameters
============================================================================+*/
procedure update_cust_acc_profile(
    p_party_number in varchar2) is

    l_fault_code          varchar2(4000);
    l_fault_string        varchar2(4000); 
    l_soap_env clob;
    l_empty_clob clob;
    l_text varchar2(32000);
    l_find_text varchar2(32000);
    x_return_status varchar2(500);
    x_return_message varchar2(32000);
    l_error_message varchar2(32000);
    x_ws_call_id number;
    xt_ws_call_id number;
    xf_ws_call_id number;
    l_cnt number := 0;
    l_cloud_party_id number:=0;     
    l_app_url varchar2(300);
    
    cursor c_cust_accounts is 
    select
    xhca.*
    from
    xxdl_hz_cust_accounts xhca
    ,xxdl_hz_parties xhp
    where nvl(xhca.process_flag,'X') = 'S'
    and nvl(xhca.cloud_profile,'X') != 'S'
    and xhca.party_id = xhp.party_id
    and xhp.party_number like nvl(p_party_number,'%') 
    ;


begin


l_app_url := get_config('ServiceRootURL');


for c_ca in c_cust_accounts loop
  
  log(' Found cust account number:'||c_ca.account_number);

  log(' Building soap call!');

  l_find_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/financials/receivables/customers/customerProfileService/types/" xmlns:cus="http://xmlns.oracle.com/apps/financials/receivables/customers/customerProfileService/" xmlns:cus1="http://xmlns.oracle.com/apps/financials/receivables/customerSetup/customerProfiles/model/flex/CustomerProfileDff/" xmlns:cus2="http://xmlns.oracle.com/apps/financials/receivables/customerSetup/customerProfiles/model/flex/CustomerProfileGdf/">
   <soapenv:Header/>
   <soapenv:Body>
      <typ:createCustomerProfile>
         <typ:customerProfile>            
            <cus:AccountNumber>'||c_ca.account_number||'</cus:AccountNumber>            
            <cus:ProfileClassName>DEFAULT</cus:ProfileClassName>
            <cus:PartyId>'||c_ca.cloud_party_id||'</cus:PartyId>
 		   <cus:CustAccountId>'||c_ca.CLOUD_CUST_ACCOUNT_ID||'</cus:CustAccountId>            
         </typ:customerProfile>
      </typ:createCustomerProfile>
   </soapenv:Body>
</soapenv:Envelope>'; 

  l_soap_env := l_soap_env||to_clob(l_find_text);

  log ('    Calling web service:');

  XXFN_CLOUD_WS_PKG.WS_CALL(
      p_ws_url => l_app_url||'fscmService/ReceivablesCustomerProfileService?WSDL',
      p_soap_env => l_soap_env,
      p_soap_act => 'createCustomerProfile',
      p_content_type => 'text/xml;charset="UTF-8"',
      x_return_status => x_return_status,
      x_return_message => x_return_message,
      x_ws_call_id => x_ws_call_id);
      
  log('     Web service status:'||x_return_status);
  log('     Web service call:'||x_ws_call_id);

  dbms_lob.freetemporary(l_soap_env);

  if x_return_status = 'S' then

    log('       Account profile created!');

    update xxdl_hz_cust_accounts xhca
    set xhca.cloud_profile = x_return_status
    ,xhca.ERROR_MSG = null
    where xhca.CLOUD_CUST_ACCOUNT_ID = c_ca.CLOUD_CUST_ACCOUNT_ID;

       
         
  else
    log('       Account profile creation error!');
    BEGIN

        SELECT
            xt.faultcode,
            xt.faultstring
        INTO
            l_fault_code,
            l_fault_string
        FROM
            xxfn_ws_call_log x,
            XMLTABLE ( XMLNAMESPACES ( 'http://schemas.xmlsoap.org/soap/envelope/' AS "env" ), './/env:Fault' PASSING x.response_xml COLUMNS
            faultcode VARCHAR2(4000) PATH '.', faultstring VARCHAR2(4000) PATH '.' ) xt
        WHERE
            x.ws_call_id = x_ws_call_id;

        EXCEPTION
            WHEN no_data_found THEN
                BEGIN
                    SELECT
                        nvl(x.response_status_code, 'ERROR'),
                        x.response_reason_phrase
                    INTO
                        l_fault_code,
                        l_fault_string
                    FROM
                        xxfn_ws_call_log x
                    WHERE
                        x.ws_call_id = x_ws_call_id;
           EXCEPTION
                    WHEN OTHERS THEN
                        l_error_message := 'Cannot find env:Fault in ws call results.';
                END;
        END;             

        if l_fault_code is not null or l_fault_string is not null then
            l_error_message := substr( '   Greska => Code:'||l_fault_code||' Text:'||l_fault_string,1,1000);        
        end if;
        log('   '||l_error_message);

        update xxdl_hz_cust_accounts xhca
        set xhca.cloud_profile = x_return_status
        ,xhca.ERROR_MSG = l_error_message
        where xhca.CLOUD_CUST_ACCOUNT_ID = c_ca.CLOUD_CUST_ACCOUNT_ID;

  end if;

    l_find_text:='';
end loop;

exception
    when others then
        log('   Unexpected error! SQLCODE:'||SQLCODE||' SQLERRM:'||SQLERRM);
        log('   Error_Stack...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_STACK()||' Error_Backtrace...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE());
end update_cust_acc_profile;

/*===========================================================================+
  Function   : DecodeBASE64
  Description : Decodes BASE64
  Usage       : 
  Arguments   : 
  Returns     :
============================================================================+*/
FUNCTION DecodeBASE64(InBase64Char IN OUT NOCOPY CLOB) RETURN CLOB IS

    blob_loc BLOB;
    clob_trim CLOB;
    res CLOB;

    lang_context INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
    dest_offset INTEGER := 1;
    src_offset INTEGER := 1;
    read_offset INTEGER := 1;
    warning INTEGER;
    ClobLen INTEGER;

    amount INTEGER := 1440; -- must be a whole multiple of 4
    buffer RAW(1440);
    stringBuffer VARCHAR2(1440);

BEGIN

    -- Remove all NEW_LINE from base64 string
    ClobLen := DBMS_LOB.GETLENGTH(InBase64Char);
    DBMS_LOB.CREATETEMPORARY(clob_trim, TRUE);
    LOOP
        EXIT WHEN read_offset > ClobLen;
        stringBuffer := REPLACE(REPLACE(DBMS_LOB.SUBSTR(InBase64Char, amount, read_offset), CHR(13), NULL), CHR(10), NULL);
        DBMS_LOB.WRITEAPPEND(clob_trim, LENGTH(stringBuffer), stringBuffer);
        read_offset := read_offset + amount;
    END LOOP;

    read_offset := 1;
    ClobLen := DBMS_LOB.GETLENGTH(clob_trim);
    DBMS_LOB.CREATETEMPORARY(blob_loc, TRUE);
    LOOP
        EXIT WHEN read_offset > ClobLen;
        buffer := UTL_ENCODE.BASE64_DECODE(UTL_RAW.CAST_TO_RAW(DBMS_LOB.SUBSTR(clob_trim, amount, read_offset)));
        DBMS_LOB.WRITEAPPEND(blob_loc, DBMS_LOB.GETLENGTH(buffer), buffer);
        read_offset := read_offset + amount;
    END LOOP;

    DBMS_LOB.CREATETEMPORARY(res, TRUE);
    DBMS_LOB.CONVERTTOCLOB(res, blob_loc, DBMS_LOB.LOBMAXSIZE, dest_offset, src_offset,  DBMS_LOB.DEFAULT_CSID, lang_context, warning);

    DBMS_LOB.FREETEMPORARY(blob_loc);
    DBMS_LOB.FREETEMPORARY(clob_trim);
    RETURN res;


END DecodeBASE64;


/*===========================================================================+
Function   : get_suppliers
Description : Download suppliers, addresses, sites and contacts from cloud to EBS. Update existing records if there were changes after max(transfer creation_date)
Usage       :
Arguments   : p_entity - name of the entity we download, SUPPLIER,SUPPLIER_SITES, SUPPLIER_ADDRESSES, SUPPLIER_CONTACTS
              p_date - entities max date of creation of last_update_date
Remarks     :
============================================================================+*/
function get_suppliers(p_entity in varchar2, P_DATE IN varchar2) return varchar2
is

l_body VARCHAR2(30000);
l_result varchar2(500);
l_result_clob  clob;
x_return_status varchar2(500);
x_return_message varchar2(32000);
l_soap_env clob;
l_text varchar2(32000);
x_ws_call_id number;
l_inflated_resp blob;
l_result_nr varchar2(32000);
l_resp_xml       XMLType;
l_resp_xml_id   XMLType;
l_result_nr_id  varchar2(500);
l_result_varchar  varchar2(32000);
l_result_clob_decode clob;

l_app_url varchar2(300);

l_sup_rec xxdl_poz_suppliers%ROWTYPE;
l_sup_rec_empty xxdl_poz_suppliers%ROWTYPE;
l_sup_addr_rec xxdl_poz_supplier_addresses%ROWTYPE;
l_sup_addr_rec_empty xxdl_poz_supplier_addresses%ROWTYPE;
l_sup_site_rec xxdl_poz_supplier_sites%ROWTYPE;
l_sup_site_rec_empty xxdl_poz_supplier_sites%ROWTYPE;
l_sup_cont_rec xxdl_poz_supplier_contacts%ROWTYPE;
l_sup_cont_rec_empty xxdl_poz_supplier_contacts%ROWTYPE;

 XX_NO_REPORT exception;

BEGIN

execute immediate 'alter session set NLS_TIMESTAMP_TZ_FORMAT= ''YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM''';
--execute immediate 'alter session set nls_date_format=''yyyy-mm-dd hh24:mi:ss''';
--execute immediate 'alter session set NLS_TIMESTAMP_FORMAT= ''YYYY-MM-DD"T"HH24:MI:SS.FF3''';

l_app_url := get_config('ServiceRootURL');

l_text :='<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
   <soap:Header/>
   <soap:Body>
      <pub:runReport>
         <pub:reportRequest>
            <pub:attributeFormat>xml</pub:attributeFormat>
            <pub:attributeLocale></pub:attributeLocale>
            <pub:attributeTemplate></pub:attributeTemplate>
            <pub:parameterNameValues>
               <!--Zero or more repetitions:-->
               <pub:item>
                  <pub:name>p_entity</pub:name>
                  <pub:values>
                     <!--Zero or more repetitions:-->
                     <pub:item>'||p_entity||'</pub:item>   
                  </pub:values>
               </pub:item>
               <pub:item>
                  <pub:name>p_date</pub:name>
                  <pub:values>
                     <!--Zero or more repetitions:-->
                    <pub:item>'||p_date||'</pub:item>   
                  </pub:values>
               </pub:item>
            </pub:parameterNameValues>
            <pub:reportAbsolutePath>Custom/XXDL_Integration/XXDL_SUPPLIERS_EXPORT_PRT.xdo</pub:reportAbsolutePath>
            <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
         </pub:reportRequest>
         <pub:appParams></pub:appParams>
      </pub:runReport>
   </soap:Body>
</soap:Envelope>';

--log('Payload:'||l_text);

  l_soap_env := to_clob(l_text);

  XXFN_CLOUD_WS_PKG.WS_CALL(
    p_ws_url => l_app_url||'xmlpserver/services/ExternalReportWSSService?WSDL',
    p_soap_env => l_soap_env,
    p_soap_act => 'runReport',
    p_content_type => 'application/soap+xml;charset="UTF-8"',
    x_return_status => x_return_status,
    x_return_message => x_return_message,
    x_ws_call_id => x_ws_call_id);
      
  dbms_lob.freetemporary(l_soap_env);
  log(x_ws_call_id);
  log('Return status: '||x_return_status);
  --log(x_return_message);


  if(x_return_status = 'S') then
  
    log('Extracting xml response');
      
      begin
      select response_xml
      into l_resp_xml
      from xxfn_ws_call_log
      where ws_call_id = x_ws_call_id;
      exception
        when no_data_found then
          raise XX_NO_REPORT;
      end;

      begin
      SELECT xml.vals
      INTO l_result_clob
      FROM xxfn_ws_call_log a,
        XMLTable(xmlnamespaces('http://xmlns.oracle.com/oxp/service/PublicReportService' AS "ns2",'http://www.w3.org/2003/05/soap-envelope' AS "env"), '/env:Envelope/env:Body/ns2:runReportResponse/ns2:runReportReturn' PASSING a.response_xml COLUMNS vals CLOB PATH './ns2:reportBytes') xml
      WHERE a.ws_call_id = x_ws_call_id
      AND xml.vals      IS NOT NULL;
      exception
        when no_data_found then
          raise XX_NO_REPORT;
      end;
      
      
      l_result_clob_decode := DecodeBASE64(l_result_clob);
      
      l_resp_xml_id := XMLType.createXML(l_result_clob_decode);
      
      log('Parsing report response for suppliers');
      
      FOR cur_rec IN (
      SELECT xt.*
      FROM   XMLTABLE('/DATA_DS/SUPPLIERS'
               PASSING l_resp_xml_id
               COLUMNS 
                   VENDOR_ID number PATH 'VENDOR_ID', 
				   PARTY_ID number PATH 'PARTY_ID',
                   VENDOR_NAME VARCHAR2(1440) PATH 'VENDOR_NAME',
                   SUPPLIER_NUMBER VARCHAR2(120) PATH 'SUPPLIER_NUMBER',
                   VAT_NUMBER VARCHAR2(200) PATH 'VAT_NUMBER',
				   DUNS_NUMBER VARCHAR2(200) PATH 'DUNS_NUMBER',
				   TAXPAYER_ID VARCHAR2(200) PATH 'TAXPAYER_ID',
                   INACTIVE_DATE VARCHAR2(35) PATH 'INACTIVE_DATE',
                   CREATION_DATE VARCHAR2(35) PATH 'CREATION_DATE',
                   LAST_UPDATE_DATE VARCHAR2(35) PATH 'LAST_UPDATE_DATE'
               ) xt)
      LOOP
  
        log('====================');
        log('Vendor ID:'||cur_rec.vendor_id);
        log('Vendor name:'||cur_rec.vendor_name);
        log('Supplier number:'||cur_rec.supplier_number);
        log('VAT number:'||cur_rec.vat_number);
        log('DUNS number:'||cur_rec.DUNS_NUMBER);
        log('TAXPAYER ID:'||cur_rec.TAXPAYER_ID);
        log('==============================');
        
        
        log('Inserting supplier into table');
        
        l_sup_rec.vendor_id := cur_rec.vendor_id;
		l_sup_rec.party_id := cur_rec.party_id;
        l_sup_rec.vendor_name := cur_rec.vendor_name;
        l_sup_rec.supplier_number := cur_rec.supplier_number;
        l_sup_rec.vat_number := cur_rec.vat_number;
        l_sup_rec.DUNS_NUMBER := cur_rec.DUNS_NUMBER;
        l_sup_rec.TAXPAYER_ID := cur_rec.TAXPAYER_ID;
        l_sup_rec.inactive_date := cast(to_timestamp_tz(  cur_rec.inactive_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
        l_sup_rec.creation_date := cast(to_timestamp_tz(  cur_rec.creation_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
        l_sup_rec.last_update_date := cast(to_timestamp_tz(  cur_rec.last_update_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
        l_sup_rec.transf_creation_date := sysdate;
        begin
        
          insert into xxdl_poz_suppliers values l_sup_rec;        
        
        exception
          when dup_val_on_index then
          log('Supplier already in table, updating record!');
            update xxdl_poz_suppliers xx
            set xx.vendor_name = cur_rec.vendor_name
            ,xx.supplier_number = cur_rec.supplier_number
            ,xx.vat_number = cur_rec.vat_number
            ,xx.DUNS_NUMBER = cur_rec.DUNS_NUMBER
            ,xx.TAXPAYER_ID = cur_rec.TAXPAYER_ID
            ,xx.inactive_date = cast(to_timestamp_tz(  cur_rec.inactive_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
            ,xx.creation_date = cast(to_timestamp_tz(  cur_rec.creation_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
            ,xx.last_update_date =cast(to_timestamp_tz(  cur_rec.last_update_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
            ,xx.transf_last_update = sysdate
            where xx.vendor_id = cur_rec.vendor_id;
        end;
      end loop;
      
      log('End of suppliers download');
      
      log('Parsing report response for suppliers addresses');
      
      FOR cur_rec IN (
      SELECT xt.*
      FROM   XMLTABLE('/DATA_DS/SUPPLIER_ADDRESSES'
               PASSING l_resp_xml_id
               COLUMNS 
                   VENDOR_ID NUMBER PATH 'VENDOR_ID', 
                   VENDOR_SITE_ID NUMBER PATH 'VENDOR_SITE_ID',
                   PARTY_SITE_ID NUMBER PATH 'PARTY_SITE_ID',
                   LOCATION_ID NUMBER PATH 'LOCATION_ID',
                   ADDRESS VARCHAR2(3840) PATH 'ADDRESS',
                   ADDRESS1 VARCHAR2(960) PATH 'ADDRESS1',
                   ADDRESS2 VARCHAR2(960) PATH 'ADDRESS2',
                   ADDRESS3 VARCHAR2(960) PATH 'ADDRESS3',
                   ADDRESS4 VARCHAR2(960) PATH 'ADDRESS4',
                   CITY  VARCHAR2(240) PATH 'CITY',
                   COUNTRY VARCHAR2(240) PATH 'COUNTRY',
                   POSTAL_CODE  VARCHAR2(240) PATH 'POSTAL_CODE',
                   INACTIVE_DATE VARCHAR2(35) PATH 'INACTIVE_DATE',
                   CREATION_DATE VARCHAR2(35) PATH 'CREATION_DATE',
                   LAST_UPDATE_DATE VARCHAR2(35) PATH 'LAST_UPDATE_DATE'
               ) xt)
      LOOP
  
        log('====================');
        log('Vendor ID:'||cur_rec.vendor_id);
        log('Location Id:'||to_char(cur_rec.location_id));
        log('Address:'||cur_rec.address);
        log('Address country:'||cur_rec.country);
        log('==============================');
        
        
        log('Inserting supplier address into table');
        l_sup_addr_rec.vendor_id := cur_rec.vendor_id;
        l_sup_addr_rec.vendor_site_id := cur_rec.vendor_site_id;
        l_sup_addr_rec.party_site_id := cur_rec.party_site_id;
        l_sup_addr_rec.location_id := cur_rec.location_id;
        l_sup_addr_rec.address := cur_rec.address;
        l_sup_addr_rec.address1 := cur_rec.address1;
        l_sup_addr_rec.address2 := cur_rec.address2;
        l_sup_addr_rec.address3 := cur_rec.address3;
        l_sup_addr_rec.address4 := cur_rec.address4;
        l_sup_addr_rec.city := cur_rec.city;
        l_sup_addr_rec.country := cur_rec.country;
        l_sup_addr_rec.postal_code := cur_rec.postal_code;
        l_sup_addr_rec.inactive_date := cast(to_timestamp_tz(  cur_rec.inactive_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
        l_sup_addr_rec.creation_date := cast(to_timestamp_tz(  cur_rec.creation_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
        l_sup_addr_rec.last_update_date := cast(to_timestamp_tz(  cur_rec.last_update_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
        l_sup_addr_rec.transf_creation_date := sysdate;
        
        begin
        
          insert into xxdl_poz_supplier_addresses values l_sup_addr_rec;        
        
        exception
          when dup_val_on_index then
          log('Supplier address already in table, updating record!');
            update xxdl_poz_supplier_addresses xx
            set xx.vendor_id = cur_rec.vendor_id
            ,xx.vendor_site_id = cur_rec.vendor_site_id
            ,xx.party_site_id = cur_rec.party_site_id
            ,xx.location_id = cur_rec.location_id
            ,xx.address = cur_rec.address
            ,xx.address1 = cur_rec.address1
            ,xx.address2 = cur_rec.address2
            ,xx.address3 = cur_rec.address3
            ,xx.address4 = cur_rec.address4
            ,xx.city = cur_rec.city
            ,xx.country = cur_rec.country
            ,xx.postal_code = cur_rec.postal_code
            ,xx.inactive_date = cast(to_timestamp_tz(  cur_rec.inactive_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
            ,xx.creation_date = cast(to_timestamp_tz(  cur_rec.creation_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
            ,xx.last_update_date =cast(to_timestamp_tz(  cur_rec.last_update_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
            ,xx.transf_last_update = sysdate
            where xx.location_id = cur_rec.location_id;
        end;
      end loop;
      
      
      log('End of suppliers addresses interface check');
      
      log('Parsing report response for suppliers sites');
      
     FOR cur_rec IN (
      SELECT xt.*
      FROM   XMLTABLE('/DATA_DS/SUPPLIER_SITES'
               PASSING l_resp_xml_id
               COLUMNS 
                   VENDOR_ID NUMBER PATH 'VENDOR_ID', 
                   VENDOR_SITE_ID NUMBER PATH 'VENDOR_SITE_ID',
                   VENDOR_SITE_CODE VARCHAR2(60) PATH 'VENDOR_SITE_CODE',
                   PARTY_SITE_ID  NUMBER PATH 'PARTY_SITE_ID',
                   INACTIVE_DATE  VARCHAR2(35) PATH 'INACTIVE_DATE',
                   CREATION_DATE VARCHAR2(35) PATH 'CREATION_DATE',
                   LAST_UPDATE_DATE VARCHAR2(35) PATH 'LAST_UPDATE_DATE',
                   BU_NAME VARCHAR2(100) PATH 'BU_NAME'
               ) xt)
      LOOP
  
        log('====================');
        log('Vendor ID:'||cur_rec.vendor_id);
        log('Vendor site Id:'||cur_rec.VENDOR_SITE_ID);
        log('Vendor site code:'||cur_rec.VENDOR_SITE_CODE);
        log('BU Namee:'||cur_rec.bu_name);
        log('==============================');
        
        
        log('Inserting supplier site into table');
        l_sup_site_rec.vendor_id := cur_rec.vendor_id;
        l_sup_site_rec.vendor_site_id := cur_rec.vendor_site_id;
        l_sup_site_rec.vendor_site_code := cur_rec.vendor_site_code;
        l_sup_site_rec.party_site_id := cur_rec.party_site_id;
        l_sup_site_rec.inactive_date := cast(to_timestamp_tz(  cur_rec.inactive_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
        l_sup_site_rec.creation_date := cast(to_timestamp_tz(  cur_rec.creation_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
        l_sup_site_rec.last_update_date := cast(to_timestamp_tz(  cur_rec.last_update_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
        l_sup_site_rec.transf_creation_date := sysdate;
        l_sup_site_rec.bu_name := cur_rec.bu_name;
        
        begin
        
          insert into xxdl_poz_supplier_sites values l_sup_site_rec;        
        
        exception
          when dup_val_on_index then
          log('Supplier site already in table, updating record!');
            update xxdl_poz_supplier_sites xx
            set xx.vendor_id = cur_rec.vendor_id
            ,xx.vendor_site_id = cur_rec.vendor_site_id
            ,xx.vendor_site_code = cur_rec.vendor_site_code
            ,xx.inactive_date = cast(to_timestamp_tz(  cur_rec.inactive_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
            ,xx.creation_date = cast(to_timestamp_tz(  cur_rec.creation_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
            ,xx.last_update_date =cast(to_timestamp_tz(  cur_rec.last_update_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
            ,xx.transf_last_update = sysdate
            ,xx.bu_name = cur_rec.bu_name
            where xx.vendor_site_id = cur_rec.vendor_site_id
            and xx.bu_name = cur_rec.bu_name;
        end;
      end loop;
      
      log('End of suppliers sites download');
      
      log('Parsing report response for suppliers contacts');
      
          FOR cur_rec IN (
      SELECT xt.*
      FROM   XMLTABLE('/DATA_DS/SUPPLIER_CONTACTS'
               PASSING l_resp_xml_id
               COLUMNS 
                   VENDOR_CONTACT_ID NUMBER PATH 'VENDOR_CONTACT_ID', 
                   VENDOR_ID NUMBER PATH 'VENDOR_ID',
                   PER_PARTY_ID NUMBER PATH 'PER_PARTY_ID',
                   PARTY_SITE_ID VARCHAR2(60) PATH 'PARTY_SITE_ID',
                   PERSON_FIRST_NAME VARCHAR2(600) PATH 'PERSON_FIRST_NAME',
                   PERSON_LAST_NAME VARCHAR2(600) PATH 'PERSON_LAST_NAME',
                   EMAIL_ADDRESS VARCHAR2(1280) PATH 'EMAIL_ADDRESS',
                   INACTIVE_DATE VARCHAR2(35) PATH 'INACTIVE_DATE',
                   CREATION_DATE VARCHAR2(35) PATH 'CREATION_DATE',
                   LAST_UPDATE_DATE VARCHAR2(35) PATH 'LAST_UPDATE_DATE'
               ) xt)
      LOOP
  
        log('====================');
        log('Vendor contact ID:'||cur_rec.VENDOR_CONTACT_ID);
        log('Party site ID:'||cur_rec.PARTY_SITE_ID);
        log('First name Id:'||cur_rec.PERSON_FIRST_NAME);
        log('Last name:'||cur_rec.PERSON_LAST_NAME);
        log('==============================');
        
        
        log('Inserting supplier address into table');
        l_sup_cont_rec.vendor_contact_id := cur_rec.vendor_contact_id;
        l_sup_cont_rec.vendor_id := cur_rec.vendor_id;
        l_sup_cont_rec.PER_PARTY_ID := cur_rec.PER_PARTY_ID;
        l_sup_cont_rec.PARTY_SITE_ID := cur_rec.PARTY_SITE_ID;
        l_sup_cont_rec.PERSON_FIRST_NAME := cur_rec.PERSON_FIRST_NAME;
        l_sup_cont_rec.PERSON_LAST_NAME := cur_rec.PERSON_LAST_NAME;
        l_sup_cont_rec.EMAIL_ADDRESS := cur_rec.EMAIL_ADDRESS;
        l_sup_cont_rec.inactive_date := cast(to_timestamp_tz(  cur_rec.inactive_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
        l_sup_cont_rec.creation_date := cast(to_timestamp_tz(  cur_rec.creation_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
        l_sup_cont_rec.last_update_date := cast(to_timestamp_tz(  cur_rec.last_update_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
        l_sup_cont_rec.transf_creation_date := sysdate;
        
        begin
        
          insert into xxdl_poz_supplier_contacts values l_sup_cont_rec;        
        
        exception
          when dup_val_on_index then
          log('Supplier site already in table, updating record!');
            update xxdl_poz_supplier_contacts xx
            set xx.vendor_contact_id = cur_rec.vendor_contact_id
            ,xx.per_party_id = cur_rec.per_party_id
            ,xx.vendor_id = cur_rec.vendor_id
            ,xx.party_site_id = cur_rec.party_site_id
            ,xx.PERSON_FIRST_NAME = cur_rec.PERSON_FIRST_NAME
            ,xx.PERSON_LAST_NAME = cur_rec.PERSON_LAST_NAME
            ,xx.EMAIL_ADDRESS = cur_rec.EMAIL_ADDRESS
            ,xx.inactive_date = cast(to_timestamp_tz(  cur_rec.inactive_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
            ,xx.creation_date = cast(to_timestamp_tz(  cur_rec.creation_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
            ,xx.last_update_date =cast(to_timestamp_tz(  cur_rec.last_update_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
            ,xx.transf_last_update = sysdate
            where xx.vendor_contact_id = cur_rec.vendor_contact_id;
        end;
      end loop;
      log('End of suppliers contacts download');      
      
end if;
return x_return_status;
exception
  when XX_NO_REPORT then
    log('Cant find the report for call ID:'||x_ws_call_id);
    return 'E';
  when others then
  rollback;
    log('Error occured during web service call for sending csv to cloud: '||sqlcode);
      log('Msg:'||sqlerrm);
      log('Error_Stack...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_STACK());
      log('Error_Backtrace...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE());
      return 'E';
END get_suppliers;

/*===========================================================================+
Function   : get_supplier_info
Description : retrieves all supplier (supplier, site, address, contact) info to a local EBS custom table
Usage       : Callin from concurrent program xxdl_CS_SUPPLIER_DL_PRG
Arguments   :
Remarks     :
============================================================================+*/
procedure get_supplier_info (errbuf out varchar2, retcode out varchar2) is


l_max_date date;
l_max_date_empty date;
l_status varchar2(1);
begin

 retcode:=0;
 errbuf:= 'Success';

  log('Get max date of creation or update from xxdl_poz_suppliers');
  
  l_max_date := l_max_date_empty;
  
  begin
  
    select
      case
        when max(xx.creation_date) > max(xx.last_update_date) then
          max(xx.creation_date)
        else max(xx.last_update_date)
        end
    into l_max_date
    from
    xxdl_poz_suppliers xx;
  exception
    when NO_DATA_FOUND then
      l_max_date := to_date('01.12.2017 00:00:00','DD.MM.RRRR HH24:MI:SS');
  end;
  
  if l_max_date is null then
    l_max_date := to_date('01.12.2017 00:00:00','DD.MM.RRRR HH24:MI:SS');  
  end if;
  
  log('Max date for SUPPLIERS is:'||to_char(l_max_date,'YYYY-MM-DD HH24:MI:SS'));
  
  log('Calling cloud report for SUPPLIER download');
  
  l_status := get_suppliers('SUPPLIERS',to_char(l_max_date,'YYYY-MM-DD HH24:MI:SS'));
    
  log('Supplier download status:'||l_status);
  
  log('Get max date of creation or update from xxdl_poz_supplier_addresses');
  
  l_max_date := l_max_date_empty;
  
  begin
  
    select
      case
        when max(xx.creation_date) > max(xx.last_update_date) then
          max(xx.creation_date)
        else max(xx.last_update_date)
        end
    into l_max_date
    from
    xxdl_poz_supplier_addresses xx;
  exception
    when NO_DATA_FOUND then
      l_max_date := to_date('01.12.2017 00:00:00','DD.MM.RRRR HH24:MI:SS'); 
  end;
  
  if l_max_date is null then
    l_max_date := to_date('01.12.2017 00:00:00','DD.MM.RRRR HH24:MI:SS');   
  end if;
  
  log('Max date for SUPPLIER_ADDRESSES is:'||to_char(l_max_date,'YYYY-MM-DD HH24:MI:SS'));
  
  log('Calling cloud report for SUPPLIER_ADDRESSES download');
  
  l_status := get_suppliers('SUPPLIER_ADDRESSES',to_char(l_max_date,'YYYY-MM-DD HH24:MI:SS'));
    
  log('Supplier addresses download status:'||l_status);
  
  log('Get max date of creation or update from xxdl_poz_supplier_sites');
  
  l_max_date := l_max_date_empty;
  
  begin
  
    select
      case
        when max(xx.creation_date) > max(xx.last_update_date) then
          max(xx.creation_date)
        else max(xx.last_update_date)
        end
    into l_max_date
    from
    xxdl_poz_supplier_sites xx;
  exception
    when NO_DATA_FOUND then
      l_max_date := to_date('01.12.2017 00:00:00','DD.MM.RRRR HH24:MI:SS'); 
  end;
  
  if l_max_date is null then
    l_max_date := to_date('01.12.2017 00:00:00','DD.MM.RRRR HH24:MI:SS');   
  end if;
  
  log('Max date for SUPPLIERS_SITES is:'||to_char(l_max_date,'YYYY-MM-DD HH24:MI:SS'));
  
  log('Calling cloud report for SUPPLIER_SITES download');
  
  l_status := get_suppliers('SUPPLIER_SITES',to_char(l_max_date,'YYYY-MM-DD HH24:MI:SS'));
    
  log('Supplier sites download status:'||l_status);
  
  log('Get max date of creation or update from xxdl_poz_supplier_contacts');
  
  l_max_date := l_max_date_empty;
  
  begin
  
    select
      case
        when max(xx.creation_date) > max(xx.last_update_date) then
          max(xx.creation_date)
        else max(xx.last_update_date)
        end
    into l_max_date
    from
    xxdl_poz_supplier_contacts xx;
  exception
    when NO_DATA_FOUND then
      l_max_date := to_date('01.12.2017 00:00:00','DD.MM.RRRR HH24:MI:SS'); 
  end;
  
  if l_max_date is null then
    l_max_date := to_date('01.12.2017 00:00:00','DD.MM.RRRR HH24:MI:SS');  
  end if;
  
  log('Max date for SUPPLIER_CONTACTS is:'||to_char(l_max_date,'YYYY-MM-DD HH24:MI:SS'));
  
  log('Calling cloud report for SUPPLIER_CONTACTS download');
  
  l_status := get_suppliers('SUPPLIER_CONTACTS',to_char(l_max_date,'YYYY-MM-DD HH24:MI:SS'));
    
  log('Supplier contacts download status:'||l_status);
  
  log('Download procedure is finished');
  

exception
  when others then
     retcode := 2;
     errbuf := 'Error';
     log('Error occured during web service call for sending csv to cloud: '||sqlcode);
      log('Msg:'||sqlerrm);
      log('Error_Stack...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_STACK());
      log('Error_Backtrace...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE());

end;


 /*===========================================================================+
  -- Name    : find_supplier_site
  -- Desc    : Find existing supplier site
  -- Usage   : 
  -- Parameters
============================================================================+*/

function find_existing_supplier(p_bu_name in varchar2,p_vendor_site_code in varchar2) return number is 
l_count number :=0 ;

begin

  begin
  select count(*)
  into l_count
  from
  xxdl_poz_supplier_sites xx
  where xx.bu_name = p_bu_name
  and xx.vendor_site_code = p_vendor_site_code;
  exception
    when no_data_found then
      l_count := 0;
  end;    

  return l_count;

end;

 /*===========================================================================+
  -- Name    : find_supplier_site_assign
  -- Desc    : Find existing supplier site assign
  -- Usage   : 
  -- Parameters
============================================================================+*/

function find_site_suplier_assign(p_bu_name in varchar2,p_vendor_site_id in number) return number is 
l_count number :=0 ;

begin

  begin
  select count(*)
  into l_count
  from
  xxdl_poz_supplier_sites xx
  where xx.bu_name = p_bu_name
  and xx.vendor_site_id = p_vendor_site_id
  and nvl(xx.CLOUD_SITE_ASSIGNMENT,'X') = 'Y';
  exception
    when no_data_found then
      l_count := 0;
  end;    

  return l_count;

end;

 /*===========================================================================+
  -- Name    : find_supplier_contact
  -- Desc    : Find existing supplier contact
  -- Usage   : 
  -- Parameters
============================================================================+*/

function find_supplier_contact(p_first_name in varchar2, p_last_name in varchar2, p_party_site_id in number) return number is 
l_count number :=0 ;

begin

  begin
  select count(*)
  into l_count
  from
  xxdl_poz_supplier_contacts xx
  where xx.party_site_id = p_party_site_id
  and xx.person_first_name = p_first_name 
  and xx.person_last_name = p_last_name
  and nvl(xx.cloud_imported,'X') = 'Y';
  exception
    when no_data_found then
      l_count := 0;
  end;    

  return l_count;

end;

 /*===========================================================================+
  -- Name    : find_supplier_contact_address
  -- Desc    : Find existing supplier contact address
  -- Usage   : 
  -- Parameters
============================================================================+*/

function find_supplier_contact_address(p_first_name in varchar2, p_last_name in varchar2, p_party_site_id in number) return number is 
l_count number :=0 ;

begin

  begin
  select count(*)
  into l_count
  from
  xxdl_poz_supplier_contacts xx
  where xx.party_site_id = p_party_site_id
  and xx.person_first_name = p_first_name 
  and xx.person_last_name = p_last_name
  and nvl(xx.cloud_imported,'X') = 'Y'
  and nvl(xx.cloud_address_assign,'X') = 'Y';
  exception
    when no_data_found then
      l_count := 0;
  end;    

  return l_count;

end;


 /*===========================================================================+
  -- Name    : migrate_suppliers_cloud
  -- Desc    : Migrate supppliers based on imported customers
  -- Usage   : 
  -- Parameters
============================================================================+*/
procedure migrate_suppliers_cloud(
      p_party_number in varchar2) is

    l_fault_code          varchar2(4000);
    l_fault_string        varchar2(4000); 
    l_soap_env clob;
    l_empty_clob clob;
    l_text varchar2(32000);
    l_find_text varchar2(32000);
    x_return_status varchar2(500);
    x_return_message varchar2(32000);
    x_ws_call_id number;
    xs_ws_call_id number;
    xsa_ws_call_id number;    
    xc_ws_call_id number;    
    xca_ws_call_id number;
    xb_ws_call_id number;
    xbo_ws_call_id number;
    xba_ws_call_id number;
    xp_ws_call_id number;
    xpa_ws_call_id number;
    xt_ws_call_id number;
    xf_ws_call_id number;
    l_cnt number := 0;
    l_cloud_party_id number:=0;     
    l_app_url varchar2(300);

    l_existing_site varchar2(1) := 'N';
    l_existing_site_assign varchar2(1) := 'N';
    l_existing_site_contact varchar2(1) := 'N';
    l_existing_site_bank varchar2(1) := 'N';

    l_site_rec xxdl_poz_supplier_sites%ROWTYPE;
    l_site_rec_empty xxdl_poz_supplier_sites%ROWTYPE;
    l_contact_rec xxdl_poz_supplier_contacts%ROWTYPE;
    l_contact_rec_empty xxdl_poz_supplier_contacts%ROWTYPE;
    l_bank_acc_rec XXDL_POZ_SUPPLIER_BANK_ACC%ROWTYPE;
    l_bank_acc_rec_empty XXDL_POZ_SUPPLIER_BANK_ACC%ROWTYPE;
    
    cursor c_supplier_address is
    select distinct
    xx_psa.*,xx_hp.taxpayer_id,xx_hp.party_id,xx_hp.cloud_party_id,xx_cust_site.party_site_id party_site_id_orig,xx_cust_site.cloud_party_site_id
    ,xx_hp.party_name vendor_name
    ,xx_hp.party_number
    ,xx_ps.supplier_number
    ,nvl(initcap(pvs.language),'Croatian') language
    from
    XXDL_POZ_SUPPLIER_ADDRESSES XX_PSA
    ,xxdl_hz_cust_acct_sites xx_cust_site
    ,xxdl_hz_cust_accounts xx_hca
    ,xxdl_hz_parties xx_hp 
    ,xxdl_poz_suppliers xx_ps
    ,apps.hz_party_sites@ebsprod hps
    ,apps.po_vendor_sites_all@ebsprod pvs
    WHERE
    xx_psa.party_site_id = xx_cust_site.cloud_party_site_id
    and xx_cust_site.cust_account_id = xx_hca.cust_account_id
    and xx_hca.party_id = xx_hp.party_id
    and xx_psa.vendor_id = xx_ps.vendor_id
    and xx_cust_site.party_site_id = hps.party_site_id
    and to_char(hps.party_site_number) = pvs.attribute3
    and xx_cust_site.org_id = pvs.org_id
    and xx_hp.party_number like nvl(p_party_number,'%')  
    ;

    cursor c_supplier_contacts(c_vendor_site_id in number) is 
    select 
    *
    from
    apps.po_vendor_contacts@ebstest pvc 
    where pvc.vendor_site_id = c_vendor_site_id;


begin


l_app_url := get_config('ServiceRootURL');


for c_sa in c_supplier_address loop
  
  log(' Found supplier address:'||c_sa.address);

  if nvl(c_sa.taxpayer_id,'X') != 'X' then
    dbms_lob.createtemporary(l_soap_env, TRUE);

    log('   Updating tax info!');

    l_find_text := '{
        "TaxRegistrationCountryCode" : "'||c_sa.country||'",
        "TaxRegistrationNumber" : "'||c_sa.country||c_sa.taxpayer_id||'"
    }';

    l_soap_env := l_soap_env||to_clob(l_find_text);

    log ('    Calling web service:');

    XXFN_CLOUD_WS_PKG.WS_REST_CALL(
        p_ws_url => l_app_url||'fscmRestApi/resources/11.13.18.05/suppliers/'||c_sa.vendor_id,
        p_rest_env => l_soap_env,
        p_rest_act => 'PATCH',
        p_content_type => 'application/json;charset="UTF-8"',
        x_return_status => x_return_status,
        x_return_message => x_return_message,
        x_ws_call_id => x_ws_call_id);
        
    log('     Web service status:'||x_return_status);
    if x_return_status = 'S' then
        log('       Updated tax information!');
        x_ws_call_id := null;
    else
        x_return_message := get_ws_err_msg(x_ws_call_id);
        log('     Web service message:'||x_return_message);
    end if;
    
    log('     Web service call:'||x_ws_call_id);

    dbms_lob.freetemporary(l_soap_env);

  end if; 

  log(' Updating order purpose flags!');
  dbms_lob.createtemporary(l_soap_env, TRUE);

  l_find_text := '{
    "AddressPurposeOrderingFlag" : "Y",
    "AddressPurposeRemitToFlag" : "Y",
    "AddressPurposeRFQOrBiddingFlag" : "Y",
    "Language" : "'||c_sa.language||'"
  }';

  l_soap_env := l_soap_env||to_clob(l_find_text);

  log ('    Calling web service:');

  XXFN_CLOUD_WS_PKG.WS_REST_CALL(
      p_ws_url => l_app_url||'fscmRestApi/resources/11.13.18.05/suppliers/'||c_sa.vendor_id||'/child/addresses/'||c_sa.party_site_id,
      p_rest_env => l_soap_env,
      p_rest_act => 'PATCH',
      p_content_type => 'application/json;charset="UTF-8"',
      x_return_status => x_return_status,
      x_return_message => x_return_message,
      x_ws_call_id => x_ws_call_id);
      
  log('     Web service status:'||x_return_status);
  if x_return_status = 'E' then
    x_return_message := get_ws_err_msg(x_ws_call_id);
    log('     Web service message:'||x_return_message);
  end if;
  
  log('     Web service call:'||x_ws_call_id);

  dbms_lob.freetemporary(l_soap_env);

  if x_return_status = 'S' then

    log('   Address purpose updated! For pary_site_id:'||c_sa.party_site_id); 
    log('   Next, creating site for address!');

    update xxdl_poz_supplier_addresses xx
    set xx.cloud_imported = 'S'
    where xx.party_site_id = c_sa.party_site_id;

    for c_a in (          
            select distinct
            jt.address_id
            ,jt.address_name
            ,jt.country
            ,xx_set.business_unit_id
            ,xx_set.business_unit_name
            ,pvs.vendor_site_code
            ,case
                when pvs.PRIMARY_PAY_SITE_FLAG = 'Y' then
                    'true'
                else
                    'false'
                end PRIMARY_PAY_SITE_FLAG
            ,case 
              when (nvl(pvs.email_address,'X') != 'X' and nvl(pvs.phone,'X') = 'X' and nvl(pvs.fax,'X') = 'X') then
                'EMAIL'
              when ( (nvl(pvs.fax,'X') != 'X' or nvl(pvs.phone,'X') != 'X') and nvl(pvs.email_address,'X') = 'X' and nvl(pvs.phone,'X') != 'X' ) then
                'FAX'
              else 'NONE'  end communication_method_code
            ,nvl(pvs.email_address,pvc.email_address) email_address                             --,EMAIL_ADDRESS (email address)
            ,null phone_country
            ,decode(nvl(substr(pvs.phone,1,3),'X'),'X',substr(pvs.fax,1,3),pvs.FAX_AREA_CODE)  fax_area_code                                --ovdje ide pozivni broj zemlje koji nemamo u ebs decode(povs.phone,null,null,povs.FAX_AREA_CODE) --,FAX_AREA_CODE                     (Fax Area Code)
            ,CASE
            when nvl(pvs.FAX,pvs.phone) != 'X' then
                nvl(pvs.FAX,pvs.phone)
            else null end fax_number  
            ,pvs.FREIGHT_TERMS_LOOKUP_CODE                  --,FREIGHT_TERMS_LOOKUP_CODE (Freight Terms)     
            ,pvs.PAY_ON_CODE                                --,PAY_ON_CODE (Pay on receipt)                 
            ,pvs.FOB_LOOKUP_CODE                            --,FOB_LOOKUP_CODE (FOB)
            ,pvs.COUNTRY_OF_ORIGIN_CODE
            ,pvs.PAY_ON_RECEIPT_SUMMARY_CODE                --,PAY_ON_RECEIPT_SUMMARY_CODE     (Invoice Summary Level) PAY_SITE/PACKING_SLIP/RECEPIT
            ,case
                when pvs.PRIMARY_PAY_SITE_FLAG = 'Y' then
                    'true'
                else
                    'false'
                end GAPLESS_INV_NUM_FLAG                       --,GAPLESS_INV_NUM_FLAG            (Gapless invoice numbering)
            ,pvs.SELLING_COMPANY_IDENTIFIER                 --,SELLING_COMPANY_IDENTIFIER (Selling Company Identifier)
            ,case
                when pvs.create_debit_memo_flag = 'Y' then
                    'true'
                else
                    'false'
                end create_debit_memo_flag                    --,CREATE_DEBIT_MEMO_FLAG (Create debit memo from return)
            ,pv.ENFORCE_SHIP_TO_LOCATION_CODE                --,ENFORCE_SHIP_TO_LOCATION_CODE (Ship-to Exception Action )
            ,pv.RECEIVING_ROUTING_ID                         --,RECEIVING_ROUTING_ID (Receipt Routing )
            ,pv.QTY_RCV_TOLERANCE                            --,QTY_RCV_TOLERANCE    (Over-receipt Tolerance)
            ,pv.QTY_RCV_EXCEPTION_CODE                       --,QTY_RCV_EXCEPTION_CODE  (Over-receipt Action)
            ,pv.DAYS_EARLY_RECEIPT_ALLOWED                   --,DAYS_EARLY_RECEIPT_ALLOWED (Early Receipt Tolerance in Days)
            ,pv.DAYS_LATE_RECEIPT_ALLOWED                    --,DAYS_LATE_RECEIPT_ALLOWED (Late Receipt Tolerance in Days)
            ,pv.ALLOW_SUBSTITUTE_RECEIPTS_FLAG                --,ALLOW_SUBSTITUTE_RECEIPTS_FLAG (Allow Substitute Receipts)
            ,pv.ALLOW_UNORDERED_RECEIPTS_FLAG                 --,ALLOW_UNORDERED_RECEIPTS_FLAG (Allow unordered receipts)
            ,pv.RECEIPT_DAYS_EXCEPTION_CODE                   --,RECEIPT_DAYS_EXCEPTION_CODE (Receipt Date Exception)
            ,pv.INVOICE_CURRENCY_CODE                         --,INVOICE_CURRENCY_CODE (Invoice Currency)
            ,pvs.INVOICE_AMOUNT_LIMIT                        --,INVOICE_AMOUNT_LIMIT (Invoice Amount Limit)
            ,pvs.MATCH_OPTION                                --, MATCH_OPTION Invoice Match Option)
            ,case 
              when pv.RECEIVING_ROUTING_ID = 2 then 
                'FOUR'
              when pv.RECEIVING_ROUTING_ID = 3 then
                'THREE'
              else null end MATCH_APPROVAL_LEVEL -- (Match Approval Level)
            ,pvs.PAYMENT_CURRENCY_CODE                               --,PAYMENT_CURRENCY_CODE (Payment Currency)
            ,pvs.PAYMENT_PRIORITY                                    --,PAYMENT_PRIORITY (Payment Priority)
            ,'DOMESTIC' PAY_GROUP_LOOKUP_CODE --pvs.PAY_GROUP_LOOKUP_CODE                               --,PAY_GROUP_LOOKUP_CODE (Pay Group)
            ,null --pvs.tolerance_id                                 --,TOLERANCE_NAME (Quantity Tolerances)
            ,null --pvs.service_tolerance_id                         --,SERVICES_TOLERANCE (Amount Tolerance)
            ,case
                when pvs.HOLD_ALL_PAYMENTS_FLAG = 'Y' then
                    'true'
                else
                    'false'
                end HOLD_ALL_PAYMENTS_FLAG                              --,HOLD_ALL_PAYMENTS_FLAG (Hold All Invoices)
            ,pvs.HOLD_UNMATCHED_INVOICES_FLAG                       --,HOLD_UNMATCHED_INVOICES_FLAG    (Hold Unmatched Invoices)                    
            ,case
                when pvs.HOLD_FUTURE_PAYMENTS_FLAG = 'Y' then
                    'true'
                else
                    'false'
                end HOLD_FUTURE_PAYMENTS_FLAG                           --,HOLD_FUTURE_PAYMENTS_FLAG  (Hold Unvalidated Invoices)
            ,pv.HOLD_BY                                               --,HOLD_BY  (Payment Hold By)
            ,pv.HOLD_DATE                                             --,HOLD_DATE  (Payment Hold Date)
            ,case
                when pvs.HOLD_ALL_PAYMENTS_FLAG = 'Y' then
                'Hold All Invoices'
                when pvs.HOLD_UNMATCHED_INVOICES_FLAG = 'Y' then
                'Hold Unmatched Invoices'
                when pvs.HOLD_FUTURE_PAYMENTS_FLAG = 'Y' then
                'Hold Unvalidated Invoices'
                else pv.HOLD_REASON     end hold_reason
            ,pv.terms_id --TERMS_NAME
            ,pv.TERMS_DATE_BASIS                                      --TERMS_DATE_BASIS (Terms Date Basis)
            ,pv.PAY_DATE_BASIS_LOOKUP_CODE
            ,null                                                     --BANK_CHARGE_DEDUCTION_TYPE
            ,pv.ALWAYS_TAKE_DISC_FLAG                                   --,ALWAYS_TAKE_DISC_FLAG
            ,pv.EXCLUDE_FREIGHT_FROM_DISCOUNT                         --,EXCLUDE_FREIGHT_FROM_DISCOUNT
            ,null                                                     --,EXCLUDE_TAX_FROM_DISCOUNT
            ,pv.AUTO_CALCULATE_INTEREST_FLAG                          --,AUTO_CALCULATE_INTEREST_FLAG
            ,pvs.VAT_CODE                                            --,VAT_CODE
            ,pv.VAT_REGISTRATION_NUM                                  --,VAT_REGISTRATION_NUM
            ,apt.name term_name
            ,gcc_l.segment1||'.'||gcc_l.segment2||'.'||gcc_l.segment3||'.'||gcc_l.segment4||'.'||gcc_l.segment5||'.'||gcc_l.segment6||'.'||gcc_l.segment7||'.0.000000.000000' liability
            ,gcc_p.segment1||'.'||gcc_p.segment2||'.'||gcc_p.segment3||'.'||gcc_p.segment4||'.'||gcc_p.segment5||'.'||gcc_p.segment6||'.'||gcc_p.segment7||'.0.000000.000000'  prepayment
            ,pvs.vendor_site_id
            ,xx_bank.bank_number
            ,xx_bank.bank_party_id cloud_branch_id
            ,xx_bank.branch_party_id cloud_bank_id
            ,bank_acc.bank_branch_id
            ,bank_acc.bank_account_name
            ,bank_acc.bank_account_num
            ,bank_acc.address_line1
            ,bank_acc.iban_number
            ,bank_acc.country bank_country            
            ,bank_acc.EFT_SWIFT_CODE
            ,bank_acc.bank_name
            from
            xxfn_ws_call_log xx,
            json_table(xx.response_json,'$'
                columns(
                                address_id number path '$.SupplierAddressId',
                                address_name varchar2(30) path '$.AddressName',
                                country varchar2(3) path '$.CountryCode')) jt
            ,xxdl_hz_cust_acct_sites xx_cust_site      
            ,xxdl_cloud_reference_sets xx_set        
            ,apps.hz_party_sites@ebstest hps      
            ,apps.hz_cust_accounts@ebstest hca
            ,apps.hz_parties@ebstest hp
            ,apps.po_vendor_sites_all@ebstest pvs
            ,apps.po_vendors@ebstest pv
            ,(select * from apps.ap_terms_tl@ebstest
            where language = 'US') apt
            ,apps.gl_code_combinations@ebstest gcc_l
            ,apps.gl_code_combinations@ebstest gcc_p
            ,apps.po_vendor_contacts@ebstest pvc
            ,(select
            pv.vendor_name
            ,bauses.bank_account_uses_id
            ,bauses.customer_id
            ,bauses.customer_site_use_id
            ,bauses.external_bank_account_id
            ,bacct.bank_account_id
            ,bauses.primary_flag
            ,bauses.org_id uses_org_id
            ,bbnch.bank_branch_id
            ,bbnch.bank_name
            ,bbnch.bank_branch_name
            ,bbnch.bank_number
            ,bbnch.description
            ,bbnch.address_line1
            ,bbnch.address_line2
            ,bbnch.address_line3
            ,bbnch.address_line4
            ,bbnch.city
            ,bbnch.country
            ,bbnch.institution_type
            ,bbnch.EFT_SWIFT_CODE
            ,bacct.iban_number
            ,bacct.bank_account_name
            ,bacct.bank_account_id
            ,bacct.bank_account_num
            ,bacct.currency_code
            ,bacct.set_of_books_id
            ,bacct.account_type
            ,bacct.org_id
            ,bauses.vendor_site_id
            ,bauses.vendor_id 
            FROM
                apps.ap_bank_account_uses_all@ebsprod bauses,
                apps.ap_bank_branches@ebsprod     bbnch,
                apps.ap_bank_accounts_all@ebsprod     bacct,
                apps.po_vendors@ebsprod pv,
                apps.po_vendor_sites_all@ebsprod pvs
            WHERE
                    bauses.external_bank_account_id = bacct.bank_account_id
                AND bacct.bank_branch_id = bbnch.bank_branch_id
                and bauses.vendor_id = pv.vendor_id
                and bauses.vendor_site_id = pvs.vendor_site_id
                and bauses.vendor_id = pvs.vendor_id
                and exists (select
                    1 from     
                    apps.ap_invoices_all@ebsprod aia,
                    apps.ap_payment_schedules_all@ebsprod apsa
                    where aia.invoice_id = apsa.invoice_id
                    and aia.vendor_site_id = pvs.vendor_site_id
                    and apsa.external_bank_account_id = bacct.bank_account_id
--                    and to_char(aia.creation_date,'YYYY') > :p_year
                    )
                ) bank_acc
            ,xxdl_bank_branches xx_bank    
            where xx.ws_call_id = x_ws_call_id   
            and jt.address_id = xx_cust_site.cloud_party_site_id(+)        
            and xx_cust_site.party_site_id = hps.party_site_id(+)
            and xx_cust_site.cloud_set_id = xx_set.reference_data_set_id(+) 
            and xx_cust_site.cust_account_id = hca.cust_account_id
            and hca.party_id = hp.party_id(+)
            and to_char(hps.party_site_number) = pvs.attribute3(+)
            and xx_cust_site.org_id = pvs.org_id
            and pvs.terms_id = apt.term_id(+)
            and pvs.accts_pay_code_combination_id=gcc_l.code_combination_id
            and pvs.prepay_code_combination_id=gcc_p.code_combination_id
            and pvs.vendor_id = pv.vendor_id
            and pvs.vendor_site_id = pvc.vendor_site_id(+)
            and pvs.vendor_site_id = bank_acc.vendor_site_id(+)
            and bank_acc.bank_branch_name = xx_bank.bank_branch_name(+)) loop

        log('	        Found address name:'||c_a.address_name);

        l_existing_site := 'N';
        l_existing_site_assign := 'N';
        l_existing_site_contact := 'N';


        if find_existing_supplier(c_a.business_unit_name,c_a.vendor_site_code) > 0 then

            log('           Supplier site already exists! Going to create assignment and setting status to success!');
            l_existing_site := 'Y';
            xs_ws_call_id := x_ws_call_id;
            x_return_status := 'S';
            GOTO create_assignment;
        end if;    



        l_soap_env := l_empty_clob;
        dbms_lob.createtemporary(l_soap_env, TRUE);

        l_text := '{
            "SupplierSite": "'||c_a.vendor_site_code||'",
            "ProcurementBU": "'||c_a.business_unit_name||'",
            "SupplierAddressName": "'||c_a.address_name||'",
            "InactiveDate": null,
            "SitePurposeSourcingOnlyFlag": false,
            "SitePurposePurchasingFlag": true,
            "SitePurposeProcurementCardFlag": false,
            "SitePurposePayFlag": true,
            "SitePurposePrimaryPayFlag": '||c_a.PRIMARY_PAY_SITE_FLAG||',
            "CommunicationMethodCode": "'||c_a.communication_method_code||'",
            "Email": "'||c_a.email_address||'",
            "FaxNumber": "'||c_a.fax_number ||'",
            "FOBCode": "'||c_a.FOB_LOOKUP_CODE||'",
            "HoldAllNewPurchasingDocumentsFlag": false,
            "PurchasingHoldReason": null,
            "RequiredAcknowledgmentCode": "D",
            "AcknowledgmentWithinDays": 7,
            "PayOnReceiptFlag": false, 
            "CountryOfOriginCode": "'||c_a.country_of_origin_code||'",
            "BuyerManagedTransportationCode": "N",
            "CreateDebitMemoFromReturnFlag": '||c_a.create_debit_memo_flag||',
            "ReceiptRoutingId": "'||c_a.RECEIVING_ROUTING_ID||'",
            "OverReceiptTolerance": "'||c_a.qty_rcv_tolerance||'",
            "OverReceiptActionCode": "'||c_a.QTY_RCV_EXCEPTION_CODE||'",
            "EarlyReceiptToleranceInDays": "'||c_a.days_early_receipt_allowed||'",
            "LateReceiptToleranceInDays": "'||c_a.days_late_receipt_allowed||'",
            "AllowSubstituteReceiptsCode": "'||c_a.allow_substitute_receipts_flag||'",
            "AllowUnorderedReceiptsFlag": "'||c_a.allow_unordered_receipts_flag||'",
            "ReceiptDateExceptionCode": "'||c_a.RECEIPT_DAYS_EXCEPTION_CODE||'",
            "InvoiceCurrencyCode": "'||c_a.invoice_currency_code||'",
            "InvoiceAmountLimit": "'||c_a.invoice_amount_limit||'",
            "InvoiceMatchOptionCode": "'||c_a.match_option||'",
            "MatchApprovalLevelCode": "'||c_a.MATCH_APPROVAL_LEVEL||'",
            "PaymentCurrencyCode": "'||c_a.payment_currency_code||'",
            "PaymentPriority": "'||c_a.PAYMENT_PRIORITY||'",
            "PayGroupCode": "'||c_a.PAY_GROUP_LOOKUP_CODE||'",
            "HoldAllInvoicesFlag": '||c_a.HOLD_ALL_PAYMENTS_FLAG||',
            "HoldUnmatchedInvoicesCode": "'||c_a.HOLD_UNMATCHED_INVOICES_FLAG||'",
            "PaymentHoldReason": "'||c_a.hold_reason||'",
            "PaymentTerms": "'||c_a.term_name||'",
            "PaymentTermsDateBasisCode": "'||c_a.TERMS_DATE_BASIS||'",
            "PayDateBasisCode": "'||c_a.PAY_DATE_BASIS_LOOKUP_CODE||'",
            "BankChargeDeductionTypeCode": "D",
            "AlwaysTakeDiscountCode": "D",
            "ExcludeFreightFromDiscountCode": "D",
            "ExcludeTaxFromDiscountCode": "D",
            "CreateInterestInvoicesCode": "D"            
        }';

        l_soap_env := l_soap_env||to_clob(l_text);       

        log('       Calling web service to create supplier site');

        XXFN_CLOUD_WS_PKG.WS_REST_CALL(
            p_ws_url => l_app_url||'fscmRestApi/resources/11.13.18.05/suppliers/'||c_sa.vendor_id||'/child/sites',
            p_rest_env => l_soap_env,
            p_rest_act => 'POST',
            p_content_type => 'application/json;charset="UTF-8"',
            x_return_status => x_return_status,
            x_return_message => x_return_message,
            x_ws_call_id => xs_ws_call_id);         
        
        log('       Web service status:'||x_return_status);
        if x_return_status = 'E' then
            x_return_message := get_ws_err_msg(xs_ws_call_id);
            log('     Web service message:'||x_return_message);
        end if;
        log('       Web service call:'||xs_ws_call_id);

        dbms_lob.freetemporary(l_soap_env);   

        l_text:=l_text; 

        <<create_assignment>>


        if x_return_status = 'S' then
            
            log('           Supplier site created!');
            log('           Previous web service call:'||xt_ws_call_id);
            log('           existing site flag:'||l_existing_site_assign);
            log('           Business unit:'||c_a.business_unit_name);
            log('           Vendor site code:'||c_a.vendor_site_code);
            l_site_rec.vendor_id := c_sa.vendor_id;
            l_site_rec.cloud_imported := 'Y';


             begin
                with json_response as
                    (
                    (
                        select
                        supplier_site_id
                        ,supplier_site
                        ,address_id
                        ,address_name
                        ,bu_name
                        from
                        xxfn_ws_call_log xx,
                        json_table(xx.response_json,'$'
                            columns(
                                            supplier_site_id number path '$.SupplierSiteId',
                                            supplier_site varchar2(100) path '$.SupplierSite',
                                            address_id number path '$.SupplierAddressId',
                                            address_name varchar2(140) path '$.SupplierAddressName',
                                            bu_name varchar2(240) path '$.ProcurementBU'))
                        where xx.ws_call_id = xs_ws_call_id
                        and l_existing_site = 'N' --when supplier site is freshly created
                        union                       
                        select 
                        xx.vendor_site_id
                        ,xx.vendor_site_code
                        ,xx.party_site_id address_id
                        ,'' address_name
                        ,xx.bu_name
                        from
                        xxdl_poz_supplier_sites xx
                        ,xxdl_cloud_reference_sets xx_set
                        ,xxdl_poz_supplier_addresses xx_adr
                        where xx.bu_name = c_a.business_unit_name
                        and xx.vendor_site_code = c_a.vendor_site_code
                        and xx.bu_name = xx_set.business_unit_name
                        and xx.party_site_id = xx_adr.party_site_id
                        and l_existing_site = 'Y'
                        )
                    )
                    select
                    nvl(jt.supplier_site_id,0)
                    ,jt.supplier_site
                    ,jt.address_id
                    ,sysdate
                    ,jt.bu_name
                    into l_site_rec.vendor_site_id
                    ,l_site_rec.vendor_site_code
                    ,l_site_rec.party_site_id
                    ,l_site_rec.creation_date
                    ,l_site_rec.bu_name
                    from
                    json_response jt
                    where rownum = 1
                    and jt.supplier_site_id is not null;

                    exception
                    when no_data_found then
                        l_site_rec.vendor_site_id := 0;

                end;

                log('           Cloud supplier site id:'||l_site_rec.vendor_site_id);
                log('           EBS supplier site id:'||c_a.vendor_site_id);

                begin
                    insert into xxdl_poz_supplier_sites xx values l_site_rec;
                    exception
                      when dup_val_on_index then
                        update xxdl_poz_supplier_sites xx
                        set xx.vendor_site_id = l_site_rec.vendor_site_id
                        ,xx.party_site_id = c_sa.party_site_id
                        ,xx.bu_name = l_site_rec.bu_name
                        ,xx.last_update_date = sysdate
                        where xx.vendor_site_id = l_site_rec.vendor_site_id
                        ;
                end;

                if find_site_suplier_assign(c_a.business_unit_name,l_site_rec.vendor_site_id) > 0 then
                    log('           Site assignment already exists in cloud! Skiping to contact creation and setting success status!');
                    l_existing_site_assign := 'Y';
                    GOTO create_contact;
                end if;

                l_text := '';
                log('       Creating site assignment!');

                l_soap_env := l_empty_clob;
                dbms_lob.createtemporary(l_soap_env, TRUE);

                l_text := '{
                    "ClientBUId" : '||c_a.business_unit_id||',
                    "BillToBU" : "'||c_a.business_unit_name||'",
                    "ShipToLocationId": null,
                    "BillToLocationCode": null,
                    "LiabilityDistribution": "'||c_a.liability||'",
                    "PrepaymentDistribution": "'||c_a.prepayment||'",
                    "InactiveDate": ""
                }';
                
                l_soap_env := l_soap_env||to_clob(l_text);       

                log('       Calling web service to create site assignment');

                XXFN_CLOUD_WS_PKG.WS_REST_CALL(
                    p_ws_url => l_app_url||'fscmRestApi/resources/11.13.18.05/suppliers/'||c_sa.vendor_id||'/child/sites/'||l_site_rec.vendor_site_id||'/child/assignments',
                    p_rest_env => l_soap_env,
                    p_rest_act => 'POST',
                    p_content_type => 'application/json;charset="UTF-8"',
                    x_return_status => x_return_status,
                    x_return_message => x_return_message,
                    x_ws_call_id => xsa_ws_call_id);         
                
                log('       Web service status:'||x_return_status);
                if x_return_status = 'E' then
                    x_return_message := get_ws_err_msg(xsa_ws_call_id);
                    log('       Web service message:'||x_return_message);
                end if;
                log('       Web service call:'||xsa_ws_call_id);

                dbms_lob.freetemporary(l_soap_env);   

                if x_return_status = 'S' then
                    log('       Assignment creation success!');

                    update xxdl_poz_supplier_sites xx
                    set xx.CLOUD_SITE_ASSIGNMENT = 'Y'
                    ,xx.cloud_import_message = x_return_message
                    where xx.party_site_id = c_sa.party_site_id
                    and xx.bu_name = c_a.business_unit_name;

                else
                    log('       Assignment creation failed!');
                    --log('       Message:'||x_return_message);
                    update xxdl_poz_supplier_sites xx
                    set xx.cloud_imported = 'S'
                    ,xx.CLOUD_SITE_ASSIGNMENT = 'E'
                    ,xx.cloud_import_message = x_return_message
                    where xx.party_site_id = c_sa.party_site_id
                    and xx.bu_name = c_a.business_unit_name;
                end if;

                <<create_contact>>

                log('               Start of creating contacts!');

                for c_va in c_supplier_contacts(c_a.vendor_site_id) loop
                    log('           Found contact:'||c_va.first_name||' '||c_va.last_name);
                    log('           Finding by first name:'||nvl(c_va.first_name,c_va.last_name));
                    log('           Finding by last name:'||c_va.last_name);
                    log('           Finding vendor site id:'||l_site_rec.vendor_site_id);


                    l_contact_rec.PERSON_FIRST_NAME := nvl(c_va.first_name,c_va.last_name);
                    l_contact_rec.PERSON_LAST_NAME := c_va.last_name;
                    l_contact_rec.EMAIL_ADDRESS := c_va.email_address;
                    l_contact_rec.CREATION_DATE := sysdate;
                    l_contact_rec.PARTY_SITE_ID := l_site_rec.vendor_site_id;
                    l_contact_rec.vendor_id := c_sa.vendor_id;
                    l_contact_rec.cloud_imported := 'Y';
                    
                    if find_supplier_contact(nvl(c_va.first_name,c_va.last_name),c_va.last_name,l_site_rec.vendor_site_id) > 0 then
                        log('           Contact already exists!Skipping to contact assign!');
                        GOTO contact_assign; 
                    end if;

                    l_soap_env := l_empty_clob;
                    dbms_lob.createtemporary(l_soap_env, TRUE);

                    l_text := '{ 
                        "FirstName": "'||nvl(c_va.first_name,c_va.last_name)||'",
                        "LastName": "'||c_va.last_name||'",
                        "Email": "'||c_va.email_address||'",
                        "PhoneAreaCode": "'||c_va.area_code||'",
                        "PhoneNumber": "'||c_va.phone||'"                            
                    }';
                    
                    l_soap_env := l_soap_env||to_clob(l_text);       

                    log('           Calling web service to create contact');

                    XXFN_CLOUD_WS_PKG.WS_REST_CALL(
                        p_ws_url => l_app_url||'fscmRestApi/resources/11.13.18.05/suppliers/'||c_sa.vendor_id||'/child/contacts',
                        p_rest_env => l_soap_env,
                        p_rest_act => 'POST',
                        p_content_type => 'application/json;charset="UTF-8"',
                        x_return_status => x_return_status,
                        x_return_message => x_return_message,
                        x_ws_call_id => xc_ws_call_id);         
                    
                    log('           Web service status:'||x_return_status);
                    if x_return_status = 'E' then
                        x_return_message := get_ws_err_msg(xc_ws_call_id);
                        log('           Web service message:'||x_return_message);
                    end if;
                    log('           Web service call:'||xc_ws_call_id);

                    dbms_lob.freetemporary(l_soap_env);   

                    <<contact_assign>>

                    if x_return_status = 'S' then
                        log('           Contact creation success!');

                        if find_supplier_contact_address(nvl(c_va.first_name,c_va.last_name),c_va.last_name,l_site_rec.vendor_site_id) > 0 then
                            log('           Contact assign already exists!Skipping!');
                            GOTO no_contact_assign; 
                        end if;

                         begin
                            with json_response as
                                (
                                (
                                    select
                                    supplier_contact_id
                                    from
                                    xxfn_ws_call_log xx,
                                    json_table(xx.response_json,'$'
                                        columns(
                                                        supplier_contact_id number path '$.SupplierContactId'))
                                    where xx.ws_call_id = xc_ws_call_id
                                    and xc_ws_call_id is not null --when supplier site is freshly created
                                    union                       
                                    select 
                                    xx_con.vendor_contact_id
                                    from
                                    xxdl_poz_supplier_sites xx
                                    ,xxdl_cloud_reference_sets xx_set
                                    ,xxdl_poz_supplier_addresses xx_adr
                                    ,xxdl_poz_supplier_contacts xx_con
                                    where xx.bu_name = c_a.business_unit_name
                                    and xx.vendor_site_code = c_a.vendor_site_code
                                    and xx.bu_name = xx_set.business_unit_name
                                    and xx.party_site_id = xx_adr.party_site_id
                                    and xx.party_site_id = xx_con.party_site_id
                                    and xc_ws_call_id is null
                                    )
                                )
                                select
                                nvl(jt.supplier_contact_id,0)
                                into l_contact_rec.vendor_contact_id
                                from
                                json_response jt
                                where rownum = 1
                                and jt.supplier_contact_id is not null;

                                exception
                                when no_data_found then
                                    l_contact_rec.vendor_contact_id := 0;

                            end;

                        log('               Supplier Contact Id:'||l_contact_rec.vendor_contact_id);

                        begin
                            insert into xxdl_poz_supplier_contacts xx values l_contact_rec;
                            exception
                            when dup_val_on_index then
                                update xxdl_poz_supplier_contacts xx
                                set xx.vendor_contact_id = l_contact_rec.vendor_contact_id
                                ,xx.last_update_date = sysdate
                                where xx.vendor_contact_id = l_contact_rec.vendor_contact_id
                                ;
                        end;    


                        log('               Now we need to assign contact to an address!');

                        l_text := '';
                        l_soap_env := l_empty_clob;
                        dbms_lob.createtemporary(l_soap_env, TRUE);

                        l_text := '{
                        "SupplierAddressId" : '||l_site_rec.party_site_id||'
                        }';
                    
                        l_soap_env := l_soap_env||to_clob(l_text);       

                        log('               Calling web service to create contact address!');

                        XXFN_CLOUD_WS_PKG.WS_REST_CALL(
                        p_ws_url => l_app_url||'fscmRestApi/resources/11.13.18.05/suppliers/'||c_sa.vendor_id||'/child/contacts/'||l_contact_rec.vendor_contact_id||'/child/addresses',
                        p_rest_env => l_soap_env,
                        p_rest_act => 'POST',
                        p_content_type => 'application/json;charset="UTF-8"',
                        x_return_status => x_return_status,
                        x_return_message => x_return_message,
                        x_ws_call_id => xca_ws_call_id);         
                    
                        log('               Web service status:'||x_return_status);
                        if x_return_status = 'E' then
                            x_return_message := get_ws_err_msg(xca_ws_call_id);
                            log('           Web service message:'||x_return_message);
                        end if;
                        log('               Web service call:'||xca_ws_call_id);

                        dbms_lob.freetemporary(l_soap_env);  

                        
                        if x_return_status = 'S' then

                            log('               Contact succesfully assigned to address!');

                            
                            update xxdl_poz_supplier_contacts xx
                            set xx.CLOUD_ADDRESS_ASSIGN = 'Y'
                            ,xx.last_update_date = sysdate
                            where xx.vendor_contact_id = l_contact_rec.vendor_contact_id;

                        else
                            log('               Contact failed assign address!');

                            
                            update xxdl_poz_supplier_contacts xx
                            set xx.CLOUD_ADDRESS_ASSIGN = 'E'
                            ,xx.last_update_date = sysdate
                            where xx.vendor_contact_id = l_contact_rec.vendor_contact_id;

                        end if;

                        <<no_contact_assign>>

                        log('               Continue..');


                    else

                        log('               Contact creation failed!');
                        --log('               Message:'||x_return_message);
                        update xxdl_poz_supplier_contacts xx
                        set xx.cloud_imported = 'E'
                        ,xx.cloud_import_message = x_return_message
                        where xx.party_site_id = l_contact_rec.party_site_id;

                    end if;

                    log('           Creating bank account!');

                    --starting bank account
                    if nvl(c_a.BANK_ACCOUNT_NUM,'X') = 'X' then
                        log('               There is no bank account to migrate!'); 
                    else 

                        begin
                        select xx.* into l_bank_acc_rec
                        from
                        XXDL_POZ_SUPPLIER_BANK_ACC xx
                        where xx.iban = c_a.iban_number;
                        exception
                          when no_data_found then
                          l_bank_acc_rec := null;
                        end;

                        if l_bank_acc_rec.EXT_BANK_ACCOUNT_ID > 0 then
                            log('                   Bank account already exists!');
                            log('                   Bank account id:'||l_bank_acc_rec.EXT_BANK_ACCOUNT_ID);
                            x_return_status := 'S';
                            GOTO bank_acc_exists;
                        end if;

                        --l_bank_acc_rec.EXT_BANK_ACCOUNT_ID := c_a.EXT_BANK_ACCOUNT_ID;
                        l_bank_acc_rec.BANK_NAME := c_a.bank_name;
                        l_bank_acc_rec.BANK_ADDRESS := c_a.address_line1;
                        l_bank_acc_rec.IBAN := c_a.iban_number;
                        l_bank_acc_rec.COUNTRY_CODE := c_a.country;
                        l_bank_acc_rec.BANK_ACCOUNT_NUM := c_a.BANK_ACCOUNT_NUM;
                        l_bank_acc_rec.START_DATE := sysdate;
                        l_bank_acc_rec.SIWFT_CODE := c_a.eft_swift_code;
                        l_bank_acc_rec.VENDOR_ID  := c_sa.VENDOR_ID ;
                        l_bank_acc_rec.PARTY_ID := c_sa.PARTY_ID;
                        l_bank_acc_rec.VENDOR_NAME := c_sa.VENDOR_NAME;
                        l_bank_acc_rec.SUPPLIER_NUMBER := c_sa.SUPPLIER_NUMBER;
                        l_bank_acc_rec.CREATION_DATE := sysdate;
                        l_bank_acc_rec.LAST_UPDATE_DATE := sysdate;
                        l_bank_acc_rec.PARTY_SITE_ID := c_sa.PARTY_SITE_ID_ORIG;
                        l_bank_acc_rec.SUPPLIER_SITE_ID := c_sa.vendor_site_id;
                        l_bank_acc_rec.BANK_BRANCH_ID := c_a.BANK_BRANCH_ID;
                        l_bank_acc_rec.CLOUD_PARTY_ID := c_sa.CLOUD_PARTY_ID;
                        l_bank_acc_rec.CLOUD_PARTY_SITE_ID := c_sa.PARTY_SITE_ID;
                        l_bank_acc_rec.CLOUD_SUPPLIER_SITE_ID := c_sa.VENDOR_SITE_ID;                               
                        l_bank_acc_rec.CLOUD_BANK_ID := c_a.CLOUD_BANK_ID;
                        l_bank_acc_rec.CLOUD_BRANCH_ID := c_a.CLOUD_BRANCH_ID;
                        l_bank_acc_rec.PROCESS_FLAG := 'S';
                        l_bank_acc_rec.ERROR_MESSAGE := '';

                        log('               Now we need to create the bank account:'||c_a.bank_account_name);

                        l_text := '';
                        l_soap_env := l_empty_clob;
                        dbms_lob.createtemporary(l_soap_env, TRUE);

                        l_text := '{
                                        "BankAccountNumber": "'||c_a.bank_account_num||'",
                                        "CountryCode": "'||c_a.bank_country||'",
                                        "BankBranchIdentifier": '||c_a.cloud_bank_id||',
                                        "BankIdentifier": '||c_a.cloud_branch_id||',
                                        "Intent": "Supplier",
                                        "PartyId": '||c_sa.cloud_party_id||',
                                        "IBAN": "'||c_a.iban_number||'",
                                        "BankAccountName": "'||c_a.bank_account_name||'"
                                    }';
                        
                        l_soap_env := l_soap_env||to_clob(l_text);       

                        log('               Calling web service to create external bank account!');

                        XXFN_CLOUD_WS_PKG.WS_REST_CALL(
                        p_ws_url => l_app_url||'fscmRestApi/resources/11.13.18.05/externalBankAccounts',
                        p_rest_env => l_soap_env,
                        p_rest_act => 'POST',
                        p_content_type => 'application/json;charset="UTF-8"',
                        x_return_status => x_return_status,
                        x_return_message => x_return_message,
                        x_ws_call_id => xb_ws_call_id);         
                        
                        log('               Web service status:'||x_return_status);
                        log('               Web service call:'||xb_ws_call_id);
                        dbms_lob.freetemporary(l_soap_env); 

                        <<bank_acc_exists>>

                        if x_return_status = 'S' then
                            log('                   vendor_site_code:'||c_a.vendor_site_code);
                            log('                   business_unit_name:'||c_a.business_unit_name);
                            log('                   xb_ws_call_id:'||xb_ws_call_id);

                            log('                   iban:'||c_a.iban_number);
                            begin
                                with json_response as
                                    (
                                    (
                                        select
                                        ext_bank_id
                                        from
                                        xxfn_ws_call_log xx,
                                        json_table(xx.response_json,'$'
                                            columns(
                                                            ext_bank_id number path '$.BankAccountId'))
                                        where xx.ws_call_id = xb_ws_call_id
                                        and xb_ws_call_id is not null --when supplier site is freshly created
                                        union                       
                                        select 
                                        xx_ba.EXT_BANK_ACCOUNT_ID ext_bank_id
                                        from
                                        XXDL_POZ_SUPPLIER_BANK_ACC xx_ba
                                        where xx_ba.iban = c_a.iban_number
                                        and xb_ws_call_id is null
                                        )
                                    )
                                    select
                                    nvl(jt.ext_bank_id,0)
                                    into l_bank_acc_rec.EXT_BANK_ACCOUNT_ID
                                    from
                                    json_response jt
                                    where rownum = 1
                                    and jt.ext_bank_id is not null;

                                    exception
                                    when no_data_found then
                                        l_bank_acc_rec.EXT_BANK_ACCOUNT_ID := null;

                                end;

                            log('               External bank account created!');

                            begin
                                insert into XXDL_POZ_SUPPLIER_BANK_ACC xx values l_bank_acc_rec;
                                exception
                                when dup_val_on_index then
                                    update XXDL_POZ_SUPPLIER_BANK_ACC xx
                                    set xx.process_flag = 'S'
                                    ,xx.last_update_date = sysdate
                                    where xx.EXT_BANK_ACCOUNT_ID = l_bank_acc_rec.EXT_BANK_ACCOUNT_ID
                                    ;
                            end;    

                            log('               External bank account id:'||l_bank_acc_rec.ext_bank_account_id);

                            if l_bank_acc_rec.ext_bank_account_id > 0 then

                                log('                   Create external bank account owner!');

                                if l_bank_acc_rec.CLOUD_OWNER_SET = 'Y' then
                                    log('                       Bank account owner already exists!');
                                    x_return_status := 'S';
                                    GOTO bank_acc_owner_set;
                                end if;

                                        
                                l_text := '';
                                l_soap_env := l_empty_clob;
                                dbms_lob.createtemporary(l_soap_env, TRUE);

                                l_text := '{
                                                "Intent":"Supplier",
                                                "AccountOwnerPartyIdentifier":"'||c_sa.cloud_party_id||'"
                                            }';
                                                                        
                                l_soap_env := l_soap_env||to_clob(l_text);       

                                log('                   Calling web service to create external bank account owner!');

                                XXFN_CLOUD_WS_PKG.WS_REST_CALL(
                                p_ws_url => l_app_url||'fscmRestApi/resources/11.13.18.05/externalBankAccounts/'||l_bank_acc_rec.EXT_BANK_ACCOUNT_ID||'/child/accountOwners',
                                p_rest_env => l_soap_env,
                                p_rest_act => 'POST',
                                p_content_type => 'application/json;charset="UTF-8"',
                                x_return_status => x_return_status,
                                x_return_message => x_return_message,
                                x_ws_call_id => xbo_ws_call_id);         
                                
                                log('                   Web service status:'||x_return_status);
                                if x_return_status = 'E' then
                                    x_return_message := get_ws_err_msg(x_ws_call_id);
                                    log('     Web service message:'||x_return_message);
                                end if;
                                log('                   Web service call:'||xbo_ws_call_id);
                                dbms_lob.freetemporary(l_soap_env); 
                                
                                <<bank_acc_owner_set>>

                                if x_return_status = 'S' then

                                    log('                       External bank account owner created!');

                                    l_bank_acc_rec.CLOUD_OWNER_SET := 'Y';

                                    begin
                                    with json_response as
                                        (
                                        (
                                            select
                                            CLOUD_OWNER_ID
                                            from
                                            xxfn_ws_call_log xx,
                                            json_table(xx.response_json,'$'
                                                columns(
                                                                CLOUD_OWNER_ID number path '$.AccountOwnerId'))
                                            where xx.ws_call_id = xbo_ws_call_id
                                            and xbo_ws_call_id is not null --when supplier site is freshly created
                                            union                       
                                            select 
                                            xx_ba.CLOUD_OWNER_ID
                                            from
                                            XXDL_POZ_SUPPLIER_BANK_ACC xx_ba
                                            where xx_ba.iban = c_a.iban_number
                                            and xbo_ws_call_id is null
                                            )
                                        )
                                        select
                                        nvl(jt.CLOUD_OWNER_ID,0)
                                        into l_bank_acc_rec.CLOUD_OWNER_ID
                                        from
                                        json_response jt
                                        where rownum = 1
                                        and jt.CLOUD_OWNER_ID is not null;

                                        exception
                                        when no_data_found then
                                            l_bank_acc_rec.CLOUD_OWNER_ID := null;

                                    end;

                                    update XXDL_POZ_SUPPLIER_BANK_ACC xx
                                        set xx.process_flag = 'S'
                                        ,xx.ERROR_MESSAGE = x_return_message 
                                        ,xx.CLOUD_OWNER_SET = 'Y'
                                        ,xx.CLOUD_OWNER_ID = l_bank_acc_rec.CLOUD_OWNER_ID
                                        where xx.ext_bank_account_id = l_bank_acc_rec.ext_bank_account_id;

                                    if l_bank_acc_rec.CLOUD_OWNER_ID > 0 then

                                        log('                       Assign instrument payment to supplier site!');

                                        log('                       First getting payee id!');

                                        l_text := '';
                                        l_soap_env := l_empty_clob;
                                        dbms_lob.createtemporary(l_soap_env, TRUE);

                                        l_text := ' ';
                                                                                
                                        l_soap_env := l_soap_env||to_clob(l_text);       

                                        log('                       Calling web service to get payee id!');

                                        XXFN_CLOUD_WS_PKG.WS_REST_CALL(
                                        p_ws_url => l_app_url||'fscmRestApi/resources/11.13.18.05/paymentsExternalPayees?finder=ExternalPayeeSearch;PayeePartyIdentifier='||c_sa.cloud_party_id||',Intent=Supplier,SupplierSiteIdentifier='||c_a.VENDOR_SITE_ID,
                                        p_rest_env => l_soap_env,
                                        p_rest_act => 'GET',
                                        p_content_type => 'application/json;charset="UTF-8"',
                                        x_return_status => x_return_status,
                                        x_return_message => x_return_message,
                                        x_ws_call_id => xp_ws_call_id);         
                                        
                                        log('                       Web service status:'||x_return_status);
                                        log('                       Web service call:'||xp_ws_call_id);

                                        dbms_lob.freetemporary(l_soap_env);  

                                        if x_return_status = 'S' then

                                            log('                       Parsing payee id!');

                                            begin
                                            with json_response as
                                                (
                                                (
                                                    select
                                                    payee_id
                                                    from
                                                    xxfn_ws_call_log xx,
                                                    json_table(xx.response_json,'$'
                                                        columns(nested path '$.items[*]'
                                                                columns(
                                                                    payee_id number path '$.PayeeId'
                                                                )))
                                                    where xx.ws_call_id = xp_ws_call_id
                                                    and xp_ws_call_id is not null --when supplier site is freshly created                                               
                                                    )
                                                )
                                                select
                                                nvl(jt.payee_id,0)
                                                into l_bank_acc_rec.CLOUD_EXT_PAYEE_ID
                                                from
                                                json_response jt
                                                where rownum = 1
                                                and jt.payee_id is not null;

                                                exception
                                                when no_data_found then
                                                    l_bank_acc_rec.CLOUD_EXT_PAYEE_ID := 0;

                                            end;

                                            if l_bank_acc_rec.CLOUD_EXT_PAYEE_ID > 0 then

                                                log('                           Starting assignment for payee id:'||l_bank_acc_rec.CLOUD_EXT_PAYEE_ID);

                                                if l_bank_acc_rec.cloud_payment_instrument_id > 0 then
                                                    log('                                   Payment instrument already assigned!');

                                                else    

                                                    l_text := '{
                                                        "PaymentPartyId": "'||l_bank_acc_rec.CLOUD_EXT_PAYEE_ID||'",
                                                        "PaymentInstrumentId": "'||l_bank_acc_rec.ext_bank_account_id||'",
                                                        "PaymentFlow": "DISBURSEMENTS",
                                                        "PaymentInstrumentType": "BANKACCOUNT",
                                                        "Intent": "Supplier",
                                                        "StartDate": "'||to_char(sysdate,'YYYY-MM-DD')||'"
                                                    }';
                                                    l_soap_env := l_empty_clob;
                                                    dbms_lob.createtemporary(l_soap_env, TRUE);

                                                    l_text := ' ';
                                                                                            
                                                    l_soap_env := l_soap_env||to_clob(l_text);       

                                                    log('                           Calling web service to get payee id!');

                                                    XXFN_CLOUD_WS_PKG.WS_REST_CALL(
                                                    p_ws_url => l_app_url||'fscmRestApi/resources/11.13.18.05/instrumentAssignments',
                                                    p_rest_env => l_soap_env,
                                                    p_rest_act => 'POST',
                                                    p_content_type => 'application/json;charset="UTF-8"',
                                                    x_return_status => x_return_status,
                                                    x_return_message => x_return_message,
                                                    x_ws_call_id => xpa_ws_call_id);         
                                                    
                                                    log('                           Web service status:'||x_return_status);
                                                    log('                           Web service call:'||xpa_ws_call_id);

                                                    dbms_lob.freetemporary(l_soap_env);  

                                                    if x_return_status = 'S' then

                                                        log('                           Bank account assigned to site!');

                                                        
                                                        begin
                                                        with json_response as
                                                            (
                                                            (
                                                                select
                                                                cloud_payment_instrument_id
                                                                from
                                                                xxfn_ws_call_log xx,
                                                                json_table(xx.response_json,'$'
                                                                columns(
                                                                                cloud_payment_instrument_id number path '$.PaymentInstrumentAssignmentId'
                                                                            ))
                                                                where xx.ws_call_id = xp_ws_call_id
                                                                and xp_ws_call_id is not null --when supplier site is freshly created                                               
                                                                )
                                                            )
                                                            select
                                                            nvl(jt.cloud_payment_instrument_id,0)
                                                            into l_bank_acc_rec.cloud_payment_instrument_id
                                                            from
                                                            json_response jt
                                                            where rownum = 1
                                                            and jt.cloud_payment_instrument_id is not null;

                                                            exception
                                                            when no_data_found then
                                                                l_bank_acc_rec.cloud_payment_instrument_id := 0;

                                                        end;


                                                        log('                           payment instrument id:'||l_bank_acc_rec.cloud_payment_instrument_id);

                                                        update XXDL_POZ_SUPPLIER_BANK_ACC xx
                                                        set xx.process_flag = 'S'
                                                        ,xx.CLOUD_ASSIGN = 'Y'
                                                        ,xx.cloud_payment_instrument_id = l_bank_acc_rec.cloud_payment_instrument_id
                                                        where xx.ext_bank_account_id = l_bank_acc_rec.ext_bank_account_id;


                                                    
                                                    else

                                                        log('                        Seeting payment instrument return error!');

                                                        update XXDL_POZ_SUPPLIER_BANK_ACC xx
                                                        set xx.CLOUD_ASSIGN = 'E'
                                                        ,xx.ERROR_MESSAGE = 'Fetching payee id returned 0! ' 
                                                        where xx.ext_bank_account_id = l_bank_acc_rec.ext_bank_account_id;


                                                    end if;

                                                end if;
    


                                            else
                                                log('                        Fetching payee id return error!');

                                                update XXDL_POZ_SUPPLIER_BANK_ACC xx
                                                set xx.CLOUD_ASSIGN = 'E'
                                                ,xx.ERROR_MESSAGE = 'Fetching payee id returned 0! ' 
                                                where xx.ext_bank_account_id = l_bank_acc_rec.ext_bank_account_id;

                                            end if;


                                        else

                                            log('                        Fetching payee id return error!');

                                            update XXDL_POZ_SUPPLIER_BANK_ACC xx
                                            set xx.CLOUD_ASSIGN = 'E'
                                            ,xx.ERROR_MESSAGE = 'Fetching payee id returned error! '||x_return_message 
                                            where xx.ext_bank_account_id = l_bank_acc_rec.ext_bank_account_id;

                                        end if;


                                    end if;    

                                else
                                    log('                       External bank account owner failed!');

                                    l_bank_acc_rec.CLOUD_OWNER_SET := 'E';

                                    update XXDL_POZ_SUPPLIER_BANK_ACC xx
                                    set xx.process_flag = 'E'
                                    ,xx.ERROR_MESSAGE = x_return_message
                                    ,xx.CLOUD_OWNER_SET = 'E'
                                    where xx.ext_bank_account_id = l_bank_acc_rec.ext_bank_account_id;

                                end if;

                                

                            else
                                log('                   Failed to create external bank account owner!');

                                update XXDL_POZ_SUPPLIER_BANK_ACC xx
                                    set xx.process_flag = 'E'
                                    ,xx.ERROR_MESSAGE = 'Return 0 for bank account owner!'|| x_return_message
                                    ,xx.CLOUD_OWNER_SET = 'E'
                                    where xx.ext_bank_account_id = l_bank_acc_rec.ext_bank_account_id;

                            end if;


                        else

                            log('           Failed to create external bank account');

                            l_bank_acc_rec.process_flag := 'E';
                            l_bank_acc_rec.ERROR_MESSAGE := x_return_message;

                            update XXDL_POZ_SUPPLIER_BANK_ACC xx
                            set xx.process_flag = 'E'
                            ,xx.ERROR_MESSAGE = x_return_message
                            where xx.ext_bank_account_id = l_bank_acc_rec.ext_bank_account_id;

                        end if;
                    end if; 
                    --ending bank account    
                     
                     



                end loop;


        else
            log('   Supplier site not created!');
            --log('   Message:'||x_return_message);
            
            update xxdl_poz_supplier_sites xx
                set xx.cloud_imported = 'E'
                ,xx.cloud_import_message = x_return_message
                where xx.party_site_id = c_sa.party_site_id;
        end if;

        l_text := '';
         
    end loop;
  else
    log('   Update address request failed!');
    --log('   Message:'||x_return_message);
    
    update xxdl_poz_supplier_addresses xx
    set xx.cloud_imported = 'E'
    ,xx.cloud_import_message = x_return_message
    where xx.party_site_id = c_sa.party_site_id;

  end if;

    l_find_text:='';
end loop;

exception
    when others then
        log('   Unexpected error! SQLCODE:'||SQLCODE||' SQLERRM:'||SQLERRM);
        log('   Error_Stack...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_STACK()||' Error_Backtrace...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE());
end migrate_suppliers_cloud;



function parse_cs_response(p_ws_call_id in number) return varchar2 is

  l_head_code          varchar2(4000);
  l_head_error         VARCHAR2(32767);  
  l_line_error         varchar2(4000);
  l_line_code          VARCHAR2(32767);
  l_msg_body VARCHAR2(32767);
begin


    --get header error

      FOR cur_rec IN (  select xt.code,
             substr(xt.message,instr(xt.message,'<',1,1), length(xt.message)) message
      from   xxfn_ws_call_log x,
             XMLTABLE(
               xmlnamespaces(
                 'http://xmlns.oracle.com/adf/svc/errors/' as "tns",'http://schemas.xmlsoap.org/soap/envelope/' as "env"),
                 '/env:Envelope/env:Body/env:Fault/detail/tns:ServiceErrorMessage/tns:detail'
               PASSING x.response_xml
               COLUMNS
                 code varchar2(4000) PATH 'tns:code',
                 message varchar2(4000) PATH 'tns:message'
               ) xt
      where x.ws_call_id = p_ws_call_id)
      LOOP

        select code,text into l_head_code,l_head_error from XMLTABLE('/MESSAGE' 
            passing (cur_rec.message)
            columns
                text varchar2(4000) PATH 'TEXT',
                code varchar2(4000) PATH 'CODE') ;
        if nvl(l_head_error,'X') != 'X' then 
            l_msg_body := 'Gre�ka na glavi RFQ.'||CHR(10);
            l_msg_body := 'Kod:'||l_head_code||CHR(10);
            l_msg_body := 'Tekst:'||l_head_error||CHR(10);
        end if;
    end loop;

    --get lines error

      FOR cur_rec IN (  select xt.code,
             substr(xt.message,instr(xt.message,'<',1,1), length(xt.message)) message
      from   xxfn_ws_call_log x,
             XMLTABLE(
               xmlnamespaces(
                 'http://xmlns.oracle.com/adf/svc/errors/' as "tns",'http://schemas.xmlsoap.org/soap/envelope/' as "env"),
                 '/env:Envelope/env:Body/env:Fault/detail/tns:ServiceErrorMessage/tns:detail/tns:detail'
               PASSING (x.response_xml)
               COLUMNS
                 code varchar2(4000) PATH 'tns:code',
                 message varchar2(4000) PATH 'tns:message'
               ) xt
      where x.ws_call_id = p_ws_call_id)
      LOOP


        if nvl(l_line_error,'X') != 'X' then 
            l_msg_body := 'Greska na linijama RFQ-a'||CHR(10);
            l_msg_body := 'Kod:'||l_line_code||CHR(10);
            l_msg_body := 'Tekst:'||l_line_error||CHR(10);
        end if;
        end loop;     
   return l_msg_body;
   end;

end XXDL_AR_UTIL_PKG;
/
exit;