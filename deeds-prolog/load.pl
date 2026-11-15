:- module(deeds_load, [
    project_root/1,
    setup_deeds/0,
    setup_deeds/1,
    setup_deeds_fresh/1
]).

:- use_module(library(filesex)).

:- dynamic stored_root/1.

% Record the project root and add src/ to the library path *before*
% the use_module directives that follow.
:- prolog_load_context(directory, Root),
   retractall(stored_root(_)),
   assertz(stored_root(Root)),
   directory_file_path(Root, src, Src),
   (   user:file_search_path(library, Src)
   ->  true
   ;   asserta(user:file_search_path(library, Src))
   ).

:- use_module(library(deeds_schema)).
:- use_module(library(deeds_rules)).
:- use_module(library(deeds_sample)).
:- use_module(library(deeds_report)).
:- use_module(library(deeds_cli)).
:- use_module(library(deeds_config)).
:- use_module(library(deeds_advisor)).
:- use_module(library(deeds_http)).

%! project_root(-Root) is det.
project_root(Root) :-
    stored_root(Root).

%! setup_deeds is det.
%  Attach data/deeds.db and load sample data if the register is empty.
setup_deeds :-
    project_root(Root),
    directory_file_path(Root, 'data/deeds.db', DB),
    setup_deeds(DB).

%! setup_deeds(+DBFile) is det.
setup_deeds(DBFile) :-
    attach_deeds_db(DBFile),
    load_sample.

%! setup_deeds_fresh(+DBFile) is det.
%  Attach a journal file without loading the sample register.
setup_deeds_fresh(DBFile) :-
    attach_deeds_db(DBFile).
