-module(fox_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).
-include("otp_types.hrl").


-spec(start_link() -> {ok, pid()}).
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).


-spec(init(gs_args()) -> sup_init_reply()).
init(_Args) ->

    ConnectionPoolSup =
        {fox_connection_pool_sup,
         {fox_connection_pool_sup, start_link, []},
         permanent, 2000, supervisor,
         [fox_connection_pool_sup]},

    ChannelSup =
        {fox_channel_sup,
         {fox_channel_sup, start_link, []},
         permanent, 2000, supervisor,
         [fox_channel_sup]},

    {ok, {{one_for_one, 10, 60}, [ConnectionPoolSup, ChannelSup]}}.
