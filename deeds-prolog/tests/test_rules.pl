:- prolog_load_context(directory, TestDir),
   directory_file_path(TestDir, '..', Root),
   absolute_file_name(Root, Abs),
   directory_file_path(Abs, 'load.pl', Load),
   use_module(Load).

:- use_module(library(plunit)).
:- use_module(library(deeds_schema)).
:- use_module(library(deeds_rules)).
:- use_module(library(filesex)).

:- dynamic test_db_file/1, persist_file/1.

fresh_db :-
    tmp_file(deeds_test, File),
    asserta(test_db_file(File)),
    setup_deeds_fresh(File).

close_db :-
    detach_deeds_db,
    (   retract(test_db_file(File))
    ->  ignore(catch(delete_file(File), _, true))
    ;   true
    ).

seed_basic :-
    register_party(ann, natural, 'Ann Example', 'FID-ANN', ok),
    register_party(bob, natural, 'Bob Example', 'FID-BOB', ok),
    register_party(co, company, 'Example Holdings (Pty) Ltd', '2019/000001/07', ok),
    register_property(erf1, erf, 'Erf 1 Example Township',
                      erf('1', 'Example', 'Example City', 'Western Cape', 200), ok),
    register_property(erf2, erf, 'Erf 2 Example Township',
                      erf('2', 'Example', 'Example City', 'Western Cape', 300), ok).

:- begin_tests(deed_numbers).

test(title_formats_accepted, [setup(fresh_db), cleanup(close_db)]) :-
    valid_title_deed_no('T12345/2024'),
    valid_title_deed_no('T1/1999'),
    valid_title_deed_no('ST1200/2020').

test(title_formats_rejected) :-
    \+ valid_title_deed_no('X12/24'),
    \+ valid_title_deed_no('T12/24'),
    \+ valid_title_deed_no('B1234/2024'),
    \+ valid_title_deed_no('t12345/2024'),
    \+ valid_title_deed_no('T12345/2024/1').

test(bond_formats) :-
    valid_bond_no('B6789/2024'),
    valid_bond_no('B1/2015'),
    \+ valid_bond_no('T6789/2024'),
    \+ valid_bond_no('B6789/24'),
    \+ valid_bond_no('BN6789/2024').

test(servitude_formats) :-
    valid_servitude_no('K400/2018S'),
    valid_servitude_no('K1/2023S'),
    \+ valid_servitude_no('K400/2018'),
    \+ valid_servitude_no('T400/2018S').

test(dates) :-
    valid_date('2024-02-15'),
    valid_date('2020-02-29'),
    \+ valid_date('2024-13-01'),
    \+ valid_date('2024-02-30'),
    \+ valid_date('2021-02-29'),
    \+ valid_date('24-02-15').

:- end_tests(deed_numbers).

:- begin_tests(registration).

test(first_title_and_current_owner,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    current_owner(erf1, ann),
    current_title(erf1, 'T100/2020').

test(duplicate_deed_number_rejected,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_first_title('T100/2020', erf2, bob, '2020-02-01', grant,
                         error(duplicate_deed_number('T100/2020'))).

test(invalid_deed_number_rejected,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('X12/24', erf1, ann, '2020-01-15', grant,
                         error(invalid_deed_number('X12/24'))).

test(unknown_property_rejected,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', missing, ann, '2020-01-15', grant,
                         error(unknown_property(missing))).

test(unknown_party_rejected,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ghost, '2020-01-15', grant,
                         error(unknown_party(ghost))).

test(second_first_title_rejected,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_first_title('T101/2020', erf1, bob, '2020-02-01', grant,
                         error(already_has_title(erf1, 'T100/2020'))).

test(duplicate_party_and_property,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_party(ann, natural, 'Ann Again', 'X',
                   error(duplicate_party_id(ann))),
    register_property(erf1, erf, 'dup', erf('1','A','B','C',1),
                      error(duplicate_property_id(erf1))).

test(invalid_kinds,
     [setup(fresh_db), cleanup(close_db)]) :-
    register_party(x, goblin, 'X', 'Y', error(invalid_party_kind(goblin))),
    register_property(p, castle, 'P', none, error(invalid_property_kind(castle))).

:- end_tests(registration).

:- begin_tests(transfers).

test(transfer_from_current_owner_succeeds,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_transfer('T200/2021', erf1, ann, bob, '2021-06-01', 1000000, ok),
    current_owner(erf1, bob),
    current_title(erf1, 'T200/2021').

test(title_chain_is_chronological,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_transfer('T200/2021', erf1, ann, bob, '2021-06-01', 1000000, ok),
    register_transfer('T300/2022', erf1, bob, co, '2022-03-10', 1500000, ok),
    title_chain(erf1, Chain),
    Chain = [
        title('T100/2020', erf1, ann, '2020-01-15', none, grant),
        title('T200/2021', erf1, bob, '2021-06-01', 'T100/2020', rands(1000000)),
        title('T300/2022', erf1, co,  '2022-03-10', 'T200/2021', rands(1500000))
    ].

test(transfer_from_non_owner_rejected,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_transfer('T200/2021', erf1, bob, co, '2021-06-01', 1000000, Result),
    Result = error(not_current_owner(bob, ann)),
    current_owner(erf1, ann).

test(transfer_without_title_rejected,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_transfer('T200/2021', erf1, ann, bob, '2021-06-01', 1000000,
                      error(no_registered_title(erf1))).

test(transfer_blocked_by_outstanding_bond,
     [setup((fresh_db, seed_basic)), cleanup(close_db), nondet]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_bond('B10/2020', erf1, 'Example Bank Ltd', 500000, '2020-01-20', ok),
    register_transfer('T200/2021', erf1, ann, bob, '2021-06-01', 1000000, Result),
    Result = error(outstanding_bonds(['B10/2020'])),
    current_owner(erf1, ann),
    error_message(Result, Msg),
    sub_atom(Msg, _, _, _, 'Transfer blocked'),
    sub_atom(Msg, _, _, _, 'B10/2020'),
    sub_atom(Msg, _, _, _, 'cancelled or substituted').

test(transfer_after_cancellation_succeeds,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_bond('B10/2020', erf1, 'Example Bank Ltd', 500000, '2020-01-20', ok),
    cancel_bond('B10/2020', '2021-05-01', ok),
    register_transfer('T200/2021', erf1, ann, bob, '2021-06-01', 1000000, ok),
    current_owner(erf1, bob).

test(transfer_to_self_rejected,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_transfer('T200/2021', erf1, ann, ann, '2021-06-01', 1,
                      error(transfer_to_self(ann))).

test(transfer_date_before_current_title,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-06-01', grant, ok),
    register_transfer('T200/2021', erf1, ann, bob, '2020-01-01', 1000000,
                      error(date_before_current_title('2020-01-01'))).

test(invalid_price,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_transfer('T200/2021', erf1, ann, bob, '2021-06-01', -5,
                      error(invalid_price(-5))).

:- end_tests(transfers).

:- begin_tests(bonds).

test(bond_and_is_bonded,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_bond('B10/2020', erf1, 'Example Bank Ltd', 500000, '2020-01-20', ok),
    is_bonded(erf1, Bonds),
    Bonds = [bond('B10/2020', erf1, 'T100/2020', 'Example Bank Ltd', ann, 500000, '2020-01-20')].

test(duplicate_bond_number,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_first_title('T200/2020', erf2, bob, '2020-02-01', grant, ok),
    register_bond('B10/2020', erf1, 'Example Bank Ltd', 500000, '2020-01-20', ok),
    register_bond('B10/2020', erf2, 'Other Bank', 100, '2020-02-02',
                  error(duplicate_bond_number('B10/2020'))).

test(invalid_bond_number,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_bond('T10/2020', erf1, 'Example Bank Ltd', 500000, '2020-01-20',
                  error(invalid_bond_number('T10/2020'))).

test(cancel_unknown_bond,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    cancel_bond('B10/2020', '2021-01-01', error(unknown_bond('B10/2020'))).

test(cancel_already_cancelled,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_bond('B10/2020', erf1, 'Example Bank Ltd', 500000, '2020-01-20', ok),
    cancel_bond('B10/2020', '2021-01-01', ok),
    cancel_bond('B10/2020', '2021-06-01',
                error(already_cancelled('B10/2020', '2021-01-01'))).

test(is_bonded_empty_after_cancellation,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_bond('B10/2020', erf1, 'Example Bank Ltd', 500000, '2020-01-20', ok),
    cancel_bond('B10/2020', '2021-01-01', ok),
    is_bonded(erf1, []).

test(bond_without_title,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_bond('B10/2020', erf1, 'Example Bank Ltd', 500000, '2020-01-20',
                  error(no_registered_title(erf1))).

test(cancellation_before_bond_date,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_bond('B10/2020', erf1, 'Example Bank Ltd', 500000, '2020-06-01', ok),
    cancel_bond('B10/2020', '2020-01-01',
                error(date_before_bond('2020-01-01', '2020-06-01'))).

:- end_tests(bonds).

:- begin_tests(queries).

test(properties_owned_by,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_first_title('T200/2020', erf2, ann, '2020-02-01', grant, ok),
    register_transfer('T201/2021', erf2, ann, bob, '2021-01-01', 10, ok),
    properties_owned_by(ann, Owned),
    Owned = [erf1],
    properties_owned_by(bob, [erf2]),
    properties_owned_by(co, []).

test(deed_search_title_and_bond,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_bond('B10/2020', erf1, 'Example Bank Ltd', 500000, '2020-01-20', ok),
    cancel_bond('B10/2020', '2021-01-01', ok),
    deed_search('T100/2020', TitleRec),
    TitleRec = title_history('T100/2020', erf1, ann, '2020-01-15', none, grant, current, ['B10/2020']),
    deed_search('B10/2020', BondRec),
    BondRec = bond_history('B10/2020', erf1, 'T100/2020', 'Example Bank Ltd',
                           ann, 500000, '2020-01-20',
                           cancelled('2021-01-01', 'Cancellation of mortgage bond')).

test(deed_search_missing,
     [setup(fresh_db), cleanup(close_db)]) :-
    \+ deed_search('T999/2024', _).

test(encumbrance_summary,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    register_bond('B10/2020', erf1, 'Old Bank', 100, '2020-01-20', ok),
    cancel_bond('B10/2020', '2021-01-01', ok),
    register_bond('B11/2021', erf1, 'New Bank', 200, '2021-02-01', ok),
    register_servitude('K1/2021S', erf1, 'right of way', 'neighbour',
                       '2021-03-01', 'path', ok),
    encumbrance_summary(erf1, encumbrances(erf1, Active, Cancelled, Servs)),
    Active = [bond('B11/2021', erf1, 'T100/2020', 'New Bank', ann, 200, '2021-02-01')],
    Cancelled = [cancelled_bond('B10/2020', 'T100/2020', 'Old Bank', ann, 100,
                                '2020-01-20', '2021-01-01')],
    Servs = [servitude('K1/2021S', erf1, 'right of way', 'neighbour',
                       '2021-03-01', 'path')].

test(deed_search_servitude,
     [setup((fresh_db, seed_basic)), cleanup(close_db)]) :-
    register_property(farm1, farm, 'Farm Example',
                      farm('Example', 1, remainder, 'Paarl', 'Western Cape', '1 ha'), ok),
    register_first_title('T50/2010', farm1, co, '2010-01-01', grant, ok),
    register_servitude('K9/2011S', farm1, 'pipeline', 'municipality',
                       '2011-04-01', 'water pipe', ok),
    deed_search('K9/2011S',
                servitude_history('K9/2011S', farm1, 'pipeline',
                                  'municipality', '2011-04-01', 'water pipe')).

:- end_tests(queries).

:- begin_tests(persistence).

test(records_survive_reopen, [cleanup(cleanup_persist)]) :-
    tmp_file(deeds_persist, File),
    asserta(persist_file(File)),
    setup_deeds_fresh(File),
    register_party(ann, natural, 'Ann Example', 'FID-ANN', ok),
    register_property(erf1, erf, 'Erf 1',
                      erf('1', 'Twp', 'City', 'Western Cape', 200), ok),
    register_first_title('T100/2020', erf1, ann, '2020-01-15', grant, ok),
    detach_deeds_db,
    setup_deeds_fresh(File),
    current_owner(erf1, ann),
    party(ann, natural, 'Ann Example', 'FID-ANN'),
    title_deed('T100/2020', erf1, ann, '2020-01-15', none, grant).

cleanup_persist :-
    detach_deeds_db,
    (   retract(persist_file(File))
    ->  ignore(catch(delete_file(File), _, true))
    ;   true
    ).

:- end_tests(persistence).
