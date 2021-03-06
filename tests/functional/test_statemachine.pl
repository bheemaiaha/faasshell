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

:- use_module(library(plunit)).

:- use_module(library(http/http_open)).
:- use_module(library(http/http_client)).

:- use_module(library(http/json)).
:- use_module(library(http/json_convert)).
:- use_module(library(http/http_json)).

:- include('functional_test_utils.pl').

%%
%% Functional Tests for common
%%
:- begin_tests(choice_invalid_path).

test(put_overwrite_true, Code = 200) :-
    load_json('samples/common/asl/choice_invalid_path.json', Term),
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/choice_invalid_path.json?overwrite=true',
                  URL),
    http_put(URL, json(Term), Data,
             [authorization(basic(ID, PW)), cert_verify_hook(cert_accept_any),
              status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(_{output: "ok", name: "choice_invalid_path.json",
                namespace: "demo", dsl: _, asl: _} = Dict).

test(foo, Code = 500) :-
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/choice_invalid_path.json?blocking=true',
                  URL),
    term_json_dict(Json, _{input: _{}}),
    http_post(URL, json(Json), Data,
              [authorization(basic(ID, PW)), cert_verify_hook(cert_accept_any),
               status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(
            _{error: "States.Runtime",
              cause :"existence_error(key,foo)"} :< Dict).

test(bar, Code = 500) :-
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/choice_invalid_path.json?blocking=true',
                  URL),
    term_json_dict(Json, _{input: _{foo: 3}}),
    http_post(URL, json(Json), Data,
              [authorization(basic(ID, PW)), cert_verify_hook(cert_accept_any),
               status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(
            _{error: "States.Runtime",
              cause: "existence_error(key,bar)"} :< Dict).

test(delete, Code = 200) :-
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/choice_invalid_path.json', URL),
    http_delete(URL, Data, [authorization(basic(ID, PW)),
                            cert_verify_hook(cert_accept_any), status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(_{output: "ok"} :< Dict).

:- end_tests(choice_invalid_path).

:- begin_tests(hello_all_seq,
               [setup((faasshell_api_host(Host), faasshell_api_key(ID-PW),
                       string_concat(Host,
                                     '/statemachine/hello_all_seq.json',
                                     URL),
                       http_delete(URL, _Data, [authorization(basic(ID, PW)),
                                                cert_verify_hook(cert_accept_any),
                                                status_code(_Code)])))]).

test(put_overwrite_true, Code = 200) :-
    load_json('samples/common/asl/hello_all_seq.json', Term),
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/hello_all_seq.json?overwrite=true',
                  URL),
    http_put(URL, json(Term), Data,
             [authorization(basic(ID, PW)), cert_verify_hook(cert_accept_any),
              status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(_{output: "ok", name: "hello_all_seq.json",
                namespace: "demo", dsl: _, asl: _} = Dict).

test(get, Code = 200) :-
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/hello_all_seq.json', URL),
    http_get(URL, Data, [authorization(basic(ID, PW)),
                         cert_verify_hook(cert_accept_any), status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(_{output: "ok", name: "hello_all_seq.json",
                namespace: "demo", dsl: _, asl: _} :< Dict).

test(post, Code = 200) :-
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/hello_all_seq.json?blocking=true', URL),
    term_json_dict(Json, _{input: _{name: "FaaS Shell"}}),
    http_post(URL, json(Json), Data,
              [authorization(basic(ID, PW)), cert_verify_hook(cert_accept_any),
               status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(
      _{asl: _, dsl: _, input: _{name:"FaaS Shell"}, name: _, namespace: _,
        output: _{ name: "FaaS Shell",
                   gcp: _{payload: "Hello, FaaS Shell!"},
                   bluemix: _{payload: "Hello, FaaS Shell!"},
                   azure: _{payload: "Hello, FaaS Shell!"},
                   aws: _{payload: "Hello, FaaS Shell!"}
                 }
       } :< Dict).

test(delete, Code = 200) :-
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/hello_all_seq.json', URL),
    http_delete(URL, Data, [authorization(basic(ID, PW)),
                            cert_verify_hook(cert_accept_any), status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(_{output: "ok"} :< Dict).

:- end_tests(hello_all_seq).

:- begin_tests(hello_all_par,
               [setup((faasshell_api_host(Host), faasshell_api_key(ID-PW),
                       string_concat(Host,
                                     '/statemachine/hello_all_par.json',
                                     URL),
                       http_delete(URL, _Data, [authorization(basic(ID, PW)),
                                                cert_verify_hook(cert_accept_any),
                                                status_code(_Code)])))]).

test(put_overwrite_true, Code = 200) :-
    load_json('samples/common/asl/hello_all_par.json', Term),
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/hello_all_par.json?overwrite=true',
                  URL),
    http_put(URL, json(Term), Data,
             [authorization(basic(ID, PW)), cert_verify_hook(cert_accept_any),
              status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(_{output: "ok", name: "hello_all_par.json",
                namespace: "demo", dsl: _, asl: _} = Dict).

test(get, Code = 200) :-
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/hello_all_par.json', URL),
    http_get(URL, Data, [authorization(basic(ID, PW)),
                         cert_verify_hook(cert_accept_any), status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(_{output: "ok", name: "hello_all_par.json",
                namespace: "demo", dsl: _, asl: _} :< Dict).

test(post, Code = 200) :-
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/hello_all_par.json?blocking=true', URL),
    term_json_dict(Json, _{input: _{name: "Parallel FaaS Shell"}}),
    http_post(URL, json(Json), Data,
              [authorization(basic(ID, PW)), cert_verify_hook(cert_accept_any),
               status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(
      _{asl: _, dsl: _, input: _{name:"Parallel FaaS Shell"}, name: _, namespace: _,
        output: [ _{aws: _{payload:"Hello, Parallel FaaS Shell!"}},
                  _{gcp: _{payload:"Hello, Parallel FaaS Shell!"}},
                  _{azure: _{payload:"Hello, Parallel FaaS Shell!"}},
                  _{bluemix: _{payload:"Hello, Parallel FaaS Shell!"}}
                ]
       } :< Dict).

test(delete, Code = 200) :-
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/hello_all_par.json', URL),
    http_delete(URL, Data, [authorization(basic(ID, PW)),
                            cert_verify_hook(cert_accept_any), status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(_{output: "ok"} :< Dict).

:- end_tests(hello_all_par).

%%
%% Functional Tests for Resource URI
%%
:- begin_tests(hello_world_task_uri,
               [setup((faasshell_api_host(Host), faasshell_api_key(ID-PW),
                       string_concat(Host,
                                     '/statemachine/hello_world_task.json',
                                     URL),
                       http_delete(URL, _Data, [authorization(basic(ID, PW)),
                                                cert_verify_hook(cert_accept_any),
                                                status_code(_Code)])))]).

test(put_overwrite_true, Code = 200) :-
    load_json('samples/common/asl/hello_world_task.json', Term),
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/hello_world_task.json?overwrite=true',
                  URL),
    http_put(URL, json(Term), Data,
             [authorization(basic(ID, PW)), cert_verify_hook(cert_accept_any),
              status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(_{output: "ok", name: "hello_world_task.json",
                namespace: "demo", dsl: _, asl: _} = Dict).

test(get, Code = 200) :-
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/hello_world_task.json', URL),
    http_get(URL, Data, [authorization(basic(ID, PW)),
                         cert_verify_hook(cert_accept_any), status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(_{output: "ok", name: "hello_world_task.json",
                namespace: "demo", dsl: _, asl: _} :< Dict).

test(post, Code = 200) :-
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/hello_world_task.json?blocking=true', URL),
    term_json_dict(Json, _{input: _{name: "Statemachine"}}),
    http_post(URL, json(Json), Data,
              [authorization(basic(ID, PW)), cert_verify_hook(cert_accept_any),
               status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(_{asl: _, dsl: _, input: _{name:"Statemachine"}, name: _,
                namespace: _, output: _{payload:"Hello, Statemachine!"}} :< Dict).

test(post_empty_input, Code = 200) :-
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/hello_world_task.json?blocking=true', URL),
    term_json_dict(Json, _{input: _{}}),
    http_post(URL, json(Json), Data,
              [authorization(basic(ID, PW)), cert_verify_hook(cert_accept_any),
               status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(_{asl: _, dsl: _, input: _{}, name: _, namespace: _,
                output: _{payload:"Hello, World!"}} :< Dict).

test(delete, Code = 200) :-
    faasshell_api_host(Host), faasshell_api_key(ID-PW),
    string_concat(Host, '/statemachine/hello_world_task.json', URL),
    http_delete(URL, Data, [authorization(basic(ID, PW)),
                            cert_verify_hook(cert_accept_any), status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(_{output: "ok"} :< Dict).

:- end_tests(hello_world_task_uri).
