-module(fox).

-export([validate_params_network/1,
         create_connection_pool/2,
         close_connection_pool/1,
         create_channel/1,
         subscribe/2, subscribe/3, unsubscribe/2,
         declare_exchange/2, declare_exchange/3,
         delete_exchange/2, delete_exchange/3,
         declare_queue/2, declare_queue/3,
         delete_queue/2, delete_queue/3,
         bind_queue/4, bind_queue/5,
         unbind_queue/4, unbind_queue/5,
         publish/4, publish/5,
         test_run/0]).

-include("fox.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").


%%% module API

-spec validate_params_network(#amqp_params_network{} | map()) -> ok | {error, term()}.
validate_params_network(Params) when is_map(Params) ->
    validate_params_network(fox_utils:map_to_params_network(Params));

validate_params_network(Params) ->
    true = fox_utils:validate_params_network_types(Params),
    case amqp_connection:start(Params) of
        {ok, Connection} -> amqp_connection:close(Connection), ok;
        {error, Reason} -> {error, Reason}
    end.


-spec create_connection_pool(connection_name(), #amqp_params_network{} | map()) -> ok.
create_connection_pool(ConnectionName, Params) when is_map(Params) ->
    create_connection_pool(ConnectionName, fox_utils:map_to_params_network(Params));

create_connection_pool(ConnectionName, Params) ->
    true = fox_utils:validate_params_network_types(Params),
    ConnectionName2 = fox_utils:name_to_atom(ConnectionName),
    {ok, PoolSize} = application:get_env(fox, connection_pool_size),
    fox_connection_pool_sup:start_pool(ConnectionName2, Params, PoolSize),
    ok.


-spec close_connection_pool(connection_name()) -> ok | {error, term()}.
close_connection_pool(ConnectionName) ->
    ConnectionName2 = fox_utils:name_to_atom(ConnectionName),
    fox_connection_pool_sup:stop_pool(ConnectionName2).


-spec create_channel(connection_name()) -> {ok, pid()} | {error, term()}.
create_channel(ConnectionName) ->
    ConnectionName2 = fox_utils:name_to_atom(ConnectionName),
    fox_connection_pool_sup:create_channel(ConnectionName2).


-spec subscribe(connection_name(), module()) -> {ok, pid()} | {error, term()}.
subscribe(ConnectionName, ConsumerModule) ->
    subscribe(ConnectionName, ConsumerModule, []).


-spec subscribe(connection_name(), module(), list()) -> {ok, pid()} | {error, term()}.
subscribe(ConnectionName, ConsumerModule, ConsumerModuleArgs) ->
    true = fox_utils:validate_consumer_behaviour(ConsumerModule),
    ConnectionName2 = fox_utils:name_to_atom(ConnectionName),
    fox_connection_pool_sup:subscribe(ConnectionName2, ConsumerModule, ConsumerModuleArgs).


-spec unsubscribe(connection_name(), pid()) -> ok | {error, term()}.
unsubscribe(ConnectionName, ChannelPid) ->
    ConnectionName2 = fox_utils:name_to_atom(ConnectionName),
    fox_connection_pool_sup:unsubscribe(ConnectionName2, ChannelPid).


-spec declare_exchange(pid(), binary()) -> ok | {error, term()}.
declare_exchange(ChannelPid, Name) when is_binary(Name) ->
    declare_exchange(ChannelPid, Name, maps:new()).


-spec declare_exchange(pid(), binary(), map()) -> ok | {error, term()}.
declare_exchange(ChannelPid, Name, Params) ->
    ExchangeDeclare = fox_utils:map_to_exchange_declare(Params),
    ExchangeDeclare2 = ExchangeDeclare#'exchange.declare'{exchange = Name},
    case fox_utils:channel_call(ChannelPid, ExchangeDeclare2) of
        #'exchange.declare_ok'{} -> ok;
        ok -> ok;
        {error, Reason} -> {error, Reason}
    end.

-spec delete_exchange(pid(), binary()) -> ok | {error, term()}.
delete_exchange(ChannelPid, Name) when is_binary(Name) ->
    delete_exchange(ChannelPid, Name, maps:new()).


-spec delete_exchange(pid(), binary(), map()) -> ok | {error, term()}.
delete_exchange(ChannelPid, Name, Params) ->
    ExchangeDelete = fox_utils:map_to_exchange_delete(Params),
    ExchangeDelete2 = ExchangeDelete#'exchange.delete'{exchange = Name},
    case fox_utils:channel_call(ChannelPid, ExchangeDelete2) of
        #'exchange.delete_ok'{} -> ok;
        {error, Reason} -> {error, Reason}
    end.


-spec declare_queue(pid(), binary()) -> ok | {error, term()}.
declare_queue(ChannelPid, Name) when is_binary(Name) ->
    declare_queue(ChannelPid, Name, maps:new()).


-spec declare_queue(pid(), binary(), map()) -> ok | {error, term()}.
declare_queue(ChannelPid, Name, Params) ->
    QueueDeclare = fox_utils:map_to_queue_declare(Params),
    QueueDeclare2 = QueueDeclare#'queue.declare'{queue = Name},
    case fox_utils:channel_call(ChannelPid, QueueDeclare2) of
        #'queue.declare_ok'{} -> ok;
        ok -> ok;
        {error, Reason} -> {error, Reason}
    end.


-spec delete_queue(pid(), binary()) -> ok | {error, term()}.
delete_queue(ChannelPid, Name) when is_binary(Name) ->
    delete_queue(ChannelPid, Name, maps:new()).


-spec delete_queue(pid(), binary(), map()) -> ok | {error, term()}.
delete_queue(ChannelPid, Name, Params) ->
    QueueDelete = fox_utils:map_to_queue_delete(Params),
    QueueDelete2 = QueueDelete#'queue.delete'{queue = Name},
    case fox_utils:channel_call(ChannelPid, QueueDelete2) of
        #'queue.delete_ok'{} -> ok;
        {error, Reason} -> {error, Reason}
    end.


-spec bind_queue(pid(), binary(), binary(), binary()) -> ok | {error, term()}.
bind_queue(ChannelPid, Queue, Exchange, RoutingKey) ->
    bind_queue(ChannelPid, Queue, Exchange, RoutingKey, maps:new()).


-spec bind_queue(pid(), binary(), binary(), binary(), map()) -> ok | {error, term()}.
bind_queue(ChannelPid, Queue, Exchange, RoutingKey, Params) ->
    QueueBind = fox_utils:map_to_queue_bind(Params),
    QueueBind2 = QueueBind#'queue.bind'{queue = Queue,
                                        exchange = Exchange,
                                        routing_key = RoutingKey},
    case fox_utils:channel_call(ChannelPid, QueueBind2) of
        #'queue.bind_ok'{} -> ok;
        {error, Reason} -> {error, Reason}
    end.


-spec unbind_queue(pid(), binary(), binary(), binary()) -> ok | {error, term()}.
unbind_queue(ChannelPid, Queue, Exchange, RoutingKey) ->
    unbind_queue(ChannelPid, Queue, Exchange, RoutingKey, maps:new()).


-spec unbind_queue(pid(), binary(), binary(), binary(), map()) -> ok | {error, term()}.
unbind_queue(ChannelPid, Queue, Exchange, RoutingKey, Params) ->
    QueueUnbind = fox_utils:map_to_queue_unbind(Params),
    QueueUnbind2 = QueueUnbind#'queue.unbind'{queue = Queue,
                                              exchange = Exchange,
                                              routing_key = RoutingKey},
    case fox_utils:channel_call(ChannelPid, QueueUnbind2) of
        #'queue.unbind_ok'{} -> ok;
        {error, Reason} -> {error, Reason}
    end.


-spec publish(pid(), binary(), binary(), binary()) -> ok | {error, term()}.
publish(ChannelPid, Exchange, RoutingKey, Payload) ->
    publish(ChannelPid, Exchange, RoutingKey, Payload, maps:new()).


-spec publish(pid(), binary(), binary(), binary(), map()) -> ok | {error, term()}.
publish(ChannelPid, Exchange, RoutingKey, Payload, Params) ->
    Publish = fox_utils:map_to_basic_publish(Params),
    Publish2 = Publish#'basic.publish'{exchange = Exchange, routing_key = RoutingKey},
    PBasic = fox_utils:map_to_pbasic(Params),
    Message = #amqp_msg{payload = Payload, props = PBasic},
    fox_utils:channel_cast(ChannelPid, Publish2, Message).


-spec(test_run() -> ok).
test_run() ->
    application:ensure_all_started(fox),

    Params = #{host => "localhost",
               port => 5672,
               virtual_host => <<"/">>,
               username => <<"guest">>,
               password => <<"guest">>},

    ok = validate_params_network(Params),
    {error, {auth_failure, _}} = validate_params_network(Params#{username => <<"Bob">>}),

    create_connection_pool("test_pool", Params),
    {ok, _SChannel} = subscribe("test_pool", sample_channel_consumer),

    timer:sleep(500),

    {ok, PChannel} = create_channel("test_pool"),
    publish(PChannel, <<"my_exchange">>, <<"my_key">>, <<"Hi there!">>),
    publish(PChannel, <<"my_exchange">>, <<"my_key_2">>, <<"Hello!">>),

    timer:sleep(1000),

    %%unsubscribe("test_pool", SChannel),
    %%amqp_channel:close(PChannel),
    %%close_connection_pool("test_pool"),

    ok.
