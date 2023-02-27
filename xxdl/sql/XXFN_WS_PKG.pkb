create or replace package body xxfn_ws_pkg is
  /* $Header $
  ============================================================================+
  File Name   : XXFN_WS_PKG.pkb
  Description : Package for web service call utilities 
  History     :
  v1.0 09.01.2020 - 
  v1.1 16.05.2022 - Marko Sladoljev - Handling case without <?xml ?> tag in Response (ImportBulkData case)
  v1.2 18.07.2022 - Marko Sladoljev - XXFN_WS_CALL_LOG.response_json column supported
  v1.3 20.07.2022 - Marko Sladoljev - response_json column null bug
  v1.4 25.11.2022 - Marko Sladoljev - DELETE_LOBS_FROM_LOG: response_json set to null
  v1.5 25.11.2022 - Marko Sladoljev: Removed scheme prefix
  v1.6 06.01.2022 - Marko Sladoljev: delete_log_records 
  ============================================================================+*/

  g_step varchar2(200);

  /*===========================================================================+
  Procedure   : BUILD_SOAP_ENVELOPE
  Description : Builds G_SOAP_ENVELOPE global from chunks
  Usage       :
  Arguments   :
  ============================================================================+*/
  procedure build_soap_envelope(p_chunk varchar2) is
    l_chunk varchar2(20000);
  begin
    l_chunk         := p_chunk;
    g_soap_envelope := g_soap_envelope || l_chunk;
  end;

  /*===========================================================================+
  Procedure   : BUILD_SOAP_ENVELOPE
  Description : Adds chunks to G_RAW_TABLE global table that is used later for soap envelope
  Usage       :
  Arguments   :
  ============================================================================+*/
  procedure build_soap_envelopeb(p_chunk raw) is
  begin
    g_raw_table(g_raw_table.count + 1) := p_chunk;
  end;

  /*===========================================================================+
  Procedure   : BUILD_REST_ENVELOPE
  Description : Builds G_SOAP_ENVELOPE global from chunks
  Usage       :
  Arguments   :
  ============================================================================+*/
  procedure build_rest_envelope(p_chunk varchar2) is
    l_chunk varchar2(20000);
  begin
    l_chunk         := p_chunk;
    g_rest_envelope := g_rest_envelope || l_chunk;
  end;

  /*===========================================================================+
  Procedure   : BUILD_REST_ENVELOPE
  Description : Adds chunks to G_RAW_TABLE global table that is used later for soap envelope
  Usage       :
  Arguments   :
  ============================================================================+*/
  procedure build_rest_envelopeb(p_chunk raw) is
  begin
    g_raw_table(g_raw_table.count + 1) := p_chunk;
  end;

  /*===========================================================================+
  Procedure   : BUILD_RETURN_MESSAGE
  Description : Adds given text to G_RETURN_MESSAGE global
  Usage       :
  Arguments   :
  ============================================================================+*/
  procedure build_return_message(p_text varchar2) is
    l_text varchar2(32000);
  begin
    --dbms_output.put_line(p_text);
  
    l_text           := g_return_message || chr(10) || p_text;
    g_return_message := substr(l_text, 1, 10000);
  end;

  /*===========================================================================+
  Function    : GET_RETURN_STATUS
  Description : Returns and resets value of G_RETURN_STATUS global
  Usage       : Call just once after WS_CALL
  Arguments   :
  ============================================================================+*/
  function get_return_status return varchar2 is
    l_return g_return_status%type;
  begin
    l_return        := g_return_status;
    g_return_status := null;
    return(l_return);
  end;

  /*===========================================================================+
  Function    : GET_RETURN_MESSAGE
  Description : Returns and resets value of G_RETURN_MESSAGE global
  Usage       : Call just once after WS_CALL
  Arguments   :
  ============================================================================+*/
  function get_return_message return varchar2 is
    l_return g_return_message%type;
  begin
    l_return         := g_return_message;
    g_return_message := null;
    return(l_return);
  end;

  /*===========================================================================+
  Function    : GET_WS_CALL_ID
  Description : Returns and resets value of G_WS_CALL_ID global that contains the actual call's ID
  Usage       : Call just once after WS_CALL
  Arguments   :
  ============================================================================+*/
  function get_ws_call_id return number is
    l_return g_ws_call_id%type;
  begin
    l_return     := g_ws_call_id;
    g_ws_call_id := null;
    return(l_return);
  end;

  /*===========================================================================+
  Function    : WRITE_LOG
  Description : Writes given information to the log table
  Usage       : Autonomous transaction
  Arguments   :
  ============================================================================+*/
  procedure write_log(p_ws_url           in varchar2,
                      p_soap_act         in varchar2,
                      p_soap_env         in clob,
                      p_soap_xml         in xmltype,
                      p_status_code      in varchar2,
                      p_reason_phrase    in varchar2,
                      p_content_encoding in varchar2,
                      p_resp_xml         in xmltype,
                      p_clob_response    in clob,
                      p_blob_response    in blob,
                      p_resp_json        in clob) is
    pragma autonomous_transaction;
    check_constraint_violated exception;
    pragma exception_init(check_constraint_violated, -2290);
  begin
    g_step := 'insert into XXFN_WS_CALL_LOG';
  
    begin
      insert into xxfn_ws_call_log
        (ws_call_id,
         ws_call_timestamp,
         ws_url,
         ws_soap_action,
         ws_payload,
         ws_payload_xml,
         response_status_code,
         response_reason_phrase,
         response_content_encoding,
         response_xml,
         response_clob,
         response_blob,
         response_json)
      values
        (g_ws_call_id,
         systimestamp,
         p_ws_url,
         p_soap_act,
         p_soap_env,
         p_soap_xml,
         p_status_code,
         p_reason_phrase,
         p_content_encoding,
         p_resp_xml,
         p_clob_response,
         p_blob_response,
         p_resp_json);
      commit;
    exception
      when check_constraint_violated then
        -- insert without json response if json is not valid (in case of bad requests, etc.)
        insert into xxfn_ws_call_log
          (ws_call_id,
           ws_call_timestamp,
           ws_url,
           ws_soap_action,
           ws_payload,
           ws_payload_xml,
           response_status_code,
           response_reason_phrase,
           response_content_encoding,
           response_xml,
           response_clob,
           response_blob,
           response_json)
        values
          (g_ws_call_id,
           systimestamp,
           p_ws_url,
           p_soap_act,
           p_soap_env,
           p_soap_xml,
           p_status_code,
           p_reason_phrase,
           p_content_encoding,
           p_resp_xml,
           p_clob_response,
           p_blob_response,
           null);
        commit;
    end;
  
  exception
    when others then
      build_return_message('Error writing to log table: ' || sqlerrm);
  end;

  /*===========================================================================+
  Procedure   : WS_CALL
  Description : Calls the given web service and writes log to XXFN_WS_CALL_LOG table
  Usage       : If p_soap_envb is supplied the it is used for the call, otherwise p_soap_env is used
  Arguments   :
  ============================================================================+*/
  procedure ws_call(p_ws_url        in varchar2,
                    p_soap_env      in clob,
                    p_soap_envb     in blob default null,
                    p_soap_act      in varchar2,
                    p_content_type  in varchar2,
                    p_cloud_user    in varchar2 default null,
                    p_cloud_pass    in varchar2 default null,
                    x_return_status out nocopy varchar2) is
    l_http_request       utl_http.req;
    l_http_response      utl_http.resp;
    l_buffer_size        number(10) := 1024;
    l_raw_data           raw(1024);
    l_clob_response_orig clob;
    l_clob_response      clob;
    l_blob_response      blob;
    l_soap_xml           xmltype;
    l_resp_xml           xmltype;
    l_vc_header_name     varchar2(256);
    l_vc_header_value    varchar2(1024);
    l_content_encoding   varchar2(250);
    l_content_type       varchar2(350);
    l_status_code        varchar2(500);
    l_reason_phrase      varchar2(500);
    l_http_error_msg     varchar2(30000);
  
    l_soap_env clob;
    l_blob_env blob;
  
    l_boundary varchar2(250);
    l_start    varchar2(250);
    l_offset   binary_integer;
  begin
    g_step          := 'init';
    x_return_status := 'S';
  
    l_soap_env := p_soap_env;
    l_blob_env := p_soap_envb;
  
    g_ws_call_id := xxfn_ws_call_log_s.nextval;
  
    if p_soap_env is not null then
      begin
        l_soap_xml := xmltype.createxml(p_soap_env);
      exception
        when others then
          build_return_message('***');
          build_return_message('Error when parsing XML from p_soap_env:');
          build_return_message(sqlerrm);
          build_return_message('***');
      end;
    end if;
  
    utl_http.set_wallet('file:' || 'D:\oracle\admin\XE\wallet', 'welcome123');
    utl_http.set_response_error_check(false);
    utl_http.set_detailed_excp_support(false);
    l_http_request := utl_http.begin_request(p_ws_url, 'POST', 'HTTP/1.1');
    utl_http.set_authentication(l_http_request,
                                username       => nvl(p_cloud_user, 'XX_INTEGRATION'),
                                password       => nvl(p_cloud_pass, 'Welcome123'),
                                scheme         => 'Basic',
                                for_proxy      => false);
    utl_http.set_header(l_http_request, 'SOAP-Action', p_soap_act);
    utl_http.set_header(l_http_request, 'Cache-Control', 'no-cache');
  
    g_step := 'sent content type and body charset';
    utl_http.set_header(l_http_request, 'Content-Type', p_content_type);
    if instr(lower(p_content_type), 'text/xml') != 0 then
      utl_http.set_body_charset('UTF-8');
    end if;
  
    /*send the contents in chunks*/
    g_step := 'send the contents in chunks';
    if l_blob_env is not null then
      utl_http.set_header(l_http_request, 'Content-Length', dbms_lob.getlength(l_blob_env));
      g_step := 'send blob envelope in chunks; length: ' || dbms_lob.getlength(l_blob_env);
      build_return_message(g_step);
      declare
        amount integer;
        chunk_size constant pls_integer := 1024;
        buff      raw(2000);
        written   pls_integer := 0;
        remaining pls_integer;
      begin
        amount := dbms_lob.getlength(l_blob_env);
        if amount != 0 and l_blob_env is not null then
          while written + chunk_size < amount loop
            remaining := chunk_size;
            dbms_lob.read(lob_loc => l_blob_env, amount => remaining, offset => written + 1, buffer => buff);
            written := written + chunk_size;
          
            utl_http.write_raw(l_http_request, buff);
          end loop;
        
          -- put remaining
          remaining := amount - written;
          if remaining != 0 then
            dbms_lob.read(lob_loc => l_blob_env, amount => remaining, offset => written + 1, buffer => buff);
          
            utl_http.write_raw(l_http_request, buff);
          end if;
        end if;
      exception
        when others then
          build_return_message('***');
          build_return_message('Error when sending the contents in chunks:');
          build_return_message(sqlerrm);
          build_return_message('***');
          return;
      end;
    else
      utl_http.set_header(l_http_request, 'Content-Length', dbms_lob.getlength(l_soap_env));
      g_step := 'send clob envelope in chunks; length: ' || dbms_lob.getlength(l_soap_env);
      build_return_message(g_step);
      declare
        amount integer;
        chunk_size constant pls_integer := 1024;
        buff      varchar2(2000);
        written   pls_integer := 0;
        remaining pls_integer;
      begin
        amount := dbms_lob.getlength(l_soap_env);
        if amount != 0 and l_soap_env is not null then
          while written + chunk_size < amount loop
            remaining := chunk_size;
            dbms_lob.read(lob_loc => l_soap_env, amount => remaining, offset => written + 1, buffer => buff);
            written := written + chunk_size;
          
            utl_http.write_raw(l_http_request, utl_raw.cast_to_raw(buff));
          end loop;
        
          -- put remaining
          remaining := amount - written;
          if remaining != 0 then
            dbms_lob.read(lob_loc => l_soap_env, amount => remaining, offset => written + 1, buffer => buff);
          
            utl_http.write_raw(l_http_request, utl_raw.cast_to_raw(buff));
          end if;
        end if;
      exception
        when others then
          build_return_message('***');
          build_return_message('Error when sending the contents in chunks:');
          build_return_message(sqlerrm);
          build_return_message('***');
          return;
      end;
    end if;
  
    begin
      l_http_response := utl_http.get_response(l_http_request);
    exception
      when others then
        build_return_message('***');
        build_return_message('Error when getting response:');
        build_return_message(sqlerrm);
        build_return_message('***');
    end;
  
    l_status_code   := l_http_response.status_code;
    l_reason_phrase := l_http_response.reason_phrase;
  
    build_return_message(chr(10) || '=== Print result ===' || chr(10));
    build_return_message('Response> status_code: "' || l_status_code || '"');
    build_return_message('Response> reason_phrase: "' || l_reason_phrase || '"');
    build_return_message('Response> http_version: "' || l_http_response.http_version || '"');
  
    if l_status_code != '200' then
      x_return_status := 'E';
      if l_http_error_msg is null then
        l_http_error_msg := ' SQLCODE:' || utl_http.get_detailed_sqlcode || ' ERROR:' || utl_http.get_detailed_sqlerrm;
        build_return_message('SQL ERROR: ' || l_http_error_msg);
      end if;
    end if;
  
    if l_http_response.status_code is not null then
      build_return_message(chr(10) || 'Response header:');
      for loop_hc in 1 .. utl_http.get_header_count(l_http_response) loop
        utl_http.get_header(l_http_response, loop_hc, l_vc_header_name, l_vc_header_value);
        build_return_message(l_vc_header_name || ': ' || l_vc_header_value);
        if lower(l_vc_header_name) = lower('Content-Encoding') then
          l_content_encoding := l_vc_header_value;
        end if;
        if lower(l_vc_header_name) = lower('Content-Type') then
          l_content_type := l_vc_header_value;
        end if;
      end loop loop_hc;
    end if;
    build_return_message(chr(10));
  
    begin
      if l_content_type like 'multipart/related;%' and instr(l_content_type, 'boundary') != 0 then
        l_boundary := substr(l_content_type, instr(l_content_type, 'boundary="') + 10, 90);
        if instr(l_boundary, '"') != 0 then
          l_boundary := substr(l_boundary, 1, instr(l_boundary, '"') - 1);
        end if;
      
        l_start := substr(l_content_type, instr(l_content_type, 'start="') + 7, 90);
        if instr(l_start, '"') != 0 then
          l_start := substr(l_start, 1, instr(l_start, '"') - 1);
        end if;
      end if;
    exception
      when others then
        l_start := null;
        build_return_message('***');
        build_return_message('Error when getting boundary and start for content-type: ' || l_content_type);
    end;
  
    if nvl(l_content_encoding, 'x') != 'gzip' then
      dbms_lob.createtemporary(l_clob_response, false);
      begin
        <<response_loop>>
        loop
          utl_http.read_raw(l_http_response, l_raw_data, l_buffer_size);
          --dbms_output.put_line(utl_raw.cast_to_varchar2(l_raw_data));
          dbms_lob.append(l_clob_response, utl_raw.cast_to_varchar2(l_raw_data));
        end loop response_loop;
      exception
        when utl_http.end_of_body then
          utl_http.end_response(l_http_response);
      end;
    
      build_return_message('Response length ' || l_content_encoding || ': ' || length(l_clob_response));
      begin
        g_step := 'store original response';
        dbms_lob.createtemporary(l_clob_response_orig, false);
        dbms_lob.append(l_clob_response_orig, l_clob_response);
      exception
        when others then
          null; /*ignore errors*/
      end;
    
    else
      dbms_lob.createtemporary(l_blob_response, false);
      begin
        <<response_loop2>>
        loop
          utl_http.read_raw(l_http_response, l_raw_data, l_buffer_size);
          dbms_lob.append(l_blob_response, l_raw_data);
        end loop response_loop2;
      exception
        when utl_http.end_of_body then
          utl_http.end_response(l_http_response);
      end;
    
      build_return_message('Response length gzip: "' || dbms_lob.getlength(l_blob_response) || '"');
    
      begin
        l_blob_response := utl_compress.lz_uncompress(l_blob_response);
      exception
        when others then
          build_return_message('***');
          build_return_message('Error when uncompressing BLOB response:');
          build_return_message(sqlerrm);
          build_return_message('***');
      end;
    
    end if;
  
    if dbms_lob.getlength(l_blob_response) != 0 or l_start is not null then
      declare
        l_clob         clob;
        l_dest_offset  integer := 1;
        l_src_offset   integer := 1;
        l_lang_context integer := dbms_lob.default_lang_ctx;
        l_warning      integer;
      begin
        dbms_lob.createtemporary(l_clob, false);
      
        if l_blob_response is not null then
          g_step := 'convert response blob to clob';
          dbms_lob.converttoclob(dest_lob     => l_clob,
                                 src_blob     => l_blob_response,
                                 amount       => dbms_lob.lobmaxsize,
                                 dest_offset  => l_dest_offset,
                                 src_offset   => l_src_offset,
                                 blob_csid    => 871, /*871 = UTF-8, default is: dbms_lob.default_csid*/
                                 lang_context => l_lang_context,
                                 warning      => l_warning);
          l_clob_response := l_clob;
        else
          l_clob := l_clob_response;
        end if;
      
        if l_start is not null then
          g_step   := 'trim to start';
          l_offset := dbms_lob.instr(l_clob, l_start);
          l_offset := l_offset + length(l_start) + 1;
          l_clob   := dbms_lob.substr(l_clob, dbms_lob.getlength(l_clob) - l_offset, l_offset);
        
          g_step := 'remove boundaries';
          l_clob := regexp_replace(l_clob, '--' || l_boundary || '--', ''); /*end*/
          l_clob := regexp_replace(l_clob, '--' || l_boundary, ''); /*start*/
          l_clob := regexp_replace(l_clob, l_boundary, ''); /*inside*/
        
          g_step   := 'remove xml page tag';
          l_start  := '<?xml';
          l_offset := dbms_lob.instr(l_clob, l_start);
          -- if xml tag exists, remove it
          if l_offset > 0 then
            l_offset := l_offset + length(l_start) + 1;
            l_clob   := dbms_lob.substr(l_clob, dbms_lob.getlength(l_clob) - l_offset, l_offset);
            l_start  := '?>';
            l_offset := dbms_lob.instr(l_clob, l_start);
            l_offset := l_offset + length(l_start) + 1;
            l_clob   := dbms_lob.substr(l_clob, dbms_lob.getlength(l_clob) - l_offset, l_offset);
          end if;
          l_clob_response := l_clob;
        end if;
      
        dbms_lob.freetemporary(l_clob);
      exception
        when others then
          build_return_message('***');
          build_return_message('Error when converting BLOB response to CLOB:');
          build_return_message(sqlerrm);
          build_return_message('***');
      end;
    end if;
  
    if dbms_lob.getlength(l_clob_response) != 0 then
      begin
        g_step     := 'parsing XML from response';
        l_resp_xml := xmltype.createxml(l_clob_response);
      
        build_return_message(dbms_lob.substr(l_clob_response, 250, 1));
      exception
        when others then
          build_return_message('***');
          build_return_message('Error when parsing XML from response:');
          build_return_message(sqlerrm);
          build_return_message('***');
      end;
    end if;
  
    write_log(p_ws_url           => p_ws_url,
              p_soap_act         => p_soap_act,
              p_soap_env         => p_soap_env,
              p_soap_xml         => l_soap_xml,
              p_status_code      => l_status_code,
              p_reason_phrase    => l_reason_phrase,
              p_content_encoding => l_content_encoding,
              p_resp_xml         => l_resp_xml,
              p_clob_response    => l_clob_response_orig,
              p_blob_response    => l_blob_response,
              p_resp_json        => null);
  
    if l_blob_response is not null then
      begin
        g_step := 'freetemporary(l_blob_response)';
        dbms_lob.freetemporary(l_blob_response);
      exception
        when others then
          null;
      end;
    end if;
  
    if l_clob_response is not null then
      begin
        g_step := 'freetemporary(l_clob_response)';
        dbms_lob.freetemporary(l_clob_response);
      exception
        when others then
          null;
      end;
    end if;
  
    if l_clob_response_orig is not null then
      begin
        g_step := 'freetemporary(l_clob_response_orig)';
        dbms_lob.freetemporary(l_clob_response_orig);
      exception
        when others then
          null;
      end;
    end if;
  
    if dbms_lob.isopen(g_soap_envelope) = 1 then
      g_step := 'close(G_SOAP_ENVELOPE)';
      dbms_lob.close(g_soap_envelope);
    end if;
  
    begin
      utl_http.end_request(l_http_request);
      utl_http.end_response(l_http_response);
      utl_http.close_persistent_conns();
    exception
      when others then
        null;
    end;
  
  exception
    when utl_http.end_of_body then
      utl_http.end_response(l_http_response);
    when others then
      x_return_status := 'E';
      build_return_message('ERROR OCCURED:');
      build_return_message(sqlerrm);
      build_return_message('last step: ' || g_step);
      rollback;
  end;

  /*===========================================================================+
  Procedure   : WS_CALL
  Description : overloaded
  Usage       :
  Arguments   :
  ============================================================================+*/
  procedure ws_call(p_ws_url       in varchar2,
                    p_soap_act     in varchar2,
                    p_content_type in varchar2,
                    p_cloud_user   in varchar2 default null,
                    p_cloud_pass   in varchar2 default null) is
    l_soap_env      clob;
    l_blob_env      blob;
    l_return_status varchar2(10);
  begin
    l_soap_env := g_soap_envelope;
  
    dbms_lob.createtemporary(l_blob_env, false);
    for i in g_raw_table.first .. g_raw_table.last loop
      dbms_lob.append(l_blob_env, g_raw_table(i));
    end loop;
  
    ws_call(p_ws_url        => p_ws_url,
            p_soap_act      => p_soap_act,
            p_soap_env      => l_soap_env,
            p_soap_envb     => l_blob_env,
            p_content_type  => p_content_type,
            p_cloud_user    => p_cloud_user,
            p_cloud_pass    => p_cloud_pass,
            x_return_status => l_return_status);
  
    g_return_status := l_return_status;
    g_soap_envelope := null;
    dbms_lob.freetemporary(l_blob_env);
    g_raw_table := g_raw_table_empty;
  exception
    when others then
      g_return_status := 'E';
      g_soap_envelope := null;
      g_raw_table     := g_raw_table_empty;
      dbms_output.put_line('ERROR!' || chr(10));
      dbms_output.put_line(sqlerrm);
    
  end;

  /*===========================================================================+
  Procedure   : PURGE_OLD_LOG
  Description : Deletes records from XXFN_WS_CALL_LOG table
  Usage       : 
  Arguments   : p_keep_days -> number of days to keep
  ============================================================================+*/
  procedure purge_old_log(p_keep_days in number) is
    pragma autonomous_transaction;
    l_days number;
  begin
    l_days := p_keep_days;
  
    if l_days is null then
      l_days := 30;
    end if;
  
    delete from xxfn_ws_call_log wcl where wcl.ws_call_timestamp < sysdate - l_days;
  
    commit;
  end;

  /*===========================================================================+
  Function   : get_tinyurl
  Description : calls tinyurl via http call and gets tinyurl of provided p_url
  Usage       : 
  Arguments   : p_url ->original url
  Return      : tinyurl
  ============================================================================+*/
  function get_tinyurl(p_url in varchar2) return varchar2 is
  
    l_req         utl_http.req;
    l_resp        utl_http.resp;
    l_text        varchar2(2000);
    l_return_text varchar2(2000);
  begin
  
    l_req  := utl_http.begin_request(p_url);
    l_resp := utl_http.get_response(l_req);
  
    -- loop through the data coming back
    begin
      loop
        utl_http.read_text(l_resp, l_text, 2000);
        l_return_text := l_return_text || l_text;
        --dbms_output.put_line(l_text);
      end loop;
    exception
      when utl_http.end_of_body then
        utl_http.end_response(l_resp);
    end;
  
    return l_return_text;
  
  end get_tinyurl;

  /*===========================================================================+
  Procedure   : WS_REST_CALL
  Description : Calls the given REST web service and writes log to XXFN_WS_CALL_LOG table
  Usage       : If p_rest_envb is supplied the it is used for the call, otherwise p_rest_env is used
  Arguments   :
  ============================================================================+*/
  procedure ws_rest_call(p_ws_url        in varchar2,
                         p_rest_env      in clob,
                         p_rest_envb     in blob default null,
                         p_rest_act      in varchar2,
                         p_content_type  in varchar2,
                         p_cloud_user    in varchar2 default null,
                         p_cloud_pass    in varchar2 default null,
                         x_return_status out nocopy varchar2) is
    l_http_request       utl_http.req;
    l_http_response      utl_http.resp;
    l_buffer_size        number(10) := 1024;
    l_raw_data           raw(1024);
    l_clob_response_orig clob;
    l_clob_response      clob;
    l_blob_response      blob;
    --  l_soap_xml           xmltype;
    l_resp_xml         xmltype;
    l_vc_header_name   varchar2(256);
    l_vc_header_value  varchar2(1024);
    l_content_encoding varchar2(250);
    l_content_type     varchar2(350);
    l_status_code      varchar2(500);
    l_reason_phrase    varchar2(500);
    l_http_error_msg   varchar2(30000);
  
    l_rest_env clob;
    l_blob_env blob;
  
    l_boundary      varchar2(250);
    l_start         varchar2(250);
    l_offset        binary_integer;
    l_response_raw  raw(32766);
    l_response_clob clob;
  begin
    g_step          := 'init';
    x_return_status := 'S';
  
    l_rest_env := p_rest_env;
    l_blob_env := p_rest_envb;
  
    g_ws_call_id := xxfn_ws_call_log_s.nextval;
  
    --dbms_output.put_line('XXWS:4');
  
    utl_http.set_wallet('file:' || 'D:\oracle\admin\XE\wallet', 'welcome123');
    utl_http.set_response_error_check(false);
    utl_http.set_detailed_excp_support(false);
  
    -- dbms_output.put_line('XXWS:5');
  
    --dbms_output.put_line('p_ws_url:'||p_ws_url);
    --dbms_output.put_line('p_rest_act'||p_rest_act);
    l_http_request := utl_http.begin_request(p_ws_url, p_rest_act, 'HTTP/1.1'); --'POST'
  
    --dbms_output.put_line('XXWS:6');
  
    utl_http.set_authentication(l_http_request,
                                username       => nvl(p_cloud_user, 'XX_INTEGRATION'),
                                password       => nvl(p_cloud_pass, 'Welcome123'),
                                scheme         => 'Basic',
                                for_proxy      => false);
  
    --dbms_output.put_line('XXWS:7');
  
    -- utl_http.set_header(l_http_request, 'SOAP-Action', p_soap_act);
    utl_http.set_header(l_http_request, 'Cache-Control', 'no-cache');
  
    g_step := 'sent content type and body charset';
    -- dbms_output.put_line('g_step:'||g_step);
    utl_http.set_header(l_http_request, 'Content-Type', p_content_type);
    if instr(lower(p_content_type), 'text/xml') != 0 then
      utl_http.set_body_charset('UTF-8');
    end if;
  
    --dbms_output.put_line('XXWS:8');
  
    /*send the contents in chunks*/
    g_step := 'send the contents in chunks';
    -- dbms_output.put_line('g_step:'||g_step);
    if l_blob_env is not null then
      utl_http.set_header(l_http_request, 'Content-Length', dbms_lob.getlength(l_blob_env));
      g_step := 'send blob envelope in chunks; length: ' || dbms_lob.getlength(l_blob_env);
      -- dbms_output.put_line('g_step:'||g_step);
      build_return_message(g_step);
      declare
        amount integer;
        chunk_size constant pls_integer := 1024;
        buff      raw(2000);
        written   pls_integer := 0;
        remaining pls_integer;
      begin
        amount := dbms_lob.getlength(l_blob_env);
        if amount != 0 and l_blob_env is not null then
          while written + chunk_size < amount loop
            remaining := chunk_size;
            dbms_lob.read(lob_loc => l_blob_env, amount => remaining, offset => written + 1, buffer => buff);
            written := written + chunk_size;
          
            utl_http.write_raw(l_http_request, buff);
          end loop;
        
          -- put remaining
          remaining := amount - written;
          if remaining != 0 then
            dbms_lob.read(lob_loc => l_blob_env, amount => remaining, offset => written + 1, buffer => buff);
          
            utl_http.write_raw(l_http_request, buff);
          end if;
        end if;
      exception
        when others then
          build_return_message('***');
          build_return_message('Error when sending the contents in chunks:');
          dbms_output.put_line('g_step:' || 'Error when sending the contents in chunks:');
          build_return_message(sqlerrm);
          build_return_message('***');
          return;
      end;
    else
      utl_http.set_header(l_http_request, 'Content-Length', dbms_lob.getlength(l_rest_env));
      g_step := 'send clob envelope in chunks; length: ' || dbms_lob.getlength(l_rest_env);
      -- dbms_output.put_line('g_step:'||g_step);
      build_return_message(g_step);
      declare
        amount integer;
        chunk_size constant pls_integer := 1024;
        buff      varchar2(2000);
        written   pls_integer := 0;
        remaining pls_integer;
      begin
        amount := dbms_lob.getlength(l_rest_env);
        if amount != 0 and l_rest_env is not null then
          while written + chunk_size < amount loop
            remaining := chunk_size;
            dbms_lob.read(lob_loc => l_rest_env, amount => remaining, offset => written + 1, buffer => buff);
            written := written + chunk_size;
          
            utl_http.write_raw(l_http_request, utl_raw.cast_to_raw(buff));
          end loop;
        
          -- put remaining
          remaining := amount - written;
          if remaining != 0 then
            dbms_lob.read(lob_loc => l_rest_env, amount => remaining, offset => written + 1, buffer => buff);
          
            utl_http.write_raw(l_http_request, utl_raw.cast_to_raw(buff));
          end if;
        end if;
      exception
        when others then
          build_return_message('***');
          build_return_message('Error when sending the contents in chunks:');
          dbms_output.put_line('g_step:' || 'Error when sending the contents in chunks:');
          build_return_message(sqlerrm);
          build_return_message('***');
          return;
      end;
    end if;
  
    --dbms_output.put_line('XXWS:9');
  
    begin
      l_http_response := utl_http.get_response(l_http_request);
    exception
      when others then
        build_return_message('***');
        build_return_message('Error when getting response:');
        dbms_output.put_line('g_step:' || 'Error when getting response:');
        build_return_message(sqlerrm);
        build_return_message('***');
    end;
  
    l_status_code   := l_http_response.status_code;
    l_reason_phrase := l_http_response.reason_phrase;
  
    build_return_message(chr(10) || '=== Print result ===' || chr(10));
    build_return_message('Response> status_code: "' || l_status_code || '"');
    build_return_message('Response> reason_phrase: "' || l_reason_phrase || '"');
    build_return_message('Response> http_version: "' || l_http_response.http_version || '"');
    --  dbms_output.put_line('dbms_output output code:'||l_status_code);
    --  dbms_output.put_line('dbms_output reason phrase:'||l_reason_phrase);
    -- dbms_output.put_line('dbms_output http_version:'||l_http_response.http_version);
  
    if l_status_code != '200' and l_status_code != '201' then
      x_return_status := 'E';
      if l_http_error_msg is null then
        l_http_error_msg := ' SQLCODE:' || utl_http.get_detailed_sqlcode || ' ERROR:' || utl_http.get_detailed_sqlerrm;
        build_return_message('SQL ERROR: ' || l_http_error_msg);
        --   dbms_output.put_line('dbms_output SQL ERROR: '||l_http_error_msg);
      end if;
    end if;
  
    if l_http_response.status_code is not null then
      build_return_message(chr(10) || 'Response header:');
      for loop_hc in 1 .. utl_http.get_header_count(l_http_response) loop
      
        begin
          utl_http.get_header(l_http_response, loop_hc, l_vc_header_name, l_vc_header_value);
          build_return_message(l_vc_header_name || ': ' || l_vc_header_value);
          if lower(l_vc_header_name) = lower('Content-Encoding') then
            l_content_encoding := l_vc_header_value;
          end if;
          if lower(l_vc_header_name) = lower('Content-Type') then
            l_content_type := l_vc_header_value;
          end if;
        
          if l_vc_header_name = 'RESPONSE' then
            l_clob_response := '<RESPONSE>' || l_vc_header_value || '</RESPONSE>';
          end if;
        
          if lower(l_vc_header_name) = lower('Error-Reason') then
            l_clob_response := '<RESPONSE>' || l_vc_header_value || '</RESPONSE>';
            build_return_message('Error at Paas:' || l_vc_header_value);
            l_clob_response := '<PAAS_ERROR>' || l_vc_header_value || '</PAAS_ERROR>';
          end if;
          /*REST response does not have headers, just response*/
          -- UTL_HTTP.read_raw(l_http_response, l_response_raw,32766);
          -- l_response_clob := xxfn_cloud_ws_pkg.blob_to_clob(l_response_raw);
          -- dbms_output.put_line(dbms_lob.substr(l_response_clob,24000,1));
          -- BUILD_RETURN_MESSAGE('Response clob:'||l_response_clob); 
        
        exception
          when utl_http.end_of_body then
            utl_http.end_response(l_http_response);
        end;
      
      end loop loop_hc;
    end if;
    build_return_message(chr(10));
  
    begin
      -- novo
      if l_content_type like 'multipart/related;%' and instr(l_content_type, 'boundary') != 0 then
        l_boundary := substr(l_content_type, instr(l_content_type, 'boundary="') + 10, 90);
        if instr(l_boundary, '"') != 0 then
          l_boundary := substr(l_boundary, 1, instr(l_boundary, '"') - 1);
        end if;
      
        l_start := substr(l_content_type, instr(l_content_type, 'start="') + 7, 90);
        if instr(l_start, '"') != 0 then
          l_start := substr(l_start, 1, instr(l_start, '"') - 1);
        end if;
      end if;
    exception
      when others then
        l_start := null;
        build_return_message('***');
        build_return_message('Error when getting boundary and start for content-type: ' || l_content_type);
    end; -- novo   
    if nvl(l_content_encoding, 'x') != 'gzip' then
      -- if 1=1 then
      dbms_lob.createtemporary(l_clob_response, false);
      begin
      
        -- dbms_output.put_line('dbms_output before response_loop');
        <<response_loop>>
        loop
          utl_http.read_raw(l_http_response, l_raw_data, l_buffer_size);
          --dbms_output.put_line(utl_raw.cast_to_varchar2(l_raw_data));
          dbms_lob.append(l_clob_response, utl_raw.cast_to_varchar2(l_raw_data));
        end loop response_loop;
      exception
        when utl_http.end_of_body then
          utl_http.end_response(l_http_response);
      end;
    
      build_return_message('Response length ' || l_content_encoding || ': ' || length(l_clob_response));
      begin
        g_step := 'store original response';
        dbms_lob.createtemporary(l_clob_response_orig, false);
        dbms_lob.append(l_clob_response_orig, l_clob_response);
      exception
        when others then
          null;
      end;
    
    else
      -- novo
      dbms_lob.createtemporary(l_blob_response, false);
      begin
        <<response_loop2>>
        loop
          utl_http.read_raw(l_http_response, l_raw_data, l_buffer_size);
          dbms_lob.append(l_blob_response, l_raw_data);
        end loop response_loop2;
      exception
        when utl_http.end_of_body then
          utl_http.end_response(l_http_response);
      end;
    
      build_return_message('Response length gzip: "' || dbms_lob.getlength(l_blob_response) || '"');
    
      begin
        l_blob_response := utl_compress.lz_uncompress(l_blob_response);
      exception
        when others then
          build_return_message('***');
          build_return_message('Error when uncompressing BLOB response:');
          build_return_message(sqlerrm);
          build_return_message('***');
      end; -- novo end
    end if;
  
    if dbms_lob.getlength(l_blob_response) != 0 or l_start is not null then
      -- novo
      declare
        l_clob         clob;
        l_dest_offset  integer := 1;
        l_src_offset   integer := 1;
        l_lang_context integer := dbms_lob.default_lang_ctx;
        l_warning      integer;
      begin
        dbms_lob.createtemporary(l_clob, false);
      
        if l_blob_response is not null then
          g_step := 'convert response blob to clob';
          dbms_lob.converttoclob(dest_lob     => l_clob,
                                 src_blob     => l_blob_response,
                                 amount       => dbms_lob.lobmaxsize,
                                 dest_offset  => l_dest_offset,
                                 src_offset   => l_src_offset,
                                 blob_csid    => 871, /*871 = UTF-8, default is: dbms_lob.default_csid*/
                                 lang_context => l_lang_context,
                                 warning      => l_warning);
          l_clob_response := l_clob;
        else
          l_clob := l_clob_response;
        end if;
      
        if l_start is not null then
          g_step   := 'trim to start';
          l_offset := dbms_lob.instr(l_clob, l_start);
          l_offset := l_offset + length(l_start) + 1;
          l_clob   := dbms_lob.substr(l_clob, dbms_lob.getlength(l_clob) - l_offset, l_offset);
        
          g_step := 'remove boundaries';
          l_clob := regexp_replace(l_clob, '--' || l_boundary || '--', ''); /*end*/
          l_clob := regexp_replace(l_clob, '--' || l_boundary, ''); /*start*/
          l_clob := regexp_replace(l_clob, l_boundary, ''); /*inside*/
        
          g_step   := 'remove xml page tag';
          l_start  := '<?xml';
          l_offset := dbms_lob.instr(l_clob, l_start);
          l_offset := l_offset + length(l_start) + 1;
          l_clob   := dbms_lob.substr(l_clob, dbms_lob.getlength(l_clob) - l_offset, l_offset);
          l_start  := '?>';
          l_offset := dbms_lob.instr(l_clob, l_start);
          l_offset := l_offset + length(l_start) + 1;
          l_clob   := dbms_lob.substr(l_clob, dbms_lob.getlength(l_clob) - l_offset, l_offset);
        
          l_clob_response := l_clob;
        end if;
      
        dbms_lob.freetemporary(l_clob);
      exception
        when others then
          build_return_message('***');
          build_return_message('Error when converting BLOB response to CLOB:');
          build_return_message(sqlerrm);
          build_return_message('***');
      end;
    end if; -- end novo    
    if dbms_lob.getlength(l_clob_response) != 0 then
      begin
        g_step := 'parsing XML from response';
        -- dbms_output.put_line('dbms_output before parsing XML response');
        -- l_resp_xml := XMLType.createXML(l_clob_response);
      
        build_return_message(dbms_lob.substr(l_clob_response, 250, 1)); -- novo                           
      exception
        when others then
          build_return_message('***');
          build_return_message('Error when parsing XML from response:');
          build_return_message(sqlerrm);
          build_return_message('***');
      end;
    end if;
  
    --dbms_output.put_line('dbms_output before write_log');
    write_log(p_ws_url           => p_ws_url,
              p_soap_act         => p_rest_act,
              p_soap_env         => p_rest_env,
              p_soap_xml         => null, --l_soap_xml,
              p_status_code      => l_status_code,
              p_reason_phrase    => l_reason_phrase,
              p_content_encoding => l_content_encoding,
              p_resp_xml         => l_resp_xml,
              p_clob_response    => l_clob_response,
              p_blob_response    => l_blob_response,
              p_resp_json        => l_clob_response);
  
    if l_blob_response is not null then
      begin
        g_step := 'freetemporary(l_blob_response)';
        --  dbms_output.put_line('dbms_output before freetemporary blob response');
        dbms_lob.freetemporary(l_blob_response);
      exception
        when others then
          null;
      end;
    end if;
  
    if l_clob_response is not null then
      begin
        g_step := 'freetemporary(l_clob_response)';
        --  dbms_output.put_line('dbms_output before freetemporary clob response');
        dbms_lob.freetemporary(l_clob_response);
      exception
        when others then
          null;
      end;
    end if;
  
    if l_clob_response_orig is not null then
      begin
        g_step := 'freetemporary(l_clob_response_orig)';
        --  dbms_output.put_line('dbms_output before freetemporary blob response orig');
        dbms_lob.freetemporary(l_clob_response_orig);
      exception
        when others then
          null;
      end;
    end if;
  
    if dbms_lob.isopen(g_rest_envelope) = 1 then
      g_step := 'close(G_REST_ENVELOPE)';
      --  dbms_output.put_line('dbms_output before close(G_REST_ENVELOPE)');
      dbms_lob.close(g_rest_envelope);
    end if;
  
    begin
      utl_http.end_request(l_http_request);
      utl_http.end_response(l_http_response);
      utl_http.close_persistent_conns();
    exception
      when others then
        null;
    end;
  
  exception
    when utl_http.end_of_body then
      utl_http.end_response(l_http_response);
    when utl_http.too_many_requests then
      utl_http.end_response(l_http_response);
    when others then
      x_return_status := 'E';
      build_return_message('ERROR OCCURED:');
      build_return_message(sqlerrm);
      build_return_message('last step: ' || g_step);
      rollback;
  end;

  /*===========================================================================+
  Procedure   : WS_REST_CALL
  Description : overloaded
  Usage       :
  Arguments   :
  ============================================================================+*/
  procedure ws_rest_call(p_ws_url       in varchar2,
                         p_rest_act     in varchar2,
                         p_content_type in varchar2,
                         p_cloud_user   in varchar2 default null,
                         p_cloud_pass   in varchar2 default null) is
    l_rest_env      clob;
    l_blob_env      blob;
    l_return_status varchar2(10);
  begin
    l_rest_env := g_rest_envelope;
  
    dbms_lob.createtemporary(l_blob_env, false);
    for i in g_raw_table.first .. g_raw_table.last loop
      dbms_lob.append(l_blob_env, g_raw_table(i));
    end loop;
  
    -- dbms_output.put_line('XXWS:1');
  
    ws_rest_call(p_ws_url        => p_ws_url,
                 p_rest_act      => p_rest_act,
                 p_rest_env      => l_rest_env,
                 p_rest_envb     => l_blob_env,
                 p_content_type  => p_content_type,
                 p_cloud_user    => p_cloud_user,
                 p_cloud_pass    => p_cloud_pass,
                 x_return_status => l_return_status);
  
    --dbms_output.put_line('XXWS:2');
  
    g_return_status := l_return_status;
    g_rest_envelope := null;
    dbms_lob.freetemporary(l_blob_env);
    g_raw_table := g_raw_table_empty;
  exception
    when others then
      g_return_status := 'E';
      g_rest_envelope := null;
      g_raw_table     := g_raw_table_empty;
      --dbms_output.put_line('XXWS:3');
      dbms_output.put_line('ERROR!' || chr(10));
      dbms_output.put_line(sqlerrm);
  end;

  /*===========================================================================+
  Procedure   : DELETE_LOBS_FROM_LOG
  Description : Empties blob and xmltype columns for given row in XXFN_WS_CALL_LOG table
  Usage       : 
  Arguments   : p_ws_call_id -> web service call identifier
  ============================================================================+*/
  procedure delete_lobs_from_log(p_ws_call_id in xxfn_ws_call_log.ws_call_id%type) is
    pragma autonomous_transaction;
  begin
    update xxfn_ws_call_log wcl
       set wcl.ws_payload     = null,
           wcl.ws_payload_xml = null,
           wcl.response_xml   = null,
           wcl.response_clob  = null,
           wcl.response_blob  = null,
           wcl.response_json  = null
     where wcl.ws_call_id = p_ws_call_id;
    commit;
  end;

  /*===========================================================================+
  Procedure   : delete_log_records
  Description : Deletes sucessful old log records leaving up to 2 hours old logs
  Usage       : 
  Arguments   : 
  ============================================================================+*/
  procedure delete_log_records is
  begin
    delete from xxfn_ws_call_log ws
     where ws.ws_call_timestamp < sysdate - 2 / 24
       and ws.response_status_code in (200, 201);
  end;

end xxfn_ws_pkg;
/
