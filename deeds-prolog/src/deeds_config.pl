:- module(deeds_config, [
    config_root/1,
    ai_settings/1,
    ai_configured/0,
    save_ai_settings/3,
    clear_ai_key/0,
    builtin_ai_endpoint/1,
    builtin_ai_model/1
]).

:- use_module(library(filesex)).
:- use_module(library(http/json)).

%! builtin_ai_endpoint(-URL) is det.
%! builtin_ai_model(-Model) is det.
%  Built-in defaults for an OpenAI-compatible chat completions API.
%  No API key is stored in source.
builtin_ai_endpoint('https://api.openai.com/v1/chat/completions').
builtin_ai_model('gpt-4o').

%! config_root(-Root) is det.
config_root(Root) :-
    module_property(deeds_config, file(File)),
    file_directory_name(File, Src),
    file_directory_name(Src, Root).

ai_settings_file(Path) :-
    config_root(Root),
    directory_file_path(Root, 'data', Data),
    make_directory_path(Data),
    directory_file_path(Data, 'ai_settings.json', Path).

user_config_file(Path) :-
    config_root(Root),
    directory_file_path(Root, 'config.pl', Path).

%! ai_settings(-Settings) is det.
%  Settings is a dict:
%    configured, has_key, endpoint, model, key_source, endpoint_source
%  The raw API key is never included.
ai_settings(Settings) :-
    resolve_ai(Endpoint, Model, Key, EndSrc, KeySrc),
    (   nonvar(Key), Key \== "", Key \== ''
    ->  HasKey = true, Configured = true
    ;   HasKey = false, Configured = false, KeySrc = none
    ),
    Settings = _{
        configured: Configured,
        has_key: HasKey,
        endpoint: Endpoint,
        model: Model,
        endpoint_source: EndSrc,
        key_source: KeySrc
    }.

%! ai_configured is semidet.
ai_configured :-
    resolve_ai(_, _, Key, _, _),
    nonvar(Key),
    Key \== "",
    Key \== ''.

%! resolve_ai(-Endpoint, -Model, -Key, -EndSrc, -KeySrc) is det.
%  Precedence: environment variables, then data/ai_settings.json,
%  then optional config.pl facts, then built-in defaults.
%  Key is unbound (and KeySrc = none) when no key is available.
resolve_ai(Endpoint, Model, Key, EndSrc, KeySrc) :-
    load_settings_file(FileDict),
    load_user_config(UserEnd, UserModel),
    builtin_ai_endpoint(DefEnd),
    builtin_ai_model(DefModel),
    (   getenv('DEEDS_AI_ENDPOINT', E1), E1 \== ""
    ->  atom_string(Endpoint, E1), EndSrc = environment
    ;   get_dict(endpoint, FileDict, E2), E2 \== "", E2 \== null
    ->  json_to_atom(E2, Endpoint), EndSrc = settings_file
    ;   nonvar(UserEnd)
    ->  Endpoint = UserEnd, EndSrc = config_pl
    ;   Endpoint = DefEnd, EndSrc = builtin
    ),
    (   getenv('DEEDS_AI_MODEL', M1), M1 \== ""
    ->  atom_string(Model, M1)
    ;   get_dict(model, FileDict, M2), M2 \== "", M2 \== null
    ->  json_to_atom(M2, Model)
    ;   nonvar(UserModel)
    ->  Model = UserModel
    ;   Model = DefModel
    ),
    (   getenv('DEEDS_AI_API_KEY', K1), K1 \== ""
    ->  atom_string(Key, K1), KeySrc = environment
    ;   get_dict(api_key, FileDict, K2), K2 \== "", K2 \== null
    ->  json_to_atom(K2, Key), KeySrc = settings_file
    ;   true
    ).

%! ai_credentials(-Endpoint, -Model, -Key) is semidet.
%  Succeeds only when a non-empty key is available.
:- export(ai_credentials/3).
ai_credentials(Endpoint, Model, Key) :-
    resolve_ai(Endpoint, Model, Key, _, _),
    nonvar(Key),
    Key \== "",
    Key \== ''.

json_to_atom(V, A) :-
    (   atom(V) -> A = V
    ;   string(V) -> atom_string(A, V)
    ;   term_to_atom(V, A)
    ).

load_settings_file(Dict) :-
    ai_settings_file(Path),
    (   exists_file(Path)
    ->  setup_call_cleanup(
            open(Path, read, In, [encoding(utf8)]),
            catch(json_read_dict(In, Dict, [default_tag(json)]), _, Dict = _{}),
            close(In))
    ;   Dict = _{}
    ).

load_user_config(Endpoint, Model) :-
    user_config_file(Path),
    (   exists_file(Path)
    ->  load_files(Path, [if(true), silent(true), module(deeds_user_config)]),
        (   current_predicate(deeds_user_config:ai_endpoint/1),
            deeds_user_config:ai_endpoint(Endpoint)
        ->  true
        ;   true
        ),
        (   current_predicate(deeds_user_config:ai_model/1),
            deeds_user_config:ai_model(Model)
        ->  true
        ;   true
        )
    ;   true
    ).

%! save_ai_settings(+Endpoint, +Model, +KeyOrKeep) is det.
%  KeyOrKeep = keep leaves an existing file key unchanged;
%  an empty atom/string leaves the key unchanged as well unless
%  no key exists. A non-empty value overwrites the stored key.
save_ai_settings(Endpoint, Model, KeyOrKeep) :-
    load_settings_file(Old),
    (   KeyOrKeep == keep
    ->  (   get_dict(api_key, Old, Existing) -> Key = Existing ; Key = "" )
    ;   (KeyOrKeep == '' ; KeyOrKeep == "")
    ->  (   get_dict(api_key, Old, Existing) -> Key = Existing ; Key = "" )
    ;   json_to_atom(KeyOrKeep, Key)
    ),
    json_to_atom(Endpoint, EndAtom),
    json_to_atom(Model, ModelAtom),
    Dict = _{endpoint: EndAtom, model: ModelAtom, api_key: Key},
    ai_settings_file(Path),
    setup_call_cleanup(
        open(Path, write, Out, [encoding(utf8)]),
        json_write_dict(Out, Dict, [null(null), width(80)]),
        close(Out)).

%! clear_ai_key is det.
clear_ai_key :-
    load_settings_file(Old),
    (   get_dict(endpoint, Old, E) -> true ; builtin_ai_endpoint(E) ),
    (   get_dict(model, Old, M) -> true ; builtin_ai_model(M) ),
    Dict = _{endpoint: E, model: M, api_key: ""},
    ai_settings_file(Path),
    setup_call_cleanup(
        open(Path, write, Out, [encoding(utf8)]),
        json_write_dict(Out, Dict, [null(null), width(80)]),
        close(Out)).
