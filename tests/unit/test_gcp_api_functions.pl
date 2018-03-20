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

:- include('../../src/gcp_api_functions.pl').

%%
%% Unit Tests
%%
:- use_module(library(plunit)).


:- begin_tests(list).

test(all, Code = 200) :-
    gcp_api_functions:faas:list([], [status_code(Code)], R),
    assertion(is_list(R)).

test(hello, Code = 200) :-
    gcp_api_functions:faas:list(
      'grn:gcp:lambda:us-central1:glowing-program-196406:cloudfunctions.net:hello',
      [status_code(Code)], R),
    assertion(
      "projects/glowing-program-196406/locations/us-central1/functions/hello"
      = R.name).

:- end_tests(list).

:- begin_tests(invoke).

test(hello_noarg, (Code, R) = (200, _{payload:"Hello, World!"})) :-
    gcp_api_functions:faas:invoke(
      'grn:gcp:lambda:us-central1:glowing-program-196406:cloudfunctions.net:hello',
          [status_code(Code)], _{}, R).

test(hello_arg, (Code, R) = (200, _{payload:"Hello, GCP!"})) :-
    gcp_api_functions:faas:invoke(
      'grn:gcp:lambda:us-central1:glowing-program-196406:cloudfunctions.net:hello',
          [status_code(Code)], _{name: "GCP"}, R).

%% should not be error such as AWS, Azure
test(hello_badarg, (Code, R) = (400, _{cause:status_code(400),
                                    error:'Bad Request\n'})) :-
    gcp_api_functions:faas:invoke(
      'grn:gcp:lambda:us-central1:glowing-program-196406:cloudfunctions.net:hello',
          [status_code(Code)], '', R).

:- end_tests(invoke).
