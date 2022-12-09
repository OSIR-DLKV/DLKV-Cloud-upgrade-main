create or replace package body XXFN_CLOUD_WS_PKG is
/* $Header $
============================================================================+
File Name   : XXFN_CLOUD_WS_PKG.pkb
Object      : XXFN_CLOUD_WS_PKG
Description : Mirror for Cloud package XXFN_WS_PKG, used for web service calls
              Endpoint for web service calls
History     :
v1.0 25.11.2022 Marko Sladoljev: Copy from XE db to Git
============================================================================+*/
  x_success            number := 0;
  x_warning            number := 1;
  x_error              number := 2;
  g_step               varchar2(250);
/*===========================================================================+
Procedure   : XLOG
Description : Puts the in variable to log file
Usage       : Logging the request
Arguments   : p_text -> text to log
============================================================================+*/
procedure XLOG(p_text in varchar2) is
begin
  dbms_output.put_line(p_text);
 -- apps.fnd_file.put_line(apps.fnd_file.log, p_text);
exception when OTHERS then
    null;
end;

/*===========================================================================+
Procedure   : WS_CALL
Description :
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure WS_CALL(
    p_ws_url          varchar2,
    p_soap_env        clob,
    p_soap_act        varchar2,
    p_content_type    varchar2,
    x_return_status   out nocopy varchar2,
    x_return_message  out nocopy varchar2,
    x_ws_call_id      out nocopy number) is
  amount         integer;
  chunk_size     constant pls_integer := 300;
  buff           varchar2(4000);
  written        pls_integer := 0;
  remaining      pls_integer;
  l_username     varchar2(60);
  l_pass         varchar2(60);
begin

  x_ws_call_id := null;

  if p_soap_env is null then
    return;
  end if;

  amount := dbms_lob.getlength(p_soap_env);
  if amount is null then
    return;
  end if;

  /*get username and pass*/
/*  begin
    select fpov.profile_option_value
      into l_username
    from APPS.FND_PROFILE_OPTION_VALUES fpov,
         APPS.FND_PROFILE_OPTIONS fpo
    where fpov.profile_option_id = fpo.profile_option_id
    and fpo.profile_option_name = 'XXFN_CLOUD_INTEGRATION_USER_PRF'
    and rownum = 1;
  exception when OTHERS then
      l_username := null;
  end;
  begin
    select fpov.profile_option_value
      into l_pass
    from APPS.FND_PROFILE_OPTION_VALUES fpov,
         APPS.FND_PROFILE_OPTIONS fpo
    where fpov.profile_option_id = fpo.profile_option_id
    and fpo.profile_option_name = 'XXFN_CLOUD_INTEGRATION_PASS_PRF'
    and rownum = 1;
  exception when OTHERS then
      l_pass := null;
  end;  */


    select value 
  into l_username
  from xx_configuration
  where name = 'ServiceUsername'; 


  select value 
  into l_pass
  from xx_configuration
  where name = 'ServicePassword'; 

 /* if l_username is null or l_pass is null then
    apps.fnd_file.put_line(apps.fnd_file.log, '**********.');
    apps.fnd_file.put_line(apps.fnd_file.log, 'Profile options for Cloud integrations are not set.');
    apps.fnd_file.put_line(apps.fnd_file.log, 'Please check value of XXFN_CLOUD_INTEGRATION_USER_PRF and XXFN_CLOUD_INTEGRATION_PASS_PRF.');
    apps.fnd_file.put_line(apps.fnd_file.log, '**********.');
  end if; */

  if amount != 0 and p_soap_env is not null then
    while written + chunk_size < amount loop
      remaining := chunk_size;
      -- read blob
      dbms_lob.read(
        lob_loc => p_soap_env,
        amount  => remaining,
        offset  => written+1,
        buffer  => buff);
      written := written + chunk_size;
      XXFN_WS_PKG.BUILD_SOAP_ENVELOPE(buff);
      XXFN_WS_PKG.BUILD_SOAP_ENVELOPEB(utl_raw.cast_to_raw(buff));
    end loop;

    -- put remaining
    remaining := amount - written;
    if remaining != 0 then
      dbms_lob.read(
        lob_loc => p_soap_env,
        amount  => remaining,
        offset  => written+1,
        buffer  => buff);
      XXFN_WS_PKG.BUILD_SOAP_ENVELOPE(buff);
      XXFN_WS_PKG.BUILD_SOAP_ENVELOPEB(utl_raw.cast_to_raw(buff));
    end if;
  end if;

  XXFN_WS_PKG.WS_CALL(
      p_ws_url          => p_ws_url,
      p_soap_act        => p_soap_act,
      p_content_type    => p_content_type,
      p_cloud_user      => l_username,
      p_cloud_pass      => l_pass);

  x_return_status := XXFN_WS_PKG.GET_RETURN_STATUS;
  x_return_message := XXFN_WS_PKG.GET_RETURN_MESSAGE;
  x_ws_call_id := XXFN_WS_PKG.GET_WS_CALL_ID;
exception when OTHERS then
      x_return_status := 'E';
      x_return_message := SQLERRM;
end;


/*===========================================================================+
Procedure   : WS_CALL
Description :
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure WS_CALL_D(
    p_ws_url          varchar2,
    p_soap_env        clob,
    p_soap_act        varchar2,
    p_content_type    varchar2,
    x_return_status   out nocopy varchar2,
    x_return_message  out nocopy varchar2,
    x_ws_call_id      out nocopy number) is
  amount         integer;
  chunk_size     constant pls_integer := 300;
  buff           varchar2(4000);
  written        pls_integer := 0;
  remaining      pls_integer;
  l_username     varchar2(60);
  l_pass         varchar2(60);
begin

dbms_output.enable(10000);
dbms_output.put_line('calling ws_call_d');
  x_ws_call_id := null;

  if p_soap_env is null then
    return;
  end if;

  amount := dbms_lob.getlength(p_soap_env);
  if amount is null then
    return;
  end if;

  /*get username and pass*/
/*  begin
    select fpov.profile_option_value
      into l_username
    from APPS.FND_PROFILE_OPTION_VALUES fpov,
         APPS.FND_PROFILE_OPTIONS fpo
    where fpov.profile_option_id = fpo.profile_option_id
    and fpo.profile_option_name = 'XXFN_CLOUD_INTEGRATION_USER_PRF'
    and rownum = 1;
  exception when OTHERS then
      l_username := null;
  end;
  begin
    select fpov.profile_option_value
      into l_pass
    from APPS.FND_PROFILE_OPTION_VALUES fpov,
         APPS.FND_PROFILE_OPTIONS fpo
    where fpov.profile_option_id = fpo.profile_option_id
    and fpo.profile_option_name = 'XXFN_CLOUD_INTEGRATION_PASS_PRF'
    and rownum = 1;
  exception when OTHERS then
      l_pass := null;
  end;  */


  /*  select value 
  into l_username
  from xx_configuration
  where name = 'ServiceUsername'; 


  select value 
  into l_pass
  from xx_configuration
  where name = 'ServicePassword';  */
  
 --- l_username := 'XX_INTEGRATION';
 -- l_pass := 'Zetor2511';

 /* if l_username is null or l_pass is null then
    apps.fnd_file.put_line(apps.fnd_file.log, '**********.');
    apps.fnd_file.put_line(apps.fnd_file.log, 'Profile options for Cloud integrations are not set.');
    apps.fnd_file.put_line(apps.fnd_file.log, 'Please check value of XXFN_CLOUD_INTEGRATION_USER_PRF and XXFN_CLOUD_INTEGRATION_PASS_PRF.');
    apps.fnd_file.put_line(apps.fnd_file.log, '**********.');
  end if; */

  if amount != 0 and p_soap_env is not null then
    while written + chunk_size < amount loop
      remaining := chunk_size;
      -- read blob
      dbms_lob.read(
        lob_loc => p_soap_env,
        amount  => remaining,
        offset  => written+1,
        buffer  => buff);
      written := written + chunk_size;
      XXFN_WS_PKG.BUILD_SOAP_ENVELOPE(buff);
      XXFN_WS_PKG.BUILD_SOAP_ENVELOPEB(utl_raw.cast_to_raw(buff));
    end loop;

    -- put remaining
    remaining := amount - written;
    if remaining != 0 then
      dbms_lob.read(
        lob_loc => p_soap_env,
        amount  => remaining,
        offset  => written+1,
        buffer  => buff);
      XXFN_WS_PKG.BUILD_SOAP_ENVELOPE(buff);
      XXFN_WS_PKG.BUILD_SOAP_ENVELOPEB(utl_raw.cast_to_raw(buff));
    end if;
  end if;

  XXFN_WS_PKG.WS_CALL(
      p_ws_url          => p_ws_url,
      p_soap_act        => p_soap_act,
      p_content_type    => p_content_type,
      p_cloud_user      => l_username,
      p_cloud_pass      => l_pass);

  x_return_status := XXFN_WS_PKG.GET_RETURN_STATUS;
  x_return_message := XXFN_WS_PKG.GET_RETURN_MESSAGE;
  x_ws_call_id := XXFN_WS_PKG.GET_WS_CALL_ID;
exception when OTHERS then
      x_return_status := 'E';
      x_return_message := SQLERRM;
end;

/*===========================================================================+
Procedure   : PURGE_OLD_LOG
Description : Deletes records from XXFN_WS_CALL_LOG table
Usage       : 
Arguments   : p_keep_days -> number of days to keep
============================================================================+*/
procedure PURGE_OLD_LOG(
            p_errbuf       out nocopy varchar2,
            p_retcode      out nocopy number,
            p_keep_days    in number) is
  c_module constant varchar2(255) := $$PLSQL_UNIT ||'.PURGE_OLD_LOG';
begin
  g_step := 'init '||c_module;
  p_retcode := x_success;

  g_step := 'draw header';
  xlog('-------------------------------------------------------------------');
  xlog('');
  xlog('Delete old records from XXFN_WS_CALL_LOG table');
  xlog('');
  xlog('Request run date:  '||to_char(sysdate, 'DD.MM.RRRR. HH24:MI:SS'));
  xlog('-------------------------------------------------------------------');
  xlog('');

  g_step := '  call XXFN_WS_PKG.PURGE_OLD_LOG';
  xlog(g_step);
  XXFN_WS_PKG.PURGE_OLD_LOG(
      p_keep_days => p_keep_days);

  xlog('');
  xlog('Request finished with success at '||to_char(sysdate, 'DD.MM.RRRR. HH24:MI:SS'));
exception when OTHERS then
    p_errbuf := 'Error occured after '||g_step||CHR(10)||SQLERRM;
    xlog(p_errbuf);
    p_retcode := x_error;
end;

/*===========================================================================+
Function   : get_tinyurl
Description : calls tinyurl via http call and gets tinyurl of provided p_url
Usage       : 
Arguments   : p_url ->original url
Return      : tinyurl
============================================================================+*/    
function get_tinyurl(p_url in varchar2) return varchar2
is
l_tinyurl  varchar2(2000);
begin
l_tinyurl := XXFN_WS_PKG.get_tinyurl(p_url);

return l_tinyurl;
end get_tinyurl;

/*===========================================================================+
Procedure   : WS_REST_CALL
Description : Performs REST API call on PaaS
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure WS_REST_CALL(
    p_ws_url          varchar2,
    p_rest_env        clob,
    p_rest_act        varchar2,
    p_content_type    varchar2,
    x_return_status   out nocopy varchar2,
    x_return_message  out nocopy varchar2,
    x_ws_call_id      out nocopy number) is
  amount         integer;
  chunk_size     constant pls_integer := 300;
  buff           varchar2(4000);
  written        pls_integer := 0;
  remaining      pls_integer;
  l_username     varchar2(60);
  l_pass         varchar2(60);
begin
  x_ws_call_id := null;

  if p_rest_env is null then
    return;
  end if;

  amount := dbms_lob.getlength(p_rest_env);
  if amount is null then
    return;
  end if;

  /*get username and pass*/
 /* begin
    select fpov.profile_option_value
      into l_username
    from APPS.FND_PROFILE_OPTION_VALUES fpov,
         APPS.FND_PROFILE_OPTIONS fpo
    where fpov.profile_option_id = fpo.profile_option_id
    and fpo.profile_option_name = 'XXFN_CLOUD_INTEGRATION_USER_PRF'
    and rownum = 1;
  exception when OTHERS then
      l_username := null;
  end;
  begin
    select fpov.profile_option_value
      into l_pass
    from APPS.FND_PROFILE_OPTION_VALUES fpov,
         APPS.FND_PROFILE_OPTIONS fpo
    where fpov.profile_option_id = fpo.profile_option_id
    and fpo.profile_option_name = 'XXFN_CLOUD_INTEGRATION_PASS_PRF'
    and rownum = 1;
  exception when OTHERS then
      l_pass := null;
  end; */

  /*  l_username := 'marko.matanovic@osir-erpis.eu';
  l_pass := 'welcome123'; 
*/

  select value 
  into l_username
  from xx_configuration
  where name = 'ServiceUsername'; 

--dbms_output.put_line('XXFN:1');

  select value 
  into l_pass
  from xx_configuration
  where name = 'ServicePassword'; 


--  dbms_output.put_line('XXFN:2');

 /* if l_username is null or l_pass is null then
    apps.fnd_file.put_line(apps.fnd_file.log, '**********.');
    apps.fnd_file.put_line(apps.fnd_file.log, 'Profile options for Cloud integrations are not set.');
    apps.fnd_file.put_line(apps.fnd_file.log, 'Please check value of XXFN_CLOUD_INTEGRATION_USER_PRF and XXFN_CLOUD_INTEGRATION_PASS_PRF.');
    apps.fnd_file.put_line(apps.fnd_file.log, '**********.');
  end if; */

  if amount != 0 and p_rest_env is not null then
    while written + chunk_size < amount loop
      remaining := chunk_size;
      -- read blob
      dbms_lob.read(
        lob_loc => p_rest_env,
        amount  => remaining,
        offset  => written+1,
        buffer  => buff);
      written := written + chunk_size;
      XXFN_WS_PKG.BUILD_REST_ENVELOPE(buff);
      XXFN_WS_PKG.BUILD_REST_ENVELOPEB(utl_raw.cast_to_raw(buff));
    end loop;

--dbms_output.put_line('XXFN:3');

    -- put remaining
    remaining := amount - written;
    if remaining != 0 then
      dbms_lob.read(
        lob_loc => p_rest_env,
        amount  => remaining,
        offset  => written+1,
        buffer  => buff);
      XXFN_WS_PKG.BUILD_REST_ENVELOPE(buff);
      XXFN_WS_PKG.BUILD_REST_ENVELOPEB(utl_raw.cast_to_raw(buff));
    end if;
  end if;

--  dbms_output.put_line('XXFN:4');

  XXFN_WS_PKG.WS_REST_CALL(
      p_ws_url          => p_ws_url,
      p_rest_act        => p_rest_act,
      p_content_type    => p_content_type,
      p_cloud_user      => l_username,
      p_cloud_pass      => l_pass);

  x_return_status := XXFN_WS_PKG.GET_RETURN_STATUS;
  x_return_message := XXFN_WS_PKG.GET_RETURN_MESSAGE;
  x_ws_call_id := XXFN_WS_PKG.GET_WS_CALL_ID;

--  dbms_output.put_line('XXFN:5');
exception when OTHERS then
--dbms_output.put_line('XXFN:6'||SQLERRM);
      x_return_status := 'E';
      x_return_message := SQLERRM;
end;


/*===========================================================================+
Procedure   : WS_REST_CALL
Description : Performs REST API call on PaaS
Usage       :
Arguments   :
Remarks     :
============================================================================+*/
procedure WS_REST_CALL_D(
    p_ws_url          varchar2,
    p_rest_env        clob,
    p_rest_act        varchar2,
    p_content_type    varchar2,
    x_return_status   out nocopy varchar2,
    x_return_message  out nocopy varchar2,
    x_ws_call_id      out nocopy number) is
  amount         integer;
  chunk_size     constant pls_integer := 300;
  buff           varchar2(4000);
  written        pls_integer := 0;
  remaining      pls_integer;
  l_username     varchar2(60);
  l_pass         varchar2(60);
begin
  x_ws_call_id := null;

  if p_rest_env is null then
    return;
  end if;

  amount := dbms_lob.getlength(p_rest_env);
  if amount is null then
    return;
  end if;

  /*get username and pass*/
 /* begin
    select fpov.profile_option_value
      into l_username
    from APPS.FND_PROFILE_OPTION_VALUES fpov,
         APPS.FND_PROFILE_OPTIONS fpo
    where fpov.profile_option_id = fpo.profile_option_id
    and fpo.profile_option_name = 'XXFN_CLOUD_INTEGRATION_USER_PRF'
    and rownum = 1;
  exception when OTHERS then
      l_username := null;
  end;
  begin
    select fpov.profile_option_value
      into l_pass
    from APPS.FND_PROFILE_OPTION_VALUES fpov,
         APPS.FND_PROFILE_OPTIONS fpo
    where fpov.profile_option_id = fpo.profile_option_id
    and fpo.profile_option_name = 'XXFN_CLOUD_INTEGRATION_PASS_PRF'
    and rownum = 1;
  exception when OTHERS then
      l_pass := null;
  end; */

  /*  l_username := 'marko.matanovic@osir-erpis.eu';
  l_pass := 'welcome123'; 
*/

 /* select value 
  into l_username
  from xx_configuration
  where name = 'ServiceUsername';  */

--dbms_output.put_line('XXFN:1');

 /* select value 
  into l_pass
  from xx_configuration
  where name = 'ServicePassword'; */

l_username := 'XX_INTEGRATION';
l_pass := 'Welcome123';
--  dbms_output.put_line('XXFN:2');

 /* if l_username is null or l_pass is null then
    apps.fnd_file.put_line(apps.fnd_file.log, '**********.');
    apps.fnd_file.put_line(apps.fnd_file.log, 'Profile options for Cloud integrations are not set.');
    apps.fnd_file.put_line(apps.fnd_file.log, 'Please check value of XXFN_CLOUD_INTEGRATION_USER_PRF and XXFN_CLOUD_INTEGRATION_PASS_PRF.');
    apps.fnd_file.put_line(apps.fnd_file.log, '**********.');
  end if; */

  if amount != 0 and p_rest_env is not null then
    while written + chunk_size < amount loop
      remaining := chunk_size;
      -- read blob
      dbms_lob.read(
        lob_loc => p_rest_env,
        amount  => remaining,
        offset  => written+1,
        buffer  => buff);
      written := written + chunk_size;
      XXFN_WS_PKG.BUILD_REST_ENVELOPE(buff);
      XXFN_WS_PKG.BUILD_REST_ENVELOPEB(utl_raw.cast_to_raw(buff));
    end loop;

--dbms_output.put_line('XXFN:3');

    -- put remaining
    remaining := amount - written;
    if remaining != 0 then
      dbms_lob.read(
        lob_loc => p_rest_env,
        amount  => remaining,
        offset  => written+1,
        buffer  => buff);
      XXFN_WS_PKG.BUILD_REST_ENVELOPE(buff);
      XXFN_WS_PKG.BUILD_REST_ENVELOPEB(utl_raw.cast_to_raw(buff));
    end if;
  end if;

--  dbms_output.put_line('XXFN:4');

  XXFN_WS_PKG.WS_REST_CALL(
      p_ws_url          => p_ws_url,
      p_rest_act        => p_rest_act,
      p_content_type    => p_content_type,
      p_cloud_user      => l_username,
      p_cloud_pass      => l_pass);

  x_return_status := XXFN_WS_PKG.GET_RETURN_STATUS;
  x_return_message := XXFN_WS_PKG.GET_RETURN_MESSAGE;
  x_ws_call_id := XXFN_WS_PKG.GET_WS_CALL_ID;

  dbms_output.put_line('XXFN:5');
exception when OTHERS then
dbms_output.put_line('XXFN:6'||SQLERRM);
      x_return_status := 'E';
      x_return_message := SQLERRM;
end;

/*===========================================================================+
Procedure   : DELETE_LOBS_FROM_LOG
Description : Empties blob and xmltype columns for given row in XXFN_WS_CALL_LOG table
Usage       : 
Arguments   : p_ws_call_id -> web service call identifier
============================================================================+*/
procedure DELETE_LOBS_FROM_LOG(
    p_ws_call_id    in xxfn_ws_call_log_v.ws_call_id%type) is
begin
  XXFN_WS_PKG.DELETE_LOBS_FROM_LOG(p_ws_call_id => p_ws_call_id);
end;

/*===========================================================================+
Procedure   : BLOB_TO_CLOB
Description : Converts blob to clob
Usage       : 
Arguments   : b in BLOB
============================================================================+*/
function blob_to_clob(b blob) return clob
is
c clob;
n number;
begin 
if (b is null) then 
return null;
end if;
if (length(b)=0) then
return empty_clob(); 
end if;
dbms_lob.createtemporary(c,true);
n:=1;
while (n+32767<=length(b)) loop
dbms_lob.writeappend(c,32767,utl_raw.cast_to_varchar2(dbms_lob.substr(b,32767,n)));
n:=n+32767;
end loop;
dbms_lob.writeappend(c,length(b)-n+1,utl_raw.cast_to_varchar2(dbms_lob.substr(b,length(b)-n+1,n)));
return c;
end blob_to_clob;

/*===========================================================================+
Procedure   : CLOB_TO_BLOB
Description : Converts clob to blob
Usage       : 
Arguments   : p_data in clob
============================================================================+*/
FUNCTION clob_to_blob (p_data  IN  CLOB)
  RETURN BLOB

AS
  l_blob         BLOB;
  l_dest_offset  PLS_INTEGER := 1;
  l_src_offset   PLS_INTEGER := 1;
  l_lang_context PLS_INTEGER := DBMS_LOB.default_lang_ctx;
  l_warning      PLS_INTEGER := DBMS_LOB.warn_inconvertible_char;
BEGIN

  DBMS_LOB.createtemporary(
    lob_loc => l_blob,
    cache   => TRUE);

  DBMS_LOB.converttoblob(
   dest_lob      => l_blob,
   src_clob      => p_data,
   amount        => DBMS_LOB.lobmaxsize,
   dest_offset   => l_dest_offset,
   src_offset    => l_src_offset, 
   blob_csid     => DBMS_LOB.default_csid,
   lang_context  => l_lang_context,
   warning       => l_warning);

   RETURN l_blob;
END;


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
  Function   : send_csv_to_cloud
  Description : 
  Usage       :
  Arguments   :
  Returns     :
============================================================================+*/
procedure send_csv_to_cloud(p_document      in varchar2,
                              p_doc_name      in varchar2,
                              p_doc_type      in varchar2,
                              p_author        in varchar2,
                              p_app_account   in varchar2,
                              p_job_name      in varchar2,
                              p_job_option    in varchar2,
                              p_wsdl_link     in varchar2,
                              p_wsdl_method   in varchar2,
                              x_return_status out varchar2,
                              x_msg           out varchar2,
                              x_ws_call_id out number) is

    l_body               varchar2(30000);
    l_result             varchar2(500);
    l_result_clob        clob;
    l_return_status      varchar2(500);
    l_return_message     varchar2(32000);
    l_soap_env           clob;
    l_text               varchar2(32000);
    l_inflated_resp      blob;
    l_result_nr          varchar2(32000);
    l_resp_xml           xmltype;
    l_resp_xml_id        xmltype;
    l_result_nr_id       varchar2(500);
    l_result_varchar     varchar2(32000);
    l_result_clob_decode clob;

  begin

    xlog('Calling external web service');

    xlog('WSDL method:' || p_wsdl_method);
    xlog('Document:' || p_document);
    xlog('Doc name:' || p_doc_name);
    xlog('Author:' || p_author);
    xlog('Account:' || p_app_account);
    xlog('Job:' || p_job_name);
    xlog('Job option:' || p_job_option);

l_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/" xmlns:erp="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/">
           <soapenv:Header/>
           <soapenv:Body>
              <typ:' || p_wsdl_method || '>
                 <typ:document>
                    <erp:Content>' || p_document || '</erp:Content>
                    <erp:FileName>' || p_doc_name || '</erp:FileName>
                    <erp:ContentType>' || p_doc_type || '</erp:ContentType>
                    <erp:DocumentAuthor>' || p_author || '</erp:DocumentAuthor>
                    <erp:DocumentSecurityGroup>FAFusionImportExport</erp:DocumentSecurityGroup>
                    <erp:DocumentAccount>' || p_app_account || '</erp:DocumentAccount>
                 </typ:document>
                 <typ:jobDetails>
                    <erp:JobName>' || p_job_name || '</erp:JobName>
                    <erp:ParameterList>#NULL</erp:ParameterList>
                 </typ:jobDetails>
                 <typ:notificationCode>#NULL</typ:notificationCode>
                 <typ:callbackURL>#NULL</typ:callbackURL>
                 <typ:jobOptions>' || p_job_option || '</typ:jobOptions>
              </typ:' || p_wsdl_method || '>
           </soapenv:Body>
      </soapenv:Envelope>';

    l_soap_env := to_clob(l_text);

    xxfn_cloud_ws_pkg.ws_call(p_ws_url         => p_wsdl_link,
                                          p_soap_env       => l_soap_env,
                                          p_soap_act       => p_wsdl_method,
                                          p_content_type   => 'text/xml;charset="UTF-8"',
                                          x_return_status  => l_return_status,
                                          x_return_message => l_return_message,
                                          x_ws_call_id     => x_ws_call_id);

    dbms_lob.freetemporary(l_soap_env);
    xlog('Web service call ID:' || x_ws_call_id);
    xlog('Return status: ' || l_return_status);
    xlog('Return message:' || l_return_message);

    x_return_status := l_return_status;
    x_msg           := l_return_message;

  exception
    when others then
      xlog('Error occured during web service call for sending csv to cloud: ' || sqlcode);
      xlog('Msg:' || sqlerrm);
      xlog('Error_Stack...' || chr(10) || dbms_utility.format_error_stack());
      xlog('Error_Backtrace...' || chr(10) || dbms_utility.format_error_backtrace());
  end send_csv_to_cloud;

/*===========================================================================+
  Procedure   : submit_ess_job
  Description : Submit ESS job on Cloud (concurrent)
  Usage       : 
  Arguments   : p_job_name          - path of the ESS job
                p_definition_name   - name of the job
                p_params            - list of parameters delimited with comma
                x_ws_call_id        - ID of ws callw
============================================================================+*/
  procedure submit_ess_job(p_job_name in varchar2, p_definition_name in varchar2, p_params in varchar2, x_ws_call_id out number) is
    l_wsdl_link    varchar2(500); --:= 'https://ehaz-test.fa.em2.oraclecloud.com:443/fscmService/ErpIntegrationService';
    l_wsdl_domain  varchar2(200);
    l_wsdl_method  varchar2(100) := 'submitESSJobRequest';
    l_ws_http_type varchar2(100) := 'text/xml;charset=UTF-8';

    x_return_status  varchar2(500);
    x_return_message varchar2(32000);
    l_soap_env       clob;
    l_text           varchar2(32000);

    XXPO_NO_ENV exception;

  begin

    xlog('Building link for environment');

    select value 
    into l_wsdl_domain
    from xx_configuration
    where name = 'ServiceRootURL'; 

    --l_wsdl_domain := xxpo_cs_integrations_pkg.get_wsdl_domain;

    if l_wsdl_domain is null then
      raise XXPO_NO_ENV;
    end if;

    l_wsdl_link := l_wsdl_domain|| '/fscmService/ErpIntegrationService';

    xlog('Link to environment: '||l_wsdl_link);

    xlog('Start of submit ESS job');

    xlog('Preparing soap envelope');
    l_text := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/">
         <soapenv:Header/>
         <soapenv:Body>
            <typ:submitESSJobRequest>
               <typ:jobPackageName>' || p_job_name || '</typ:jobPackageName>
               <typ:jobDefinitionName>' || p_definition_name || '</typ:jobDefinitionName>
               <!--Zero or more repetitions:-->' || chr(10) || parse_params(p_params) || '
            </typ:submitESSJobRequest>
         </soapenv:Body>
      </soapenv:Envelope>';

    xlog(l_text);
    xlog('Soap envelope to clob');
    l_soap_env := to_clob(l_text);

    xlog('Calling web service');
    xxfn_cloud_ws_pkg.ws_call(p_ws_url         => l_wsdl_link,
                                          p_soap_env       => l_soap_env,
                                          p_soap_act       => l_wsdl_method,
                                          p_content_type   => l_ws_http_type,
                                          x_return_status  => x_return_status,
                                          x_return_message => x_return_message,
                                          x_ws_call_id     => x_ws_call_id);

    dbms_lob.freetemporary(l_soap_env);
    xlog('WS call Id from ESS job:' || x_ws_call_id);
    xlog('Return status: ' || x_return_status);

    if (x_return_status = 'S') then

      xlog('ESS job submitted');

    else

      xlog('ESS job submit failed');

    end if;

  exception
    when XXPO_NO_ENV then
      xlog('Cannot find enviroment to establish domain!');
      xlog('Error code:' || sqlcode);
      xlog('Error msg:' || sqlerrm);
      dbms_lob.freetemporary(l_soap_env);
    when others then
      dbms_lob.freetemporary(l_soap_env);
      xlog('Error occured during submit ESS job request: ' || sqlcode);
      xlog('Msg:' || sqlerrm);
      xlog('Error_Stack...' || chr(10) || dbms_utility.format_error_stack());
      xlog('Error_Backtrace...' || chr(10) || dbms_utility.format_error_backtrace());
  end;

/*===========================================================================+
  Function   : parse_params
  Description : Exploder params sent as a string
  Usage       : 
  Arguments   : p_params        - list of parameters delimited with comma
  Return      : Return list of parameters in xml definition
  ============================================================================+*/
  function parse_params(p_params in varchar2) return varchar2 is
    l_params varchar2(1000);
  begin

    xlog('Starting to parse params:' || p_params);

    for c_r in (with data as
                   (select '' || p_params || '' str from dual)
                  select trim(regexp_substr(str, '[^,]+', 1, level)) str from data connect by instr(str, ',', 1, level - 1) > 0) loop

      l_params := l_params || '<typ:paramList>' || c_r.str || '</typ:paramList>' || chr(10);
    end loop;
    xlog('Returning parsed params');
    return l_params;

  exception
    when others then
      xlog('Error occured during parse_params function: ' || sqlcode);
      xlog('Msg:' || sqlerrm);
      xlog('Error_Stack...' || chr(10) || dbms_utility.format_error_stack());
      xlog('Error_Backtrace...' || chr(10) || dbms_utility.format_error_backtrace());
  end;

end XXFN_CLOUD_WS_PKG;
/
