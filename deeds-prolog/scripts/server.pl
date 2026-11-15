#!/usr/bin/env swipl
:- initialization(main, main).

:- prolog_load_context(directory, Dir),
   directory_file_path(Dir, '..', Root),
   absolute_file_name(Root, Abs),
   directory_file_path(Abs, 'load.pl', Load),
   use_module(Load).

:- use_module(library(deeds_http)).

main(Args) :-
    setup_deeds,
    port_from(Args, Port),
    (   memberchk('--no-browser', Args)
    ->  Browser = false
    ;   Browser = true
    ),
    start_http_server(Port, [browser(Browser)]),
    thread_get_message(_).

port_from(Args, Port) :-
    (   append(_, ['--port', PAtom | _], Args),
        atom_number(PAtom, Port)
    ->  true
    ;   member(Arg, Args),
        atom_concat('--port=', PAtom, Arg),
        atom_number(PAtom, Port)
    ->  true
    ;   getenv('DEEDS_PORT', PS),
        atom_number(PS, Port)
    ->  true
    ;   Port = 8080
    ).
