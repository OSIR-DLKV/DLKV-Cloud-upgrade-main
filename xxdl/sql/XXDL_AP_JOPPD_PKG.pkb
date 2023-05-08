create or replace PACKAGE body XXDL_AP_JOPPD_PKG  is
/* $Header $
============================================================================+
File Name   : XXDL_AP_JOPPD_PKG.pks
Object      : XXDL_AP_JOPPD_PKG
Description : 
History     :
v1.0 09.05.2020 - 
============================================================================+*/


/*===========================================================================+
Procedure   : PROCESS_RECORDS_SCHED
Description : Scheduled process
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure PROCESS_RECORDS_SCHED is

l_result  varchar2(25);
p_status varchar2(2000) ;
p_message varchar2(2000);
l_max_date date;
begin



select  max(last_update_date) 
into l_max_date
from XXDL_UNPAID_PAY_REQUESTS_INT;

if(l_max_date is null)
then
l_max_date := to_date( '2022-12-07 08:00', 'YYYY-MM-DD HH24:MI');
end if;

l_max_date := l_max_date - 2/24;


--XXDL_AP_JOPPD_PKG.get_DATA(to_char(l_max_date   , 'YYYY-MM-DD HH24:MI'));
XXDL_AP_JOPPD_PKG.INSERT_PAY_REQUEST_DATA;

end PROCESS_RECORDS_SCHED;


/*===========================================================================+
Procedure   : insert_data
Description :
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure insert_data
is


cursor c_main is
select 
        LEGAL_ENTITY_ID,
        LEGAL_ENTITY_NAME,
        LEGAL_ENTITY_IDENTIFIER,
        INVOICE_ID,
        PERIOD_NAME,
        OIB,
        NAME,
        surname,
         to_date(PERIOD_FROM,'RRRR-MM-DD') PERIOD_FROM,
        to_date(PERIOD_TO,'RRRR-MM-DD') PERIOD_TO,

        person_number,
        to_date(payment_date, 'RRRR-MM-DD')  as payment_date, 
        PAYMENT_AMOUNT,
        status,
        MESSAGE
from xxdl_joppd_payments_int
where 1=1
and nvl(status, 'E') != 'S';
--and invoice_id = 19001; --6001;

l_status varchar2(1);
l_message varchar2(2000);
l_poduzece_id varchar2(11);
l_vrsta_stjecatelja varchar2(5);
l_vrsta_primitaka varchar2(5);
l_vrsta_neoporezivih varchar2(5);
l_nacin_izvrsenja varchar2(5);
l_region_home  varchar2(25);
l_region_work  varchar2(25);


begin


for c_main_rec in c_main loop

--HR_DALEKOVOD.IPD_SUCELJE.prenesi_stavku_joppd@ebsprod();
begin

select id 
into l_poduzece_id
from zpd_poduzeca@ebsprod
where maticni_broj = c_main_rec.legal_entity_identifier;

l_vrsta_stjecatelja := '67';
l_vrsta_primitaka := '81';
l_vrsta_neoporezivih := '17';
l_nacin_izvrsenja := '1';--isplata na tekuci uvijek
/*
hardcode sve
select * from ipd_vrste_stjecatelja ivs where oznaka='0000'


select * from ipd_vrste_primitaka ivpr where oznaka='0000'


select * from ipd_vrste_neoporezivih_prim ivnp where oznaka='17'


select * from ipd_nacini_izvrsenja ini where oznaka='1'
*/


/*mmatanovic 10.02.2023 hardcode l_region_work i l_region_home*/

/*
begin

select hrl.region_1
into l_region_work
from hr_locations@ebsprod hrl,
apps.xx_hr_pay_inter_assign_v@ebsprod xhp
where hrl.location_id = xhp.location_id
and xhp.employee_number = c_main_rec.person_number;

exception when no_data_found then
l_status := 'E';
l_message := substrb('Nije definiran region work za person_number:'||c_main_rec.person_number, 1, 2000);

update xxdl_joppd_payments_int
        set 
         status  = l_status,
         message = l_message
        where legal_entity_id = c_main_rec.legal_entity_id
         and invoice_id = c_main_rec.invoice_id
         and period_name = c_main_rec.period_name;
        continue; 
    -- l_region_work := 01333;   

end;*/

---l_region_work := '04740';

/*mk i oso imaju 05410, dalekovod i projekti 01333, emu je 04740 */
if(c_main_rec.LEGAL_ENTITY_NAME in ('Proizvodnja MK d.o.o.', 'Proizvodnja OSO d.o.o.'))
then
l_region_work := '05410';
elsif(c_main_rec.LEGAL_ENTITY_NAME in ('Dalekovod d.d.', 'Dalekovod Projekt d.o.o.'))
then
l_region_work := '01333';
elsif(c_main_rec.LEGAL_ENTITY_NAME = ('Dalekovod EMU d.o.o.'))
then
l_region_work := '04740';
end if;



begin
select region_1 
into l_region_home
from apps.xx_hr_pay_inter_empl_v@ebsprod
where employee_number = c_main_rec.person_number;

exception when no_data_found then

l_status := 'E';
l_message := substrb('Nije definiran region home za person_number:'||c_main_rec.person_number, 1, 2000);

update xxdl_joppd_payments_int
        set 
         status  = l_status,
         message = l_message
        where legal_entity_id = c_main_rec.legal_entity_id
         and invoice_id = c_main_rec.invoice_id
         and period_name = c_main_rec.period_name;
        continue; 
--l_region_home := 05410;
end;

if (c_main_rec.person_number = '315001')
then 
l_region_home := '04740';
end if;



/*
dbms_output.put_line('inserting values:'
||'l_poduzece_id'||l_poduzece_id
||'l_vrsta_stjecatelja'||l_vrsta_stjecatelja
||'l_vrsta_primitaka'||l_vrsta_primitaka
||'l_vrsta_neoporezivih'||l_vrsta_neoporezivih
||'l_nacin_izvrsenja'||l_nacin_izvrsenja
||'l_region_home'||l_region_home
||'l_region_work'||l_region_work
||'c_main_rec.oib'||c_main_rec.oib
||'c_main_rec.name'||c_main_rec.name
||'c_main_rec.surname'||c_main_rec.surname
||'c_main_rec.period_from'||c_main_rec.period_from
||'c_main_rec.period_to'||c_main_rec.period_to
||'c_main_rec.payment_amount'||c_main_rec.payment_amount
||'c_main_rec.payment_date'||c_main_rec.payment_date
);
*/

HR_DALEKOVOD.IPD_SUCELJE.prenesi_stavku_joppd@ebsprod (l_poduzece_id, --p_nPoduzece_id      in ipd_stavke_joppd.poduzece_id%type,
                                8, --p_vcOzn_izvor       in ipd_izvori.oznaka%type,
                                l_vrsta_stjecatelja, --p_vcOzn_vr_stj      in ipd_vrste_stjecatelja.oznaka%type,
                                l_vrsta_primitaka , --p_vcOzn_vr_prim     in ipd_vrste_primitaka.oznaka%type,
                                l_vrsta_neoporezivih,--p_vcOzn_vr_neopor   in ipd_vrste_neoporezivih_prim.oznaka%type,
                                l_nacin_izvrsenja,--p_vcOzn_nac_izvr    in ipd_nacini_izvrsenja.oznaka%type,
                                1,--p_vc_Vr_izvj        in ipd_stavke_joppd.vrsta_izvjesca%type,
                                l_region_home, --p_vcOpc_preb        in ipd_stavke_joppd.opcina_prebivalista%type,
                                l_region_work, --p_vcOpc_rada        in ipd_stavke_joppd.opcina_rada%type,
                                c_main_rec.oib,--p_vcPor_br          in ipd_stavke_joppd.porezni_broj%type,
                                c_main_rec.name, --p_vcIme                in ipd_stavke_joppd.ime%type,
                                c_main_rec.surname,--p_vcPrezime         in ipd_stavke_joppd.prezime%type,
                                0,--p_vcBen_staz        in ipd_stavke_joppd.beneficirani_staz%type,
                                0,--p_vcSt_zap_inv      in ipd_stavke_joppd.stopa_za_zaposljavanje_invalid%type,
                                0,--p_vcMj_osig         in ipd_stavke_joppd.mjesec_osiguranja%type,
                                0,--p_vcRadno_vr        in ipd_stavke_joppd.radno_vrijeme%type,
                                0,--p_nSati_rada        in ipd_stavke_joppd.sati_rada%type,
                                c_main_rec.period_from, --p_dPoc_razd         in ipd_stavke_joppd.pocetak_razdoblja%type,
                                c_main_rec.period_to, --p_dKraj_razd        in ipd_stavke_joppd.kraj_razdoblja%type,
                                0, --p_nRedovna_placa    in ipd_stavke_joppd.redovna_placa%type,
                                c_main_rec.payment_amount,--p_nNeopor           in ipd_stavke_joppd.neoporezivo%type,
                                0, --p_nOpor_prim        in ipd_stavke_joppd.oporezivi_primitak%type,
                                0, --p_nOsn_dopr         in ipd_stavke_joppd.osnovica_doprinosa%type,
                                0, --p_nDopr_mo1         in ipd_stavke_joppd.doprinos_mo_1%type,
                                0, --p_nDopr_mo2         in ipd_stavke_joppd.doprinos_mo_2%type,
                                0, --p_nDopr_zdrav       in ipd_stavke_joppd.doprinos_zdravstvo%type,
                                0, --p_nDopr_zzr         in ipd_stavke_joppd.doprinos_zzr%type,
                                0, --p_nDopr_zapos       in ipd_stavke_joppd.doprinos_zaposljavanje%type,
                                0, --p_nDopr_ben1        in ipd_stavke_joppd.doprinos_beneficirani_1%type,
                                0, --p_nDopr_ben2        in ipd_stavke_joppd.doprinos_beneficirani_2%type,
                                0, --p_nDopr_ino_zdrav   in ipd_stavke_joppd.doprinos_ino_zdravstvo%type,
                                0, --p_nDopr_zapos_inv   in ipd_stavke_joppd.doprinos_zaposljavanje_invalid%type,
                                0, --p_nIzdatak          in ipd_stavke_joppd.izdatak%type,
                                0, --p_nIzdatak_mo        in ipd_stavke_joppd.izdatak_mo%type,
                                0, --p_nDohodak          in ipd_stavke_joppd.dohodak%type,
                                0, --p_nOsobni_odb       in ipd_stavke_joppd.osobni_odbitak%type,
                                0, --p_nPor_osn          in ipd_stavke_joppd.porezna_osnovica%type,
                                0, --p_nPorez            in ipd_stavke_joppd.porez%type,
                                0, --p_nPrirez           in ipd_stavke_joppd.prirez%type,
                                c_main_rec.payment_amount, --p_nNeto             in ipd_stavke_joppd.neto%type,
                                'FUSION', --p_vcVanjski_ident   in ipd_stavke_joppd.vanjski_identifikator%type,
                                c_main_rec.payment_date,--p_dDatum_isplate    in ipd_stavke_joppd.datum_isplate%type,
                                null, --p_vcPoduzeceMatbr   in varchar2 default null,
                                null--p_nNeodradjeni_sati_rada in ipd_stavke_joppd.neodradjeni_sati_rada%type default null
                                );

        update xxdl_joppd_payments_int
        set 
         status  = 'S',
         message =NULL
        where legal_entity_id = c_main_rec.legal_entity_id
         and invoice_id = c_main_rec.invoice_id
         and period_name = c_main_rec.period_name;

exception when others then
        l_status := 'E';
        l_message := substrb('Exception in XX_AP_JOPPD_PKG.INSERT_DATA, SQLCODE:'||sqlcode||', SQLERRM:'||SQLERRM, 1, 2000);

        update xxdl_joppd_payments_int
        set 
         status  = l_status,
         message = l_message
        where legal_entity_id = c_main_rec.legal_entity_id
         and invoice_id = c_main_rec.invoice_id
         and period_name = c_main_rec.period_name;

end;
commit;
end loop;


end insert_data;

/*===========================================================================+
Procedure   : get_data
Description :
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure get_data (p_period_name in varchar2, p_legal_entity_name in varchar2,p_status out varchar2, p_msg out varchar2)
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

l_ws_call_id    number;

l_domain varchar2(150);
l_count number := 0;
l_url varchar2(75);

l_return_status varchar2(10);
l_return_message varchar2(2000);
p_supplier_name varchar2(20);
p_source_system varchar2(2000);
p_source_site_id varchar2(50);
p_supplier_site varchar2(20);
p_ws_call_id number;
BEGIN

execute immediate 'alter session set NLS_TIMESTAMP_TZ_FORMAT= ''YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM''';
--execute immediate 'alter session set nls_date_format=''yyyy-mm-dd hh24:mi:ss''';
--execute immediate 'alter session set NLS_TIMESTAMP_FORMAT= ''YYYY-MM-DD"T"HH24:MI:SS.FF3''';

select value 
into l_url
from xx_configuration
where name = 'ServiceRootURL'; 
 --l_url:= 'https://fa-ewha-test-saasfaprod1.fa.ocs.oraclecloud.com/';

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
                  <pub:name>p_period_name</pub:name>
                  <pub:values>
                     <!--Zero or more repetitions:-->
                     <pub:item>'||p_period_name||'</pub:item>
                  </pub:values>
               </pub:item>
               <pub:item>
                  <pub:name>p_legal_entity_name</pub:name>
                  <pub:values>
                     <!--Zero or more repetitions:-->
                    <pub:item>'||p_legal_entity_name||'</pub:item>
                  </pub:values>
               </pub:item>
            </pub:parameterNameValues>
            <pub:reportAbsolutePath>Custom/XXDL_Integration/XXDL_JOPPD_REP.xdo</pub:reportAbsolutePath>
            <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
         </pub:reportRequest>
         <pub:appParams></pub:appParams>
      </pub:runReport>
   </soap:Body>
</soap:Envelope>';

--log('Payload:'||l_text);

 /* If (fnd_profile.value('APPS_DATABASE_ID')='prod') then
                  L_domain:= fnd_profile.value('XXFN_CS_PROD_DOMAIN_PRF');
  Else
                  L_domain:= fnd_profile.value('XXFN_CS_TEST_DOMAIN_PRF');
  end if; */

 --  l_domain := xxpo_cs_download_pkg.get_wsdl_domain;
  --l_domain := 'https://epfc-test.fa.em2.oraclecloud.com';
  l_soap_env := to_clob(l_text);

  l_count := 0;
    XXFN_CLOUD_WS_PKG.WS_CALL(
        p_ws_url => l_url||'/xmlpserver/services/ExternalReportWSSService?WSDL',
        p_soap_env => l_soap_env,
        p_soap_act => 'runReport',
        p_content_type => 'application/soap+xml;charset="UTF-8"',
        x_return_status => l_return_status,
        x_return_message => l_return_message,
        x_ws_call_id => l_ws_call_id);

  p_ws_call_id := l_ws_call_id;
  dbms_lob.freetemporary(l_soap_env);

  p_status := l_return_status;
  p_msg := substrb(l_return_message, 1,2000);

  if(l_return_status = 'S') then
      begin
      select response_xml
      into l_resp_xml
      from xxfn_ws_call_log_v
      where ws_call_id = l_ws_call_id;
      exception
        when no_data_found then
        p_Status := 'E';
        p_msg := substrb('Error in XXDL_AP_JOPPD_PKG.GET_DATA, there is no data in xxfn_ws_call_log_v, ws_Call_id:'||l_ws_call_id  , 1, 2000);
        return;
      end;

      begin
      SELECT xml.vals
      INTO l_result_clob
      FROM xxfn_ws_call_log_v a,
        XMLTable(xmlnamespaces('http://xmlns.oracle.com/oxp/service/PublicReportService' AS "ns2",'http://www.w3.org/2003/05/soap-envelope' AS "env"), '/env:Envelope/env:Body/ns2:runReportResponse/ns2:runReportReturn' PASSING a.response_xml COLUMNS vals CLOB PATH './ns2:reportBytes') xml
      WHERE a.ws_call_id = l_ws_call_id
      AND xml.vals      IS NOT NULL;
      exception
        when no_data_found then
        p_Status := 'E';
        p_msg := substrb('Error in XXDL_AP_JOPPD_PKG.GET_DATA, cannot get xml.vals from xxfn_ws_call_log_v, ws_Call_id:'||l_ws_call_id  , 1, 2000);
        return;
      end;


      l_result_clob_decode := xxfn_cloud_ws_pkg.DecodeBASE64(l_result_clob);
      l_resp_xml_id := XMLType.createXML(l_result_clob_decode);
      --log('Parsing report response for suppliers');
      FOR cur_rec IN (
      SELECT xt.*
      FROM   XMLTABLE('/DATA_DS/NALOZI'
               PASSING l_resp_xml_id
               COLUMNS

                   LEGAL_ENTITY_ID NUMBER PATH 'LEGAL_ENTITY_ID',
                    LEGAL_ENTITY_NAME VARCHAR2(50) PATH 'LEGAL_ENTITY_NAME',
                    LEGAL_ENTITY_IDENTIFIER VARCHAR2(50) PATH 'LEGAL_ENTITY_IDENTIFIER',
                    INVOICE_ID NUMBER PATH 'INVOICE_ID',
                    PERIOD_NAME VARCHAR2(7) PATH 'PERIOD_NAME',
                    OIB VARCHAR2(11) PATH 'OIB',
                    NAME VARCHAR2(50) PATH 'NAME',
                    SURNAME VARCHAR2(50) PATH 'SURNAME',
                    PERSON_NUMBER NUMBER PATH 'PERSON_NUMBER',
                    PERIOD_FROM VARCHAR2(10) PATH 'PERIOD_FROM',
                    PERIOD_TO VARCHAR2(10) PATH 'PERIOD_TO',
                    PAYMENT_DATE VARCHAR2(10) PATH 'PAYMENT_DATE',
                    PAYMENT_AMOUNT NUMBER PATH 'PAYMENT_AMOUNT'
               ) xt)
      LOOP

        begin

        insert into
        xxdl_joppd_payments_int
        (LEGAL_ENTITY_ID,
        LEGAL_ENTITY_NAME,
        LEGAL_ENTITY_IDENTIFIER,
        INVOICE_ID,
        PERIOD_NAME,
        OIB,
        NAME,
        SURNAME,
        PERSON_NUMBER,
        PERIOD_FROM,
        PERIOD_TO,
        PAYMENT_DATE,
        PAYMENT_AMOUNT,
        status,
        MESSAGE)
        values 
        (cur_rec.LEGAL_ENTITY_ID,
        cur_rec.LEGAL_ENTITY_NAME,
        cur_rec.LEGAL_ENTITY_IDENTIFIER,
        cur_rec.INVOICE_ID,
        cur_rec.PERIOD_NAME,
        cur_rec.OIB,
        cur_rec.NAME,
        cur_rec.SURNAME,
        cur_rec.PERSON_NUMBER,
        cur_rec.PERIOD_FROM,
        cur_rec.PERIOD_TO,
        cur_rec.PAYMENT_DATE,
        cur_rec.PAYMENT_AMOUNT,
        null,
        null);

         exception when dup_val_on_index then

         update xxdl_joppd_payments_int
         set 
         LEGAL_ENTITY_NAME = cur_rec.LEGAL_ENTITY_NAME,
         LEGAL_ENTITY_IDENTIFIER = cur_rec.LEGAL_ENTITY_IDENTIFIER,
        OIB = cur_rec.oib,
        NAME = cur_rec.name,
        SURNAME = cur_rec.surname,
        PERIOD_FROM = cur_rec.period_from,
        PERIOD_TO = cur_rec.period_to,
        PAYMENT_DATE = cur_rec.PAYMENT_DATE,
        PAYMENT_AMOUNT = cur_rec.payment_amount,
         PERSON_NUMBER = cur_rec.PERSON_NUMBER

         where legal_entity_id = cur_rec.legal_entity_id
         and invoice_id = cur_rec.invoice_id
         and period_name = cur_rec.period_name;

         end;
      end loop;
commit;
p_status := 'S';
else
       p_Status := 'E';
       p_msg := substrb('Error in XXDL_AP_JOPPD_PKG.GET_DATA, Call to report XX_GET_CURRENCY_RATES_REP did not end with S', 1, 2000);
       return;
end if;


exception
  when others then

       p_Status := 'E';
       p_msg := substrb('Exception in XXDL_AP_JOPPD_PKG.GET_DATA; SQLCODE:'||SQLCODE||'; SQLERRM:'|| SQLERRM, 1, 2000);

end;



/*===========================================================================+
Procedure   : insert_pay_request_data
Description :
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure insert_pay_request_data
is


cursor c_main is            
select 
        LEGAL_ENTITY_ID,
        LEGAL_ENTITY_NAME,
        LEGAL_ENTITY_IDENTIFIER,
        INVOICE_ID,
        PERIOD_NAME,
        OIB,
        NAME,
        surname,
        PERSON_NUMBER,
         to_date(PERIOD_FROM,'RRRR-MM-DD') PERIOD_FROM,
        to_date(PERIOD_TO,'RRRR-MM-DD') PERIOD_TO,
        to_char(to_date(PERIOD_FROM,'RRRR-MM-DD'), 'RRRR') as year,
        to_char(to_date(PERIOD_FROM,'RRRR-MM-DD'), 'MM') as month,
        VENDOR_NAME,
        VENDOR_SITE_CODE,
        VENDOR_ID,
        INVOICE_NUM,
        INVOICE_CURRENCY_CODE,
        EXCHANGE_RATE,
        INVOICE_AMOUNT,
        AMOUNT_PAID,
        LAST_UPDATE_DATE,
          nvl(INVOICE_AMOUNT, 0) - nvl(AMOUNT_PAID, 0) as pay_amount,
        status,
        MESSAge
from XXDL_UNPAID_PAY_REQUESTS_INT
where 1=1
and nvl(insert_interface_status, 'E') != 'S';
--and invoice_id = 19001; --6001;

l_status varchar2(1);
l_message varchar2(2000);
l_poduzece_id varchar2(11);

l_counter number;


begin


for c_main_rec in c_main loop

--HR_DALEKOVOD.IPD_SUCELJE.prenesi_stavku_joppd@ebsprod();
begin

select id 
into l_poduzece_id
from zpd_poduzeca@ebsprod
where maticni_broj = c_main_rec.legal_entity_identifier;




/*
begin
select region_1 
into l_region_home
from xx_hr_pay_inter_empl_v@ebsprod
where employee_number = c_main_rec.person_number;

exception when no_data_found then

l_status := 'E';
l_message := substrb('Nije definiran region home za person_number:'||c_main_rec.person_number, 1, 2000);

update XXDL_UNPAID_PAY_REQUESTS_INT
        set 
         status  = l_status,
         message = l_message
        where legal_entity_id = c_main_rec.legal_entity_id
         and invoice_id = c_main_rec.invoice_id
         and period_name = c_main_rec.period_name;
        continue; 
--l_region_home := 05410;
end;
*/

/*
dbms_output.put_line('inserting values:'
||'l_poduzece_id'||l_poduzece_id
||'l_vrsta_stjecatelja'||l_vrsta_stjecatelja
||'l_vrsta_primitaka'||l_vrsta_primitaka
||'l_vrsta_neoporezivih'||l_vrsta_neoporezivih
||'l_nacin_izvrsenja'||l_nacin_izvrsenja
||'l_region_home'||l_region_home
||'l_region_work'||l_region_work
||'c_main_rec.oib'||c_main_rec.oib
||'c_main_rec.name'||c_main_rec.name
||'c_main_rec.surname'||c_main_rec.surname
||'c_main_rec.period_from'||c_main_rec.period_from
||'c_main_rec.period_to'||c_main_rec.period_to
||'c_main_rec.payment_amount'||c_main_rec.payment_amount
||'c_main_rec.payment_date'||c_main_rec.payment_date
);
*/


	 BEGIN
	  SELECT NVL(MAX(NVL(ID,0)),0) 
      INTO l_counter
	  FROM PLA_EVIDENCIJE_SATI_PRIHVATI@ebsprod;
	  EXCEPTION WHEN NO_DATA_FOUND
	  THEN l_counter :=0;
	 END;

	l_counter:=l_counter+1;

	INSERT INTO PLA_EVIDENCIJE_SATI_PRIHVATI@ebsprod
	(
	ID,
	korisnik_unosa,
	korisnik_zadnje_izmjene,
	datum_zadnje_izmjene,
	datum_unosa,
	poduzece_id,
	godina,
	mjesec,
	redni_broj,
	korisnicko_ime,
	osoba_sifra,
    osoba_jmbg,
    osoba_ime,
    osoba_prezime,
	primanje_sifra,
	primanje_sati,
	--primanje_razdoblje_od,
	--primanje_razdoblje_do,
	izvrsen,
	iznos,
	tip_iznosa,
	valuta,
	prenesen,
	--radni_nalog_sifra, --opis
    opis,
	vanjski_identifikator,
	koeficijent_1,
	koeficijent_2,
	koeficijent_3,
	koeficijent_4
	)
	VALUES
	(
	NVL(l_counter,0),
	'A',
	'A',
	SYSDATE,
	SYSDATE,
	l_poduzece_id,
	c_main_rec.year,
	c_main_rec.month,
	1,
	'XXDL_INTEGRATION_DEV', --OZIMEC',
	TO_CHAR(c_main_rec.person_number),   --TO_CHAR(kiden,'fm000000'),
    c_main_rec.oib,
    c_main_rec.name,
    c_main_rec.surname,
	71, --c.primanje_sifra,
	0, --NVL(c.primanje_sati,0),
	--datum_od,
	--datum_do,
	'N',
	c_main_rec.pay_amount,
	'N', -- n je netto 'B',
	c_main_rec.invoice_currency_code,--'HRK',
	'N',
	substrb(c_main_rec.invoice_num, 1, 20), --c.brnsp, max 20 char
	'',
	'',
	'',
	'',
	''
	);



/*
HR_DALEKOVOD.IPD_SUCELJE.prenesi_stavku_joppd@ebsprod (l_poduzece_id, --p_nPoduzece_id      in ipd_stavke_joppd.poduzece_id%type,
                                8, --p_vcOzn_izvor       in ipd_izvori.oznaka%type,
                                l_vrsta_stjecatelja, --p_vcOzn_vr_stj      in ipd_vrste_stjecatelja.oznaka%type,
                                l_vrsta_primitaka , --p_vcOzn_vr_prim     in ipd_vrste_primitaka.oznaka%type,
                                l_vrsta_neoporezivih,--p_vcOzn_vr_neopor   in ipd_vrste_neoporezivih_prim.oznaka%type,
                                l_nacin_izvrsenja,--p_vcOzn_nac_izvr    in ipd_nacini_izvrsenja.oznaka%type,
                                1,--p_vc_Vr_izvj        in ipd_stavke_joppd.vrsta_izvjesca%type,
                                l_region_home, --p_vcOpc_preb        in ipd_stavke_joppd.opcina_prebivalista%type,
                                l_region_work, --p_vcOpc_rada        in ipd_stavke_joppd.opcina_rada%type,
                                c_main_rec.oib,--p_vcPor_br          in ipd_stavke_joppd.porezni_broj%type,
                                c_main_rec.name, --p_vcIme                in ipd_stavke_joppd.ime%type,
                                c_main_rec.surname,--p_vcPrezime         in ipd_stavke_joppd.prezime%type,
                                0,--p_vcBen_staz        in ipd_stavke_joppd.beneficirani_staz%type,
                                0,--p_vcSt_zap_inv      in ipd_stavke_joppd.stopa_za_zaposljavanje_invalid%type,
                                0,--p_vcMj_osig         in ipd_stavke_joppd.mjesec_osiguranja%type,
                                0,--p_vcRadno_vr        in ipd_stavke_joppd.radno_vrijeme%type,
                                0,--p_nSati_rada        in ipd_stavke_joppd.sati_rada%type,
                                c_main_rec.period_from, --p_dPoc_razd         in ipd_stavke_joppd.pocetak_razdoblja%type,
                                c_main_rec.period_to, --p_dKraj_razd        in ipd_stavke_joppd.kraj_razdoblja%type,
                                0, --p_nRedovna_placa    in ipd_stavke_joppd.redovna_placa%type,
                                c_main_rec.payment_amount,--p_nNeopor           in ipd_stavke_joppd.neoporezivo%type,
                                0, --p_nOpor_prim        in ipd_stavke_joppd.oporezivi_primitak%type,
                                0, --p_nOsn_dopr         in ipd_stavke_joppd.osnovica_doprinosa%type,
                                0, --p_nDopr_mo1         in ipd_stavke_joppd.doprinos_mo_1%type,
                                0, --p_nDopr_mo2         in ipd_stavke_joppd.doprinos_mo_2%type,
                                0, --p_nDopr_zdrav       in ipd_stavke_joppd.doprinos_zdravstvo%type,
                                0, --p_nDopr_zzr         in ipd_stavke_joppd.doprinos_zzr%type,
                                0, --p_nDopr_zapos       in ipd_stavke_joppd.doprinos_zaposljavanje%type,
                                0, --p_nDopr_ben1        in ipd_stavke_joppd.doprinos_beneficirani_1%type,
                                0, --p_nDopr_ben2        in ipd_stavke_joppd.doprinos_beneficirani_2%type,
                                0, --p_nDopr_ino_zdrav   in ipd_stavke_joppd.doprinos_ino_zdravstvo%type,
                                0, --p_nDopr_zapos_inv   in ipd_stavke_joppd.doprinos_zaposljavanje_invalid%type,
                                0, --p_nIzdatak          in ipd_stavke_joppd.izdatak%type,
                                0, --p_nIzdatak_mo        in ipd_stavke_joppd.izdatak_mo%type,
                                0, --p_nDohodak          in ipd_stavke_joppd.dohodak%type,
                                0, --p_nOsobni_odb       in ipd_stavke_joppd.osobni_odbitak%type,
                                0, --p_nPor_osn          in ipd_stavke_joppd.porezna_osnovica%type,
                                0, --p_nPorez            in ipd_stavke_joppd.porez%type,
                                0, --p_nPrirez           in ipd_stavke_joppd.prirez%type,
                                c_main_rec.payment_amount, --p_nNeto             in ipd_stavke_joppd.neto%type,
                                'FUSION', --p_vcVanjski_ident   in ipd_stavke_joppd.vanjski_identifikator%type,
                                c_main_rec.payment_date,--p_dDatum_isplate    in ipd_stavke_joppd.datum_isplate%type,
                                null, --p_vcPoduzeceMatbr   in varchar2 default null,
                                null--p_nNeodradjeni_sati_rada in ipd_stavke_joppd.neodradjeni_sati_rada%type default null
                                );
   */                             
        update XXDL_UNPAID_PAY_REQUESTS_INT
        set 
         insert_interface_status  = 'S',
         insert_interface_message =NULL
        where legal_entity_id = c_main_rec.legal_entity_id
         and invoice_id = c_main_rec.invoice_id
         and period_name = c_main_rec.period_name;

exception when others then
        l_status := 'E';
        l_message := substrb('Exception in XX_AP_JOPPD_PKG.INSERT_pay_request_DATA, SQLCODE:'||sqlcode||', SQLERRM:'||SQLERRM, 1, 2000);

        update XXDL_UNPAID_PAY_REQUESTS_INT
        set 
         insert_interface_status  = l_status,
         insert_interface_message = l_message
        where legal_entity_id = c_main_rec.legal_entity_id
         and invoice_id = c_main_rec.invoice_id
         and period_name = c_main_rec.period_name;

end;
commit;
end loop;


end insert_pay_request_data;

/*===========================================================================+
Procedure   : get_pay_request_data
Description :
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure get_pay_request_data (p_period_name in varchar2, p_legal_entity_name in varchar2,p_status out varchar2, p_msg out varchar2)
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

l_ws_call_id    number;

l_domain varchar2(150);
l_count number := 0;
l_url varchar2(75);

l_return_status varchar2(10);
l_return_message varchar2(2000);
p_supplier_name varchar2(20);
p_source_system varchar2(2000);
p_source_site_id varchar2(50);
p_supplier_site varchar2(20);
p_ws_call_id number;
BEGIN

execute immediate 'alter session set NLS_TIMESTAMP_TZ_FORMAT= ''YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM''';
--execute immediate 'alter session set nls_date_format=''yyyy-mm-dd hh24:mi:ss''';
--execute immediate 'alter session set NLS_TIMESTAMP_FORMAT= ''YYYY-MM-DD"T"HH24:MI:SS.FF3''';

select value 
into l_url
from xx_configuration
where name = 'ServiceRootURL'; 
 --l_url:= 'https://fa-ewha-test-saasfaprod1.fa.ocs.oraclecloud.com/';

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
                  <pub:name>p_period_name</pub:name>
                  <pub:values>
                     <!--Zero or more repetitions:-->
                     <pub:item>'||p_period_name||'</pub:item>
                  </pub:values>
               </pub:item>
               <pub:item>
                  <pub:name>p_legal_entity_name</pub:name>
                  <pub:values>
                     <!--Zero or more repetitions:-->
                    <pub:item>'||p_legal_entity_name||'</pub:item>
                  </pub:values>
               </pub:item>
            </pub:parameterNameValues>
            <pub:reportAbsolutePath>Custom/XXDL_Integration/XXDL_UNPAID_PAY_REQUESTS_REP.xdo</pub:reportAbsolutePath>
            <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
         </pub:reportRequest>
         <pub:appParams></pub:appParams>
      </pub:runReport>
   </soap:Body>
</soap:Envelope>';

--log('Payload:'||l_text);

 /* If (fnd_profile.value('APPS_DATABASE_ID')='prod') then
                  L_domain:= fnd_profile.value('XXFN_CS_PROD_DOMAIN_PRF');
  Else
                  L_domain:= fnd_profile.value('XXFN_CS_TEST_DOMAIN_PRF');
  end if; */

 --  l_domain := xxpo_cs_download_pkg.get_wsdl_domain;
  --l_domain := 'https://epfc-test.fa.em2.oraclecloud.com';
  l_soap_env := to_clob(l_text);

  l_count := 0;
    XXFN_CLOUD_WS_PKG.WS_CALL(
        p_ws_url => l_url||'/xmlpserver/services/ExternalReportWSSService?WSDL',
        p_soap_env => l_soap_env,
        p_soap_act => 'runReport',
        p_content_type => 'application/soap+xml;charset="UTF-8"',
        x_return_status => l_return_status,
        x_return_message => l_return_message,
        x_ws_call_id => l_ws_call_id);

  p_ws_call_id := l_ws_call_id;
  dbms_lob.freetemporary(l_soap_env);

  p_status := l_return_status;
  p_msg := substrb(l_return_message, 1,2000);

  if(l_return_status = 'S') then
      begin
      select response_xml
      into l_resp_xml
      from xxfn_ws_call_log_v
      where ws_call_id = l_ws_call_id;
      exception
        when no_data_found then
        p_Status := 'E';
        p_msg := substrb('Error in XXDL_AP_JOPPD_PKG.GET_DATA, there is no data in xxfn_ws_call_log_v, ws_Call_id:'||l_ws_call_id  , 1, 2000);
        return;
      end;

      begin
      SELECT xml.vals
      INTO l_result_clob
      FROM xxfn_ws_call_log_v a,
        XMLTable(xmlnamespaces('http://xmlns.oracle.com/oxp/service/PublicReportService' AS "ns2",'http://www.w3.org/2003/05/soap-envelope' AS "env"), '/env:Envelope/env:Body/ns2:runReportResponse/ns2:runReportReturn' PASSING a.response_xml COLUMNS vals CLOB PATH './ns2:reportBytes') xml
      WHERE a.ws_call_id = l_ws_call_id
      AND xml.vals      IS NOT NULL;
      exception
        when no_data_found then
        p_Status := 'E';
        p_msg := substrb('Error in XXDL_AP_JOPPD_PKG.GET_DATA, cannot get xml.vals from xxfn_ws_call_log_v, ws_Call_id:'||l_ws_call_id  , 1, 2000);
        return;
      end;


      l_result_clob_decode := xxfn_cloud_ws_pkg.DecodeBASE64(l_result_clob);
      l_resp_xml_id := XMLType.createXML(l_result_clob_decode);
      --log('Parsing report response for suppliers');
      FOR cur_rec IN (
      SELECT xt.*
      FROM   XMLTABLE('/DATA_DS/MAIN'
               PASSING l_resp_xml_id
               COLUMNS

                   LEGAL_ENTITY_ID NUMBER PATH 'LEGAL_ENTITY_ID',
                    LEGAL_ENTITY_NAME VARCHAR2(50) PATH 'LEGAL_ENTITY_NAME',
                    LEGAL_ENTITY_IDENTIFIER VARCHAR2(50) PATH 'LEGAL_ENTITY_IDENTIFIER',
                    BU_NAME VARCHAR2(150) PATH 'BU_NAME',
                    INVOICE_ID NUMBER PATH 'INVOICE_ID',
                    PERIOD_NAME VARCHAR2(7) PATH 'PERIOD_NAME',
                    OIB VARCHAR2(11) PATH 'OIB',
                    NAME VARCHAR2(50) PATH 'NAME',
                    SURNAME VARCHAR2(50) PATH 'SURNAME',
                    PERSON_NUMBER NUMBER PATH 'PERSON_NUMBER',
                    PERIOD_FROM VARCHAR2(10) PATH 'PERIOD_FROM',
                    PERIOD_TO VARCHAR2(10) PATH 'PERIOD_TO',
                	VENDOR_NAME VARCHAR2(150) PATH 'PARTY_NAME', 
                    VENDOR_SITE_CODE VARCHAR2(150) PATH 'VENDOR_SITE_CODE',
                    VENDOR_ID NUMBER PATH 'VENDOR_ID', 
                    INVOICE_NUM VARCHAR2(150) PATH 'INVOICE_NUM', 
                    INVOICE_CURRENCY_CODE VARCHAR2(3) PATH 'INVOICE_CURRENCY_CODE', 
                    EXCHANGE_RATE NUMBER PATH 'EXCHANGE_RATE',
                    INVOICE_AMOUNT NUMBER PATH 'INVOICE_AMOUNT', 
                    AMOUNT_PAID NUMBER PATH 'AMOUNT_PAID', 
                    LAST_UPDATE_DATE VARCHAR2(35) PATH 'LAST_UPDATE_DATE'



               ) xt)
      LOOP

        begin

        insert into
        XXDL_UNPAID_PAY_REQUESTS_INT
        (LEGAL_ENTITY_ID,
        LEGAL_ENTITY_NAME,
        LEGAL_ENTITY_IDENTIFIER,
        BU_NAME,
        INVOICE_ID,
        PERIOD_NAME,
        OIB,
        NAME,
        SURNAME,
        PERSON_NUMBER,
        PERIOD_FROM,
        PERIOD_TO,
        VENDOR_NAME,
         VENDOR_SITE_CODE,
        VENDOR_ID,
        INVOICE_NUM,
        INVOICE_CURRENCY_CODE,
        EXCHANGE_RATE,
        INVOICE_AMOUNT,
        AMOUNT_PAID,
        LAST_UPDATE_DATE,
        PAYMENT_NUMBER,
        status,
        MESSAGE)
        values 
        (cur_rec.LEGAL_ENTITY_ID,
        cur_rec.LEGAL_ENTITY_NAME,
        cur_rec.LEGAL_ENTITY_IDENTIFIER,
        CUR_REC.BU_NAME,
        cur_rec.INVOICE_ID,
        cur_rec.PERIOD_NAME,
        cur_rec.OIB,
        cur_rec.NAME,
        cur_rec.SURNAME,
        cur_rec.PERSON_NUMBER,
        cur_rec.PERIOD_FROM,
        cur_rec.PERIOD_TO,
        cur_rec.VENDOR_NAME,
        cur_rec.VENDOR_SITE_CODE,
        cur_rec.VENDOR_ID,
        cur_rec.INVOICE_NUM,
        cur_rec.INVOICE_CURRENCY_CODE,
        cur_rec.EXCHANGE_RATE,
        cur_rec.INVOICE_AMOUNT,
        cur_rec.AMOUNT_PAID ,
        cur_rec.LAST_UPDATE_DATE,
        NULL, --XXDL_UNPAID_PAY_REQUESTS_S.NEXTVAL,
        null,
        null);

         exception when dup_val_on_index then

      /*   update XXDL_UNPAID_PAY_REQUESTS_INTt
         set 
         LEGAL_ENTITY_NAME = cur_rec.LEGAL_ENTITY_NAME,
         LEGAL_ENTITY_IDENTIFIER = cur_rec.LEGAL_ENTITY_IDENTIFIER,
        OIB = cur_rec.oib,
        NAME = cur_rec.name,
        SURNAME = cur_rec.surname,
        PERIOD_FROM = cur_rec.period_from,
        PERIOD_TO = cur_rec.period_to,
        PAYMENT_DATE = cur_rec.PAYMENT_DATE,
        PAYMENT_AMOUNT = cur_rec.payment_amount,
         PERSON_NUMBER = cur_rec.PERSON_NUMBER

         where legal_entity_id = cur_rec.legal_entity_id
         and invoice_id = cur_rec.invoice_id
         and period_name = cur_rec.period_name;
         */
         NULL;
         end;
      end loop;
commit;
p_status := 'S';
else
       p_Status := 'E';
       p_msg := substrb('Error in XXDL_AP_JOPPD_PKG.GET_DATA, Call to report XX_GET_CURRENCY_RATES_REP did not end with S', 1, 2000);
       return;
end if;


exception
  when others then

       p_Status := 'E';
       p_msg := substrb('Exception in XXDL_AP_JOPPD_PKG.GET_DATA; SQLCODE:'||SQLCODE||'; SQLERRM:'|| SQLERRM, 1, 2000);

end;

/*===========================================================================+
Procedure   : create_payments
Description : 
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure create_payments is

cursor c_headers is
select 
        LEGAL_ENTITY_ID,
        LEGAL_ENTITY_NAME,
        LEGAL_ENTITY_IDENTIFIER,
        bu_name,
        INVOICE_ID,
        PERIOD_NAME,
        OIB,
        NAME,
        surname,
        PERSON_NUMBER,
         to_date(PERIOD_FROM,'RRRR-MM-DD') PERIOD_FROM,
        to_date(PERIOD_TO,'RRRR-MM-DD') PERIOD_TO,
        VENDOR_NAME,
        VENDOR_SITE_CODE,
        VENDOR_ID,
        INVOICE_NUM,
        INVOICE_CURRENCY_CODE,
        EXCHANGE_RATE,
        INVOICE_AMOUNT,
        AMOUNT_PAID,
        NVL(INVOICE_AMOUNT, 0) - NVL(AMOUNT_PAID, 0) AS PAYMENT_AMOUNT,
        LAST_UPDATE_DATE,

        status,
        MESSAGE
from XXDL_UNPAID_PAY_REQUESTS_INT
        WHERE 1=1
        and nvl(insert_interface_status, 'E') = 'S'
    and nvl(status, 'E') != 'S'; 
  --  and p.invoice_num = '18006157/NY100679'


x_return_status varchar2(500);
x_return_message varchar2(32000);
l_rest_env clob;
l_text varchar2(32000);
x_ws_call_id number;
l_result_nr         varchar2(240);
l_resp_xml       XMLType;
l_supplier_result varchar2(1);
l_nls_chars varchar2(5);
l_error number;
l_negotiation_id number;
l_domain varchar2(150);
l_line_num number;
l_exist number;
l_step varchar2(2000);
l_requisitions varchar2(150);
l_counter number := 0;

l_sqlerrm varchar2(2000);
l_sqlcode number;
l_error_exists number :=0;

l_err_msg varchar2(2000);
p_call_id number;
p_status varchar2(3);
p_negotiation_number varchar2(25);
l_line_count number := 0;
l_response_clob clob;
l_invoice_id number;
l_val_return_Status varchar2(5);
l_val_return_message varchar2(2000);
l_acc_num varchar2(255);
l_liability_distribution varchar2(35);
l_cost_center varchar2(3);
l_ws_call_id number;
l_document_category varchar2(255);

l_url  varchar2(75);
L_PAYMENT_NUMBER NUMBER;
BEGIN

--dbms_output.enable(1000000);
l_line_num := 0;
l_exist :=0;

select value
into l_nls_chars
from nls_session_parameters
where parameter = 'NLS_NUMERIC_CHARACTERS';

select value 
into l_url
from xx_configuration
where name = 'ServiceRootURL'; 

l_text := '';

for c_headers_rec in c_headers loop

begin --because of exception handling inside of loop
l_line_count := 0;
l_text := '';
l_rest_env := '';
l_response_clob := '';
L_PAYMENT_NUMBER := XXDL_UNPAID_PAY_REQUESTS_S.NEXTVAL;
--"PayeeSite": "'||c_headers_rec.vendor_site_code||'",
l_text :=  '{
"PaymentNumber": "'||L_payment_number||'" ,
"PaymentDate": "'||to_char(sysdate, 'YYYY-MM-DD')||'",
"PaymentDescription": "Manual_Payment",
"PaymentType": "Manual",
"PaymentCurrency": "'||c_headers_rec.INVOICE_CURRENCY_CODE||'",
"BusinessUnit": "'||c_headers_rec.bu_name||'",
"ProcurementBU": "'||c_headers_rec.bu_name||'",
"Payee": "'||c_headers_rec.vendor_name||'",
"PaymentFunction": "Employee expenses",
"EmployeeAddress": "Home",
"DisbursementBankAccountName": "EUR-2360000-1001226102",
"PaymentMethod": "Electronic",
"PaymentProcessProfile": "SEPA HR",
"PaymentDocument": "",
"relatedInvoices": [
{
"InvoiceNumber": "'||c_headers_rec.invoice_num||'",
"InstallmentNumber": 1,
"AmountPaidPaymentCurrency": '||c_headers_rec.payment_amount||'
}
]
}';

l_step := 'XX_AP_PREDUJMOVI_PKG.IMPORT_INVOICE, rest envelope created';

--dbms_output.put_line (l_rest_env);

l_rest_env := l_rest_env|| to_clob(l_text);
l_text := '';

XXFN_CLOUD_WS_PKG.WS_REST_CALL(
      p_ws_url => l_url||'fscmRestApi/resources/11.13.18.05/payablesPayments',
      p_rest_env => l_rest_env,
      p_rest_act => 'POST',
      p_content_type => 'application/json;charset="UTF-8"',
      x_return_status => x_return_status,
      x_return_message => x_return_message,
      x_ws_call_id => x_ws_call_id);

dbms_output.put_line('After call XXFN_CLOUD_WS_PKG.WS_REST_CALL');

dbms_lob.freetemporary(l_rest_env);
dbms_output.put_line('ws_call_id:'|| x_ws_call_id);
dbms_output.put_line('Return status: '||x_return_status);
dbms_output.put_line('Return message:'||x_return_message);



if(x_return_status = 'S')
then
 select nvl(response_clob, response_json)
into l_response_clob
from xxfn_ws_call_log
where ws_call_id = x_ws_call_id;

   APEX_JSON.parse(l_response_clob);

  --p_request_id := apex_json.get_varchar2(p_path=> 'RequestId');
    l_invoice_id := apex_json.get_number(p_path=> 'CheckId');

      dbms_output.put_line('Result = '||l_invoice_id);
       /*update header status*/
      update XXDL_UNPAID_PAY_REQUESTS_INT
      set status = 'S',
      ebs_check_id = l_invoice_id,
      last_api_message = null,
      last_api_call_status = 'Success',
      last_ws_call_id = x_ws_call_id,
      payment_number = l_payment_number
      where invoice_id = c_headers_rec.invoice_id;

else
   begin

 select nvl(response_clob, response_json)
  into l_response_clob
  from xxfn_ws_call_log
  where ws_call_id = x_ws_call_id;

   l_err_msg := substrb(to_char(l_response_clob), 1, 2000);
    dbms_output.put_line('Error_message = '||l_err_msg);
   update XXDL_UNPAID_PAY_REQUESTS_INT
      set status = 'E',
      last_api_message = l_err_msg,
      last_ws_call_id = x_ws_call_id
      where invoice_id = c_headers_rec.invoice_id;

   exception when others then null;
   end;
end if;

exception when others then
  x_return_status := 'Error';
  x_return_message := substrb('Exception in XX_AP_predujmovi_pkg.create_crmem_payments, SQLCODE:'||sqlcode||', SQLERRM:'||SQLERRM, 1, 2000);

  update XXDL_UNPAID_PAY_REQUESTS_INT
      set status = 'E',
      last_api_message = x_return_message,
      last_api_call_Status = x_return_status,
      last_ws_call_id = x_ws_call_id
      where invoice_id = c_headers_rec.invoice_id;
end;
--p_call_id := x_ws_call_id;
--p_status := x_return_status;
--p_negotiation_number := l_result_nr;

--execute immediate 'alter session set NLS_NUMERIC_CHARACTERS= '''||l_nls_chars||'''';
end loop;
commit;
end create_payments;


end XXDL_AP_JOPPD_PKG;