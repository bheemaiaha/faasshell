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
:- begin_tests(faas).

test(normal, Code = 200) :-
    api_host(Host), api_key(ID-PW),
    string_concat(Host, '/faas/', URL),
    http_get(URL, Data, [authorization(basic(ID, PW)), status_code(Code)]),
    term_json_dict(Data, List),
    assertion(is_list(List)).

test(auth_error, Code = 401) :-
    api_host(Host),
    string_concat(Host, '/faas/', URL),
    http_get(URL, Data, [authorization(basic(unknown, ng)), status_code(Code)]),
    term_json_dict(Data, Dict),
    assertion(_{error: "Authentication Failure"} = Dict).

:- end_tests(faas).