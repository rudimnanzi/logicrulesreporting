%% REPL entry point. Imports the public API into user and attaches
%% data/deeds.db (seeding the fictional sample on first run).
%%
%%   swipl -s repl.pl
%%   ?- current_owner(prop_claremont_123, Owner).

:- use_module('load.pl').
:- use_module(library(deeds_schema)).
:- use_module(library(deeds_rules)).
:- use_module(library(deeds_sample)).
:- use_module(library(deeds_report)).

:- initialization(repl_welcome).

repl_welcome :-
    setup_deeds,
    writeln('Deeds register attached (data/deeds.db). All sample data is fictional.'),
    writeln('Try:  current_owner(prop_claremont_123, Owner).'),
    writeln('      title_chain(prop_parktown_789, Chain).'),
    writeln('      is_bonded(prop_claremont_123, Bonds).'),
    writeln('      properties_owned_by(ayesha, List).'),
    writeln('      deed_search(\'T9100/2024\', Record).'),
    writeln('      encumbrance_summary(prop_weltevreden_78, Summary).').
