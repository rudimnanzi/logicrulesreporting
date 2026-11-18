:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).

% Route
:- http_handler(root(.), home, []).

% Test page
home(_Request) :-
    format('Content-type: text/html~n~n'),
    format('<html>
    <head><title>Prolog Test</title></head>
    <body>
        <h1>SWI-Prolog is running!</h1>
        <p>Our test server is alive.</p>
        <p>Port: 8000</p>
    </body>
    </html>').

% Start server
start :-
    http_server(http_dispatch, [port(8000)]),
    format('Prolog server running on port 8000~n').

% Application entry point
main :-
    start,
    thread_get_message(_).

:- initialization(main, main).