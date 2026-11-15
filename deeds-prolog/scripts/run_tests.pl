#!/usr/bin/env swipl
:- initialization(main, main).

:- use_module(library(filesex)).
:- use_module(library(process)).

:- dynamic stored_root/1.

:- prolog_load_context(directory, Dir),
   directory_file_path(Dir, '..', Root0),
   absolute_file_name(Root0, Root),
   retractall(stored_root(_)),
   assertz(stored_root(Root)).

main(_Args) :-
    stored_root(Root),
    directory_file_path(Root, tests, Tests),
    Files = ['test_rules.pl', 'test_advisor.pl', 'test_http.pl'],
    maplist(run_suite(Root, Tests), Files, Codes),
    (   forall(member(Code, Codes), Code =:= 0)
    ->  format('All test suites passed.~n', []),
        halt(0)
    ;   format('One or more test suites failed: ~w~n', [Codes]),
        halt(1)
    ).

run_suite(Root, Tests, File, Code) :-
    directory_file_path(Tests, File, Path),
    format('~n== ~w ==~n', [File]),
    flush_output,
    process_create(path(swipl),
                   ['-q', '-s', Path, '-g', 'run_tests,halt', '-t', 'halt(1)'],
                   [cwd(Root), process(Pid),
                    stdout(std), stderr(std)]),
    process_wait(Pid, Status),
    (   Status = exit(Code)
    ->  true
    ;   Code = 1
    ).
