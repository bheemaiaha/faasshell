%% #!/usr/bin/swipl -q
%% -*- mode: prolog; coding: utf-8; -*-
%%
%% Copyright 2017 FUJITSU LIMITED
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%

%%
%%  FaaS Shell Microservice
%%

:- module(asl_svc, [main/0]).

:- use_module(asl_gen, [gen_dsl/2]).
:- use_module(asl_run, [start/4]).
:- use_module(cdb_api).
:- use_module(mq_utils).

%% http server
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/json)).
:- use_module(library(http/json_convert)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_log)).
:- use_module(library(http/http_client)).
:- use_module(library(http/html_write)).
:- use_module(library(http/http_authenticate)).
%% :- use_module(library(http/http_error)). % should be removed in puroduction

%% start
%% :- initialization(main).

%%
%% main
%%   $ swipl -q -l asl_svc.pl -g main -t halt
%%
%% start:
%%   ?- asl_svc:main.
%% stop the server:
%%   ?- http_stop_server(8080,[]).
%%
main :-
    set_setting(http:logfile,'/logs/httpd.log'), % docker volume /tmp
    mq_utils:mq_init,
    catch(db_init(faasshell, faas, _Codes),
          Error,
          (print_message(error, Error), halt(1))),
    getenv('SVC_PORT', Port) -> server(Port); server(8080).

server(Port) :-
    http_server(http_dispatch, [port(Port)]),
    thread_get_message(stop).

%% signal handler
:- on_signal(hup, _, hup).

hup(_Signal) :-
    thread_send_message(main, stop),
    halt(0).

%%
%%
:- http_handler('/activity/', activity, [methods([get, post, patch]), prefix,
                                         authentication(openwhisk)]).

activity(Request) :-
    http_log('~w~n', [request(Request)]),
    option(namespace(nil), Request)
    -> reply_json_dict(_{error: 'Authentication Failure'}, [status(401)])
    ;  memberchk(method(Method), Request),
       catch( activity(Method, Request),
              (Message, Code),
              ( http_log('~w~n', [catch((Message, Code))]),
                reply_json_dict(Message, [status(Code)])
              )).

activity(get, Request) :-
    ( memberchk(path_info(Activity), Request)
      -> uuid(TaskToken),
         http_log('~w, ~p~n',
                  [activity(get, Activity), task_token(TaskToken)]),
         mq_utils:activity_start(Activity, TaskToken, InputText),
         atom_json_dict(InputText, Input, []),
         Reply = _{output: "ok", taskToken: TaskToken, input: Input}
      ;  http_header:status_number(bad_request, S_400),
         throw((_{error: 'Missing activity task name'}, S_400))
    ),
    reply_json_dict(Reply).

activity(post, Request) :-
    http_read_json_dict(Request, Dict, []),
    http_log('~w, ~p~n', [activity(post), params(Dict)]),
    ( _{output: Output, taskToken: TaskToken} :< Dict
      -> Result = success,
         atom_json_dict(OutputText, Output, []),
         http_log('~w, ~p~n', [activity(post(Result)),
                               output_text(OutputText)])
      ; ( _{error: Error, cause: Cause, taskToken: TaskToken} :< Dict
          -> Result = failure,
             atom_json_dict(OutputText, _{error: Error, cause: Cause}, []),
             http_log('~w, ~p~n', [activity(post(Result)),
                               output_text(OutputText)])
          ; http_header:status_number(bad_request, S_400),
            throw((_{error: 'InvalidOutput'}, S_400))
        )
    ),
    ( memberchk(path_info(Activity), Request)
      -> http_log('~w, ~p~n', [activity(post),
                               (Activity, TaskToken, Result, OutputText)]),
         mq_utils:activity_end(Activity, TaskToken, Result, OutputText),
         Reply = _{}
      ;  http_header:status_number(bad_request, S_400),
         throw((_{error: 'Missing activity task name'}, S_400))
    ),
    reply_json_dict(Reply).

activity(patch, Request) :-
    http_read_json_dict(Request, Dict, []),
    http_log('~w, ~p~n', [activity(patch), params(Dict)]),
    ( _{taskToken: TaskToken} :< Dict
      -> true
      ; http_header:status_number(bad_request, S_400),
        throw((_{error: 'InvalidToken'}, S_400))
    ),
    ( memberchk(path_info(Activity), Request)
      -> mq_utils:activity_heartbeat(Activity, TaskToken),
         Reply = _{}
      ;  http_header:status_number(bad_request, S_400),
         throw((_{error: 'Missing activity task name'}, S_400))
    ),
    reply_json_dict(Reply).

%% $ curl -sLX GET localhost:8080/faas
%% $ curl -sLX GET localhost:8080/faas/{actionName}
:- http_handler('/faas/', faas, [methods([get]), prefix,
                                 authentication(openwhisk)]).

faas(Request) :-
    http_log('~w~n', [request(Request)]),
    option(namespace(nil), Request)
    -> reply_json_dict(_{error: 'Authentication Failure'}, [status(401)])
    ;  memberchk(method(Method), Request),
       catch( faas(Method, Request),
              (Message, Code),
              ( http_log('~w~n', [catch((Message, Code))]),
                reply_json_dict(Message, [status(Code)])
              )).

faas(get, Request) :-
    option(api_key(ID-PW), Request),
    wsk_api_utils:openwhisk(Defaults),
    merge_options([api_key(ID-PW)], Defaults, Options),
    ( memberchk(path_info(Action), Request)
      -> %% Fully-Qualified Action Name
         option(namespace(NS), Request),
         atomics_to_string(["/", NS, "/", Action], FQAN),
         wsk_api_actions:list(FQAN, Options, Reply)
      ;  wsk_api_actions:list(none, Options, Reply)
    ),
    reply_json_dict(Reply).

%%    GET: get statemachine information
%%    PUT: create statemachine
%%   POST: execute statemachine
%% DELETE: delete statemachine
%% PATCH : create graph of statemachine
:- http_handler('/statemachine/', statemachine,
                [methods([get, put, post, delete, patch]), prefix,
                 authentication(openwhisk)]).

statemachine(Request) :-
    http_log('~w~n', [request(Request)]),
    option(namespace(nil), Request)
    -> reply_json_dict(_{error: 'Authentication Failure'}, [status(401)])
    ;  memberchk(method(Method), Request),
       catch( statemachine(Method, Request),
              (Message, Code),
              ( http_log('~w~n', [catch((Message, Code))]),
                reply_json_dict(Message, [status(Code)])
              )).

%% get state machine information
%% $ curl -sLX GET localhost:8080/statemachine/{statemachine}
%% $ curl -sLX GET localhost:8080/statemachine/
statemachine(get, Request) :-
    option(namespace(NS), Request),
    ( memberchk(path_info(File), Request)
      -> atomics_to_string([NS, "/", File], NSFile),
         cdb_api:doc_read(faasshell, NSFile, Code1, Dict1),
         http_log('~w~n', [doc_read(Code1)]),
         ( Code1 = 200
           -> select_dict(_{'_id':_, '_rev':_}, Dict1, Dict1Rest),
              Output = _{output:ok}.put(Dict1Rest)
           ;  throw((Dict1, Code1))
         )
      ;  format(string(Query), '["asl","~w"]',[NS]),
         uri_encoded(query_value, Query, EncordedQuery),
         cdb_api:view_read(faasshell, faas, statemachine,
                           ['?key=', EncordedQuery], Code2, Dict2),
         http_log('~w~n', [view_read(Code2, Dict2)]),
         ( Code2 = 200
           -> maplist([Row,Elm]>>(
                          _{value: [Namespace, Name]} :< Row,
                          Elm = _{namespace: Namespace, name: Name}
                      ), Dict2.rows, Value),
              Output = _{output:ok}.put(asl, Value)
           ;  throw((Dict2, Code2))
         )
    ),
    reply_json_dict(Output).

%% create state machine
%% $ curl -sX PUT localhost:8080/statemachine/{statemachine}?overwrite=true
%%        -H 'Content-Type: application/json' -d @asl.json
statemachine(put, Request) :-
    http_read_json_dict(Request, Dict, []),
    http_log('~w~n', [params(Dict)]),
    ( option(path_info(File), Request),
      option(namespace(NS), Request)
      -> atomics_to_string([NS, "/", File], NSFile),
         asl_gen:gen_dsl(Dict, Dsl),
         http_log('~w: ~w~n', [NSFile, dsl(Dsl)]),
         term_string(Dsl, DslStr),
         ( Dsl = asl(_)
           -> AslDict = _{name: File, namespace: NS, asl: Dict, dsl: DslStr},
              http_parameters(Request, [overwrite(Overwrite, [default(false)])]),
              http_log('~w~n', [overwrite(Overwrite)]),
              ( Overwrite = false
                -> cdb_api:doc_create(faasshell, NSFile, AslDict, Code, Res),
                   http_log('~w~n', [doc_create(Code, Res)])
                ;  cdb_api:doc_update(faasshell, NSFile, AslDict, Code, Res),
                   http_log('~w~n', [doc_update(Code, Res)])
              ),
              ( Code = 201
                -> Output = AslDict.put(_{output:ok, dsl: DslStr})
                ;  throw((Res, Code))
              )
           ;  http_header:status_number(server_error, S_500),
              throw((_{error: 'syntax error', reason: DslStr}, S_500))
         )
      ; http_header:status_number(bad_request, S_400),
        throw((_{error: 'Missing statemashine name'}, S_400))
    ),
    reply_json_dict(Output).

%% execute state machine
%% $ curl -sX POST localhost:8080/statemachine/{statemachine} \
%%        -H 'Content-Type: application/json' -d '{"input":{"arg":1}}'
statemachine(post, Request) :-
    ( http_read_json_dict(Request, Params, []); Params = _{input:_{}} ),
    http_log('~w~n', [params(Params)]),
    ( get_dict(input, Params, Input);
      http_header:status_number(bad_request, S_400),
      throw((_{error:'Missing input key in params'}, S_400))),
    ( memberchk(path_info(File), Request),
      option(namespace(NS), Request)
      -> atomics_to_string([NS, "/", File], NSFile),
         cdb_api:doc_read(faasshell, NSFile, Code, Dict),
         http_log('~w~n', [doc_read(File, Code)]),
         select_dict(_{'_id':_, '_rev':_}, Dict, DictRest),
         DictParams = DictRest.put(Params),
         ( Code = 200
           -> % http_log('~w~n', [dsl(Dict.Dsl)]),
              option(api_key(ID-PW), Request),
              wsk_api_utils:openwhisk(Defaults),
              merge_options([api_key(ID-PW)], Defaults, Options),
              term_string(Dsl, Dict.dsl),
              asl_run:start(Dsl, Options, Input, O),
              Output = DictParams.put(_{output:O})
           ;  throw((_{error: 'database error'}, 500))
         )
      ;  http_header:status_number(bad_request, S_400),
         throw((_{error: 'Missing statemashine name'}, S_400))
    ),
    reply_json_dict(Output).

%% delete state machine
%% $ curl -sX DELETE localhost:8080/statemachine/{statemachine}
statemachine(delete, Request) :-
    ( memberchk(path_info(File), Request),
      option(namespace(NS), Request)
      -> atomics_to_string([NS, "/", File], NSFile),
         cdb_api:doc_delete(faasshell, NSFile, Code, Res),
         http_log('~w~n', [doc_delete(Code, Res)]),
         ( Code = 200
           -> Output = _{output:ok}
           ;  throw((Res, Code))
         )
      ; http_header:status_number(bad_request, S_400),
        throw((_{error: 'Missing statemashine name'}, S_400))
    ),
    reply_json_dict(Output).

%% create graph of state machine
%% $ curl -sX PATTCH localhost:8080/statemachine/{statemachine}
statemachine(patch, Request) :-
    memberchk(path_info(File), Request),
    option(namespace(NS), Request)
    -> atomics_to_string([NS, "/", File], NSFile),
       cdb_api:doc_read(faasshell, NSFile, Code, Dict),
       http_log('~w~n', [doc_read(Code)]),
       ( Code = 200
         -> format('Content-type: text/plain~n~n'),
            asl_gen:gen_dot(Dict.asl)
         ;  throw((Dict, Code))
       )
    ; http_header:status_number(bad_request, S_400),
      throw((_{error: 'Missing statemashine name'}, S_400)).

%%    GET: get shell.dsl information
%%    PUT: create shell.dsl
%%   POST: execute shell.dsl
%% DELETE: delete shell.dsl
:- http_handler('/shell/', shell,
                [methods([get, put, post, delete]), prefix,
                 authentication(openwhisk)]).

shell(Request) :-
    http_log('~w~n', [request(Request)]),
    option(namespace(nil), Request)
    -> reply_json_dict(_{error: 'Authentication Failure'}, [status(401)])
    ;  memberchk(method(Method), Request),
       catch( shell(Method, Request),
              (Message, Code),
              ( http_log('~w~n', [catch((Message, Code))]),
                reply_json_dict(Message, [status(Code)])
              )).

%% get shell information
%% $ curl -sLX GET localhost:8080/shell/{shell.dsl}
%% $ curl -sLX GET localhost:8080/shell
shell(get, Request) :-
    option(namespace(NS), Request),
    ( memberchk(path_info(File), Request)
      -> atomics_to_string([NS, "/", File], NSFile),
         cdb_api:doc_read(faasshell, NSFile, Code1, Dict1),
         http_log('~w~n', [doc_read(Code1, Dict1)]),
         ( Code1 = 200
           -> select_dict(_{'_id':_, '_rev':_}, Dict1, Dict1Rest),
              Output = _{output:ok}.put(Dict1Rest)
           ;  throw((Dict1, Code1))
         )
      ;  format(string(Query), '["dsl","~w"]',[NS]),
         uri_encoded(query_value, Query, EncordedQuery),
         cdb_api:view_read(faasshell, faas, shell,
                           ['?key=', EncordedQuery], Code2, Dict2),
         http_log('~w~n', [view_read(Code2, Dict2)]),
         ( Code2 = 200
           -> maplist([Row,Elm]>>(
                          _{value: [Namespace, Name]} :< Row,
                          Elm = _{namespace: Namespace, name: Name}
                      ), Dict2.rows, Value),
              Output = _{output:ok}.put(dsl, Value)
           ;  throw((Dict2, Code2))
         )
    ),
    reply_json_dict(Output).

%% create shell
%% $ curl -sX PUT localhost:8080/shell/{shell.dsl}?overwrite=true \
%%        -H 'Content-Type: text/plain' -d @shell.dsl
shell(put, Request) :-
    http_read_data(Request, DslStr, [text/plain]),
    http_log('~w~n', [put(Dsl)]),
    ( memberchk(path_info(File), Request),
      option(namespace(NS), Request)
      -> ( term_string(Dsl, DslStr),
           Dsl = asl(_)
           -> atomics_to_string([NS, "/", File], NSFile),
              http_parameters(Request, [overwrite(Overwrite, [default(false)])]),
              http_log('~w~n', [overwrite(Overwrite)]),
              Dict = _{dsl: DslStr, name: File, namespace: NS},
              ( Overwrite = false
                -> cdb_api:doc_create(faasshell, NSFile, Dict, Code, Res),
                   http_log('~w~n', [doc_create(Code, Res)])
                ;  cdb_api:doc_update(faasshell, NSFile, Dict, Code, Res),
                   http_log('~w~n', [doc_update(Code, Code, Res)])
              ),
              ( Code = 201
                -> Output = Dict.put(_{output:ok})
                ;  throw((Res, Code))
              )
           ; http_header:status_number(server_error, S_500),
             throw((_{error: 'syntax error', reason: DslStr}, S_500))
         )
      ; http_header:status_number(bad_request, S_400),
        throw((_{error: 'Missing shell name'}, S_400))
    ),
    reply_json_dict(Output).

%% execute shell
%% $ curl -sX POST localhost:8080/shell/{shell.dsl} \
%%        -H 'Content-Type: application/json' -d '{"input":{"arg":1}}'
shell(post, Request) :-
    ( http_read_json_dict(Request, Params, []); Params = _{input:_{}} ),
    http_log('~w~n', [params(Params)]),
    ( get_dict(input, Params, Input);
      http_header:status_number(bad_request, S_400),
      throw((_{error: 'Missing input key in params'}, S_400))),
    ( memberchk(path_info(File), Request),
      option(namespace(NS), Request)
      -> atomics_to_string([NS, "/", File], NSFile),
         cdb_api:doc_read(faasshell, NSFile, Code, Dict),
         http_log('~w~n', [doc_read(NSFile, Code)]),
         ( Code = 200
           -> select_dict(_{'_id':_, '_rev':_}, Dict, DictRest),
              DictParams = DictRest.put(Params),
              % http_log('~w~n', [dsl(Dsl)]),
              option(api_key(ID-PW), Request),
              wsk_api_utils:openwhisk(Defaults),
              merge_options([api_key(ID-PW)], Defaults, Options),
              term_string(Dsl, Dict.dsl),
              asl_run:start(Dsl, Options, Input, O),
              Output = DictParams.put(_{output:O})
           ;  throw((Dict, Code))
         )
      ; http_header:status_number(bad_request, S_400),
        throw((_{error: 'Missing shell name'}, S_400))
    ),
    reply_json_dict(Output).

%% delete shell
%% $ curl -sX DELETE localhost:8080/shell/{shell.dsl}
shell(delete, Request) :-
    ( memberchk(path_info(File), Request),
      option(namespace(NS), Request)
      -> atomics_to_string([NS, "/", File], NSFile),
         cdb_api:doc_delete(faasshell, NSFile, Code, Res),
         http_log('~w~n', [doc_delete(NSFile, Code, Res)]),
         ( Code = 200
           -> Output = _{output:ok}
           ;  throw((Res, Code))
         )
      ; http_header:status_number(bad_request, S_400),
        throw((_{error: 'Missing shell name'}, S_400))
    ),
    reply_json_dict(Output).

/*******************************
 *   PLUGIN FOR HTTP_DISPATCH   *
 *******************************/
:- multifile
http:authenticate/3.

:- use_module(library(debug)).

%% $ swipl -q -l src/asl_svc.pl -g asl_svc:debug_auth -g main -t halt
debug_auth :- debug(http_authenticate > user_error).

%%
:- dynamic
       cached_auth/4. % cached_auth(User, Password, Id, Time)

http:authenticate(openwhisk, Request, [api_key(User-Password), namespace(Id)]) :-
    memberchk(authorization(Text), Request),
    debug(http_authenticate, 'Authorization: ~w~n', [Text]),
    http_authorization_data(Text, basic(User, PasswordCode)),
    atom_codes(Password, PasswordCode),
    debug(http_authenticate, 'User: ~w, Password: ~s~n', [User, Password]),
    ( cached_auth(User, Password, Id, Time),
      get_time(Now),
      Now-Time =< 60
      -> debug(http_authenticate, 'Hit Cache: ~w, ~w~n', [User, Time]),
         http_log('Subject(cache): ~w, ~w~n', [User, Time]),
         true
      ;  ( retract(cached_auth(User, Password, Id, Time))
           -> debug(http_authenticate, 'retracted cache: ~w, ~w~n', [User, Time])
           ;  debug(http_authenticate, 'cache not exist: ~w, ~w~n', [User, Time]),
              true
         ),
         format(string(Query), '["~w","~w"]',[User, Password]),
         uri_encoded(query_value, Query, EncodedQuery),
         cdb_api:db_env(DBOptions),
         option(subject_db(SubjectDB), DBOptions),
         cdb_api:view_read(SubjectDB, subjects, identities,
                           ['?key=', EncodedQuery], Code, Dict),
         debug(http_authenticate, 'view_read: ~w~n', [Dict]),
         length(Dict.rows, RowsLen),
         ( Code = 200, RowsLen = 1
           -> [Row0] = Dict.rows,
              debug(http_authenticate, 'Subject: ~w~n Row0: ~w~n', [Dict, Row0]),
              atom_string(User, UserStr),
              atom_string(Password, PasswordStr),
              _{id:IdStr, key:[UserStr,PasswordStr], value:_} :< Row0,
              atom_string(Id, IdStr),
              get_time(Updated),
              assertz(cached_auth(User, Password, Id, Updated)),
              http_log('Subject(refresh): ~w, ~w-~w~n', [User, Time, Updated])
           ;  http_log('Authentication failed: ~w~n', [Dict]),
              Id = nil
         )
    ).
