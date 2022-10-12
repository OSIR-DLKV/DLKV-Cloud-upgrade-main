create or replace package body XXDL_INV_UTIL_PKG as
 /*$Header:  $
 =============================================================================
  -- Name        :  XXDL_INV_UTIL_PKG
  -- Author      :  Zoran Kovac
  -- Date        :  28-APR-2022
  -- Version     :  120.00
  -- Description :  Cloud Utils package
  --
  -- -------- ------ ------------ -----------------------------------------------
  --   Date    Ver     Author     Description
  -- -------- ------ ------------ -----------------------------------------------
  -- 28-04-22 120.00 zkovac       Initial creation 
  --*/
c_log_module   CONSTANT VARCHAR2(300) := $$PLSQL_UNIT;
g_prod_url CONSTANT VARCHAR2(300) := 'https://fa-encc-test-saasfaprod1.fa.ocs.oraclecloud.com/';
g_dev_url CONSTANT VARCHAR2(300) := 'https://fa-encc-test-saasfaprod1.fa.ocs.oraclecloud.com/';

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

  --/*-----------------------------------------------------------------------------
  -- Name    : migrate_items_cloud
  -- Desc    : Procedure for migrating EBS items to cloud
  -- Usage   : 
  -- Parameters	
--       - p_item_seg: item number in EBS
--       - p_rows: number of rows to process, default 1000
--		 - p_year: year of oldest purchase order created
--		 - p_retry_error: should we process records that ended in error
  -------------------------------------------------------------------------------*/

procedure migrate_items_cloud (
p_item_seg in varchar2,
p_rows in number,
p_year in varchar2,
p_retry_error in varchar2
)
is

cursor c_items is
select
msi.segment1
,'<![CDATA['||msi.description||']]>' description_escaped
,msi.description description
,msi.primary_uom_code
,msi.inventory_item_id
,msi.organization_id
,case 
  when mp.organization_code = 'DLK' then
    'DLK_EUR'
    when mp.organization_code = 'I02' then
    'I02'    
    when mp.organization_code = 'I04' then
    'I_04'
    when mp.organization_code = 'I05' then
    'I05'
    when mp.organization_code = 'I10' then
    'I10'
    when mp.organization_code = 'GRA' then
    'GRA'
    when mp.organization_code = 'T01' then
    'T_01'
  else organization_code
end organization_code
,mic.segment1 kat
,mitav.template_name
,case 
  when mp.organization_code = 'DLK' then
    1
    when mp.organization_code = 'I02' then
    2   
    when mp.organization_code = 'I04' then
    3
    when mp.organization_code = 'I05' then
    4
    when mp.organization_code = 'I10' then
    5
    when mp.organization_code = 'GRA' then
    6
    when mp.organization_code = 'T01' then
    7
  else 0
end custom_sort
from
apps.mtl_system_items_b@EBSPROD msi
,apps.mtl_parameters@EBSPROD mp
,(select
mic.inventory_item_id
,mic.organization_id
,mic.category_set_id
,mic.category_id
,mcst.category_set_name
,mcst.description
,mcb.segment1
,mcb.segment2
,mcb.segment3
,mcb.segment4
,mcb.segment5
,mcb.segment6
,mcb.segment7
,mcb.segment8
,mcb.segment9
,mcb.segment10
from
apps.mtl_item_categories@EBSPROD mic,
apps.mtl_category_sets_tl@EBSPROD mcst,
apps.mtl_category_sets_b@EBSPROD mcs,
apps.mtl_categories_b@EBSPROD mcb
where mic.category_set_id = mcs.category_set_id
AND mcs.category_set_id = mcst.category_set_id
AND mcst.LANGUAGE = 'HR'
AND mic.category_id = mcb.category_id) mic
,(select * from apps.mtl_item_templ_attributes_v@EBSPROD
    where user_attribute_name = 'User Item Type') mita
,(select * from apps.MTL_ITEM_TEMPLATES_ALL_V@EBSPROD
    where template_name like 'XXDL%') mitav
where 1=1
and to_char(msi.segment1) like nvl(to_char(p_item_seg),'%')
and msi.organization_id = mp.organization_id
--and mp.organization_code in ('DLK','I10','T01', 'I01','I02','I05','GRA','I04')
and mp.organization_code in ('DLK')
--and nvl(xx.process_flag,'X') != 'P'
--and xx.segment1 = msi.segment1
and msi.inventory_item_id = mic.inventory_item_id
and msi.organization_id = mic.organization_id
and mic.category_set_name = 'XXDL kategorizacija'
and msi.item_type = mita.attribute_value
and mita.template_id = mitav.template_id
and rownum <= p_rows
and mic.segment1 != '0'
/*
and not exists (select 1 from XXDL_MTL_SYSTEM_ITEMS_MIG xx 
                    where xx.inventory_item_id = msi.inventory_item_id
                    and xx.organization_id = msi.organization_id
                    and nvl(xx.process_flag,'X') in ('S',decode(p_retry_error,'Y','N','E'))) --ne zelim da ponovo pokusava errored recorde, njih treba pregledati
*/
and exists (select 1 from apps.mtl_material_transactions@EBSPROD mmt
            where mmt.INVENTORY_ITEM_ID = msi.inventory_item_id
            and mmt.organization_id = msi.organization_id
            and mmt.creation_date >= to_date('01.01.'||nvl(p_year,to_char(sysdate,'YYYY')),'DD.MM.YYYY')
            and msi.organization_id not in (102)
            union
            select 1 
            from dual
            where msi.organization_id in (102)
            )
order by custom_sort
;

cursor c_items_lang (c_item_id in number, c_org_id in number) is
select
'<![CDATA['||msit.description||']]>' description_escaped
,'<![CDATA['||msit.long_description||']]>' long_description_esc
,msit.description description
,msit.long_description long_description
,msit.language
,msit.source_lang
from
apps.mtl_system_items_tl@EBSPROD msit
where
msit.inventory_item_id = c_item_id
and msit.organization_id = c_org_id
and msit.language = 'D'
;

cursor c_item_categories(c_item_id in number, c_org_id in number) is
select
distinct
case
    when mic.category_set_name = 'XXDL kategorizacija' then
        '<![CDATA[Nabavne kategorije]]>'
    when mic.category_set_name = 'XXDL PLA' then
        '<![CDATA[Racunovodstvena kategorija]]>'
    else mic.category_set_name end category_set_name
,case
    when mic.category_set_name = 'XXDL kategorizacija' then
        mic.segment1||'.'||mic.segment2
    when mic.category_set_name = 'XXDL PLA' then
        mic.segment1
    else mic.segment1 end category_code
,mic.category_set_name orig_category_set_name
from
(select
mic.inventory_item_id
,mic.organization_id
,mic.category_set_id
,mic.category_id
,mcst.category_set_name
,mcst.description
,mcb.segment1
,mcb.segment2
,mcb.segment3
,mcb.segment4
,mcb.segment5
,mcb.segment6
,mcb.segment7
,mcb.segment8
,mcb.segment9
,mcb.segment10
from
apps.mtl_item_categories@EBSPROD mic,
apps.mtl_category_sets_tl@EBSPROD mcst,
apps.mtl_category_sets_b@EBSPROD mcs,
apps.mtl_categories_b@EBSPROD mcb
where mic.category_set_id = mcs.category_set_id
AND mcs.category_set_id = mcst.category_set_id
AND mcst.LANGUAGE = 'HR'
AND mic.category_id = mcb.category_id) mic
where mic.inventory_item_id = c_item_id
and mic.organization_id =c_org_id
;



    l_item_rec XXDL_MTL_SYSTEM_ITEMS_MIG%ROWTYPE;
    l_item_empty XXDL_MTL_SYSTEM_ITEMS_MIG%ROWTYPE;
    l_fault_code          varchar2(4000);
    l_fault_string        varchar2(4000); 
    l_soap_env clob;
    l_empty_clob clob;
    l_text varchar2(32000);
    x_return_status varchar2(500);
    x_return_message varchar2(32000);
    x_ws_call_id number;
    l_cnt number := 0;

    l_app_url           varchar2(100);
    l_username          varchar2(100);
    l_password           varchar2(100);

    l_cloud_item number;
    l_cloud_org number;

XX_USER exception;
XX_APP exception;
XX_PASS exception;
begin


log('Starting to import items:');

l_app_url := get_config('ServiceRootURL');
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

for c_i in c_items loop

    log('   Import item: '||c_i.segment1);

    log('   Checking if already exists in cloud!');

    find_item_cloud(c_i.segment1,c_i.organization_code,l_cloud_item,l_cloud_org);

    log('   Cloud item id:'||l_cloud_item);

    l_item_rec.inventory_item_id := c_i.inventory_item_id;
    l_item_rec.organization_id := c_i.organization_id;
    l_item_rec.segment1 := c_i.segment1;
    l_item_rec.organization_code := c_i.organization_code;
    l_item_rec.description := c_i.description;
    l_item_rec.primary_uom_code := c_i.primary_uom_code;
    l_item_rec.process_flag := x_return_status;
    l_item_rec.creation_date := sysdate;
    l_item_rec.category := c_i.kat;

    if l_cloud_item = 0 then
        log('   Creating item!');
        log('   Building envelope!');
        l_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/" xmlns:item="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/" xmlns:cat="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/itemSupplier/categories/" xmlns:item1="http://xmlns.oracle.com/apps/scm/productModel/items/flex/itemRevision/" xmlns:cat1="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/itemRevision/categories/" xmlns:cat2="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/item/categories/" xmlns:item2="http://xmlns.oracle.com/apps/scm/productModel/items/flex/item/" xmlns:item3="http://xmlns.oracle.com/apps/scm/productModel/items/flex/itemGdf/" xmlns:mod="http://xmlns.oracle.com/apps/flex/fnd/applcore/attachments/model/">
                        <soapenv:Header/>
                        <soapenv:Body>
                            <typ:createItem>
                                <typ:item>
                                    <item:OrganizationCode>'||c_i.organization_code||'</item:OrganizationCode>
                                    <item:Template>'||c_i.template_name||'</item:Template>
                                    <item:ItemNumber>'||c_i.segment1||'</item:ItemNumber>
                                    <item:ItemClass>Root Item Class</item:ItemClass>
                                    <item:ItemDescription>'||c_i.description_escaped||'</item:ItemDescription>
                                    <item:LongDescription>'||c_i.description_escaped||'</item:LongDescription>
                                    <item:PrimaryUOMValue>'||c_i.primary_uom_code||'</item:PrimaryUOMValue>
                                    <item:ItemStatusValue>Active</item:ItemStatusValue>
                                    <item:LifecyclePhaseValue>Production</item:LifecyclePhaseValue>';


                for c_i_cat in c_item_categories(c_i.inventory_item_id, c_i.organization_id) loop

                    if c_i_cat.orig_category_set_name = 'XXDL kategorizacija' then
                        l_item_rec.category := c_i_cat.category_code;
                    end if;

                    if c_i_cat.orig_category_set_name = 'XXDL PLA' then
                        l_item_rec.account := c_i_cat.category_code;
                    end if;

                    if c_i.organization_code = 'DLK_EUR' and c_i_cat.orig_category_set_name = 'XXDL kategorizacija' then
                        l_text:= l_text||'<item:ItemCategory>
                                                <item:ItemCatalog>'||c_i_cat.category_set_name||'</item:ItemCatalog>               
                                                <item:CategoryCode>'||c_i_cat.category_code||'</item:CategoryCode>
                                        </item:ItemCategory>';
                    end if;

                    if c_i.organization_code != 'DLK_EUR' and c_i_cat.orig_category_set_name = 'XXDL PLA' then
                        l_text:= l_text||'<item:ItemCategory>
                                                <item:ItemCatalog>'||c_i_cat.category_set_name||'</item:ItemCatalog>               
                                                <item:CategoryCode>'||c_i_cat.category_code||'</item:CategoryCode>
                                        </item:ItemCategory>';
                    end if; 
                end loop;

             --prijenos prijevoda u cloud zasad ne radi
            for cil in c_items_lang(c_i.inventory_item_id, c_i.organization_id) loop

                log('       Found translation! Lang: '||cil.language);

                l_text := l_text ||'<item:ItemTranslation>
                                    <item:ItemDescription>'||cil.description_escaped||'></item:ItemDescription>
                                    <item:LongDescription>'||cil.long_description_esc||'</item:LongDescription>
                                    <item:Language>'||cil.language||'</item:Language>
                                    <item:SourceLanguage>US</item:SourceLanguage>
                                    </item:ItemTranslation>
                                    ';

            end loop;
            
            l_text := l_text||'</typ:item>
                            </typ:createItem>
                        </soapenv:Body>
                        </soapenv:Envelope>';

        l_soap_env := l_soap_env|| to_clob(l_text);
        l_text := '';

        log('   Envelope built!');

        log('   Calling web service.');
        log('   Url:'||l_app_url||'fscmService/ItemServiceV2?WSDL');
        XXFN_CLOUD_WS_PKG.WS_CALL(
        p_ws_url => l_app_url||'fscmService/ItemServiceV2?WSDL',
        p_soap_env => l_soap_env,
        p_soap_act => 'createItem',
        p_content_type => 'text/xml;charset="UTF-8"',
        x_return_status => x_return_status,
        x_return_message => x_return_message,
        x_ws_call_id => x_ws_call_id);

        log('   Web service finished! ws_call_id:'||x_ws_call_id);

    --log(l_text);
    --dbms_lob.freetemporary(l_soap_env);
        log('   ws_call_id:'||x_ws_call_id);

        if x_return_status = 'S' then

            log('   Item migrated!');
            l_item_rec.process_flag := x_return_status;
            
            BEGIN
            SELECT
                xt.cloud_item_id,
                xt.cloud_org_id
            INTO
                l_item_rec.cloud_item_id,
                l_item_rec.cloud_org_id
            FROM
                xxfn_ws_call_log x,
                XMLTABLE ( XMLNAMESPACES ( 'http://schemas.xmlsoap.org/soap/envelope/' AS "env" 
                                            ,'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/' AS "ns0"
                                            ,'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/' AS "ns2"
                                            ,'http://xmlns.oracle.com/adf/svc/types/' AS "val"
                                            ,'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/' as "ns1"
                                            ), '/env:Envelope/env:Body/ns0:createItemResponse/ns2:result/val:Value' PASSING x.response_xml COLUMNS
                cloud_item_id VARCHAR2(4000) PATH './ns1:ItemId', cloud_org_id VARCHAR2(4000) PATH './ns1:OrganizationId' ) xt
            WHERE
                x.ws_call_id = x_ws_call_id;

            EXCEPTION
                WHEN no_data_found THEN
                    l_item_rec.cloud_item_id := null;
                    l_item_rec.cloud_org_id := null;
            END;             

            update xxfn_ws_call_log xx 
            set xx.response_xml = null
            ,xx.response_clob = null
            ,xx.response_blob = null
            ,xx.ws_payload_xml = null
            where ws_call_id = x_ws_call_id;

        else
            log('   Error! Item not migrated!');

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
                            l_item_rec.error_msg := 'Cannot find env:Fault in ws call results.';
                    END;
            END;             

            if l_fault_code is not null or l_fault_string is not null then
                l_item_rec.error_msg := substr( '   Greska => Code:'||l_fault_code||' Text:'||l_fault_string,1,1000);        
            end if;
            log('   '||l_item_rec.error_msg);        
        end if;

        BEGIN
            INSERT INTO XXDL_MTL_SYSTEM_ITEMS_MIG VALUES l_item_rec;

        EXCEPTION
            WHEN dup_val_on_index THEN
                l_item_rec.last_update_date := SYSDATE;
                UPDATE XXDL_MTL_SYSTEM_ITEMS_MIG xx
                SET
                    row = l_item_rec
                WHERE
                    xx.inventory_item_id = l_item_rec.inventory_item_id
                    AND xx.organization_id = l_item_rec.organization_id;

        END;


    else
        log('   Already exists!');

        BEGIN
            INSERT INTO XXDL_MTL_SYSTEM_ITEMS_MIG VALUES l_item_rec;

        EXCEPTION
            WHEN dup_val_on_index THEN
                l_item_rec.last_update_date := SYSDATE;
                UPDATE XXDL_MTL_SYSTEM_ITEMS_MIG xx
                SET
                    row = l_item_rec
                WHERE
                    xx.inventory_item_id = l_item_rec.inventory_item_id
                    AND xx.organization_id = l_item_rec.organization_id;

        END;

        update XXDL_MTL_SYSTEM_ITEMS_MIG xx
        SET xx.cloud_item_id = l_cloud_item
        ,xx.cloud_org_id = l_cloud_org
        ,xx.process_flag = 'S'
        ,xx.error_msg = null
        WHERE
            xx.inventory_item_id = c_i.inventory_item_id
            AND xx.organization_id = c_i.organization_id; 

    end if;

    l_item_rec := l_item_empty;
    l_soap_env := l_empty_clob;
    l_cnt := l_cnt + 1;

end loop;

log('Finished item import!');
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

end migrate_items_cloud;


  --/*-----------------------------------------------------------------------------
  -- Name    : get_item_template
  -- Desc    : 
  -------------------------------------------------------------------------------*/  
function get_item_template(p_segment1 varchar, p_organization_code varchar2) return varchar2 as
  l_template varchar2(30);
  l_count    number;
begin
  

  l_template := null;

  if p_segment1 like 'U%' then
    select count(1) into l_count from xxdl_item_mig_proizv_usluge@ebsprod where item = p_segment1;
    
    if l_count > 0 then
      l_template := 'XXDL_Usluga-Nabava';
    end if;
  end if;
  
  -- TODO: Remove after testing!!
  l_template := 'XXDL_Usluga-Nabava';
  
  return l_template;

end;

  --/*-----------------------------------------------------------------------------
  -- Name    : migrate_items_cloud_ewha_test
  -- Desc    : Procedure for migrating EBS items to cloud ewha-test
  -- Usage   : 
  -- Parameters	
--       - p_item_seg: item number in EBS
--       - p_rows: number of rows to process, default 1000
--		 - p_year: year of oldest purchase order created
--		 - p_retry_error: should we process records that ended in error
  -------------------------------------------------------------------------------*/

procedure migrate_items_cloud_ewha_test(p_item_seg in varchar2, p_rows in number, p_year in varchar2, p_retry_error in varchar2, p_suffix in varchar2) is

---------
-- Items
---------
  cursor c_items is
  select * from (
    select msi.segment1,
           '<![CDATA[' || msi.description || ']]>' description_escaped,
           msi.description description,
           case
             when msi.primary_uom_code = 'kom' then
              muom.unit_of_measure_tl
             else
              msi.primary_uom_code
           end primary_uom_code,
           msi.inventory_item_id,
           msi.organization_id,
           mp.organization_code,
           mic.segment1 kat,
           case
             when mp.organization_code = 'DLK' then
              1
             when mp.organization_code = 'CIN' then
              2
             when mp.organization_code = 'POS' then
              3
             else
              99
           end custom_sort
      from apps.mtl_system_items_b@ebsprod msi,
           apps.mtl_parameters@ebsprod mp,
           (select mic.inventory_item_id,
                   mic.organization_id,
                   mic.category_set_id,
                   mic.category_id,
                   mcst.category_set_name,
                   mcst.description,
                   mcb.segment1,
                   mcb.segment2,
                   mcb.segment3,
                   mcb.segment4,
                   mcb.segment5,
                   mcb.segment6,
                   mcb.segment7,
                   mcb.segment8,
                   mcb.segment9,
                   mcb.segment10
              from apps.mtl_item_categories@ebsprod  mic,
                   apps.mtl_category_sets_tl@ebsprod mcst,
                   apps.mtl_category_sets_b@ebsprod  mcs,
                   apps.mtl_categories_b@ebsprod     mcb
             where mic.category_set_id = mcs.category_set_id
               and mcs.category_set_id = mcst.category_set_id
               and mcst.language = 'HR'
               and mic.category_id = mcb.category_id) mic,
           apps.mtl_units_of_measure_tl@ebsprod muom
     where 1 = 1
       and to_char(msi.segment1) like nvl(to_char(p_item_seg), '%')
       and msi.organization_id = mp.organization_id
       and mp.organization_code in ('DLK', 'POS', 'GDP')
          --and nvl(xx.process_flag,'X') != 'P'
          --and xx.segment1 = msi.segment1
       and msi.inventory_item_id = mic.inventory_item_id
       and msi.organization_id = mic.organization_id
       and mic.category_set_name = 'XXDL kategorizacija'
       and msi.primary_uom_code = muom.uom_code
       and muom.language = 'US'
       and rownum <= p_rows
       and mic.segment1 != '0'
          /*
          and not exists (select 1 from XXDL_MTL_SYSTEM_ITEMS_MIG xx 
                              where xx.inventory_item_id = msi.inventory_item_id
                              and xx.organization_id = msi.organization_id
                              and nvl(xx.process_flag,'X') in ('S',decode(p_retry_error,'Y','N','E'))) --ne zelim da ponovo pokusava errored recorde, njih treba pregledati
                              */
     /* 
      and exists (select 1
              from apps.mtl_material_transactions@ebsprod mmt
             where mmt.inventory_item_id = msi.inventory_item_id
               and mmt.organization_id = msi.organization_id
               and mmt.creation_date >= to_date('01.01.' || nvl(p_year, to_char(sysdate, 'YYYY')), 'DD.MM.YYYY')
               and msi.organization_id not in (102)
            union
            select 1
              from dual
             where msi.organization_id in (102))
             */
             )
     order by segment1, custom_sort;

-------------
-- Languages
-------------
  cursor c_items_lang(c_item_id in number, c_org_id in number) is
    select '<![CDATA[' || msit.description || ']]>' description_escaped,
           '<![CDATA[' || msit.long_description || ']]>' long_description_esc,
           msit.description description,
           msit.long_description long_description,
           msit.language,
           msit.source_lang
      from apps.mtl_system_items_tl@ebsprod msit
     where msit.inventory_item_id = c_item_id
       and msit.organization_id = c_org_id
       and msit.language = 'HR';

--------------
-- Categories
---------------
  cursor c_item_categories(c_item_id in number, c_org_id in number) is
    select distinct case
                      when mic.category_set_name = 'XXDL kategorizacija' then
                       '<![CDATA[Nabavne kategorije]]>'
                      when mic.category_set_name = 'XXDL PLA' then
                       '<![CDATA[Racunovodstvena kategorija]]>'
                      else
                       mic.category_set_name
                    end category_set_name,
                    case
                      when mic.category_set_name = 'XXDL kategorizacija' then
                       mic.segment1 || '.' || mic.segment2
                      when mic.category_set_name = 'XXDL PLA' then
                       mic.segment1
                      else
                       mic.segment1
                    end category_code,
                    mic.category_set_name orig_category_set_name
      from (select mic.inventory_item_id,
                   mic.organization_id,
                   mic.category_set_id,
                   mic.category_id,
                   mcst.category_set_name,
                   mcst.description,
                   mcb.segment1,
                   mcb.segment2,
                   mcb.segment3,
                   mcb.segment4,
                   mcb.segment5,
                   mcb.segment6,
                   mcb.segment7,
                   mcb.segment8,
                   mcb.segment9,
                   mcb.segment10
              from apps.mtl_item_categories@ebsprod  mic,
                   apps.mtl_category_sets_tl@ebsprod mcst,
                   apps.mtl_category_sets_b@ebsprod  mcs,
                   apps.mtl_categories_b@ebsprod     mcb
             where mic.category_set_id = mcs.category_set_id
               and mcs.category_set_id = mcst.category_set_id
               and mcst.language = 'HR'
               and mic.category_id = mcb.category_id) mic
     where mic.inventory_item_id = c_item_id
       and mic.organization_id = c_org_id;

  l_item_rec       xxdl_mtl_system_items_mig%rowtype;
  l_item_empty     xxdl_mtl_system_items_mig%rowtype;
  l_fault_code     varchar2(4000);
  l_fault_string   varchar2(4000);
  l_soap_env       clob;
  l_empty_clob     clob;
  l_text           varchar2(32000);
  x_return_status  varchar2(500);
  x_return_message varchar2(32000);
  x_ws_call_id     number;
  l_cnt            number := 0;

  l_app_url  varchar2(100);
  l_username varchar2(100);
  l_password varchar2(100);

  l_cloud_item number;
  l_cloud_org  number;

  l_segment1 varchar2(100);
  l_template varchar2(30);

  xx_user exception;
  xx_app  exception;
  xx_pass exception;
begin

  log('Starting to import items:');

  l_app_url  := get_config('EwhaTestServiceRootURL');
  l_username := get_config('EwhaTestServiceUsername');
  l_password := get_config('EwhaTestServicePassword');

  if l_app_url is null then
    raise xx_app;
  end if;

  if l_username is null then
    raise xx_user;
  end if;

  if l_password is null then
    raise xx_pass;
  end if;

  for c_i in c_items loop
  
    l_segment1 := c_i.segment1 || p_suffix;
  
    log('   -----------------------------');
    log('   Import item: ' || l_segment1);
    log('   Org: ' || c_i.organization_code);
  
    log('   Checking if already exists in cloud!');
  
    find_item_cloud(l_segment1, c_i.organization_code, l_cloud_item, l_cloud_org);
  
    log('   Cloud item id:' || l_cloud_item);
  
    l_item_rec.inventory_item_id := c_i.inventory_item_id;
    l_item_rec.organization_id   := c_i.organization_id;
    l_item_rec.segment1          := l_segment1;
    l_item_rec.organization_code := c_i.organization_code;
    l_item_rec.description       := c_i.description;
    l_item_rec.primary_uom_code  := c_i.primary_uom_code;
    l_item_rec.process_flag      := x_return_status;
    l_item_rec.creation_date     := sysdate;
    l_item_rec.category          := c_i.kat;
  
    l_template := get_item_template(c_i.segment1, null);
    log('l_template: ' || l_template);
  
    if l_cloud_item = 0 then
      log('   Creating item!');
      log('   Building envelope!');
      l_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/" xmlns:item="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/" xmlns:cat="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/itemSupplier/categories/" xmlns:item1="http://xmlns.oracle.com/apps/scm/productModel/items/flex/itemRevision/" xmlns:cat1="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/itemRevision/categories/" xmlns:cat2="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/item/categories/" xmlns:item2="http://xmlns.oracle.com/apps/scm/productModel/items/flex/item/" xmlns:item3="http://xmlns.oracle.com/apps/scm/productModel/items/flex/itemGdf/" xmlns:mod="http://xmlns.oracle.com/apps/flex/fnd/applcore/attachments/model/">
                        <soapenv:Header/>
                        <soapenv:Body>
                            <typ:createItem>
                                <typ:item>
                                    <item:OrganizationCode>' || c_i.organization_code ||
                '</item:OrganizationCode>
                                    <item:Template>' || l_template || '</item:Template>
                                    <item:ItemNumber>' || l_segment1 || '</item:ItemNumber>
                                    <item:ItemClass>Root Item Class</item:ItemClass>
                                    <item:ItemDescription>' || c_i.description_escaped ||
                '</item:ItemDescription>
                                    <item:LongDescription>' || c_i.description_escaped ||
                '</item:LongDescription>
                                    <item:PrimaryUOMValue>' || c_i.primary_uom_code ||
                '</item:PrimaryUOMValue>
                                    <item:ItemStatusValue>Active</item:ItemStatusValue>
                                    <item:LifecyclePhaseValue>Production</item:LifecyclePhaseValue>';
    
      for c_i_cat in c_item_categories(c_i.inventory_item_id, c_i.organization_id) loop
      
        if c_i_cat.orig_category_set_name = 'XXDL kategorizacija' then
          l_item_rec.category := c_i_cat.category_code;
        end if;
      
        if c_i_cat.orig_category_set_name = 'XXDL PLA' then
          l_item_rec.account := c_i_cat.category_code;
        end if;
      
        if c_i.organization_code = 'DLK' and c_i_cat.orig_category_set_name = 'XXDL kategorizacija' then
          l_text := l_text || '<item:ItemCategory>
                                                <item:ItemCatalog>' || c_i_cat.category_set_name ||
                    '</item:ItemCatalog>               
                                                <item:CategoryCode>' || c_i_cat.category_code ||
                    '</item:CategoryCode>
                                        </item:ItemCategory>';
        end if;
      
        if c_i.organization_code != 'DLK' and c_i_cat.orig_category_set_name = 'XXDL PLA' then
          l_text := l_text || '<item:ItemCategory>
                                                <item:ItemCatalog>' || c_i_cat.category_set_name ||
                    '</item:ItemCatalog>               
                                                <item:CategoryCode>' || c_i_cat.category_code ||
                    '</item:CategoryCode>
                                        </item:ItemCategory>';
        end if;
      end loop;
    
      --prijenos prijevoda u cloud zasad ne radi
      /*
      for cil in c_items_lang(c_i.inventory_item_id, c_i.organization_id) loop
      
          log('       Found translation! Lang: '||cil.language);
      
          l_text := l_text ||'<item:ItemTranslation>
                              <item:ItemDescription>'||cil.description_escaped||'</item:ItemDescription>
                              <item:LongDescription>'||cil.long_description_esc||'</item:LongDescription>
                              <item:Language>'||cil.language||'</item:Language>
                              <item:SourceLanguage>US</item:SourceLanguage>
                              </item:ItemTranslation>
                              ';
      
      end loop;
      */
      l_text := l_text || '</typ:item>
                            </typ:createItem>
                        </soapenv:Body>
                        </soapenv:Envelope>';
    
      l_soap_env := l_soap_env || to_clob(l_text);
      l_text     := '';
    
      log('   Envelope built!');
    
      log('   Calling web service.');
      log('   Url:' || l_app_url || 'fscmService/ItemServiceV2?WSDL');
      xxfn_cloud_ws_pkg.ws_call(p_ws_url         => l_app_url || 'fscmService/ItemServiceV2?WSDL',
                                p_soap_env       => l_soap_env,
                                p_soap_act       => 'createItem',
                                p_content_type   => 'text/xml;charset="UTF-8"',
                                x_return_status  => x_return_status,
                                x_return_message => x_return_message,
                                x_ws_call_id     => x_ws_call_id);
    
      log('   Web service finished! ws_call_id:' || x_ws_call_id);
    
      --log(l_text);
      --dbms_lob.freetemporary(l_soap_env);
      log('   ws_call_id:' || x_ws_call_id);
    
      if x_return_status = 'S' then
      
        log('   Item migrated!');
        l_item_rec.process_flag := x_return_status;
      
        begin
          select xt.cloud_item_id,
                 xt.cloud_org_id
            into l_item_rec.cloud_item_id,
                 l_item_rec.cloud_org_id
            from xxfn_ws_call_log x,
                 xmltable(xmlnamespaces('http://schemas.xmlsoap.org/soap/envelope/' as "env",
                                        'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/' as "ns0",
                                        'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/' as "ns2",
                                        'http://xmlns.oracle.com/adf/svc/types/' as "val",
                                        'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/' as "ns1"),
                          '/env:Envelope/env:Body/ns0:createItemResponse/ns2:result/val:Value' passing x.response_xml columns cloud_item_id
                          varchar2(4000) path './ns1:ItemId',
                          cloud_org_id varchar2(4000) path './ns1:OrganizationId') xt
           where x.ws_call_id = x_ws_call_id;
        
        exception
          when no_data_found then
            l_item_rec.cloud_item_id := null;
            l_item_rec.cloud_org_id  := null;
        end;
      
        /*update xxfn_ws_call_log xx 
        set xx.response_xml = null
        ,xx.response_clob = null
        ,xx.response_blob = null
        ,xx.ws_payload_xml = null
        where ws_call_id = x_ws_call_id;
        */
      
      else
        log('   Error! Item not migrated!');
      
        begin
          select xt.faultcode,
                 xt.faultstring
            into l_fault_code,
                 l_fault_string
            from xxfn_ws_call_log x,
                 xmltable(xmlnamespaces('http://schemas.xmlsoap.org/soap/envelope/' as "env"),
                          './/env:Fault' passing x.response_xml columns faultcode varchar2(4000) path '.',
                          faultstring varchar2(4000) path '.') xt
           where x.ws_call_id = x_ws_call_id;
        
        exception
          when no_data_found then
            begin
              select nvl(x.response_status_code, 'ERROR'),
                     x.response_reason_phrase
                into l_fault_code,
                     l_fault_string
                from xxfn_ws_call_log x
               where x.ws_call_id = x_ws_call_id;
            
            exception
              when others then
                l_item_rec.error_msg := 'Cannot find env:Fault in ws call results.';
            end;
        end;
      
        if l_fault_code is not null or l_fault_string is not null then
          l_item_rec.error_msg := substr('   Greska => Code:' || l_fault_code || ' Text:' || l_fault_string, 1, 1000);
        end if;
        log('   ' || l_item_rec.error_msg);
      end if;
    
      begin
        insert into xxdl_mtl_system_items_mig values l_item_rec;
      
      exception
        when dup_val_on_index then
          l_item_rec.last_update_date := sysdate;
          update xxdl_mtl_system_items_mig xx
             set row = l_item_rec
           where xx.inventory_item_id = l_item_rec.inventory_item_id
             and xx.organization_id = l_item_rec.organization_id;
        
      end;
    
    else
      log('   Already exists!');
    
      begin
        insert into xxdl_mtl_system_items_mig values l_item_rec;
      
      exception
        when dup_val_on_index then
          l_item_rec.last_update_date := sysdate;
          update xxdl_mtl_system_items_mig xx
             set row = l_item_rec
           where xx.inventory_item_id = l_item_rec.inventory_item_id
             and xx.organization_id = l_item_rec.organization_id;
        
      end;
    
      update xxdl_mtl_system_items_mig xx
         set xx.cloud_item_id = l_cloud_item, xx.cloud_org_id = l_cloud_org, xx.process_flag = 'S', xx.error_msg = null
       where xx.inventory_item_id = c_i.inventory_item_id
         and xx.organization_id = c_i.organization_id;
    
    end if;
  
    l_item_rec := l_item_empty;
    l_soap_env := l_empty_clob;
    l_cnt      := l_cnt + 1;
  
  end loop;

  log('Finished item import!');
  log('Record count:' || l_cnt);

exception
  when xx_app then
    log('   No cloud url found!');
  when xx_user then
    log('   No cloud user found!');
  when xx_pass then
    log('   No cloud password found!');
  when others then
    log('   Unexpected error! SQLCODE:' || sqlcode || ' SQLERRM:' || sqlerrm);
    log('   Error_Stack...' || chr(10) || dbms_utility.format_error_stack() || ' Error_Backtrace...' || chr(10) ||
        dbms_utility.format_error_backtrace());
  
end migrate_items_cloud_ewha_test;


  --/*-----------------------------------------------------------------------------
  -- Name    : update_items_cloud
  -- Desc    : Procedure for migrating EBS items to cloud to OD3
  -- Usage   : Concurrent Program XXUN Migrate items to cloud.
  -- Parameters	
--       - p_item_seg: item number in EBS
--       - p_rows: number of rows to process, default 1000
--		 - p_year: year of oldest purchase order created
--		 - p_retry_error: should we process records that ended in error
  -------------------------------------------------------------------------------*/

procedure update_items_cloud (
p_item_seg in varchar2,
p_rows in number,
p_year in varchar2,
p_retry_error in varchar2
)
is

cursor c_items is
select
msi.segment1
,'<![CDATA['||msi.description||']]>' description_escaped
,msi.description description
,msi.primary_uom_code
,msi.inventory_item_id
,msi.organization_id
,mp.organization_code
,mic.segment1 kat
from
apps.mtl_system_items_b@EBSPROD msi
,apps.mtl_parameters@EBSPROD mp
,(select
mic.inventory_item_id
,mic.organization_id
,mic.category_set_id
,mic.category_id
,mcst.category_set_name
,mcst.description
,mcb.segment1
,mcb.segment2
,mcb.segment3
,mcb.segment4
,mcb.segment5
,mcb.segment6
,mcb.segment7
,mcb.segment8
,mcb.segment9
,mcb.segment10
from
apps.mtl_item_categories@EBSPROD mic,
apps.mtl_category_sets_tl@EBSPROD mcst,
apps.mtl_category_sets_b@EBSPROD mcs,
apps.mtl_categories_b@EBSPROD mcb
where mic.category_set_id = mcs.category_set_id
AND mcs.category_set_id = mcst.category_set_id
AND mcst.LANGUAGE = 'HR'
AND mic.category_id = mcb.category_id) mic
where 1=1
and to_char(msi.segment1) like nvl(to_char(p_item_seg),'%')
and msi.organization_id = mp.organization_id
and mp.organization_code != 'DLK'
--and nvl(xx.process_flag,'X') != 'P'
--and xx.segment1 = msi.segment1
and msi.inventory_item_id = mic.inventory_item_id
and msi.organization_id = mic.organization_id
and msi.purchasing_enabled_flag = 'Y'
and mic.category_set_name = 'XXDL kategorizacija'
and rownum <= p_rows
and mic.segment1 != '0'
and not exists (select 1 from XXDL_MTL_SYSTEM_ITEMS_MIG xx 
                    where xx.inventory_item_id = msi.inventory_item_id
                    and xx.organization_id = msi.organization_id
                    and nvl(xx.process_flag,'X') in ('S',decode(p_retry_error,'Y','N','E'))) --ne zelim da ponovo pokusava errored recorde, njih treba pregledati
and exists (select 1 from apps.mtl_material_transactions@EBSPROD mmt
            where mmt.INVENTORY_ITEM_ID = msi.inventory_item_id
            and mmt.organization_id = msi.organization_id
            and mmt.creation_date >= to_date('01.01.'||nvl(p_year,to_char(sysdate,'YYYY')),'DD.MM.YYYY')
            and msi.organization_id not in (102)
            union
            select 1 
            from dual
            where msi.organization_id in (102)
            )
;


cursor c_items_lang (c_item_id in number, c_org_id in number) is
select
'<![CDATA['||msit.description||']]>' description_escaped
,'<![CDATA['||msit.long_description||']]>' long_description_esc
,msit.description description
,msit.long_description long_description
,msit.language
,msit.source_lang
from
apps.mtl_system_items_tl@EBSPROD msit
where
msit.inventory_item_id = c_item_id
and msit.organization_id = c_org_id
and msit.language = 'US'
;



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
    l_item_id number;
    l_organization_id number;

    l_app_url           varchar2(100);
    l_username          varchar2(100);
    l_password           varchar2(100);

XX_USER exception;
XX_APP exception;
XX_PASS exception;
begin
--retcode := '0';

log('Starting to update items:');


l_app_url := get_config('ServiceRootURL');
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

for c_i in c_items loop

    log('   Update item: '||c_i.segment1);

    log('   Building find item envelope!');

    l_find_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/" xmlns:typ1="http://xmlns.oracle.com/adf/svc/types/">
                   <soapenv:Header/>
                   <soapenv:Body>
                      <typ:findItem>
                         <typ:findCriteria>
                            <typ1:fetchStart>0</typ1:fetchStart>
                            <typ1:fetchSize>-1</typ1:fetchSize>
                            <!--Optional:-->
                            <typ1:filter>
                               <typ1:group>
                                  <!--Optional:-->
                                  <typ1:conjunction></typ1:conjunction>
                                  <typ1:upperCaseCompare>false</typ1:upperCaseCompare>
                                  <!--1 or more repetitions:-->
                                  <typ1:item>
                                     <!--Optional:-->
                                     <typ1:conjunction></typ1:conjunction>
                                     <typ1:upperCaseCompare>false</typ1:upperCaseCompare>
                                     <typ1:attribute>ItemNumber</typ1:attribute>
                                     <typ1:operator>=</typ1:operator>
                                     <!--You have a CHOICE of the next 2 items at this level-->
                                     <!--Zero or more repetitions:-->
                                     <typ1:value>'||c_i.segment1||'</typ1:value>                                     
                                  </typ1:item>
                               </typ1:group>
                               <!--Zero or more repetitions:-->
                               <typ1:nested/>
                            </typ1:filter>
                            <!--Optional:-->
                            <!--Zero or more repetitions:-->
                           <typ1:excludeAttribute>false</typ1:excludeAttribute>
                         </typ:findCriteria>
                         <typ:findControl>
                            <typ1:retrieveAllTranslations>false</typ1:retrieveAllTranslations>
                         </typ:findControl>
                      </typ:findItem>
                   </soapenv:Body>
                </soapenv:Envelope>';  

    l_soap_env := l_soap_env|| to_clob(l_find_text);
    l_find_text := '';    
--    l_soap_env := l_soap_env|| to_clob(l_text);
--    l_text := '';

    log('   Envelope built!');

    log('   Calling web service.');
    XXFN_CLOUD_WS_PKG.WS_CALL(
      p_ws_url => 'https://fa-encc-test-saasfaprod1.fa.ocs.oraclecloud.com:443/fscmService/ItemServiceV2?WSDL',
      p_soap_env => l_soap_env,
      p_soap_act => 'findItem',
      p_content_type => 'text/xml;charset="UTF-8"',
      x_return_status => x_return_status,
      x_return_message => x_return_message,
      x_ws_call_id => x_ws_call_id);

      log(' Web service to find item finished! ws_call_id:'||x_ws_call_id);

      log('Parsing ws_call to get item cloud id..');

      BEGIN
        SELECT
            to_number(xt.itemid),
            to_number(xt.organizationid)        
            INTO
            l_item_id,
            l_organization_id
        FROM
            xxfn_ws_call_log x,
            XMLTABLE (XMLNAMESPACES(     
            'http://schemas.xmlsoap.org/soap/envelope/' as "env",
            'http://www.w3.org/2005/08/addressing' as "wsa",
            'http://xmlns.oracle.com/adf/svc/types/' as "ns0",
            'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/' as "ns1",
            'http://xmlns.oracle.com/adf/svc/errors/' as "tns",
            'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/' as "ns2",
            'http://www.w3.org/2001/XMLSchema-instance' as "xsi"
            ),
             './/ns0:Value' PASSING x.response_xml 
             COLUMNS itemid number PATH 'ns1:ItemId', 
             organizationid VARCHAR2(4000) PATH 'ns1:OrganizationId' ) xt
        WHERE
            x.ws_call_id = x_ws_call_id;

        EXCEPTION
            WHEN no_data_found THEN
                l_item_id :=0;
                l_organization_id :=0;
        END;

        log('Cloud ItemId: '||l_item_id);
        log('Cloud OrganizationId: '||l_organization_id);


--log(l_text);
--dbms_lob.freetemporary(l_soap_env);
    log(' ws_call_id:'||x_ws_call_id);
    l_item_rec.inventory_item_id := c_i.inventory_item_id;
    l_item_rec.organization_id := c_i.organization_id;
    l_item_rec.segment1 := c_i.segment1;
    l_item_rec.organization_code := c_i.organization_code;
    l_item_rec.description := c_i.description;
    l_item_rec.primary_uom_code := c_i.primary_uom_code;
    l_item_rec.process_flag := x_return_status;
    l_item_rec.last_update_date := sysdate;
    l_item_rec.cloud_item_id := l_item_id;
    l_item_rec.cloud_org_id := l_organization_id;
    l_item_rec.category := c_i.kat;

    if x_return_status = 'S' then

        log('   Starting  item update!');

        l_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/" xmlns:item="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/" xmlns:cat="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/itemSupplier/categories/" xmlns:item1="http://xmlns.oracle.com/apps/scm/productModel/items/flex/itemRevision/" xmlns:cat1="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/itemRevision/categories/" xmlns:cat2="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/item/categories/" xmlns:item2="http://xmlns.oracle.com/apps/scm/productModel/items/flex/item/" xmlns:item3="http://xmlns.oracle.com/apps/scm/productModel/items/flex/itemGdf/" xmlns:mod="http://xmlns.oracle.com/apps/flex/fnd/applcore/attachments/model/">
                   <soapenv:Header/>
                   <soapenv:Body>
                      <typ:updateItem>
                         <typ:item>
                            <item:ItemId>'||l_item_id||'</item:ItemId>
                            <item:OrganizationId>'||l_organization_id||'</item:OrganizationId>
                            <item:ItemDescription>'||c_i.description_escaped||'</item:ItemDescription>
                            <item:LongDescription>'||c_i.description_escaped||'</item:LongDescription>
                            <item:PrimaryUOMValue>'||c_i.primary_uom_code||'</item:PrimaryUOMValue>
                         </typ:item>
                      </typ:updateItem>
                   </soapenv:Body>
                </soapenv:Envelope>';

        l_soap_env := l_empty_clob;
        l_soap_env := l_soap_env|| to_clob(l_text);
        l_text := '';    

        log('   Envelope for update built!');

        log('   Calling web service.');
        XXFN_CLOUD_WS_PKG.WS_CALL(
          p_ws_url => 'https://fa-encc-test-saasfaprod1.fa.ocs.oraclecloud.com:443/fscmService/ItemServiceV2?WSDL',
          p_soap_env => l_soap_env,
          p_soap_act => 'updateItem',
          p_content_type => 'text/xml;charset="UTF-8"',
          x_return_status => x_return_status,
          x_return_message => x_return_message,
          x_ws_call_id => x_ws_call_id);

        log(' Web service finished! ws_call_id:'||x_ws_call_id);

        if x_return_status = 'S' then


            update xxfn_ws_call_log xx 
            set xx.response_xml = null
            ,xx.response_clob = null
            ,xx.response_blob = null
            ,xx.ws_payload_xml = null
            where ws_call_id = x_ws_call_id;

            if l_item_id != 0 and l_organization_id != 0 then
                UPDATE XXDL_MTL_SYSTEM_ITEMS_MIG xx
                SET
                    xx.last_update_date = sysdate
                    ,xx.cloud_item_id = l_item_rec.cloud_item_id
                    ,xx.cloud_org_id = l_item_rec.cloud_org_id
                WHERE
                    xx.inventory_item_id = l_item_rec.inventory_item_id
                    AND xx.organization_id = l_item_rec.organization_id;
            end if;

        else
            log('   Error! Item not updated!');
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
                            l_item_rec.error_msg := 'Cannot find env:Fault in ws call results.';
                    END;
            END;             

            l_item_rec.error_msg := substr( 'Greska => Code:'||l_fault_code||' Text:'||l_fault_string,1,1000);        
            log('   '||l_item_rec.error_msg); 

        end if;


    else
        log('   Error! Item not updated!');
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
                        l_item_rec.error_msg := 'Cannot find env:Fault in ws call results.';
                END;
        END;             

        l_item_rec.error_msg := substr( 'Greska => Code:'||l_fault_code||' Text:'||l_fault_string,1,1000);        
        log('   '||l_item_rec.error_msg);        
    end if;

    BEGIN
           if l_item_id != 0 and l_organization_id != 0 then
            UPDATE XXDL_MTL_SYSTEM_ITEMS_MIG xx
                SET
                    xx.last_update_date = sysdate
                    ,xx.cloud_item_id = l_item_rec.cloud_item_id
                    ,xx.cloud_org_id = l_item_rec.cloud_org_id
                WHERE
                    xx.inventory_item_id = l_item_rec.inventory_item_id
                    AND xx.organization_id = l_item_rec.organization_id;
            end if;

    EXCEPTION
        WHEN dup_val_on_index THEN
            l_item_rec.last_update_date := SYSDATE;
            UPDATE XXDL_MTL_SYSTEM_ITEMS_MIG xx
            SET
                row = l_item_rec
            WHERE
                xx.inventory_item_id = l_item_rec.inventory_item_id
                AND xx.organization_id = l_item_rec.organization_id;

    END;

    l_item_rec := l_item_empty;
    l_soap_env := l_empty_clob;
    l_cnt := l_cnt + 1;

end loop;

log('Finished item update!');
log('Record count:'||l_cnt);


exception
    when XX_APP then
        log('No cloud url found!');
    when XX_USER then
        log('No cloud user found!');
    when XX_PASS then
        log('No cloud password found!');
    when others then
        log('Unexpected error! SQLCODE:'||SQLCODE||' SQLERRM:'||SQLERRM);
        log('Error_Stack...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_STACK()||' Error_Backtrace...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE());

end update_items_cloud;

  --/*-----------------------------------------------------------------------------
  -- Name    : update_items_cloud
  -- Desc    : Procedure for migrating EBS items to cloud to OD3
  -- Usage   : Concurrent Program XXUN Migrate items to cloud.
  -- Parameters	
--       - p_item_seg: item number in EBS
--       - p_rows: number of rows to process, default 1000
--		 - p_year: year of oldest purchase order created
--		 - p_retry_error: should we process records that ended in error
  -------------------------------------------------------------------------------*/

procedure update_items_cloud_ewha_test (
p_item_seg in varchar2,
p_rows in number,
p_year in varchar2,
p_retry_error in varchar2
)
is

cursor c_items is
select
msi.segment1
,'<![CDATA['||msi.description||']]>' description_escaped
,msi.description description
,msi.primary_uom_code
,msi.inventory_item_id
,msi.organization_id
,mp.organization_code
,mic.segment1 kat
from
apps.mtl_system_items_b@EBSPROD msi
,apps.mtl_parameters@EBSPROD mp
,(select
mic.inventory_item_id
,mic.organization_id
,mic.category_set_id
,mic.category_id
,mcst.category_set_name
,mcst.description
,mcb.segment1
,mcb.segment2
,mcb.segment3
,mcb.segment4
,mcb.segment5
,mcb.segment6
,mcb.segment7
,mcb.segment8
,mcb.segment9
,mcb.segment10
from
apps.mtl_item_categories@EBSPROD mic,
apps.mtl_category_sets_tl@EBSPROD mcst,
apps.mtl_category_sets_b@EBSPROD mcs,
apps.mtl_categories_b@EBSPROD mcb
where mic.category_set_id = mcs.category_set_id
AND mcs.category_set_id = mcst.category_set_id
AND mcst.LANGUAGE = 'HR'
AND mic.category_id = mcb.category_id) mic
where 1=1
and to_char(msi.segment1) like nvl(to_char(p_item_seg),'%')
and msi.organization_id = mp.organization_id
and mp.organization_code != 'DLK'
--and nvl(xx.process_flag,'X') != 'P'
--and xx.segment1 = msi.segment1
and msi.inventory_item_id = mic.inventory_item_id
and msi.organization_id = mic.organization_id
and msi.purchasing_enabled_flag = 'Y'
and mic.category_set_name = 'XXDL kategorizacija'
and rownum <= p_rows
and mic.segment1 != '0'
and not exists (select 1 from XXDL_MTL_SYSTEM_ITEMS_MIG xx 
                    where xx.inventory_item_id = msi.inventory_item_id
                    and xx.organization_id = msi.organization_id
                    and nvl(xx.process_flag,'X') in ('S',decode(p_retry_error,'Y','N','E'))) --ne zelim da ponovo pokusava errored recorde, njih treba pregledati
and exists (select 1 from apps.mtl_material_transactions@EBSPROD mmt
            where mmt.INVENTORY_ITEM_ID = msi.inventory_item_id
            and mmt.organization_id = msi.organization_id
            and mmt.creation_date >= to_date('01.01.'||nvl(p_year,to_char(sysdate,'YYYY')),'DD.MM.YYYY')
            and msi.organization_id not in (102)
            union
            select 1 
            from dual
            where msi.organization_id in (102)
            )
;


cursor c_items_lang (c_item_id in number, c_org_id in number) is
select
'<![CDATA['||msit.description||']]>' description_escaped
,'<![CDATA['||msit.long_description||']]>' long_description_esc
,msit.description description
,msit.long_description long_description
,msit.language
,msit.source_lang
from
apps.mtl_system_items_tl@EBSPROD msit
where
msit.inventory_item_id = c_item_id
and msit.organization_id = c_org_id
and msit.language = 'US'
;



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
    l_item_id number;
    l_organization_id number;

    l_app_url           varchar2(100);
    l_username          varchar2(100);
    l_password           varchar2(100);

XX_USER exception;
XX_APP exception;
XX_PASS exception;
begin
--retcode := '0';

log('Starting to update items:');


l_app_url := get_config('ServiceRootURL');
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

for c_i in c_items loop

    log('   Update item: '||c_i.segment1);

    log('   Building find item envelope!');

    l_find_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/" xmlns:typ1="http://xmlns.oracle.com/adf/svc/types/">
                   <soapenv:Header/>
                   <soapenv:Body>
                      <typ:findItem>
                         <typ:findCriteria>
                            <typ1:fetchStart>0</typ1:fetchStart>
                            <typ1:fetchSize>-1</typ1:fetchSize>
                            <!--Optional:-->
                            <typ1:filter>
                               <typ1:group>
                                  <!--Optional:-->
                                  <typ1:conjunction></typ1:conjunction>
                                  <typ1:upperCaseCompare>false</typ1:upperCaseCompare>
                                  <!--1 or more repetitions:-->
                                  <typ1:item>
                                     <!--Optional:-->
                                     <typ1:conjunction></typ1:conjunction>
                                     <typ1:upperCaseCompare>false</typ1:upperCaseCompare>
                                     <typ1:attribute>ItemNumber</typ1:attribute>
                                     <typ1:operator>=</typ1:operator>
                                     <!--You have a CHOICE of the next 2 items at this level-->
                                     <!--Zero or more repetitions:-->
                                     <typ1:value>'||c_i.segment1||'</typ1:value>                                     
                                  </typ1:item>
                               </typ1:group>
                               <!--Zero or more repetitions:-->
                               <typ1:nested/>
                            </typ1:filter>
                            <!--Optional:-->
                            <!--Zero or more repetitions:-->
                           <typ1:excludeAttribute>false</typ1:excludeAttribute>
                         </typ:findCriteria>
                         <typ:findControl>
                            <typ1:retrieveAllTranslations>false</typ1:retrieveAllTranslations>
                         </typ:findControl>
                      </typ:findItem>
                   </soapenv:Body>
                </soapenv:Envelope>';  

    l_soap_env := l_soap_env|| to_clob(l_find_text);
    l_find_text := '';    
--    l_soap_env := l_soap_env|| to_clob(l_text);
--    l_text := '';

    log('   Envelope built!');

    log('   Calling web service.');
    XXFN_CLOUD_WS_PKG.WS_CALL(
      p_ws_url => 'https://fa-encc-test-saasfaprod1.fa.ocs.oraclecloud.com:443/fscmService/ItemServiceV2?WSDL',
      p_soap_env => l_soap_env,
      p_soap_act => 'findItem',
      p_content_type => 'text/xml;charset="UTF-8"',
      x_return_status => x_return_status,
      x_return_message => x_return_message,
      x_ws_call_id => x_ws_call_id);

      log(' Web service to find item finished! ws_call_id:'||x_ws_call_id);

      log('Parsing ws_call to get item cloud id..');

      BEGIN
        SELECT
            to_number(xt.itemid),
            to_number(xt.organizationid)        
            INTO
            l_item_id,
            l_organization_id
        FROM
            xxfn_ws_call_log x,
            XMLTABLE (XMLNAMESPACES(     
            'http://schemas.xmlsoap.org/soap/envelope/' as "env",
            'http://www.w3.org/2005/08/addressing' as "wsa",
            'http://xmlns.oracle.com/adf/svc/types/' as "ns0",
            'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/' as "ns1",
            'http://xmlns.oracle.com/adf/svc/errors/' as "tns",
            'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/' as "ns2",
            'http://www.w3.org/2001/XMLSchema-instance' as "xsi"
            ),
             './/ns0:Value' PASSING x.response_xml 
             COLUMNS itemid number PATH 'ns1:ItemId', 
             organizationid VARCHAR2(4000) PATH 'ns1:OrganizationId' ) xt
        WHERE
            x.ws_call_id = x_ws_call_id;

        EXCEPTION
            WHEN no_data_found THEN
                l_item_id :=0;
                l_organization_id :=0;
        END;

        log('Cloud ItemId: '||l_item_id);
        log('Cloud OrganizationId: '||l_organization_id);


--log(l_text);
--dbms_lob.freetemporary(l_soap_env);
    log(' ws_call_id:'||x_ws_call_id);
    l_item_rec.inventory_item_id := c_i.inventory_item_id;
    l_item_rec.organization_id := c_i.organization_id;
    l_item_rec.segment1 := c_i.segment1;
    l_item_rec.organization_code := c_i.organization_code;
    l_item_rec.description := c_i.description;
    l_item_rec.primary_uom_code := c_i.primary_uom_code;
    l_item_rec.process_flag := x_return_status;
    l_item_rec.last_update_date := sysdate;
    l_item_rec.cloud_item_id := l_item_id;
    l_item_rec.cloud_org_id := l_organization_id;
    l_item_rec.category := c_i.kat;

    if x_return_status = 'S' then

        log('   Starting  item update!');

        l_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/" xmlns:item="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/" xmlns:cat="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/itemSupplier/categories/" xmlns:item1="http://xmlns.oracle.com/apps/scm/productModel/items/flex/itemRevision/" xmlns:cat1="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/itemRevision/categories/" xmlns:cat2="http://xmlns.oracle.com/apps/scm/productCatalogManagement/advancedItems/flex/egoItemEff/item/categories/" xmlns:item2="http://xmlns.oracle.com/apps/scm/productModel/items/flex/item/" xmlns:item3="http://xmlns.oracle.com/apps/scm/productModel/items/flex/itemGdf/" xmlns:mod="http://xmlns.oracle.com/apps/flex/fnd/applcore/attachments/model/">
                   <soapenv:Header/>
                   <soapenv:Body>
                      <typ:updateItem>
                         <typ:item>
                            <item:ItemId>'||l_item_id||'</item:ItemId>
                            <item:OrganizationId>'||l_organization_id||'</item:OrganizationId>
                            <item:ItemDescription>'||c_i.description_escaped||'</item:ItemDescription>
                            <item:LongDescription>'||c_i.description_escaped||'</item:LongDescription>
                            <item:PrimaryUOMValue>'||c_i.primary_uom_code||'</item:PrimaryUOMValue>
                         </typ:item>
                      </typ:updateItem>
                   </soapenv:Body>
                </soapenv:Envelope>';

        l_soap_env := l_empty_clob;
        l_soap_env := l_soap_env|| to_clob(l_text);
        l_text := '';    

        log('   Envelope for update built!');

        log('   Calling web service.');
        XXFN_CLOUD_WS_PKG.WS_CALL(
          p_ws_url => 'https://fa-encc-test-saasfaprod1.fa.ocs.oraclecloud.com:443/fscmService/ItemServiceV2?WSDL',
          p_soap_env => l_soap_env,
          p_soap_act => 'updateItem',
          p_content_type => 'text/xml;charset="UTF-8"',
          x_return_status => x_return_status,
          x_return_message => x_return_message,
          x_ws_call_id => x_ws_call_id);

        log(' Web service finished! ws_call_id:'||x_ws_call_id);

        if x_return_status = 'S' then


            update xxfn_ws_call_log xx 
            set xx.response_xml = null
            ,xx.response_clob = null
            ,xx.response_blob = null
            ,xx.ws_payload_xml = null
            where ws_call_id = x_ws_call_id;

            if l_item_id != 0 and l_organization_id != 0 then
                UPDATE XXDL_MTL_SYSTEM_ITEMS_MIG xx
                SET
                    xx.last_update_date = sysdate
                    ,xx.cloud_item_id = l_item_rec.cloud_item_id
                    ,xx.cloud_org_id = l_item_rec.cloud_org_id
                WHERE
                    xx.inventory_item_id = l_item_rec.inventory_item_id
                    AND xx.organization_id = l_item_rec.organization_id;
            end if;

        else
            log('   Error! Item not updated!');
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
                            l_item_rec.error_msg := 'Cannot find env:Fault in ws call results.';
                    END;
            END;             

            l_item_rec.error_msg := substr( 'Greska => Code:'||l_fault_code||' Text:'||l_fault_string,1,1000);        
            log('   '||l_item_rec.error_msg); 

        end if;


    else
        log('   Error! Item not updated!');
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
                        l_item_rec.error_msg := 'Cannot find env:Fault in ws call results.';
                END;
        END;             

        l_item_rec.error_msg := substr( 'Greska => Code:'||l_fault_code||' Text:'||l_fault_string,1,1000);        
        log('   '||l_item_rec.error_msg);        
    end if;

    BEGIN
           if l_item_id != 0 and l_organization_id != 0 then
            UPDATE XXDL_MTL_SYSTEM_ITEMS_MIG xx
                SET
                    xx.last_update_date = sysdate
                    ,xx.cloud_item_id = l_item_rec.cloud_item_id
                    ,xx.cloud_org_id = l_item_rec.cloud_org_id
                WHERE
                    xx.inventory_item_id = l_item_rec.inventory_item_id
                    AND xx.organization_id = l_item_rec.organization_id;
            end if;

    EXCEPTION
        WHEN dup_val_on_index THEN
            l_item_rec.last_update_date := SYSDATE;
            UPDATE XXDL_MTL_SYSTEM_ITEMS_MIG xx
            SET
                row = l_item_rec
            WHERE
                xx.inventory_item_id = l_item_rec.inventory_item_id
                AND xx.organization_id = l_item_rec.organization_id;

    END;

    l_item_rec := l_item_empty;
    l_soap_env := l_empty_clob;
    l_cnt := l_cnt + 1;

end loop;

log('Finished item update!');
log('Record count:'||l_cnt);


exception
    when XX_APP then
        log('No cloud url found!');
    when XX_USER then
        log('No cloud user found!');
    when XX_PASS then
        log('No cloud password found!');
    when others then
        log('Unexpected error! SQLCODE:'||SQLCODE||' SQLERRM:'||SQLERRM);
        log('Error_Stack...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_STACK()||' Error_Backtrace...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE());

end update_items_cloud_ewha_test;

  --/*-----------------------------------------------------------------------------
  -- Name    : find_item_cloud
  -- Desc    : Function to find item in cloud
  -- Usage   : 
  -- Parameters
  --     p_item in varchar2,
  --    p_org in varchar
  -------------------------------------------------------------------------------*/
procedure find_item_cloud (
      p_item in varchar2,
      p_org in varchar2,
      p_cloud_item out number,
      p_cloud_org out number) is

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
    l_item_id number;
    l_organization_id number;     
l_app_url varchar2(300);
begin


l_app_url := get_config('ServiceRootURL');

    log('   Building find item envelope!');

    l_find_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/" xmlns:typ1="http://xmlns.oracle.com/adf/svc/types/">
                   <soapenv:Header/>
                   <soapenv:Body>
                      <typ:findItem>
                         <typ:findCriteria>
                            <typ1:fetchStart>0</typ1:fetchStart>
                            <typ1:fetchSize>-1</typ1:fetchSize>
                            <!--Optional:-->
                            <typ1:filter>
                               <typ1:group>
                                  <!--Optional:-->
                                  <typ1:conjunction></typ1:conjunction>
                                  <typ1:upperCaseCompare>false</typ1:upperCaseCompare>
                                  <!--1 or more repetitions:-->
                                  <typ1:item>
                                     <!--Optional:-->
                                     <typ1:conjunction></typ1:conjunction>
                                     <typ1:upperCaseCompare>false</typ1:upperCaseCompare>
                                     <typ1:attribute>ItemNumber</typ1:attribute>
                                     <typ1:operator>=</typ1:operator>
                                     <!--You have a CHOICE of the next 2 items at this level-->
                                     <!--Zero or more repetitions:-->
                                     <typ1:value>'||p_item||'</typ1:value>                                     
                                  </typ1:item>
                                  <typ1:item>
                                     <!--Optional:-->
                                     <typ1:conjunction></typ1:conjunction>
                                     <typ1:upperCaseCompare>false</typ1:upperCaseCompare>
                                     <typ1:attribute>OrganizationCode</typ1:attribute>
                                     <typ1:operator>=</typ1:operator>
                                     <!--You have a CHOICE of the next 2 items at this level-->
                                     <!--Zero or more repetitions:-->
                                     <typ1:value>'||p_org||'</typ1:value>                                     
                                  </typ1:item>
                               </typ1:group>
                               <!--Zero or more repetitions:-->
                               <typ1:nested/>
                            </typ1:filter>
                            <!--Optional:-->
                            <!--Zero or more repetitions:-->
                           <typ1:excludeAttribute>false</typ1:excludeAttribute>
                         </typ:findCriteria>
                         <typ:findControl>
                            <typ1:retrieveAllTranslations>false</typ1:retrieveAllTranslations>
                         </typ:findControl>
                      </typ:findItem>
                   </soapenv:Body>
                </soapenv:Envelope>';  

    l_soap_env := l_soap_env|| to_clob(l_find_text);
    l_find_text := '';    
--    l_soap_env := l_soap_env|| to_clob(l_text);
--    l_text := '';

    log('   Envelope built!');

    log('   Calling web service.');
    XXFN_CLOUD_WS_PKG.WS_CALL(
      p_ws_url => l_app_url||'fscmService/ItemServiceV2?WSDL',
      p_soap_env => l_soap_env,
      p_soap_act => 'findItem',
      p_content_type => 'text/xml;charset="UTF-8"',
      x_return_status => x_return_status,
      x_return_message => x_return_message,
      x_ws_call_id => x_ws_call_id);

      log(' Web service to find item finished! ws_call_id:'||x_ws_call_id);

      log('Parsing ws_call to get item cloud id..');

      BEGIN
        SELECT
            to_number(xt.itemid),
            to_number(xt.organizationid)        
            INTO
            p_cloud_item,
            p_cloud_org
        FROM
            xxfn_ws_call_log x,
            XMLTABLE (XMLNAMESPACES(     
            'http://schemas.xmlsoap.org/soap/envelope/' as "env",
            'http://www.w3.org/2005/08/addressing' as "wsa",
            'http://xmlns.oracle.com/adf/svc/types/' as "ns0",
            'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/' as "ns1",
            'http://xmlns.oracle.com/adf/svc/errors/' as "tns",
            'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/' as "ns2",
            'http://www.w3.org/2001/XMLSchema-instance' as "xsi"
            ),
             './/ns0:Value' PASSING x.response_xml 
             COLUMNS itemid number PATH 'ns1:ItemId', 
             organizationid VARCHAR2(4000) PATH 'ns1:OrganizationId' ) xt
        WHERE
            x.ws_call_id = x_ws_call_id;

        EXCEPTION
            WHEN no_data_found THEN
                p_cloud_item :=0;
                p_cloud_org :=0;
        END;

        log('Cloud ItemId: '||p_cloud_item);
        log('Cloud OrganizationId: '||p_cloud_org);

exception
  when others then
    p_cloud_item := 0;
    p_cloud_org := 0;
end;


 --/*-----------------------------------------------------------------------------
  -- Name    : find_item_cloud_ewha_test
  -- Desc    : Function to find item in cloud
  -- Usage   : 
  -- Parameters
  --     p_item in varchar2,
  --    p_org in varchar
  -------------------------------------------------------------------------------*/
procedure find_item_cloud_ewha_test (
      p_item in varchar2,
      p_org in varchar2,
      p_cloud_item out number,
      p_cloud_org out number) is

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
    l_item_id number;
    l_organization_id number;     
l_app_url varchar2(300);
begin


l_app_url := get_config('ServiceRootURL');

    log('   Building find item envelope!');

    l_find_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/" xmlns:typ1="http://xmlns.oracle.com/adf/svc/types/">
                   <soapenv:Header/>
                   <soapenv:Body>
                      <typ:findItem>
                         <typ:findCriteria>
                            <typ1:fetchStart>0</typ1:fetchStart>
                            <typ1:fetchSize>-1</typ1:fetchSize>
                            <!--Optional:-->
                            <typ1:filter>
                               <typ1:group>
                                  <!--Optional:-->
                                  <typ1:conjunction></typ1:conjunction>
                                  <typ1:upperCaseCompare>false</typ1:upperCaseCompare>
                                  <!--1 or more repetitions:-->
                                  <typ1:item>
                                     <!--Optional:-->
                                     <typ1:conjunction></typ1:conjunction>
                                     <typ1:upperCaseCompare>false</typ1:upperCaseCompare>
                                     <typ1:attribute>ItemNumber</typ1:attribute>
                                     <typ1:operator>=</typ1:operator>
                                     <!--You have a CHOICE of the next 2 items at this level-->
                                     <!--Zero or more repetitions:-->
                                     <typ1:value>'||p_item||'</typ1:value>                                     
                                  </typ1:item>
                                  <typ1:item>
                                     <!--Optional:-->
                                     <typ1:conjunction></typ1:conjunction>
                                     <typ1:upperCaseCompare>false</typ1:upperCaseCompare>
                                     <typ1:attribute>OrganizationCode</typ1:attribute>
                                     <typ1:operator>=</typ1:operator>
                                     <!--You have a CHOICE of the next 2 items at this level-->
                                     <!--Zero or more repetitions:-->
                                     <typ1:value>'||p_org||'</typ1:value>                                     
                                  </typ1:item>
                               </typ1:group>
                               <!--Zero or more repetitions:-->
                               <typ1:nested/>
                            </typ1:filter>
                            <!--Optional:-->
                            <!--Zero or more repetitions:-->
                           <typ1:excludeAttribute>false</typ1:excludeAttribute>
                         </typ:findCriteria>
                         <typ:findControl>
                            <typ1:retrieveAllTranslations>false</typ1:retrieveAllTranslations>
                         </typ:findControl>
                      </typ:findItem>
                   </soapenv:Body>
                </soapenv:Envelope>';  

    l_soap_env := l_soap_env|| to_clob(l_find_text);
    l_find_text := '';    
--    l_soap_env := l_soap_env|| to_clob(l_text);
--    l_text := '';

    log('   Envelope built!');

    log('   Calling web service.');
    XXFN_CLOUD_WS_PKG.WS_CALL(
      p_ws_url => l_app_url||'fscmService/ItemServiceV2?WSDL',
      p_soap_env => l_soap_env,
      p_soap_act => 'findItem',
      p_content_type => 'text/xml;charset="UTF-8"',
      x_return_status => x_return_status,
      x_return_message => x_return_message,
      x_ws_call_id => x_ws_call_id);

      log(' Web service to find item finished! ws_call_id:'||x_ws_call_id);

      log('Parsing ws_call to get item cloud id..');

      BEGIN
        SELECT
            to_number(xt.itemid),
            to_number(xt.organizationid)        
            INTO
            p_cloud_item,
            p_cloud_org
        FROM
            xxfn_ws_call_log x,
            XMLTABLE (XMLNAMESPACES(     
            'http://schemas.xmlsoap.org/soap/envelope/' as "env",
            'http://www.w3.org/2005/08/addressing' as "wsa",
            'http://xmlns.oracle.com/adf/svc/types/' as "ns0",
            'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/' as "ns1",
            'http://xmlns.oracle.com/adf/svc/errors/' as "tns",
            'http://xmlns.oracle.com/apps/scm/productModel/items/itemServiceV2/types/' as "ns2",
            'http://www.w3.org/2001/XMLSchema-instance' as "xsi"
            ),
             './/ns0:Value' PASSING x.response_xml 
             COLUMNS itemid number PATH 'ns1:ItemId', 
             organizationid VARCHAR2(4000) PATH 'ns1:OrganizationId' ) xt
        WHERE
            x.ws_call_id = x_ws_call_id;

        EXCEPTION
            WHEN no_data_found THEN
                p_cloud_item :=0;
                p_cloud_org :=0;
        END;

        log('Cloud ItemId: '||p_cloud_item);
        log('Cloud OrganizationId: '||p_cloud_org);

exception
  when others then
    p_cloud_item := 0;
    p_cloud_org := 0;
end;


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

end XXDL_INV_UTIL_PKG;
/
