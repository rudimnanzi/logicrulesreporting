:- module(deeds_http, [
    start_http_server/1,
    start_http_server/2,
    stop_http_server/1,
    server_port/1,
    web_root/1
]).

:- use_module(library(http/http_server)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_header)).
:- use_module(library(http/http_cors)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_path)).
:- use_module(library(http/json)).
:- use_module(library(www_browser)).
:- use_module(library(filesex)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(aggregate)).
:- use_module(library(deeds_schema)).
:- use_module(library(deeds_rules)).
:- use_module(library(deeds_sample)).
:- use_module(library(deeds_advisor)).
:- use_module(library(deeds_config)).

:- dynamic server_port/1.

web_root(Root) :-
    module_property(deeds_http, file(File)),
    file_directory_name(File, Src),
    file_directory_name(Src, Proj),
    directory_file_path(Proj, web, Root).

:- http_handler(root(.), serve_index, [method(get), id(app_index)]).
:- http_handler(root(static),
                serve_static,
                [prefix, method(get), id(app_static)]).
:- http_handler(root(api/dashboard),
                api_dashboard,
                [method(get), id(api_dashboard)]).
:- http_handler(root(api/properties),
                api_properties,
                [method(get), id(api_properties)]).
:- http_handler(root(api/property),
                api_property,
                [method(get), id(api_property)]).
:- http_handler(root(api/parties),
                api_parties,
                [method(get), id(api_parties)]).
:- http_handler(root(api/party),
                api_party,
                [method(get), id(api_party)]).
:- http_handler(root(api/deeds),
                api_deeds,
                [method(get), id(api_deeds)]).
:- http_handler(root(api/advisor),
                api_advisor,
                [method(get), id(api_advisor)]).
:- http_handler(root(api/advisor/ai),
                api_advisor_ai,
                [method(post), id(api_advisor_ai)]).
:- http_handler(root(api/settings),
                api_settings,
                [methods([get,post]), id(api_settings)]).
:- http_handler(root(api/settings/clear_key),
                api_settings_clear,
                [method(post), id(api_settings_clear)]).
:- http_handler(root(api/reset),
                api_reset,
                [method(post), id(api_reset)]).
:- http_handler(root(api/register/party),
                api_reg_party,
                [method(post)]).
:- http_handler(root(api/register/property),
                api_reg_property,
                [method(post)]).
:- http_handler(root(api/register/first_title),
                api_reg_first_title,
                [method(post)]).
:- http_handler(root(api/register/transfer),
                api_reg_transfer,
                [method(post)]).
:- http_handler(root(api/register/bond),
                api_reg_bond,
                [method(post)]).
:- http_handler(root(api/register/cancel_bond),
                api_reg_cancel,
                [method(post)]).
:- http_handler(root(api/register/servitude),
                api_reg_servitude,
                [method(post)]).

%! start_http_server(+Port) is det.
start_http_server(Port) :-
    start_http_server(Port, [browser(false)]).

%! start_http_server(+Port, +Options) is det.
start_http_server(Port, Options) :-
    (   server_port(Old)
    ->  catch(http_stop_server(Old, []), _, true),
        retractall(server_port(_))
    ;   true
    ),
    http_server(http_dispatch, [port(Port)]),
    assertz(server_port(Port)),
    format(atom(URL), 'http://localhost:~w/', [Port]),
    (   option(browser(true), Options, false)
    ->  catch(www_open_url(URL), _, true)
    ;   true
    ),
    format(user_error, 'Deeds office register listening at ~w~n', [URL]).

%! stop_http_server(+Port) is det.
stop_http_server(Port) :-
    catch(http_stop_server(Port, []), _, true),
    retractall(server_port(Port)).

serve_index(Request) :-
    web_root(Web),
    directory_file_path(Web, 'index.html', Index),
    http_reply_file(Index, [unsafe(true)], Request).

serve_static(Request) :-
    memberchk(path(Path), Request),
    atom_concat('/static/', Rel, Path),
    \+ sub_atom(Rel, _, _, _, '..'),
    Rel \== '',
    web_root(Web),
    directory_file_path(Web, static, StaticDir),
    directory_file_path(StaticDir, Rel, File),
    exists_file(File),
    !,
    http_reply_file(File, [unsafe(true)], Request).
serve_static(Request) :-
    http_404([], Request).

% ---------------------------------------------------------------------------
% GET APIs
% ---------------------------------------------------------------------------

api_dashboard(_Request) :-
    aggregate_all(count, property(_,_,_,_), NProp),
    aggregate_all(count, party(_,_,_,_), NParty),
    aggregate_all(count, title_deed(_,_,_,_,_,_), NTitle),
    findall(B, (bond(B,_,_,_,_,_,_), \+ bond_cancellation(B,_,_)), Active),
    length(Active, NActive),
    aggregate_all(count, bond_cancellation(_,_,_), NCancel),
    aggregate_all(count, servitude(_,_,_,_,_,_), NServ),
    advise_registry(Findings),
    length(Findings, NFlags),
    recent_events(12, Recent),
    include(is_alert_finding, Findings, Alerts),
    take(5, Alerts, Preview),
    maplist(finding_dict, Preview, PreviewD),
    reply_json_dict(_{
        counts: _{
            properties: NProp,
            parties: NParty,
            titles: NTitle,
            active_bonds: NActive,
            cancelled_bonds: NCancel,
            servitudes: NServ,
            advisor_flags: NFlags
        },
        recent: Recent,
        advisor_preview: PreviewD
    }).

is_alert_finding(finding(critical, _, _, _, _, _)).
is_alert_finding(finding(warning, _, _, _, _, _)).

api_properties(Request) :-
    http_parameters(Request, [q(Q0, [optional(true), default('')])]),
    to_atom(Q0, Q),
    findall(P, property_list_item(Q, P), Items),
    reply_json_dict(_{properties: Items}).

api_property(Request) :-
    http_parameters(Request, [id(Id0, [])]),
    to_atom(Id0, Id),
    (   property(Id, Kind, Desc, Details)
    ->  property_detail_dict(Id, Kind, Desc, Details, Dict),
        advise_property(Id, Findings),
        maplist(finding_dict, Findings, FD),
        put_dict(advisor, Dict, FD, Out),
        reply_json_dict(Out)
    ;   reply_error(404, 'Unknown property.')
    ).

api_parties(_Request) :-
    findall(P, party_list_item(P), Items),
    reply_json_dict(_{parties: Items}).

api_party(Request) :-
    http_parameters(Request, [id(Id0, [])]),
    to_atom(Id0, Id),
    (   party(Id, Kind, Name, Ident)
    ->  properties_owned_by(Id, Props),
        maplist(holding_dict, Props, Holdings),
        party_label(Id, Label),
        reply_json_dict(_{
            id: Id, kind: Kind, name: Name,
            identifier: Ident, label: Label,
            holdings: Holdings
        })
    ;   reply_error(404, 'Unknown party.')
    ).

api_deeds(Request) :-
    http_parameters(Request, [no(No0, [])]),
    to_atom(No0, No),
    (   deed_search(No, Record)
    ->  deed_record_dict(Record, Dict),
        reply_json_dict(_{found: true, record: Dict})
    ;   reply_json_dict(_{found: false, number: No})
    ).

api_advisor(Request) :-
    http_parameters(Request,
                    [property(Prop0, [optional(true), default('')])]),
    to_atom(Prop0, Prop),
    (   Prop == ''
    ->  advise_registry(Findings),
        Scope = registry
    ;   advise_property(Prop, Findings),
        Scope = Prop
    ),
    maplist(finding_dict, Findings, FD),
    ai_settings(S),
    reply_json_dict(_{
        scope: Scope,
        findings: FD,
        ai: _{configured: S.configured, endpoint_source: S.endpoint_source}
    }).

api_advisor_ai(Request) :-
    http_read_json_dict(Request, Body),
    (   get_dict(property, Body, P0), P0 \== "", P0 \== null
    ->  to_atom(P0, Prop),
        advise_property(Prop, Findings),
        Scope = property(Prop)
    ;   advise_registry(Findings),
        Scope = registry
    ),
    ask_ai_advice(Scope, Findings, AI),
    ai_result_dict(AI, Dict),
    reply_json_dict(Dict).

api_settings(Request) :-
    memberchk(method(get), Request),
    !,
    api_settings_get(Request).
api_settings(Request) :-
    api_settings_post(Request).

api_settings_get(_Request) :-
    ai_settings(S),
    reply_json_dict(S).

api_settings_post(Request) :-
    http_read_json_dict(Request, Body),
    dict_get_atom(Body, endpoint, Endpoint),
    dict_get_atom(Body, model, Model),
    (   get_dict(api_key, Body, K0),
        K0 \== null,
        to_atom(K0, K),
        K \== ''
    ->  Key = K
    ;   Key = keep
    ),
    (   Endpoint == ''
    ->  builtin_ai_endpoint(End)
    ;   End = Endpoint
    ),
    (   Model == ''
    ->  builtin_ai_model(Mod)
    ;   Mod = Model
    ),
    save_ai_settings(End, Mod, Key),
    ai_settings(S),
    reply_json_dict(S.put(_{saved: true})).

api_settings_clear(_Request) :-
    clear_ai_key,
    ai_settings(S),
    reply_json_dict(S.put(_{saved: true, key_cleared: true})).

api_reset(_Request) :-
    reset_demo,
    aggregate_all(count, property(_,_,_,_), NProp),
    aggregate_all(count, party(_,_,_,_), NParty),
    reply_json_dict(_{ok: true, properties: NProp, parties: NParty}).

% ---------------------------------------------------------------------------
% Registration POST handlers (reuse deeds_rules validation)
% ---------------------------------------------------------------------------

api_reg_party(Request) :-
    http_read_json_dict(Request, Body),
    dict_get_atom(Body, id, Id),
    dict_get_atom(Body, kind, Kind),
    dict_get_atom(Body, name, Name),
    dict_get_atom(Body, identifier, Ident),
    register_party(Id, Kind, Name, Ident, Result),
    reply_reg(Result).

api_reg_property(Request) :-
    http_read_json_dict(Request, Body),
    dict_get_atom(Body, id, Id),
    dict_get_atom(Body, kind, Kind),
    dict_get_atom(Body, description, Desc),
    property_details_from_body(Kind, Body, Details),
    register_property(Id, Kind, Desc, Details, Result),
    reply_reg(Result).

api_reg_first_title(Request) :-
    http_read_json_dict(Request, Body),
    dict_get_atom(Body, deed_no, Deed),
    dict_get_atom(Body, property, Prop),
    dict_get_atom(Body, owner, Owner),
    dict_get_atom(Body, date, Date),
    consideration_from_body(Body, Cons),
    register_first_title(Deed, Prop, Owner, Date, Cons, Result),
    reply_reg(Result).

api_reg_transfer(Request) :-
    http_read_json_dict(Request, Body),
    dict_get_atom(Body, deed_no, Deed),
    dict_get_atom(Body, property, Prop),
    dict_get_atom(Body, from, From),
    dict_get_atom(Body, to, To),
    dict_get_atom(Body, date, Date),
    dict_get_int(Body, price, Price),
    register_transfer(Deed, Prop, From, To, Date, Price, Result),
    reply_reg(Result).

api_reg_bond(Request) :-
    http_read_json_dict(Request, Body),
    dict_get_atom(Body, bond_no, Bond),
    dict_get_atom(Body, property, Prop),
    dict_get_atom(Body, mortgagee, Bank),
    dict_get_int(Body, amount, Amount),
    dict_get_atom(Body, date, Date),
    register_bond(Bond, Prop, Bank, Amount, Date, Result),
    reply_reg(Result).

api_reg_cancel(Request) :-
    http_read_json_dict(Request, Body),
    dict_get_atom(Body, bond_no, Bond),
    dict_get_atom(Body, date, Date),
    cancel_bond(Bond, Date, Result),
    reply_reg(Result).

api_reg_servitude(Request) :-
    http_read_json_dict(Request, Body),
    dict_get_atom(Body, deed_no, Deed),
    dict_get_atom(Body, property, Prop),
    dict_get_atom(Body, type, Type),
    dict_get_atom(Body, in_favour_of, Fav),
    dict_get_atom(Body, date, Date),
    dict_get_atom(Body, description, Desc),
    register_servitude(Deed, Prop, Type, Fav, Date, Desc, Result),
    reply_reg(Result).

reply_reg(ok) :-
    reply_json_dict(_{ok: true}).
reply_reg(error(Reason)) :-
    error_message(error(Reason), Msg),
    format(atom(Code), '~q', [Reason]),
    reply_json_dict(_{ok: false, error: Msg, reason: Code}).

reply_error(Code, Msg) :-
    format('Status: ~d~n', [Code]),
    reply_json_dict(_{ok: false, error: Msg}).

% ---------------------------------------------------------------------------
% JSON builders
% ---------------------------------------------------------------------------

property_list_item(Query, Dict) :-
    property(Id, Kind, Desc, Details),
    (   current_owner(Id, Owner)
    ->  party_label(Owner, OLabel),
        current_title(Id, Deed),
        OwnerId = Owner
    ;   OLabel = '(no registered title)',
        Deed = '',
        OwnerId = ''
    ),
    is_bonded(Id, Bonds),
    (   Bonds == [] -> Bonded = false ; Bonded = true ),
    details_dict(Details, Det),
    matches_query(Query, [Id, Kind, Desc, OLabel, Deed, OwnerId], Det),
    Dict = _{
        id: Id, kind: Kind, description: Desc, details: Det,
        owner_id: OwnerId, owner: OLabel,
        current_title: Deed, bonded: Bonded
    }.

matches_query('', _, _) :- !.
matches_query(Query, Atoms, Det) :-
    downcase_atom(Query, Q),
    (   member(A, Atoms),
        A \== '',
        to_atom(A, AA),
        downcase_atom(AA, D),
        sub_atom(D, _, _, _, Q)
    ->  true
    ;   term_string(Det, S),
        string_lower(S, SL),
        atom_string(Q, QS),
        sub_string(SL, _, _, _, QS)
    ).

property_detail_dict(Id, Kind, Desc, Details, Dict) :-
    details_dict(Details, Det),
    (   current_owner(Id, Owner)
    ->  party_label(Owner, OLabel),
        current_title(Id, Deed),
        OwnerId = Owner
    ;   OLabel = '(no registered title)',
        Deed = '',
        OwnerId = ''
    ),
    (   title_chain(Id, Chain)
    ->  maplist(title_dict, Chain, ChainD)
    ;   ChainD = []
    ),
    is_bonded(Id, Bonds),
    maplist(bond_dict, Bonds, BondD),
    encumbrance_summary(Id, encumbrances(_, Active, Cancelled, Servs)),
    maplist(bond_dict, Active, ActiveD),
    maplist(cancelled_dict, Cancelled, CancelD),
    maplist(servitude_dict, Servs, ServD),
    Dict = _{
        id: Id, kind: Kind, description: Desc, details: Det,
        owner_id: OwnerId, owner: OLabel, current_title: Deed,
        title_chain: ChainD,
        active_bonds: BondD,
        encumbrances: _{
            active_bonds: ActiveD,
            cancelled_bonds: CancelD,
            servitudes: ServD
        }
    }.

party_list_item(Dict) :-
    party(Id, Kind, Name, Ident),
    properties_owned_by(Id, Props),
    length(Props, N),
    party_label(Id, Label),
    Dict = _{
        id: Id, kind: Kind, name: Name, identifier: Ident,
        label: Label, holding_count: N
    }.

holding_dict(Prop, Dict) :-
    property(Prop, Kind, Desc, _),
    current_title(Prop, Deed),
    is_bonded(Prop, Bonds),
    (   Bonds == [] -> Bonded = false ; Bonded = true ),
    Dict = _{
        id: Prop, kind: Kind, description: Desc,
        current_title: Deed, bonded: Bonded
    }.

title_dict(title(Deed, Prop, Owner, Date, Prev, Cons), Dict) :-
    party_label(Owner, OLabel),
    consideration_text(Cons, CText, CType, CAmount),
    Dict = _{
        deed_no: Deed, property: Prop, owner_id: Owner, owner: OLabel,
        date: Date, previous_deed: Prev,
        consideration: CText, consideration_type: CType,
        amount: CAmount
    }.

bond_dict(bond(No, Prop, Deed, Bank, Mortgagor, Amt, Date), Dict) :-
    party_label(Mortgagor, MLabel),
    format_money(Amt, Money),
    Dict = _{
        bond_no: No, property: Prop, deed_no: Deed, mortgagee: Bank,
        mortgagor_id: Mortgagor, mortgagor: MLabel,
        amount: Amt, amount_text: Money, date: Date, status: active
    }.

cancelled_dict(cancelled_bond(No, Deed, Bank, Mortgagor, Amt, BondDate, CDate), Dict) :-
    party_label(Mortgagor, MLabel),
    format_money(Amt, Money),
    Dict = _{
        bond_no: No, deed_no: Deed, mortgagee: Bank,
        mortgagor_id: Mortgagor, mortgagor: MLabel,
        amount: Amt, amount_text: Money, date: BondDate,
        cancelled_on: CDate, status: cancelled
    }.

servitude_dict(servitude(No, Prop, Type, Fav, Date, Desc), Dict) :-
    Dict = _{
        deed_no: No, property: Prop, type: Type,
        in_favour_of: Fav, date: Date, description: Desc
    }.

deed_record_dict(title_history(Deed, Prop, Owner, Date, Prev, Cons, NextInfo, Bonds), Dict) :-
    property_label(Prop, PLabel),
    party_label(Owner, OLabel),
    consideration_text(Cons, CText, CType, CAmount),
    next_dict(NextInfo, NextD),
    Dict = _{
        type: title, deed_no: Deed, property: Prop, property_label: PLabel,
        owner_id: Owner, owner: OLabel, date: Date, previous_deed: Prev,
        consideration: CText, consideration_type: CType, amount: CAmount,
        next: NextD, bonds_on_title: Bonds
    }.
deed_record_dict(bond_history(Deed, Prop, Title, Bank, Mortgagor, Amt, Date, Status), Dict) :-
    property_label(Prop, PLabel),
    party_label(Mortgagor, MLabel),
    format_money(Amt, Money),
    bond_status_dict(Status, SD, SAtom),
    Dict = _{
        type: bond, deed_no: Deed, property: Prop, property_label: PLabel,
        title: Title, mortgagee: Bank, mortgagor_id: Mortgagor,
        mortgagor: MLabel, amount: Amt, amount_text: Money,
        date: Date, status: SAtom, status_detail: SD
    }.
deed_record_dict(servitude_history(Deed, Prop, Type, Fav, Date, Desc), Dict) :-
    property_label(Prop, PLabel),
    Dict = _{
        type: servitude, deed_no: Deed, property: Prop,
        property_label: PLabel, servitude_type: Type,
        in_favour_of: Fav, date: Date, description: Desc
    }.

next_dict(current, _{status: current}).
next_dict(next(N, D), _{status: transferred, next_deed: N, date: D}).

bond_status_dict(active, _{}, active).
bond_status_dict(cancelled(Date, Note), _{cancelled_on: Date, note: Note}, cancelled).

finding_dict(finding(Sev, Code, Subject, Title, Msg, Rec), Dict) :-
    Dict = _{
        severity: Sev, code: Code, subject: Subject,
        title: Title, message: Msg, recommendation: Rec
    }.

ai_result_dict(ai_disabled, _{ok: true, status: disabled,
    message: 'Optional model advice is off. Configure an API key and an OpenAI-compatible endpoint under Settings, or set the DEEDS_AI_API_KEY and DEEDS_AI_ENDPOINT environment variables. Rule-based advice is still shown.'}).
ai_result_dict(ai_ok(Text), _{ok: true, status: ok, advice: Text}).
ai_result_dict(ai_error(Msg), _{ok: false, status: error, error: Msg}).

details_dict(erf(No, Twp, Mun, Prov, Ext), _{
    type: erf, erf_no: No, township: Twp,
    municipality: Mun, province: Prov, extent_m2: Ext
}) :- !.
details_dict(farm(Name, No, Portion, Div, Prov, Ext), _{
    type: farm, farm_name: Name, farm_no: No, portion: Portion,
    division: Div, province: Prov, extent: Ext
}) :- !.
details_dict(sectional(Sec, Scheme, SchemeNo, Mun, Prov, Ext), _{
    type: sectional, section: Sec, scheme: Scheme,
    scheme_no: SchemeNo, municipality: Mun, province: Prov, extent_m2: Ext
}) :- !.
details_dict(Other, _{type: other, raw: Raw}) :-
    term_to_atom(Other, Raw).

consideration_text(grant, 'grant (first registration)', grant, 0) :- !.
consideration_text(rands(N), Text, rands, N) :-
    format_money(N, Text), !.
consideration_text(Other, Text, other, 0) :-
    format(atom(Text), '~q', [Other]).

property_details_from_body(erf, Body, erf(No, Twp, Mun, Prov, Ext)) :-
    dict_get_atom(Body, erf_no, No),
    dict_get_atom(Body, township, Twp),
    dict_get_atom(Body, municipality, Mun),
    dict_get_atom(Body, province, Prov),
    dict_get_int(Body, extent, Ext), !.
property_details_from_body(farm, Body, farm(Name, No, Portion, Div, Prov, Ext)) :-
    dict_get_atom(Body, farm_name, Name),
    (   dict_get_int(Body, farm_no, No) -> true ; dict_get_atom(Body, farm_no, No) ),
    dict_get_atom(Body, portion, Portion),
    dict_get_atom(Body, division, Div),
    dict_get_atom(Body, province, Prov),
    dict_get_atom(Body, extent, Ext), !.
property_details_from_body(sectional, Body, sectional(Sec, Scheme, SchemeNo, Mun, Prov, Ext)) :-
    dict_get_int(Body, section, Sec),
    dict_get_atom(Body, scheme, Scheme),
    dict_get_atom(Body, scheme_no, SchemeNo),
    dict_get_atom(Body, municipality, Mun),
    dict_get_atom(Body, province, Prov),
    dict_get_int(Body, extent, Ext), !.
property_details_from_body(_, Body, notes(Text)) :-
    dict_get_atom(Body, details, Text).

consideration_from_body(Body, grant) :-
    get_dict(consideration, Body, C),
    to_atom(C, grant), !.
consideration_from_body(Body, rands(N)) :-
    dict_get_int(Body, amount, N), !.
consideration_from_body(Body, rands(N)) :-
    dict_get_int(Body, consideration, N), !.
consideration_from_body(_, grant).

recent_events(Limit, Events) :-
    findall(event(Date, Type, Dict), a_recent_event(Date, Type, Dict), Raw),
    sort(1, @>=, Raw, Sorted),
    take(Limit, Sorted, Taken),
    maplist(event_out, Taken, Events).

event_out(event(Date, Type, Dict), Dict.put(_{date: Date, type: Type})).

a_recent_event(Date, title, _{
        deed_no: Deed, property: Prop, summary: Sum
    }) :-
    title_deed(Deed, Prop, Owner, Date, Prev, Cons),
    consideration_text(Cons, CText, _, _),
    party_label(Owner, OLabel),
    (   Prev == none
    ->  format(atom(Sum), 'Opening title ~w in favour of ~w (~w)', [Deed, OLabel, CText])
    ;   format(atom(Sum), 'Transfer ~w to ~w (~w)', [Deed, OLabel, CText])
    ).
a_recent_event(Date, bond, _{
        deed_no: No, property: Prop, summary: Sum
    }) :-
    bond(No, Prop, _, Bank, _, Amt, Date),
    \+ bond_cancellation(No, _, _),
    format_money(Amt, Money),
    format(atom(Sum), 'Bond ~w, ~w, ~w', [No, Bank, Money]).
a_recent_event(Date, cancellation, _{
        deed_no: No, property: Prop, summary: Sum
    }) :-
    bond_cancellation(No, Date, _),
    bond(No, Prop, _, Bank, _, _, _),
    format(atom(Sum), 'Cancellation of bond ~w (~w)', [No, Bank]).
a_recent_event(Date, servitude, _{
        deed_no: No, property: Prop, summary: Sum
    }) :-
    servitude(No, Prop, Type, Fav, Date, _),
    format(atom(Sum), 'Servitude ~w (~w in favour of ~w)', [No, Type, Fav]).

% ---------------------------------------------------------------------------
% Utilities
% ---------------------------------------------------------------------------

to_atom(V, A) :-
    (   atom(V) -> A = V
    ;   string(V) -> atom_string(A, V)
    ;   number(V) -> atom_number(A, V)
    ;   term_to_atom(V, A)
    ).

dict_get_atom(Body, Key, Atom) :-
    (   get_dict(Key, Body, V), V \== null
    ->  to_atom(V, Atom)
    ;   Atom = ''
    ).

dict_get_int(Body, Key, N) :-
    (   get_dict(Key, Body, V), integer(V)
    ->  N = V
    ;   get_dict(Key, Body, V), number(V)
    ->  N is round(V)
    ;   get_dict(Key, Body, V), to_atom(V, A), atom_number(A, N0), integer(N0)
    ->  N = N0
    ;   N = 0
    ).

take(N, List, Taken) :-
    length(List, Len),
    (   Len =< N
    ->  Taken = List
    ;   length(Taken, N),
        append(Taken, _, List)
    ).
