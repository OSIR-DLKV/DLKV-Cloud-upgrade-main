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
    ,hps.party_site_name
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
                    source_address_id varchar2(240) path '$.PartySourceSystemReferenceValue',
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
                        source_address_id varchar2(240) path '$.PartySourceSystemReferenceValue',
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
                        source_address_id varchar2(240) path '$.PartySourceSystemReferenceValue',
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
            where rownum = 1;

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
                log('   Url:'||l_app_url||'crmRestApi/resources/11.13.18.05/hubOrganizations/'||c_p.party_number);
                XXFN_CLOUD_WS_PKG.WS_REST_CALL(
                p_ws_url => l_app_url||'crmRestApi/resources/11.13.18.05/hubOrganizations/'||c_p.party_number,
                p_rest_env => l_rest_env,
                p_rest_act => 'PATCH',
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
                                                            x.ws_call_id = x_ws_call_id;

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
                                                            x.ws_call_id = x_ws_call_id;

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
      p_ws_url => l_app_url||'crmRestApi/resources/11.13.18.05/hubOrganizations/'||p_party_number,
      p_rest_env => l_soap_env,
      p_rest_act => 'GET',
      p_content_type => 'application/json;charset="UTF-8"',
      x_return_status => x_return_status,
      x_return_message => x_return_message,
      x_ws_call_id => x_ws_call_id);

      log(' Web service to find item finished! ws_call_id:'||x_ws_call_id);

      if x_return_status = 'S' then

        log('Parsing ws_call to get item cloud id..');

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