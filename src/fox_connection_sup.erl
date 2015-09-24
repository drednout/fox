-module(fox_connection_sup).
-behaviour(supervisor).

-export([start_link/3, init/1, stop/1]).

-include("otp_types.hrl").
-include("fox.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").


-spec(start_link(atom(), #amqp_params_network{}, integer()) -> {ok, pid()}).
start_link(PoolName, Params, PoolSize) ->
    supervisor:start_link({local, PoolName}, ?MODULE, {Params, PoolSize}).


-spec(init(gs_args()) -> sup_init_reply()).
init({Params, PoolSize}) ->
    Spec = fun(Id) ->
                   {{fox_connection_worker, Id},
                    {fox_connection_worker, start_link, [Params]},
                    transient, 2000, worker,
                    [fox_connection_worker]}
           end,
    Childs = [Spec(Id) || Id <- lists:seq(1, PoolSize)],
    {ok, {{one_for_one, 10, 60}, Childs}}.


-spec stop(pid()) -> ok.
stop(SupPid) ->
    lists:foreach(fun({_, ChildPid, _, _}) ->
                          fox_connection_worker:stop(ChildPid)
                  end,
                  supervisor:which_children(SupPid)),
    ok.