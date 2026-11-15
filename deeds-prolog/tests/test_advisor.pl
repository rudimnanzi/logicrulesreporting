:- prolog_load_context(directory, TestDir),
   directory_file_path(TestDir, '..', Root),
   absolute_file_name(Root, Abs),
   directory_file_path(Abs, 'load.pl', Load),
   use_module(Load).

:- use_module(library(plunit)).
:- use_module(library(deeds_schema)).
:- use_module(library(deeds_rules)).
:- use_module(library(deeds_sample)).
:- use_module(library(deeds_advisor)).
:- use_module(library(deeds_config)).
:- use_module(library(lists)).
:- use_module(library(filesex)).

:- dynamic test_db_file/1.

fresh_db :-
    tmp_file(deeds_adv, File),
    asserta(test_db_file(File)),
    setup_deeds_fresh(File).

close_db :-
    detach_deeds_db,
    (   retract(test_db_file(File))
    ->  ignore(catch(delete_file(File), _, true))
    ;   true
    ).

has_code(Findings, Code) :-
    memberchk(finding(_, Code, _, _, _, _), Findings).

has_code_on(Findings, Code, Subject) :-
    memberchk(finding(_, Code, Subject, _, _, _), Findings).

:- begin_tests(advisor).

test(sample_outstanding_bonds, [setup((fresh_db, load_sample)), cleanup(close_db)]) :-
    advise_property(prop_claremont_123, Findings),
    has_code(Findings, outstanding_bonds).

test(sample_stale_bond, [setup((fresh_db, load_sample)), cleanup(close_db)]) :-
    advise_property(prop_sandton_2001, Findings),
    has_code(Findings, stale_bond),
    has_code(Findings, outstanding_bonds).

test(sample_price_jump, [setup((fresh_db, load_sample)), cleanup(close_db)]) :-
    advise_property(prop_observatory_12, Findings),
    has_code(Findings, unusual_price_jump).

test(sample_owner_missing_id, [setup((fresh_db, load_sample)), cleanup(close_db)]) :-
    advise_property(prop_seapoint_ss7, Findings),
    has_code(Findings, owner_missing_identifier).

test(sample_no_title, [setup((fresh_db, load_sample)), cleanup(close_db)]) :-
    advise_property(prop_orphan_erf_1, Findings),
    has_code(Findings, no_registered_title).

test(sample_broken_chain, [setup((fresh_db, load_sample)), cleanup(close_db)]) :-
    advise_property(prop_broken_chain, Findings),
    has_code(Findings, broken_title_chain),
    has_code(Findings, multiple_current_titles).

test(sample_servitude_noted, [setup((fresh_db, load_sample)), cleanup(close_db)]) :-
    advise_property(prop_weltevreden_78, Findings),
    has_code(Findings, servitude_noted),
    \+ has_code(Findings, outstanding_bonds).

test(clean_parktown_has_no_alerts, [setup((fresh_db, load_sample)), cleanup(close_db)]) :-
    advise_property(prop_parktown_789, Findings),
    \+ memberchk(finding(critical, _, _, _, _, _), Findings),
    \+ memberchk(finding(warning, _, _, _, _, _), Findings).

test(registry_includes_seeded_problems, [setup((fresh_db, load_sample)), cleanup(close_db)]) :-
    advise_registry(Findings),
    has_code_on(Findings, outstanding_bonds, prop_claremont_123),
    has_code_on(Findings, stale_bond, prop_sandton_2001),
    has_code_on(Findings, unusual_price_jump, prop_observatory_12),
    has_code_on(Findings, owner_missing_identifier, prop_seapoint_ss7),
    has_code_on(Findings, no_registered_title, prop_orphan_erf_1),
    has_code_on(Findings, broken_title_chain, prop_broken_chain),
    has_code(Findings, party_missing_identifier).

test(recommendations_are_nonempty, [setup((fresh_db, load_sample)), cleanup(close_db)]) :-
    advise_property(prop_claremont_123, Findings),
    forall(member(finding(_, _, _, Title, Msg, Rec), Findings),
           (   atom_length(Title, TLen), TLen > 0,
               atom_length(Msg, MLen), MLen > 0,
               atom_length(Rec, RLen), RLen > 10
           )).

test(ai_disabled_without_key, [setup(fresh_db), cleanup(close_db)]) :-
    \+ ai_configured,
    ask_ai_advice(registry, [], ai_disabled).

test(reset_demo_reloads_sample, [setup(fresh_db), cleanup(close_db)]) :-
    load_sample,
    register_party(extra, natural, 'Extra Person', 'FID-X', ok),
    party(extra, _, _, _),
    reset_demo,
    \+ party(extra, _, _, _),
    party(siya, _, _, _),
    property(prop_orphan_erf_1, _, _, _).

:- end_tests(advisor).
