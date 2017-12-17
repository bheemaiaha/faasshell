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
%% Functional Tests
%%
:- begin_tests(hello_task).

test(put, Output = "ok") :-
    load_json('samples/asl/hello_task_asl.json', Term),
    api_host(Host),
    string_concat(Host, '/statemachine/', URL),
    http_put(URL, json(Term), Data, []),
    term_json_dict(Data, Dict),
    get_dict(output, Dict, Output).

test(get, Output = "hello_task_asl.json") :-
    api_host(Host),
    string_concat(Host, '/statemachine/hello_task_asl.json', URL),
    http_get(URL, Data, []),
    term_json_dict(Data, Dict),
    get_dict(name, Dict, Output).

test(post, Output = "Hello, FaaS Shell!") :-
    api_host(Host),
    string_concat(Host, '/statemachine/hello_task_asl.json', URL),
    http_post(URL, json(json([])), Data, []),
    term_json_dict(Data, Dict),
    get_dict(payload, Dict.output, Output).

test(post, Output = "Hello, Curl!") :-
    api_host(Host),
    string_concat(Host, '/statemachine/hello_task_asl.json', URL),
    http_post(URL, json(json(['input'=json(['name'='Curl'])])), Data, []),
    term_json_dict(Data, Dict),
    get_dict(payload, Dict.output, Output).

test(patch, Output = "digraph graph_name {") :-
    api_host(Host),
    string_concat(Host, '/statemachine/hello_task_asl.json', URL),
    http_patch(URL, atom(''), Data, []),
    split_string(Data, "\n", "", [Output|_]).

test(delete, Output = "ok") :-
    api_host(Host),
    string_concat(Host, '/statemachine/hello_task_asl.json', URL),
    http_delete(URL, Data, []),
    term_json_dict(Data, Dict),
    get_dict(output, Dict, Output).

:- end_tests(hello_task).