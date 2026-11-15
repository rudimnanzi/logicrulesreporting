:- module(deeds_sample, [
    load_sample/0,
    sample_loaded/0,
    reset_demo/0
]).

:- use_module(library(deeds_rules)).
:- use_module(library(deeds_schema)).

%! sample_loaded is semidet.
%  True once the expanded (v2) fictional register is present.
sample_loaded :-
    party(siya, _, _, _).

%! load_sample is det.
%  Idempotent: loads the fictional prototype register once.
load_sample :-
    sample_loaded, !.
load_sample :-
    load_parties,
    load_properties,
    load_titles_transfers_bonds,
    seed_irregular.

%! reset_demo is det.
%  Wipe the attached journal and reload the fictional sample register.
reset_demo :-
    (   attached_db_file(File)
    ->  true
    ;   throw(error(deeds(no_db_attached), _))
    ),
    detach_deeds_db,
    catch(delete_file(File), _, true),
    attach_deeds_db(File),
    load_sample.

must_ok(Goal) :-
    call(Goal, Result),
    (   Result == ok
    ->  true
    ;   throw(error(sample_load_failed(Goal, Result), _))
    ).

load_parties :-
    must_ok(register_party(thabo, natural,
                           'Thabo Mokoena',
                           'Fictional ID 850101 5800 186')),
    must_ok(register_party(lerato, natural,
                           'Lerato Dlamini',
                           'Fictional ID 900212 0510 083')),
    must_ok(register_party(pieter, natural,
                           'Pieter van der Merwe',
                           'Fictional ID 760608 5040 081')),
    must_ok(register_party(ayesha, natural,
                           'Ayesha Khan',
                           'Fictional ID 880914 0123 085')),
    must_ok(register_party(tm_holdings, company,
                           'Table Mountain Holdings (Pty) Ltd',
                           '2018/445566/07')),
    must_ok(register_party(mokoena_trust, trust,
                           'The Mokoena Family Trust',
                           'IT 412/2018 (Cape Town Master)')),
    must_ok(register_party(siya, natural,
                           'Siya Nkosi',
                           'Fictional ID 920503 5080 087')),
    must_ok(register_party(nomsa, natural,
                           'Nomsa Khumalo',
                           'Fictional ID 850818 0120 081')),
    must_ok(register_party(isabel, natural,
                           'Isabel Ferreira',
                           'Fictional ID 781111 0045 089')),
    must_ok(register_party(jordan, natural,
                           'Jordan Patel',
                           'Fictional ID 930227 5066 083')),
    must_ok(register_party(karoo_estates, company,
                           'Karoo Estates (Pty) Ltd',
                           '2016/778899/07')),
    must_ok(register_party(naidoo_trust, trust,
                           'The Naidoo Family Trust',
                           'IT 88/2014 (Pretoria Master)')),
    % Seeded problem: natural person recorded without an identifier.
    must_ok(register_party(botha, natural,
                           'Johan Botha',
                           '')).

load_properties :-
    must_ok(register_property(prop_claremont_123, erf,
        'Erf 123 Claremont, City of Cape Town, Western Cape',
        erf('123', 'Claremont', 'City of Cape Town', 'Western Cape', 714))),
    must_ok(register_property(prop_stellenbosch_456, erf,
        'Erf 456 Stellenbosch, Stellenbosch Municipality, Western Cape',
        erf('456', 'Stellenbosch', 'Stellenbosch Municipality', 'Western Cape', 1024))),
    must_ok(register_property(prop_weltevreden_78, farm,
        'Remaining Extent of the farm Weltevreden No. 78, Paarl Division, Western Cape',
        farm('Weltevreden', 78, remainder, 'Paarl Division', 'Western Cape', '45,20 ha'))),
    must_ok(register_property(prop_harbour_ss12, sectional,
        'Section 12 SS Harbour View, Scheme No. 88/2019, Cape Town, Western Cape',
        sectional(12, 'Harbour View', 'SS 88/2019', 'City of Cape Town', 'Western Cape', 68))),
    must_ok(register_property(prop_parktown_789, erf,
        'Erf 789 Parktown, City of Johannesburg, Gauteng',
        erf('789', 'Parktown', 'City of Johannesburg', 'Gauteng', 991))),
    must_ok(register_property(prop_rondebosch_55, erf,
        'Erf 55 Rondebosch, City of Cape Town, Western Cape',
        erf('55', 'Rondebosch', 'City of Cape Town', 'Western Cape', 892))),
    must_ok(register_property(prop_observatory_12, erf,
        'Erf 12 Observatory, City of Cape Town, Western Cape',
        erf('12', 'Observatory', 'City of Cape Town', 'Western Cape', 240))),
    must_ok(register_property(prop_sandton_2001, erf,
        'Erf 2001 Sandton, City of Johannesburg, Gauteng',
        erf('2001', 'Sandton', 'City of Johannesburg', 'Gauteng', 1450))),
    must_ok(register_property(prop_durban_88, erf,
        'Erf 88 Durban North, eThekwini, KwaZulu-Natal',
        erf('88', 'Durban North', 'eThekwini', 'KwaZulu-Natal', 1010))),
    must_ok(register_property(prop_knysna_farm_12, farm,
        'Remaining Extent of the farm Langeberg No. 12, Knysna Division, Western Cape',
        farm('Langeberg', 12, remainder, 'Knysna Division', 'Western Cape', '128,40 ha'))),
    must_ok(register_property(prop_paarl_ss3, sectional,
        'Section 3 SS Paarl Vineyards, Scheme No. 14/2018, Paarl, Western Cape',
        sectional(3, 'Paarl Vineyards', 'SS 14/2018', 'Drakenstein', 'Western Cape', 86))),
    must_ok(register_property(prop_pretoria_410, erf,
        'Erf 410 Waterkloof, City of Tshwane, Gauteng',
        erf('410', 'Waterkloof', 'City of Tshwane', 'Gauteng', 1488))),
    must_ok(register_property(prop_seapoint_ss7, sectional,
        'Section 7 SS Atlantic Heights, Scheme No. 3/2016, Sea Point, Western Cape',
        sectional(7, 'Atlantic Heights', 'SS 3/2016', 'City of Cape Town', 'Western Cape', 54))),
    must_ok(register_property(prop_orphan_erf_1, erf,
        'Erf 1 Phantom Township, City of Cape Town, Western Cape',
        erf('1', 'Phantom Township', 'City of Cape Town', 'Western Cape', 500))),
    must_ok(register_property(prop_broken_chain, erf,
        'Erf 99 Anomaly Township, City of Cape Town, Western Cape',
        erf('99', 'Anomaly Township', 'City of Cape Town', 'Western Cape', 612))).

load_titles_transfers_bonds :-
    % Erf 123 Claremont: Thabo -> Lerato, bond still open (blocks transfer).
    must_ok(register_first_title('T1001/2018', prop_claremont_123, thabo,
                                 '2018-03-15', grant)),
    must_ok(register_transfer('T4521/2021', prop_claremont_123, thabo, lerato,
                              '2021-06-18', 2150000)),
    must_ok(register_bond('B2100/2021', prop_claremont_123,
                          'Atlantic Commercial Bank Limited', 1500000, '2021-06-18')),

    % Erf 456 Stellenbosch: Pieter -> Table Mountain Holdings, bond open.
    must_ok(register_first_title('T2100/2019', prop_stellenbosch_456, pieter,
                                 '2019-01-10', grant)),
    must_ok(register_transfer('T7800/2023', prop_stellenbosch_456, pieter, tm_holdings,
                              '2023-09-02', 5400000)),
    must_ok(register_bond('B3300/2023', prop_stellenbosch_456,
                          'Highveld Bank Limited', 3200000, '2023-09-02')),

    % Farm Weltevreden: trust, bond cancelled, right-of-way servitude.
    must_ok(register_first_title('T0800/2015', prop_weltevreden_78, mokoena_trust,
                                 '2015-11-20', grant)),
    must_ok(register_bond('B1500/2016', prop_weltevreden_78,
                          'Coastal Mutual Bank Limited', 4000000, '2016-02-01')),
    must_ok(cancel_bond('B1500/2016', '2020-08-12')),
    must_ok(register_servitude('K400/2018S', prop_weltevreden_78,
                               'right of way',
                               'the Remaining Extent of the farm Langhoek No. 79 (fictional neighbouring farm)',
                               '2018-05-30',
                               '6 metre right of way along the southern boundary, for access to the public road')),

    % Section 12 Harbour View: Ayesha, bond open.
    must_ok(register_first_title('ST1200/2020', prop_harbour_ss12, ayesha,
                                 '2020-04-07', rands(1850000))),
    must_ok(register_bond('B2500/2020', prop_harbour_ss12,
                          'Karoo National Bank Limited', 1200000, '2020-04-07')),

    % Erf 789 Parktown: Thabo -> Pieter (bonded, later cancelled) -> Ayesha.
    must_ok(register_first_title('T3000/2017', prop_parktown_789, thabo,
                                 '2017-05-22', grant)),
    must_ok(register_transfer('T6100/2020', prop_parktown_789, thabo, pieter,
                              '2020-11-03', 3000000)),
    must_ok(register_bond('B2800/2020', prop_parktown_789,
                          'Atlantic Commercial Bank Limited', 2000000, '2020-11-03')),
    must_ok(cancel_bond('B2800/2020', '2024-02-01')),
    must_ok(register_transfer('T9100/2024', prop_parktown_789, pieter, ayesha,
                              '2024-02-15', 3750000)),

    % Erf 55 Rondebosch: Siya -> Nomsa, clean and unencumbered.
    must_ok(register_first_title('T4001/2019', prop_rondebosch_55, siya,
                                 '2019-05-08', grant)),
    must_ok(register_transfer('T4002/2023', prop_rondebosch_55, siya, nomsa,
                              '2023-04-21', 2800000)),

    % Erf 12 Observatory: unusual price jump (seeded advisor flag).
    must_ok(register_first_title('T5100/2022', prop_observatory_12, isabel,
                                 '2022-02-14', rands(800000))),
    must_ok(register_transfer('T5101/2023', prop_observatory_12, isabel, jordan,
                              '2023-01-20', 4500000)),

    % Erf 2001 Sandton: stale bond still open since 2012 (seeded advisor flag).
    must_ok(register_first_title('T2200/2011', prop_sandton_2001, pieter,
                                 '2011-08-30', grant)),
    must_ok(register_bond('B800/2012', prop_sandton_2001,
                          'Drakensberg Bank Limited', 1800000, '2012-03-15')),

    % Erf 88 Durban North: recent first registration, clean.
    must_ok(register_first_title('T6300/2024', prop_durban_88, isabel,
                                 '2024-08-19', rands(1950000))),

    % Farm Langeberg: company, active bond and a pipeline servitude.
    must_ok(register_first_title('T1100/2016', prop_knysna_farm_12, karoo_estates,
                                 '2016-06-10', grant)),
    must_ok(register_bond('B900/2017', prop_knysna_farm_12,
                          'Garden Route Bank Limited', 6000000, '2017-02-28')),
    must_ok(register_servitude('K210/2019S', prop_knysna_farm_12,
                               'pipeline',
                               'the fictional Garden Route Water Board',
                               '2019-11-04',
                               'underground water pipeline along the eastern boundary, 3 metres wide')),

    % Section 3 Paarl Vineyards: Jordan, unencumbered.
    must_ok(register_first_title('ST1400/2021', prop_paarl_ss3, jordan,
                                 '2021-09-16', rands(1200000))),

    % Erf 410 Waterkloof: Naidoo Family Trust, unencumbered.
    must_ok(register_first_title('T3500/2018', prop_pretoria_410, naidoo_trust,
                                 '2018-10-02', grant)),

    % Section 7 Atlantic Heights: Johan Botha (no identifier) — seeded problem.
    must_ok(register_first_title('ST701/2022', prop_seapoint_ss7, botha,
                                 '2022-11-11', rands(2200000))).

%! seed_irregular is det.
%  Deliberately irregular facts that the public registration API would
%  reject. Used only to give the advisor something to flag in the demo.
seed_irregular :-
    % Property with no title at all (Erf 1 Phantom Township).
    true,
    % Broken title chain on Erf 99 Anomaly Township:
    % opening title T7001/2016, later deed T7002/2019 points at a
    % previous deed that was never registered (T6999/2016).
    assert_title_deed('T7001/2016', prop_broken_chain, siya,
                      '2016-04-01', none, grant),
    assert_title_deed('T7002/2019', prop_broken_chain, nomsa,
                      '2019-07-15', 'T6999/2016', rands(2100000)).
