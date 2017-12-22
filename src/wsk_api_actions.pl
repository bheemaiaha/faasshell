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

:- module(wsk_api_actions,
          [list/3,
           invoke/4
         ]).

:- use_module(wsk_api_dcg).
:- use_module(wsk_api_utils).
:- use_module(json_utils).

:- use_module(library(http/http_open)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_ssl_plugin)).

:- use_module(library(http/json)).
:- use_module(library(http/json_convert)).
:- use_module(library(http/http_json)).

list(Action, Options, Reply) :-
    wsk_api_utils:api_action_name(Action, NS, ActionName),
    option(api_host(HostName), Options),
    option(query(Query), Options, []),
    wsk_api_utils:api_url(HostName, 
                          wsk_api_dcg:path(get, NS, actions, ActionName, Query),
                          URL, Options),
    option(api_key(ID, PW), Options),
    option(timeout(Timeout), Options, infinite),
    http_get(URL, R1,
             [%% status_code(_Code),
              timeout(Timeout),
              authorization(basic(ID, PW)),
              cert_verify_hook(cert_accept_any)]),
    json_utils:term_json_dict(R1, Reply).

invoke(Action, Options, Payload, Reply) :-
    wsk_api_utils:api_action_name(Action, NS, ActionName),
    option(api_host(HostName), Options),
    option(query(Query), Options, [blocking=true,result=true]),
    wsk_api_utils:api_url(HostName, 
                          wsk_api_dcg:path(post, NS, actions, ActionName, Query),
                          URL, Options),
    option(api_key(ID, PW), Options),
    option(timeout(Timeout), Options, infinite),
    json_utils:term_json_dict(Json, Payload),
    http_post(URL, json(Json), R1,
              [%% status_code(_Code),
               timeout(Timeout),
               authorization(basic(ID, PW)),
               cert_verify_hook(cert_accept_any)]),
    json_utils:term_json_dict(R1, Reply).
