:- module(deeds_cli, [cli_main/0]).

:- use_module(library(deeds_schema)).
:- use_module(library(deeds_rules)).
:- use_module(library(deeds_sample)).
:- use_module(library(deeds_report)).
:- use_module(library(readutil)).

cli_main :-
    print_banner,
    nl,
    menu_loop.

menu_loop :-
    print_menu,
    prompt_line('Choice', Choice),
    (   handle_choice(Choice)
    ->  (   Choice = '0'
        ->  true
        ;   nl, menu_loop
        )
    ;   writeln('Please enter a number from the menu.'),
        nl, menu_loop
    ).

print_menu :-
    writeln('---------------------------'),
    writeln(' 1  Register a party'),
    writeln(' 2  Register a property'),
    writeln(' 3  Register a first title (opening grant)'),
    writeln(' 4  Register a transfer'),
    writeln(' 5  Register a mortgage bond'),
    writeln(' 6  Cancel a mortgage bond'),
    writeln(' 7  Register a servitude'),
    writeln(' 8  Query current owner'),
    writeln(' 9  Query title chain'),
    writeln('10  Query active bonds (is_bonded)'),
    writeln('11  Properties owned by a party'),
    writeln('12  Search by deed / bond number'),
    writeln('13  Encumbrance summary'),
    writeln('14  List all parties'),
    writeln('15  List all properties'),
    writeln(' 0  Exit'),
    writeln('---------------------------').

handle_choice('0') :-
    writeln('Closing the register. Goodbye.'),
    detach_deeds_db.
handle_choice('1') :- cli_register_party.
handle_choice('2') :- cli_register_property.
handle_choice('3') :- cli_first_title.
handle_choice('4') :- cli_transfer.
handle_choice('5') :- cli_bond.
handle_choice('6') :- cli_cancel.
handle_choice('7') :- cli_servitude.
handle_choice('8') :-
    prompt_atom('Property id', Prop),
    nl, print_current_owner(Prop).
handle_choice('9') :-
    prompt_atom('Property id', Prop),
    nl, print_title_chain(Prop).
handle_choice('10') :-
    prompt_atom('Property id', Prop),
    nl, print_bonds(Prop).
handle_choice('11') :-
    prompt_atom('Party id', Party),
    nl, print_owned_by(Party).
handle_choice('12') :-
    prompt_atom('Deed or bond number', Deed),
    nl, print_deed_search(Deed).
handle_choice('13') :-
    prompt_atom('Property id', Prop),
    nl, print_encumbrances(Prop).
handle_choice('14') :- nl, print_parties.
handle_choice('15') :- nl, print_properties.

cli_register_party :-
    prompt_atom('Party id (atom, e.g. siya)', Id),
    prompt_atom('Kind (natural/company/trust)', Kind),
    prompt_atom('Full name', Name),
    prompt_atom('Identifier (ID no. / company no. / trust ref.)', Ident),
    register_party(Id, Kind, Name, Ident, Result),
    print_result(Result).

cli_register_property :-
    prompt_atom('Property id (atom, e.g. prop_erf_10)', Id),
    prompt_atom('Kind (erf/farm/sectional)', Kind),
    prompt_atom('Short description', Desc),
    prompt_details(Kind, Details),
    register_property(Id, Kind, Desc, Details, Result),
    print_result(Result).

prompt_details(erf, erf(No, Twp, Mun, Prov, Extent)) :-
    prompt_atom('Erf number', No),
    prompt_atom('Township', Twp),
    prompt_atom('Municipality / city', Mun),
    prompt_atom('Province', Prov),
    prompt_integer('Extent in square metres', Extent), !.
prompt_details(farm, farm(Name, No, Portion, Div, Prov, Extent)) :-
    prompt_atom('Farm name', Name),
    prompt_integer('Farm number', No),
    prompt_atom('Portion (e.g. remainder or 3)', Portion),
    prompt_atom('Registration division', Div),
    prompt_atom('Province', Prov),
    prompt_atom('Extent (e.g. 12,34 ha)', Extent), !.
prompt_details(sectional, sectional(Sec, Scheme, SchemeNo, Mun, Prov, Extent)) :-
    prompt_integer('Section number', Sec),
    prompt_atom('Scheme name', Scheme),
    prompt_atom('Scheme number (e.g. SS 88/2019)', SchemeNo),
    prompt_atom('Municipality / city', Mun),
    prompt_atom('Province', Prov),
    prompt_integer('Extent in square metres', Extent), !.
prompt_details(_, notes(Text)) :-
    prompt_atom('Free-text details', Text).

cli_first_title :-
    prompt_atom('New title deed number (e.g. T12345/2024)', Deed),
    prompt_atom('Property id', Prop),
    prompt_atom('Owner party id', Owner),
    prompt_atom('Date (YYYY-MM-DD)', Date),
    prompt_atom('Consideration (grant, or a rand amount)', Raw),
    parse_consideration(Raw, Cons),
    register_first_title(Deed, Prop, Owner, Date, Cons, Result),
    print_result(Result).

cli_transfer :-
    prompt_atom('New title deed number (e.g. T12345/2024)', Deed),
    prompt_atom('Property id', Prop),
    prompt_atom('Transferor (current owner) party id', From),
    prompt_atom('Transferee party id', To),
    prompt_atom('Date (YYYY-MM-DD)', Date),
    prompt_integer('Price in rands (whole number, no spaces)', Price),
    register_transfer(Deed, Prop, From, To, Date, Price, Result),
    print_result(Result).

cli_bond :-
    prompt_atom('Bond number (e.g. B6789/2024)', BondNo),
    prompt_atom('Property id', Prop),
    prompt_atom('Mortgagee (bank name)', Bank),
    prompt_integer('Amount in rands', Amount),
    prompt_atom('Date (YYYY-MM-DD)', Date),
    register_bond(BondNo, Prop, Bank, Amount, Date, Result),
    print_result(Result).

cli_cancel :-
    prompt_atom('Bond number', BondNo),
    prompt_atom('Cancellation date (YYYY-MM-DD)', Date),
    cancel_bond(BondNo, Date, Result),
    print_result(Result).

cli_servitude :-
    prompt_atom('Servitude number (e.g. K1234/2023S)', Deed),
    prompt_atom('Property id (servient tenement)', Prop),
    prompt_atom('Type (e.g. right of way)', Type),
    prompt_atom('In favour of', Fav),
    prompt_atom('Date (YYYY-MM-DD)', Date),
    prompt_atom('Description', Desc),
    register_servitude(Deed, Prop, Type, Fav, Date, Desc, Result),
    print_result(Result).

parse_consideration(Raw, grant) :-
    downcase_atom(Raw, grant), !.
parse_consideration(Raw, rands(N)) :-
    atom_number(Raw, N), integer(N), !.
parse_consideration(Raw, Raw).

prompt_line(Label, Line) :-
    format('~w: ', [Label]),
    flush_output,
    read_line_to_string(user_input, S),
    (   S == end_of_file
    ->  Line = '0'
    ;   normalize_space(string(T), S),
        atom_string(Line, T)
    ).

prompt_atom(Label, Atom) :-
    prompt_line(Label, Atom).

prompt_integer(Label, N) :-
    prompt_line(Label, Atom),
    (   atom_number(Atom, N), integer(N)
    ->  true
    ;   format('  (~w is not a whole number; using 0)~n', [Atom]),
        N = 0
    ).
