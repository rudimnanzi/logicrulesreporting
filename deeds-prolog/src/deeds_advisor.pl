:- module(deeds_advisor, [
    advise_property/2,
    advise_registry/1,
    finding_severity_rank/2,
    stale_bond_years/1,
    price_jump_ratio/1,
    ask_ai_advice/3
]).

:- use_module(library(deeds_schema)).
:- use_module(library(deeds_rules)).
:- use_module(library(deeds_config)).
:- use_module(library(lists)).
:- use_module(library(aggregate)).
:- use_module(library(http/http_open)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_json)).
:- use_module(library(http/json)).

%! stale_bond_years(-Years) is det.
stale_bond_years(8).

%! price_jump_ratio(-Ratio) is det.
%  Flag a later price that is at least this many times the earlier price
%  (or no more than 1/Ratio of it).
price_jump_ratio(2.5).

%! finding_severity_rank(+Severity, -Rank) is det.
finding_severity_rank(critical, 1).
finding_severity_rank(warning, 2).
finding_severity_rank(info, 3).

%! advise_property(+PropertyId, -Findings) is det.
%  Findings is a list of finding/6 terms, highest severity first.
advise_property(PropertyId, Findings) :-
    findall(F, property_finding(PropertyId, F), Raw),
    sort_findings(Raw, Findings).

%! advise_registry(-Findings) is det.
advise_registry(Findings) :-
    findall(F, registry_finding(F), Raw),
    sort_findings(Raw, Findings).

sort_findings(Raw, Sorted) :-
    map_list_to_pairs(finding_sort_key, Raw, Pairs),
    keysort(Pairs, SK),
    pairs_values(SK, Sorted).

finding_sort_key(finding(Sev, Code, Subject, _, _, _), Key) :-
    finding_severity_rank(Sev, Rank),
    Key = Rank-Code-Subject.

registry_finding(F) :-
    property(Prop, _, _, _),
    property_finding(Prop, F).
registry_finding(F) :-
    global_finding(F).

% ---------------------------------------------------------------------------
% Per-property rules
% ---------------------------------------------------------------------------

property_finding(Prop, F) :-
    property(Prop, _, _, _),
    \+ title_deed(_, Prop, _, _, _, _),
    property_label(Prop, Label),
    format(atom(NoTitleMsg),
           '~w is on the register but has no title deed at all, so there is no current owner in terms of the register.',
           [Label]),
    F = finding(critical, no_registered_title, Prop,
        'No registered title',
        NoTitleMsg,
        'Lodge an opening title (first registration) after confirming the correct owner and supporting documents, or remove the property if it was captured in error.').
property_finding(Prop, F) :-
    property(Prop, _, _, _),
    once(title_deed(_, Prop, _, _, _, _)),
    findall(Deed, current_title(Prop, Deed), Deeds0),
    sort(Deeds0, Deeds),
    length(Deeds, N), N > 1,
    atomic_list_concat(Deeds, ', ', Listed),
    format(atom(Msg),
           'More than one deed appears to be current (~w). The title chain is irregular and the current owner is ambiguous.',
           [Listed]),
    F = finding(critical, multiple_current_titles, Prop,
        'Irregular title chain — more than one current title',
        Msg,
        'Reconstruct the chain from the supporting deeds, correct any wrong previous-deed reference, and endorse the register so that only one title is current.').
property_finding(Prop, F) :-
    title_deed(Deed, Prop, _, Date, Prev, _),
    Prev \== none,
    \+ title_deed(Prev, _, _, _, _, _),
    format(atom(Msg),
           'Title ~w (dated ~w) refers to previous deed ~w, which is not on this register.',
           [Deed, Date, Prev]),
    F = finding(critical, broken_title_chain, Prop,
        'Broken title chain',
        Msg,
        'Trace the missing prior deed. If it exists, capture it (or correct the previous-deed number). Do not register a further transfer until the chain is continuous.').
property_finding(Prop, F) :-
    title_chain_incomplete(Prop, CountFacts, CountChain),
    format(atom(Msg),
           'The register has ~w title(s) for this property, but walking the chain from the opening title only reaches ~w. One or more deeds are detached from the main chain.',
           [CountFacts, CountChain]),
    F = finding(critical, incomplete_title_chain, Prop,
        'Title deeds detached from the main chain',
        Msg,
        'Inspect each title\'s previous-deed pointer and relink or explain any deed that does not follow from the opening title.').
property_finding(Prop, F) :-
    active_bonds(Prop, Bonds),
    Bonds \== [],
    findall(No, member(bond(No, _, _, _, _, _, _), Bonds), Nos),
    atomic_list_concat(Nos, ', ', Listed),
    format(atom(Msg),
           'Outstanding mortgage bond(s) ~w are still registered. A transfer of this property will be blocked until they are cancelled or substituted.',
           [Listed]),
    F = finding(warning, outstanding_bonds, Prop,
        'Outstanding bond blocks transfer',
        Msg,
        'Obtain a cancellation figure from the mortgagee and register a cancellation (or a substitution of debtor) before attempting a transfer.').
property_finding(Prop, F) :-
    stale_bond_years(Threshold),
    today_iso(Today),
    active_bonds(Prop, Bonds),
    member(bond(No, _, _, Bank, _, Amt, Date), Bonds),
    years_between(Date, Today, Years),
    Years >= Threshold,
    format_money(Amt, Money),
    format(atom(YAtom), '~1f', [Years]),
    format(atom(Msg),
           'Bond ~w in favour of ~w for ~w was registered on ~w (~w years ago) and is still open.',
           [No, Bank, Money, Date, YAtom]),
    F = finding(warning, stale_bond, Prop,
        'Stale mortgage bond still open',
        Msg,
        'Confirm with the mortgagee whether the debt is still alive. If it has been settled, register a cancellation so the title is not held up by a forgotten bond.').
property_finding(Prop, F) :-
    unusual_price_jump(Prop, Earlier, Later, Ratio),
    Earlier = price_point(D1, P1),
    Later   = price_point(D2, P2),
    format_money(P1, M1),
    format_money(P2, M2),
    format(atom(RAtom), '~1f', [Ratio]),
    format(atom(Msg),
           'Consideration moved from ~w under ~w to ~w under ~w (about ~wx). This is an unusually large jump and should be explained on the papers.',
           [M1, D1, M2, D2, RAtom]),
    F = finding(warning, unusual_price_jump, Prop,
        'Unusual price movement between transfers',
        Msg,
        'Check the consideration against the deed of sale, valuations and any related-party disclosure. If the figure is right, keep the working papers with the batch; if not, correct the register.').
property_finding(Prop, F) :-
    current_owner(Prop, Owner),
    party(Owner, Kind, Name, Ident),
    missing_identifier(Ident),
    kind_word(Kind, KindW),
    format(atom(Msg),
           'The current registered owner, ~w (~w, id ~w), has no identity, registration or Master\'s reference recorded.',
           [Name, KindW, Owner]),
    F = finding(warning, owner_missing_identifier, Prop,
        'Current owner has no recorded identifier',
        Msg,
        'Capture the owner\'s official identifier (identity number, company registration number, or trust Master\'s reference) before relying on this title for a transfer or bond.').
property_finding(Prop, F) :-
    active_bonds(Prop, Bonds),
    member(bond(No, _, DeedNo, _, _, _, _), Bonds),
    current_title(Prop, Current),
    Current \== DeedNo,
    format(atom(Msg),
           'Active bond ~w is passed over title ~w, which is no longer the current title (~w). An active bond should normally sit on the current title.',
           [No, DeedNo, Current]),
    F = finding(warning, bond_on_non_current_title, Prop,
        'Active bond is not on the current title',
        Msg,
        'Check whether a transfer slipped through without a cancellation or substitution, and correct the endorsements.').
property_finding(Prop, F) :-
    last_purchase_price(Prop, Price, Deed),
    active_bonds(Prop, Bonds),
    member(bond(No, _, _, Bank, _, Amt, _), Bonds),
    Amt > Price,
    format_money(Amt, AM),
    format_money(Price, PM),
    format(atom(Msg),
           'Bond ~w (~w, ~w) exceeds the last recorded purchase price of ~w under ~w.',
           [No, Bank, AM, PM, Deed]),
    F = finding(info, high_leverage_bond, Prop,
        'Bond amount exceeds last purchase price',
        Msg,
        'This may be in order (further advance, improvement, or a grant with no earlier price). Confirm the facility against the bond papers.').
property_finding(Prop, F) :-
    servitude(SNo, Prop, Type, Fav, Date, _),
    format(atom(Msg),
           'Servitude ~w (~w, in favour of ~w, registered ~w) remains an encumbrance on the title.',
           [SNo, Type, Fav, Date]),
    F = finding(info, servitude_noted, Prop,
        'Servitude noted on the title',
        Msg,
        'Disclose the servitude to any purchaser or mortgagee and make sure the diagram and conditions are attached to the next batch.').

% ---------------------------------------------------------------------------
% Registry-wide rules
% ---------------------------------------------------------------------------

global_finding(F) :-
    duplicate_deed_number(No, Places),
    atomic_list_concat(Places, '; ', Listed),
    format(atom(Msg),
           'Deed or bond number ~w is recorded more than once (~w). Official numbers must be unique.',
           [No, Listed]),
    F = finding(critical, duplicate_deed_number, No,
        'Duplicate official number',
        Msg,
        'Identify the incorrect entry and correct or void it. Do not issue any further deed under a number that is already in use.').
global_finding(F) :-
    party(Id, Kind, Name, Ident),
    missing_identifier(Ident),
    kind_word(Kind, KindW),
    format(atom(Msg),
           '~w (~w, id ~w) is on the party register without an official identifier.',
           [Name, KindW, Id]),
    F = finding(warning, party_missing_identifier, Id,
        'Party has no recorded identifier',
        Msg,
        'Add the identity number, company registration number, or trust Master\'s reference to this party record.').

% ---------------------------------------------------------------------------
% Helpers
% ---------------------------------------------------------------------------

missing_identifier(Ident) :-
    (   Ident == ''
    ;   Ident == '-'
    ;   Ident == '—'
    ;   Ident == unknown
    ;   Ident == 'unknown'
    ;   Ident == none
    ;   Ident == 'none'
    ;   Ident == missing
    ), !.

kind_word(Kind, Word) :-
    (   Kind == natural -> Word = 'natural person'
    ;   Kind == company -> Word = company
    ;   Kind == trust -> Word = trust
    ;   Word = Kind
    ).

title_chain_incomplete(Prop, CountFacts, CountChain) :-
    findall(D, title_deed(D, Prop, _, _, _, _), Deeds),
    Deeds \== [],
    sort(Deeds, Unique),
    length(Unique, CountFacts),
    (   title_chain(Prop, Chain)
    ->  length(Chain, CountChain)
    ;   CountChain = 0
    ),
    CountChain < CountFacts.

unusual_price_jump(Prop, Earlier, Later, Ratio) :-
    title_chain(Prop, Chain),
    priced_pairs(Chain, Points),
    append(_, [price_point(D1, P1), price_point(D2, P2)|_], Points),
    P1 > 0,
    (   P2 > P1
    ->  Ratio is P2 / P1
    ;   Ratio is P1 / P2
    ),
    price_jump_ratio(Min),
    Ratio >= Min,
    Earlier = price_point(D1, P1),
    Later   = price_point(D2, P2).

priced_pairs([], []).
priced_pairs([title(Deed, _, _, _, _, rands(N))|Rest], [price_point(Deed, N)|Out]) :-
    integer(N), N > 0, !,
    priced_pairs(Rest, Out).
priced_pairs([_|Rest], Out) :-
    priced_pairs(Rest, Out).

last_purchase_price(Prop, Price, Deed) :-
    title_chain(Prop, Chain),
    reverse(Chain, Rev),
    member(title(Deed, _, _, _, _, rands(Price)), Rev),
    integer(Price), Price > 0, !.

today_iso(Date) :-
    get_time(Stamp),
    format_time(atom(Date), '%Y-%m-%d', Stamp).

years_between(Date1, Date2, Years) :-
    date_stamp(Date1, S1),
    date_stamp(Date2, S2),
    Years is (S2 - S1) / (365.25 * 24 * 3600).

date_stamp(Date, Stamp) :-
    atomic_list_concat([YS, MS, DS], '-', Date),
    atom_number(YS, Y), atom_number(MS, M), atom_number(DS, D),
    date_time_stamp(date(Y, M, D, 0, 0, 0, 0, -, -), Stamp).

duplicate_deed_number(No, Places) :-
    findall(No-Place, official_number(No, Place), Pairs),
    group_pairs_by_key(Pairs, Grouped),
    member(No-Places, Grouped),
    length(Places, N), N > 1.

official_number(No, Place) :-
    title_deed(No, Prop, _, _, _, _),
    format(atom(Place), 'title on ~w', [Prop]).
official_number(No, Place) :-
    bond(No, Prop, _, _, _, _, _),
    format(atom(Place), 'bond on ~w', [Prop]).
official_number(No, Place) :-
    servitude(No, Prop, _, _, _, _),
    format(atom(Place), 'servitude on ~w', [Prop]).

% ---------------------------------------------------------------------------
% Optional AI hook (OpenAI-compatible chat completions)
% ---------------------------------------------------------------------------

%! ask_ai_advice(+Scope, +Findings, -Result) is det.
%  Scope is registry or property(PropertyId).
%  Result is ai_disabled, ai_ok(Text), or ai_error(Message).
ask_ai_advice(Scope, Findings, Result) :-
    (   ai_credentials(Endpoint, Model, Key)
    ->  catch(call_ai(Endpoint, Model, Key, Scope, Findings, Result),
              Error,
              ai_catch(Error, Result))
    ;   Result = ai_disabled
    ).

ai_catch(Error, ai_error(Msg)) :-
    format(atom(Msg), 'The advice service could not be reached: ~q.', [Error]).

call_ai(Endpoint, Model, Key, Scope, Findings, Result) :-
    build_ai_prompt(Scope, Findings, System, User),
    Request = _{
        model: Model,
        temperature: 0.3,
        messages: [
            _{role: system, content: System},
            _{role: user, content: User}
        ]
    },
    atom_concat('Bearer ', Key, Auth),
    setup_call_cleanup(
        http_open(Endpoint, In, [
            method(post),
            post(json(Request)),
            request_header('Authorization'=Auth),
            request_header('Content-Type'='application/json'),
            request_header('Accept'='application/json'),
            timeout(30),
            status_code(Code)
        ]),
        (   catch(json_read_dict(In, Reply, []), _, Reply = _{}),
            interpret_ai_reply(Code, Reply, Result)
        ),
        close(In)).

interpret_ai_reply(Code, Reply, Result) :-
    (   Code >= 200, Code < 300,
        get_dict(choices, Reply, [Choice|_]),
        (   get_dict(message, Choice, Msg)
        ->  get_dict(content, Msg, Text0)
        ;   get_dict(text, Choice, Text0)
        )
    ->  (   string(Text0) -> Text = Text0 ; atom_string(Text, Text0) ),
        Result = ai_ok(Text)
    ;   (   get_dict(error, Reply, Err),
            get_dict(message, Err, EMsg)
        ->  format(atom(Msg), 'Advice service returned HTTP ~w: ~w', [Code, EMsg])
        ;   format(atom(Msg), 'Advice service returned HTTP ~w.', [Code])
        ),
        Result = ai_error(Msg)
    ).

build_ai_prompt(registry, Findings, System, User) :-
    System = 'You are a cautious conveyancing advisor helping a South African deeds office prototype. Base every remark only on the facts and rule findings supplied. Do not invent deed numbers, owners, prices, or law. Write plain English. If something is uncertain, say so. Keep the answer concise (short paragraphs or bullets). This is a fictional training register.',
    findings_as_text(Findings, FText),
    registry_facts_text(Facts),
    format(string(User),
           'Registry snapshot (fictional):\n~w\n\nRule-based findings:\n~w\n\nPlease comment on the findings and suggest practical next steps. Do not repeat the findings verbatim; add judgement a senior conveyancer might offer.',
           [Facts, FText]).
build_ai_prompt(property(Prop), Findings, System, User) :-
    System = 'You are a cautious conveyancing advisor helping a South African deeds office prototype. Base every remark only on the facts and rule findings supplied. Do not invent deed numbers, owners, prices, or law. Write plain English. If something is uncertain, say so. Keep the answer concise. This is a fictional training register.',
    findings_as_text(Findings, FText),
    property_facts_text(Prop, Facts),
    format(string(User),
           'Property facts (fictional):\n~w\n\nRule-based findings:\n~w\n\nPlease comment on this title and recommend practical next steps for the examiner or conveyancer.',
           [Facts, FText]).

findings_as_text([], '(no rule findings)') :- !.
findings_as_text(Findings, Text) :-
    maplist(finding_line, Findings, Lines),
    atomic_list_concat(Lines, '\n', Text).

finding_line(finding(Sev, Code, Subject, Title, Msg, Rec), Line) :-
    format(atom(Line), '- [~w/~w] ~w (~w): ~w Recommendation: ~w',
           [Sev, Code, Title, Subject, Msg, Rec]).

property_facts_text(Prop, Text) :-
    property_label(Prop, Label),
    (   current_owner(Prop, Owner)
    ->  party_label(Owner, OLabel),
        current_title(Prop, Deed),
        format(atom(OwnerLine), 'Current owner: ~w under ~w', [OLabel, Deed])
    ;   OwnerLine = 'Current owner: none'
    ),
    (   title_chain(Prop, Chain)
    ->  maplist(title_line, Chain, TLines),
        atomic_list_concat(TLines, '\n  ', TBlock)
    ;   TBlock = '(no title chain)'
    ),
    is_bonded(Prop, Bonds),
    (   Bonds == []
    ->  BondLine = 'Active bonds: none'
    ;   maplist(bond_line, Bonds, BLines),
        atomic_list_concat(BLines, '; ', BondLine0),
        format(atom(BondLine), 'Active bonds: ~w', [BondLine0])
    ),
    format(atom(Text), '~w\n~w\nTitle chain:\n  ~w\n~w',
           [Label, OwnerLine, TBlock, BondLine]).

title_line(title(Deed, _, Owner, Date, Prev, Cons), Line) :-
    format_money(Cons, CText),
    format(atom(Line), '~w dated ~w, owner ~w, previous ~w, consideration ~w',
           [Deed, Date, Owner, Prev, CText]).

bond_line(bond(No, _, Deed, Bank, _, Amt, Date), Line) :-
    format_money(Amt, Money),
    format(atom(Line), '~w ~w ~w over ~w (registered ~w)',
           [No, Bank, Money, Deed, Date]).

registry_facts_text(Text) :-
    aggregate_all(count, property(_,_,_,_), NP),
    aggregate_all(count, party(_,_,_,_), NPa),
    aggregate_all(count, title_deed(_,_,_,_,_,_), NT),
    findall(_, (bond(B,_,_,_,_,_,_), \+ bond_cancellation(B,_,_)), Active),
    length(Active, NB),
    format(atom(Text),
           '~w properties, ~w parties, ~w title deeds, ~w active bonds.',
           [NP, NPa, NT, NB]).
