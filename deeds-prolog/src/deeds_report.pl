:- module(deeds_report, [
    print_banner/0,
    print_parties/0,
    print_properties/0,
    print_current_owner/1,
    print_title_chain/1,
    print_bonds/1,
    print_owned_by/1,
    print_deed_search/1,
    print_encumbrances/1,
    print_result/1,
    consideration_text/2
]).

:- use_module(library(deeds_schema)).
:- use_module(library(deeds_rules)).

print_banner :-
    writeln('==========================================================='),
    writeln('  Deeds Office Register — prototype (South Africa)'),
    writeln('  All parties, properties and deeds are fictional.'),
    writeln('===========================================================').

print_parties :-
    writeln('Parties'),
    writeln('-------'),
    forall(party(Id, Kind, Name, Ident),
           ( party_label(Id, Label),
             format('  ~w~n    kind=~w  name=~w  identifier=~w~n',
                    [Label, Kind, Name, Ident]) )),
    nl.

print_properties :-
    writeln('Properties'),
    writeln('----------'),
    forall(property(Id, Kind, Desc, Details),
           ( format('  ~w (~w)~n    ~w~n    details: ~q~n',
                    [Id, Kind, Desc, Details]) )),
    nl.

print_current_owner(Prop) :-
    property_label(Prop, PLabel),
    format('Current owner of ~w~n', [PLabel]),
    (   current_owner(Prop, Owner),
        current_title(Prop, Deed)
    ->  party_label(Owner, OLabel),
        format('  ~w~n  under title ~w~n', [OLabel, Deed])
    ;   writeln('  (no registered title)')
    ),
    nl.

print_title_chain(Prop) :-
    property_label(Prop, PLabel),
    format('Title chain for ~w~n', [PLabel]),
    (   title_chain(Prop, Chain)
    ->  print_chain_rows(Chain, 1)
    ;   writeln('  (no titles registered)')
    ),
    nl.

print_chain_rows([], _).
print_chain_rows([title(Deed, _, Owner, Date, Prev, Cons)|Rest], N) :-
    party_label(Owner, OLabel),
    consideration_text(Cons, CText),
    format('  ~d. ~w  dated ~w~n     owner: ~w~n     previous deed: ~w~n     consideration: ~w~n',
           [N, Deed, Date, OLabel, Prev, CText]),
    N2 is N + 1,
    print_chain_rows(Rest, N2).

consideration_text(grant, 'grant (first registration)') :- !.
consideration_text(rands(N), Text) :-
    format_money(N, Text), !.
consideration_text(Other, Text) :-
    format(atom(Text), '~q', [Other]).

print_bonds(Prop) :-
    property_label(Prop, PLabel),
    format('Active mortgage bonds over ~w~n', [PLabel]),
    is_bonded(Prop, Bonds),
    (   Bonds == []
    ->  writeln('  none (property is not bonded)')
    ;   forall(member(bond(No, _, Deed, Bank, Mortgagor, Amt, Date), Bonds),
               ( format_money(Amt, Money),
                 party_label(Mortgagor, MLabel),
                 format('  ~w  dated ~w~n     mortgagee: ~w~n     mortgagor: ~w~n     amount: ~w~n     passed over title ~w~n',
                        [No, Date, Bank, MLabel, Money, Deed]) ))
    ),
    nl.

print_owned_by(Party) :-
    party_label(Party, Label),
    format('Properties currently owned by ~w~n', [Label]),
    properties_owned_by(Party, List),
    (   List == []
    ->  writeln('  none')
    ;   forall(member(Prop, List),
               ( property_label(Prop, PLabel),
                 current_title(Prop, Deed),
                 format('  ~w  (current title ~w)~n', [PLabel, Deed]) ))
    ),
    nl.

print_deed_search(DeedNo) :-
    format('Deed search: ~w~n', [DeedNo]),
    (   deed_search(DeedNo, Record)
    ->  print_deed_record(Record)
    ;   writeln('  no deed, bond or servitude found with that number')
    ),
    nl.

print_deed_record(title_history(Deed, Prop, Owner, Date, Prev, Cons, NextInfo, Bonds)) :-
    property_label(Prop, PLabel),
    party_label(Owner, OLabel),
    consideration_text(Cons, CText),
    format('  Title deed ~w~n', [Deed]),
    format('  property:      ~w~n', [PLabel]),
    format('  registered to: ~w~n', [OLabel]),
    format('  date:          ~w~n', [Date]),
    format('  previous deed: ~w~n', [Prev]),
    format('  consideration: ~w~n', [CText]),
    print_next_info(NextInfo),
    (   Bonds == []
    ->  writeln('  bonds passed over this title: none recorded')
    ;   format('  bonds passed over this title: ~w~n', [Bonds])
    ).
print_deed_record(bond_history(Deed, Prop, Title, Bank, Mortgagor, Amt, Date, Status)) :-
    property_label(Prop, PLabel),
    party_label(Mortgagor, MLabel),
    format_money(Amt, Money),
    format('  Mortgage bond ~w~n', [Deed]),
    format('  property:   ~w~n', [PLabel]),
    format('  title:      ~w~n', [Title]),
    format('  mortgagee:  ~w~n', [Bank]),
    format('  mortgagor:  ~w~n', [MLabel]),
    format('  amount:     ~w~n', [Money]),
    format('  registered: ~w~n', [Date]),
    print_bond_status(Status).
print_deed_record(servitude_history(Deed, Prop, Type, Fav, Date, Desc)) :-
    property_label(Prop, PLabel),
    format('  Notarial deed of servitude ~w~n', [Deed]),
    format('  property:     ~w~n', [PLabel]),
    format('  type:         ~w~n', [Type]),
    format('  in favour of: ~w~n', [Fav]),
    format('  date:         ~w~n', [Date]),
    format('  description:  ~w~n', [Desc]).

print_next_info(current) :-
    writeln('  status:       current title (end of chain)').
print_next_info(next(Next, NextDate)) :-
    format('  later transferred by ~w on ~w~n', [Next, NextDate]).

print_bond_status(active) :-
    writeln('  status:     ACTIVE').
print_bond_status(cancelled(Date, Note)) :-
    format('  status:     CANCELLED on ~w (~w)~n', [Date, Note]).

print_encumbrances(Prop) :-
    property_label(Prop, PLabel),
    format('Encumbrance summary for ~w~n', [PLabel]),
    encumbrance_summary(Prop, encumbrances(_, Active, Cancelled, Servitudes)),
    writeln('  Active mortgage bonds:'),
    (   Active == []
    ->  writeln('    none')
    ;   forall(member(bond(No, _, Deed, Bank, _, Amt, Date), Active),
               ( format_money(Amt, Money),
                 format('    ~w  ~w  ~w  (registered ~w over ~w)~n',
                        [No, Bank, Money, Date, Deed]) ))
    ),
    writeln('  Cancelled mortgage bonds:'),
    (   Cancelled == []
    ->  writeln('    none')
    ;   forall(member(cancelled_bond(No, _, Bank, _, Amt, BondDate, CDate), Cancelled),
               ( format_money(Amt, Money),
                 format('    ~w  ~w  ~w  (registered ~w, cancelled ~w)~n',
                        [No, Bank, Money, BondDate, CDate]) ))
    ),
    writeln('  Servitudes:'),
    (   Servitudes == []
    ->  writeln('    none')
    ;   forall(member(servitude(No, _, Type, Fav, Date, _), Servitudes),
               format('    ~w  ~w in favour of ~w (registered ~w)~n',
                      [No, Type, Fav, Date]))
    ),
    nl.

print_result(ok) :-
    writeln('  Result: registered successfully.').
print_result(error(Reason)) :-
    error_message(error(Reason), Msg),
    format('  Result: REJECTED~n  ~w~n', [Msg]).
