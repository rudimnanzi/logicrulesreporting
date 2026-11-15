:- module(deeds_rules, [
    register_party/5,
    register_property/5,
    register_first_title/6,
    register_transfer/7,
    register_bond/6,
    cancel_bond/3,
    register_servitude/7,
    current_owner/2,
    current_title/2,
    title_chain/2,
    is_bonded/2,
    active_bonds/2,
    properties_owned_by/2,
    deed_search/2,
    encumbrance_summary/2,
    valid_title_deed_no/1,
    valid_bond_no/1,
    valid_servitude_no/1,
    valid_date/1,
    error_message/2,
    format_money/2,
    party_label/2,
    property_label/2
]).

:- use_module(library(deeds_schema)).
:- use_module(library(pcre)).
:- use_module(library(lists)).
:- use_module(library(error)).

% ---------------------------------------------------------------------------
% Registration API. Each predicate binds Result to ok or error(Reason).
% ---------------------------------------------------------------------------

%! register_party(+Id, +Kind, +Name, +Identifier, -Result) is det.
register_party(Id, Kind, Name, Identifier, Result) :-
    (   \+ memberchk(Kind, [natural, company, trust])
    ->  Result = error(invalid_party_kind(Kind))
    ;   \+ atom(Id)
    ->  Result = error(invalid_id(Id))
    ;   party(Id, _, _, _)
    ->  Result = error(duplicate_party_id(Id))
    ;   assert_party(Id, Kind, Name, Identifier),
        Result = ok
    ).

%! register_property(+Id, +Kind, +Description, +Details, -Result) is det.
register_property(Id, Kind, Description, Details, Result) :-
    (   \+ memberchk(Kind, [erf, farm, sectional])
    ->  Result = error(invalid_property_kind(Kind))
    ;   \+ atom(Id)
    ->  Result = error(invalid_id(Id))
    ;   property(Id, _, _, _)
    ->  Result = error(duplicate_property_id(Id))
    ;   assert_property(Id, Kind, Description, Details),
        Result = ok
    ).

%! register_first_title(+DeedNo, +PropertyId, +OwnerId, +Date, +Consideration, -Result) is det.
%  Opens the title register for a property. Consideration is grant
%  or rands(Integer). Previous deed is recorded as none.
register_first_title(DeedNo, PropertyId, OwnerId, Date, Consideration, Result) :-
    (   \+ valid_title_deed_no(DeedNo)
    ->  Result = error(invalid_deed_number(DeedNo))
    ;   title_deed(DeedNo, _, _, _, _, _)
    ->  Result = error(duplicate_deed_number(DeedNo))
    ;   \+ property(PropertyId, _, _, _)
    ->  Result = error(unknown_property(PropertyId))
    ;   \+ party(OwnerId, _, _, _)
    ->  Result = error(unknown_party(OwnerId))
    ;   \+ valid_date(Date)
    ->  Result = error(invalid_date(Date))
    ;   \+ valid_consideration(Consideration)
    ->  Result = error(invalid_consideration(Consideration))
    ;   title_deed(Existing, PropertyId, _, _, _, _)
    ->  Result = error(already_has_title(PropertyId, Existing))
    ;   assert_title_deed(DeedNo, PropertyId, OwnerId, Date, none, Consideration),
        Result = ok
    ).

%! register_transfer(+DeedNo, +PropertyId, +FromId, +ToId, +Date, +Price, -Result) is det.
%  Registers a deed of transfer. The transferor must be the current
%  registered owner. Outstanding mortgage bonds block the transfer:
%  in South African practice they must be cancelled or substituted
%  before a new title can be registered.
register_transfer(DeedNo, PropertyId, FromId, ToId, Date, Price, Result) :-
    (   \+ valid_title_deed_no(DeedNo)
    ->  Result = error(invalid_deed_number(DeedNo))
    ;   title_deed(DeedNo, _, _, _, _, _)
    ->  Result = error(duplicate_deed_number(DeedNo))
    ;   bond(DeedNo, _, _, _, _, _, _)
    ->  Result = error(duplicate_deed_number(DeedNo))
    ;   \+ property(PropertyId, _, _, _)
    ->  Result = error(unknown_property(PropertyId))
    ;   \+ party(FromId, _, _, _)
    ->  Result = error(unknown_party(FromId))
    ;   \+ party(ToId, _, _, _)
    ->  Result = error(unknown_party(ToId))
    ;   FromId == ToId
    ->  Result = error(transfer_to_self(FromId))
    ;   \+ valid_date(Date)
    ->  Result = error(invalid_date(Date))
    ;   \+ (integer(Price), Price >= 0)
    ->  Result = error(invalid_price(Price))
    ;   \+ current_title(PropertyId, _)
    ->  Result = error(no_registered_title(PropertyId))
    ;   \+ current_owner(PropertyId, FromId)
    ->  current_owner(PropertyId, Actual),
        Result = error(not_current_owner(FromId, Actual))
    ;   active_bond_numbers(PropertyId, BondNos),
        BondNos \= []
    ->  Result = error(outstanding_bonds(BondNos))
    ;   transfer_date_ok(PropertyId, Date)
    ->  current_title(PropertyId, PrevDeed),
        assert_title_deed(DeedNo, PropertyId, ToId, Date, PrevDeed, rands(Price)),
        Result = ok
    ;   Result = error(date_before_current_title(Date))
    ).

%! register_bond(+BondNo, +PropertyId, +Mortgagee, +Amount, +Date, -Result) is det.
%  Registers a mortgage bond over the current title. The mortgagor is
%  the current registered owner.
register_bond(BondNo, PropertyId, Mortgagee, Amount, Date, Result) :-
    (   \+ valid_bond_no(BondNo)
    ->  Result = error(invalid_bond_number(BondNo))
    ;   bond(BondNo, _, _, _, _, _, _)
    ->  Result = error(duplicate_bond_number(BondNo))
    ;   title_deed(BondNo, _, _, _, _, _)
    ->  Result = error(duplicate_deed_number(BondNo))
    ;   \+ property(PropertyId, _, _, _)
    ->  Result = error(unknown_property(PropertyId))
    ;   \+ current_title(PropertyId, _)
    ->  Result = error(no_registered_title(PropertyId))
    ;   \+ (integer(Amount), Amount > 0)
    ->  Result = error(invalid_amount(Amount))
    ;   \+ valid_date(Date)
    ->  Result = error(invalid_date(Date))
    ;   \+ atom(Mortgagee)
    ->  Result = error(invalid_mortgagee(Mortgagee))
    ;   current_title(PropertyId, DeedNo),
        current_owner(PropertyId, Mortgagor),
        assert_bond(BondNo, PropertyId, DeedNo, Mortgagee, Mortgagor, Amount, Date),
        Result = ok
    ).

%! cancel_bond(+BondNo, +Date, -Result) is det.
cancel_bond(BondNo, Date, Result) :-
    (   \+ bond(BondNo, _, _, _, _, _, _)
    ->  Result = error(unknown_bond(BondNo))
    ;   bond_cancellation(BondNo, CancelledOn, _)
    ->  Result = error(already_cancelled(BondNo, CancelledOn))
    ;   \+ valid_date(Date)
    ->  Result = error(invalid_date(Date))
    ;   bond(BondNo, _, _, _, _, _, BondDate),
        Date @< BondDate
    ->  Result = error(date_before_bond(Date, BondDate))
    ;   assert_bond_cancellation(BondNo, Date, 'Cancellation of mortgage bond'),
        Result = ok
    ).

%! register_servitude(+DeedNo, +PropertyId, +Type, +InFavourOf, +Date, +Description, -Result) is det.
register_servitude(DeedNo, PropertyId, Type, InFavourOf, Date, Description, Result) :-
    (   \+ valid_servitude_no(DeedNo)
    ->  Result = error(invalid_servitude_number(DeedNo))
    ;   servitude(DeedNo, _, _, _, _, _)
    ->  Result = error(duplicate_deed_number(DeedNo))
    ;   \+ property(PropertyId, _, _, _)
    ->  Result = error(unknown_property(PropertyId))
    ;   \+ valid_date(Date)
    ->  Result = error(invalid_date(Date))
    ;   assert_servitude(DeedNo, PropertyId, Type, InFavourOf, Date, Description),
        Result = ok
    ).

% ---------------------------------------------------------------------------
% Queries
% ---------------------------------------------------------------------------

%! current_title(+PropertyId, -DeedNo) is semidet.
%  The current title is the deed that is not the previous deed of any
%  later transfer on the same property (end of the title chain).
current_title(PropertyId, DeedNo) :-
    title_deed(DeedNo, PropertyId, _, _, _, _),
    \+ title_deed(_, PropertyId, _, _, DeedNo, _).

%! current_owner(+PropertyId, -OwnerId) is semidet.
current_owner(PropertyId, OwnerId) :-
    current_title(PropertyId, DeedNo),
    title_deed(DeedNo, PropertyId, OwnerId, _, _, _).

%! title_chain(+PropertyId, -Chain) is semidet.
%  Chain is a chronological list of title/6 terms from the opening
%  title to the current title.
title_chain(PropertyId, Chain) :-
    property(PropertyId, _, _, _),
    opening_title(PropertyId, First),
    follow_chain(PropertyId, First, Chain).

opening_title(PropertyId, DeedNo) :-
    title_deed(DeedNo, PropertyId, _, _, none, _),
    !.
opening_title(PropertyId, DeedNo) :-
    title_deed(DeedNo, PropertyId, _, _, Prev, _),
    \+ title_deed(Prev, PropertyId, _, _, _, _).

follow_chain(PropertyId, DeedNo, [title(DeedNo, PropertyId, Owner, Date, Prev, Cons)|Rest]) :-
    title_deed(DeedNo, PropertyId, Owner, Date, Prev, Cons),
    (   title_deed(Next, PropertyId, _, _, DeedNo, _)
    ->  follow_chain(PropertyId, Next, Rest)
    ;   Rest = []
    ).

%! is_bonded(+PropertyId, -Bonds) is det.
%  Bonds is the list of active (not cancelled) bonds. Empty if free
%  of mortgage. Each element is bond/7 as stored.
is_bonded(PropertyId, Bonds) :-
    active_bonds(PropertyId, Bonds).

%! active_bonds(+PropertyId, -Bonds) is det.
active_bonds(PropertyId, Bonds) :-
    findall(bond(BondNo, PropertyId, DeedNo, Mortgagee, Mortgagor, Amount, Date),
            (   bond(BondNo, PropertyId, DeedNo, Mortgagee, Mortgagor, Amount, Date),
                \+ bond_cancellation(BondNo, _, _)
            ),
            Bonds).

active_bond_numbers(PropertyId, BondNos) :-
    active_bonds(PropertyId, Bonds),
    findall(No, member(bond(No, _, _, _, _, _, _), Bonds), BondNos).

%! properties_owned_by(+PartyId, -PropertyIds) is det.
properties_owned_by(PartyId, PropertyIds) :-
    findall(Prop, current_owner(Prop, PartyId), PropertyIds).

%! deed_search(+DeedNo, -Record) is semidet.
%  Looks up a title deed, bond (with cancellation if any), or servitude
%  by official number and returns a structured history term.
deed_search(DeedNo, Record) :-
    title_deed(DeedNo, Prop, Owner, Date, Prev, Cons),
    !,
    (   title_deed(Next, Prop, _, NextDate, DeedNo, _)
    ->  NextInfo = next(Next, NextDate)
    ;   NextInfo = current
    ),
    findall(B, bond(B, Prop, DeedNo, _, _, _, _), BondsOnDeed),
    Record = title_history(DeedNo, Prop, Owner, Date, Prev, Cons, NextInfo, BondsOnDeed).
deed_search(DeedNo, Record) :-
    bond(DeedNo, Prop, TitleDeed, Mortgagee, Mortgagor, Amount, Date),
    !,
    (   bond_cancellation(DeedNo, CDate, Note)
    ->  Status = cancelled(CDate, Note)
    ;   Status = active
    ),
    Record = bond_history(DeedNo, Prop, TitleDeed, Mortgagee, Mortgagor, Amount, Date, Status).
deed_search(DeedNo, Record) :-
    servitude(DeedNo, Prop, Type, InFavourOf, Date, Desc),
    Record = servitude_history(DeedNo, Prop, Type, InFavourOf, Date, Desc).

%! encumbrance_summary(+PropertyId, -Summary) is semidet.
encumbrance_summary(PropertyId, Summary) :-
    property(PropertyId, _, _, _),
    active_bonds(PropertyId, Active),
    findall(cancelled_bond(BondNo, DeedNo, Mortgagee, Mortgagor, Amount, BondDate, CDate),
            (   bond(BondNo, PropertyId, DeedNo, Mortgagee, Mortgagor, Amount, BondDate),
                bond_cancellation(BondNo, CDate, _)
            ),
            Cancelled),
    findall(servitude(SNo, PropertyId, Type, Fav, SDate, Desc),
            servitude(SNo, PropertyId, Type, Fav, SDate, Desc),
            Servitudes),
    Summary = encumbrances(PropertyId, Active, Cancelled, Servitudes).

% ---------------------------------------------------------------------------
% Validation helpers
% ---------------------------------------------------------------------------

%! valid_title_deed_no(+DeedNo) is semidet.
%  Conventional title: T12345/2024. Sectional title: ST1234/2024.
valid_title_deed_no(DeedNo) :-
    atom(DeedNo),
    re_match("^(T|ST)[0-9]+/[0-9]{4}$", DeedNo).

%! valid_bond_no(+BondNo) is semidet.
%  Mortgage bond: B6789/2024.
valid_bond_no(BondNo) :-
    atom(BondNo),
    re_match("^B[0-9]+/[0-9]{4}$", BondNo).

%! valid_servitude_no(+DeedNo) is semidet.
%  Notarial deed of servitude: K1234/2023S.
valid_servitude_no(DeedNo) :-
    atom(DeedNo),
    re_match("^K[0-9]+/[0-9]{4}S$", DeedNo).

%! valid_date(+Date) is semidet.
%  Strict calendar check on an ISO date atom YYYY-MM-DD.
valid_date(Date) :-
    atom(Date),
    atomic_list_concat([YS, MS, DS], '-', Date),
    atom_length(YS, 4), atom_length(MS, 2), atom_length(DS, 2),
    atom_number(YS, Y), atom_number(MS, M), atom_number(DS, D),
    integer(Y), integer(M), integer(D),
    M >= 1, M =< 12,
    days_in_month(Y, M, Max),
    D >= 1, D =< Max.

days_in_month(Y, 2, 29) :- leap_year(Y), !.
days_in_month(_, 2, 28) :- !.
days_in_month(_, M, 30) :- memberchk(M, [4, 6, 9, 11]), !.
days_in_month(_, _, 31).

leap_year(Y) :-
    (   0 =:= Y mod 400
    ;   0 =:= Y mod 4, 0 =\= Y mod 100
    ), !.

valid_consideration(grant).
valid_consideration(rands(N)) :- integer(N), N >= 0.

transfer_date_ok(PropertyId, Date) :-
    current_title(PropertyId, DeedNo),
    title_deed(DeedNo, PropertyId, _, CurrentDate, _, _),
    Date @>= CurrentDate.

% ---------------------------------------------------------------------------
% Human-readable messages and labels
% ---------------------------------------------------------------------------

error_message(error(invalid_deed_number(N)), Msg) :-
    !,
    format(atom(Msg),
           'Invalid title deed number ~w. Expected a number in the form T12345/2024 or ST1234/2024.',
           [N]).
error_message(error(invalid_bond_number(N)), Msg) :-
    !,
    format(atom(Msg),
           'Invalid bond number ~w. Expected a number in the form B6789/2024.',
           [N]).
error_message(error(invalid_servitude_number(N)), Msg) :-
    !,
    format(atom(Msg),
           'Invalid servitude number ~w. Expected a number in the form K1234/2023S.',
           [N]).
error_message(error(duplicate_deed_number(N)), Msg) :-
    !,
    format(atom(Msg), 'Deed number ~w is already registered and must be unique.', [N]).
error_message(error(duplicate_bond_number(N)), Msg) :-
    !,
    format(atom(Msg), 'Bond number ~w is already registered and must be unique.', [N]).
error_message(error(duplicate_party_id(Id)), Msg) :-
    !,
    format(atom(Msg), 'Party id ~w already exists.', [Id]).
error_message(error(duplicate_property_id(Id)), Msg) :-
    !,
    format(atom(Msg), 'Property id ~w already exists.', [Id]).
error_message(error(unknown_property(Id)), Msg) :-
    !,
    format(atom(Msg), 'Unknown property: ~w.', [Id]).
error_message(error(unknown_party(Id)), Msg) :-
    !,
    format(atom(Msg), 'Unknown party: ~w.', [Id]).
error_message(error(unknown_bond(N)), Msg) :-
    !,
    format(atom(Msg), 'Unknown bond: ~w.', [N]).
error_message(error(already_has_title(Prop, Deed)), Msg) :-
    !,
    format(atom(Msg),
           'Property ~w already has a registered title (~w). Use a transfer instead of a first-title registration.',
           [Prop, Deed]).
error_message(error(no_registered_title(Prop)), Msg) :-
    !,
    format(atom(Msg),
           'Property ~w has no registered title yet. Register a first title before a transfer or bond.',
           [Prop]).
error_message(error(not_current_owner(Given, Actual)), Msg) :-
    !,
    party_label(Given, GLabel),
    party_label(Actual, ALabel),
    format(atom(Msg),
           'Transfer is only allowed from the current registered owner. ~s is not the owner; the current registered owner is ~s.',
           [GLabel, ALabel]).
error_message(error(outstanding_bonds(BondNos)), Msg) :-
    !,
    atomic_list_concat(BondNos, ', ', Listed),
    format(atom(Msg),
           'Transfer blocked: outstanding mortgage bond(s) ~w must be cancelled or substituted before a transfer can be registered (South African deeds practice).',
           [Listed]).
error_message(error(already_cancelled(N, Date)), Msg) :-
    !,
    format(atom(Msg), 'Bond ~w was already cancelled on ~w.', [N, Date]).
error_message(error(transfer_to_self(Id)), Msg) :-
    !,
    format(atom(Msg), 'Transferor and transferee are the same party (~w).', [Id]).
error_message(error(invalid_date(D)), Msg) :-
    !,
    format(atom(Msg), 'Invalid date ~w. Use YYYY-MM-DD.', [D]).
error_message(error(invalid_price(P)), Msg) :-
    !,
    format(atom(Msg), 'Invalid price ~w. Enter a non-negative whole number of rands.', [P]).
error_message(error(invalid_amount(A)), Msg) :-
    !,
    format(atom(Msg), 'Invalid bond amount ~w. Enter a positive whole number of rands.', [A]).
error_message(error(invalid_consideration(C)), Msg) :-
    !,
    format(atom(Msg), 'Invalid consideration ~w. Use grant or rands(Amount).', [C]).
error_message(error(invalid_party_kind(K)), Msg) :-
    !,
    format(atom(Msg), 'Invalid party kind ~w. Use natural, company or trust.', [K]).
error_message(error(invalid_property_kind(K)), Msg) :-
    !,
    format(atom(Msg), 'Invalid property kind ~w. Use erf, farm or sectional.', [K]).
error_message(error(date_before_current_title(D)), Msg) :-
    !,
    format(atom(Msg), 'Transfer date ~w is earlier than the current title date.', [D]).
error_message(error(date_before_bond(D, B)), Msg) :-
    !,
    format(atom(Msg), 'Cancellation date ~w is earlier than the bond registration date ~w.', [D, B]).
error_message(error(Other), Msg) :-
    !,
    format(atom(Msg), 'Registration failed: ~q.', [Other]).

format_money(rands(N), S) :-
    !, format_money(N, S).
format_money(grant, 'grant (first registration)') :- !.
format_money(N, S) :-
    integer(N),
    format(string(Raw), '~D', [N]),
    format(string(S), 'R~w', [Raw]).

party_label(Id, Label) :-
    party(Id, Kind, Name, Ident),
    !,
    kind_label(Kind, KindL),
    format(atom(Label), '~w (~w, ~w; id ~w)', [Name, KindL, Ident, Id]).
party_label(Id, Label) :-
    format(atom(Label), '~w (unregistered)', [Id]).

kind_label(natural, 'natural person').
kind_label(company, 'company').
kind_label(trust, 'trust').

property_label(Id, Label) :-
    property(Id, Kind, Description, _),
    !,
    format(atom(Label), '~w [~w, ~w]', [Description, Kind, Id]).
property_label(Id, Label) :-
    format(atom(Label), '~w (unknown property)', [Id]).
