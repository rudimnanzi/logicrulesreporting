:- prolog_load_context(directory, TestDir),
   directory_file_path(TestDir, '..', Root),
   absolute_file_name(Root, Abs),
   directory_file_path(Abs, 'load.pl', Load),
   use_module(Load).

:- use_module(library(plunit)).
:- use_module(library(http/http_open)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_json)).
:- use_module(library(http/json)).
:- use_module(library(deeds_schema)).
:- use_module(library(deeds_sample)).
:- use_module(library(deeds_http)).
:- use_module(library(filesex)).

:- dynamic http_test_port/1, test_db_file/1.

http_port(18080).

setup_http :-
    tmp_file(deeds_http, File),
    asserta(test_db_file(File)),
    setup_deeds_fresh(File),
    load_sample,
    http_port(Port),
    catch(stop_http_server(Port), _, true),
    start_http_server(Port, [browser(false)]),
    retractall(http_test_port(_)),
    asserta(http_test_port(Port)),
    sleep(0.15).

cleanup_http :-
    (   retract(http_test_port(Port))
    ->  catch(stop_http_server(Port), _, true)
    ;   true
    ),
    detach_deeds_db,
    (   retract(test_db_file(File))
    ->  ignore(catch(delete_file(File), _, true))
    ;   true
    ).

base_url(URL) :-
    http_test_port(Port),
    format(atom(URL), 'http://127.0.0.1:~w', [Port]).

get_code(Path, Code, Body) :-
    base_url(Base),
    atom_concat(Base, Path, URL),
    setup_call_cleanup(
        http_open(URL, In, [status_code(Code), timeout(10)]),
        read_string(In, _, Body),
        close(In)).

get_json(Path, Code, Dict) :-
    base_url(Base),
    atom_concat(Base, Path, URL),
    setup_call_cleanup(
        http_open(URL, In, [
            status_code(Code),
            timeout(10),
            request_header('Accept'='application/json')
        ]),
        json_read_dict(In, Dict, [default_tag(json)]),
        close(In)).

post_json(Path, Body, Code, Dict) :-
    base_url(Base),
    atom_concat(Base, Path, URL),
    setup_call_cleanup(
        http_open(URL, In, [
            method(post),
            post(json(Body)),
            status_code(Code),
            timeout(10),
            request_header('Content-Type'='application/json'),
            request_header('Accept'='application/json')
        ]),
        json_read_dict(In, Dict, [default_tag(json)]),
        close(In)).

contains(Haystack, Needle) :-
    once(sub_string(Haystack, _, _, _, Needle)).

is_false(V) :- (V == false ; V == "false" ; V == 0), !.
is_true(V) :- (V == true ; V == "true" ; V == 1), !.

:- begin_tests(http, [setup(setup_http), cleanup(cleanup_http)]).

test(index_html) :-
    get_code('/', 200, Body),
    contains(Body, "Deeds Office Register"),
    contains(Body, "/static/style.css"),
    contains(Body, "/static/app.js").

test(static_css) :-
    get_code('/static/style.css', 200, Body),
    contains(Body, "--navy").

test(static_js) :-
    get_code('/static/app.js', 200, Body),
    contains(Body, "renderDashboard").

test(dashboard_json) :-
    get_json('/api/dashboard', 200, D),
    get_dict(counts, D, C),
    get_dict(properties, C, NP), NP >= 15,
    get_dict(parties, C, NPa), NPa >= 12,
    get_dict(recent, D, Recent),
    is_list(Recent),
    get_dict(advisor_preview, D, Prev),
    is_list(Prev).

test(properties_list) :-
    get_json('/api/properties', 200, D),
    get_dict(properties, D, List),
    length(List, N), N >= 15.

test(properties_search) :-
    get_json('/api/properties?q=Claremont', 200, D),
    get_dict(properties, D, List),
    List = [One|_],
    get_dict(id, One, Id),
    (   Id == prop_claremont_123
    ->  true
    ;   atom_string(prop_claremont_123, Id)
    ).

test(property_detail) :-
    get_json('/api/property?id=prop_parktown_789', 200, D),
    get_dict(title_chain, D, Chain),
    length(Chain, 3),
    get_dict(advisor, D, Adv),
    is_list(Adv),
    get_dict(current_title, D, Title),
    (   Title == 'T9100/2024'
    ->  true
    ;   atom_string('T9100/2024', Title)
    ).

test(parties_and_holdings) :-
    get_json('/api/parties', 200, All),
    get_dict(parties, All, List),
    length(List, N), N >= 12,
    get_json('/api/party?id=ayesha', 200, P),
    get_dict(holdings, P, Holdings),
    length(Holdings, H), H >= 2.

test(deed_lookup) :-
    get_json('/api/deeds?no=T9100%2F2024', 200, D),
    get_dict(found, D, Found),
    is_true(Found),
    get_dict(record, D, Rec),
    get_dict(type, Rec, Type),
    once((Type == title ; atom_string(title, Type))).

test(advisor_registry) :-
    get_json('/api/advisor', 200, D),
    get_dict(findings, D, Findings),
    length(Findings, N), N > 5,
    get_dict(ai, D, AI),
    get_dict(configured, AI, Conf),
    is_false(Conf).

test(advisor_property) :-
    get_json('/api/advisor?property=prop_orphan_erf_1', 200, D),
    get_dict(findings, D, Findings),
    once((member(F, Findings),
          get_dict(code, F, Code),
          (Code == no_registered_title ; atom_string(no_registered_title, Code)))).

test(settings_has_no_key_field) :-
    get_json('/api/settings', 200, S),
    get_dict(configured, S, Conf),
    is_false(Conf),
    \+ get_dict(api_key, S, _).

test(transfer_rejected_wrong_owner) :-
    post_json('/api/register/transfer',
              _{deed_no: 'T99901/2026', property: prop_claremont_123,
                from: thabo, to: pieter, date: '2026-01-15', price: 2500000},
              200, R),
    get_dict(ok, R, Ok),
    is_false(Ok),
    get_dict(error, R, Msg),
    (string(Msg) -> Text = Msg ; atom_string(Msg, Text)),
    contains(Text, "current registered owner").

test(transfer_blocked_by_bond) :-
    post_json('/api/register/transfer',
              _{deed_no: 'T99902/2026', property: prop_claremont_123,
                from: lerato, to: pieter, date: '2026-01-15', price: 2500000},
              200, R),
    get_dict(ok, R, Ok),
    is_false(Ok),
    get_dict(error, R, Msg),
    (string(Msg) -> Text = Msg ; atom_string(Msg, Text)),
    contains(Text, "Transfer blocked"),
    contains(Text, "B2100/2021").

test(ai_hook_disabled) :-
    post_json('/api/advisor/ai', _{property: prop_claremont_123}, 200, R),
    get_dict(status, R, Status),
    once((Status == disabled ; atom_string(disabled, Status))).

test(register_party_and_unknown_property) :-
    post_json('/api/register/party',
              _{id: http_test_party, kind: natural,
                name: 'Http Test', identifier: 'FID-HTTP'},
              200, R1),
    get_dict(ok, R1, Ok1),
    is_true(Ok1),
    post_json('/api/register/first_title',
              _{deed_no: 'T100/2026', property: no_such_prop,
                owner: http_test_party, date: '2026-01-01', consideration: grant},
              200, R2),
    get_dict(ok, R2, Ok2),
    is_false(Ok2).

:- end_tests(http).
