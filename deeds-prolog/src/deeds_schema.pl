:- module(deeds_schema, [
    attach_deeds_db/1,
    detach_deeds_db/0,
    db_is_attached/0,
    attached_db_file/1,
    party/4,
    assert_party/4,
    retractall_party/4,
    property/4,
    assert_property/4,
    retractall_property/4,
    title_deed/6,
    assert_title_deed/6,
    retractall_title_deed/6,
    bond/7,
    assert_bond/7,
    retractall_bond/7,
    bond_cancellation/3,
    assert_bond_cancellation/3,
    retractall_bond_cancellation/3,
    servitude/6,
    assert_servitude/6,
    retractall_servitude/6
]).

:- use_module(library(persistency)).

%! party(?Id, ?Kind, ?Name, ?Identifier)
%  Kind is natural, company or trust. Identifier is an ID number,
%  company registration number, or Master's trust reference.
:- persistent
    party(id:atom, kind:atom, name:atom, identifier:atom).

%! property(?Id, ?Kind, ?Description, ?Details)
%  Kind is erf, farm or sectional. Details is a compound term:
%  erf/5, farm/6 or sectional/6 (see sample data and README).
:- persistent
    property(id:atom, kind:atom, description:atom, details:any).

%! title_deed(?DeedNo, ?PropertyId, ?OwnerId, ?Date, ?PreviousDeed, ?Consideration)
%  PreviousDeed is 'none' for the opening title. Consideration is
%  grant or rands(Integer).
:- persistent
    title_deed(deed_no:atom, property_id:atom, owner_id:atom,
               date:atom, previous_deed:atom, consideration:any).

%! bond(?BondNo, ?PropertyId, ?DeedNo, ?Mortgagee, ?MortgagorId, ?Amount, ?Date)
%  Amount is an integer number of rands. DeedNo is the title current
%  at the date of registration.
:- persistent
    bond(bond_no:atom, property_id:atom, deed_no:atom, mortgagee:atom,
         mortgagor_id:atom, amount:integer, date:atom).

%! bond_cancellation(?BondNo, ?Date, ?Note)
:- persistent
    bond_cancellation(bond_no:atom, date:atom, note:atom).

%! servitude(?DeedNo, ?PropertyId, ?Type, ?InFavourOf, ?Date, ?Description)
:- persistent
    servitude(deed_no:atom, property_id:atom, type:atom,
              in_favour_of:atom, date:atom, description:atom).

:- dynamic attached_db_file/1.

%! attach_deeds_db(+File) is det.
%  Attach (or re-attach) the persistency journal at File.
%  Changes are flushed after every write so records survive a crash.
attach_deeds_db(File) :-
    (   attached_db_file(_)
    ->  detach_deeds_db
    ;   true
    ),
    absolute_file_name(File, Abs, [access(none)]),
    file_directory_name(Abs, Dir),
    make_directory_path(Dir),
    db_attach(Abs, [sync(flush)]),
    retractall(attached_db_file(_)),
    assertz(attached_db_file(Abs)).

%! detach_deeds_db is det.
%  Close the journal and release the module so a different file can
%  be attached. In-memory clauses are dropped without writing
%  retractall/1 goals into the journal, so a later re-attach of the
%  same file still has its records.
detach_deeds_db :-
    catch(db_sync(detach), _, true),
    retractall(party(_, _, _, _)),
    retractall(property(_, _, _, _)),
    retractall(title_deed(_, _, _, _, _, _)),
    retractall(bond(_, _, _, _, _, _, _)),
    retractall(bond_cancellation(_, _, _)),
    retractall(servitude(_, _, _, _, _, _)),
    retractall(attached_db_file(_)).

db_is_attached :-
    attached_db_file(_).
