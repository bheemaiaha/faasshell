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

%% Utils
api_host('http://127.0.0.1:8080').
%%api_host('http://172.17.0.1:8080').

load_json(File, Term) :-
    open(File, read, S),
    call_cleanup(
            json_read(S, Term, []),
            close(S)).

term_json_dict(Term, Dict) :-
    atom_json_term(Atom, Term, []), atom_json_dict(Atom, Dict, []).