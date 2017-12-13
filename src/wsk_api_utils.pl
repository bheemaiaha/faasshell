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

:- module(wsk_api_utils,
          [ openwhisk/1,
            api_url/4,
            api_action_name/3,
            term_json_dict/2
         ]).

:- use_module(wsk_api_dcg).

:- use_module(library(http/json)).

api_key(Key, ID, PW) :-
    split_string(Key, ':', "", [ID, PW]).

openwhisk(Options) :-
    %% prerequisite
    %% $ export $(grep AUTH ~/.wskprops)
    %% $ export $(grep APIHOST ~/.wskprops)
    getenv('AUTH',Key),
    api_key(Key, ID, PW),
    ( getenv('APIHOST',URL)
      -> ( re_match("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", URL)
           -> PROTOCOL = https,
              HOST = URL,
              PORT = 443
           ;  parse_url(URL, Attributes),
              option(protocol(PROTOCOL), Attributes),
              option(host(HOST), Attributes),
              default_port(PROTOCOL, DEFAULT_PORT),
              option(port(PORT), Attributes, DEFAULT_PORT)
         )
      ; ( getenv('NGINX_SERVICE_HOST', H),
          getenv('NGINX_SERVICE_PORT_HTTPS_API', P)
          -> PROTOCOL = https,
             atom_string(H, HOST),
             atom_number(P, PORT)
          ; throw(error(unknown_api_host, _))
        )
    ),
    Options = [
        api_key(ID, PW),
        api_host(HOST),
        protocol(PROTOCOL),
        port(PORT)
    ].

default_port(http, 80).
default_port(https, 443).

api_scheme(http).
api_scheme(https).

api_host(HostName) :- string(HostName).

api_port(Port) :- number(Port).

api_version("v1").

api_url(ApiHost, Gen, URL, Options) :-
    phrase(Gen, [_|Path]),
    option(protocol(Protocol), Options, https),
    api_scheme(Protocol),
    option(port(Port), Options, 443),
    api_port(Port),
    api_version(Ver),
    append([Protocol, "://", ApiHost, ":", Port, "/api/", Ver], Path, URLList),
    atomics_to_string(URLList, URL).

api_action_name(none, default, none).
api_action_name(Action, NS, ActionName) :-
    split_string(Action, "/", "", ["", NS | AN])
    -> (length(AN, 0), ActionName = none;
        atomics_to_string(AN, "/", ActionName))
    ; ActionName = Action,
      NS = default.

term_json_dict(Term, Dict) :-
    ground(Term), !,
    atom_json_term(Atom, Term, []), atom_json_dict(Atom, Dict, []).
term_json_dict(Term, Dict) :-
    atom_json_dict(Atom, Dict, []), atom_json_term(Atom, Term, []).
