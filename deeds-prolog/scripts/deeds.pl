#!/usr/bin/env swipl
:- initialization(main, main).

:- prolog_load_context(directory, Dir),
   directory_file_path(Dir, '..', Root),
   absolute_file_name(Root, Abs),
   directory_file_path(Abs, 'load.pl', Load),
   use_module(Load).

:- use_module(library(deeds_cli)).

main(_Args) :-
    setup_deeds,
    cli_main.
