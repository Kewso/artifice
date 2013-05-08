-module(artifice_brain_nn).
-behaviour(artifice_brain).

-compile(export_all).

%%% artifice_brain callbacks
-export([random/0]).
-export([crossover/2]).
-export([mutate/1]).
-export([react/2]).

-include("common.hrl").

%% Network node count parameters. Refers to the input,
%% hidden and output layers respectively.
-define(INPUT_COUNT,  6).
-define(OUTPUT_COUNT, 4).
-define(HIDDEN_COUNT, 2).
-define(WEIGHT_COUNT, ?HIDDEN_COUNT * (?INPUT_COUNT + ?OUTPUT_COUNT)).

-define(FLOAT_BITS, 32). % Default IEEE 754 single precision float

-record(nn, {
          hidden_weights :: [[float()]],
          output_weights :: [[float()]]
         }).

%%% artifice_brain callbacks ---------------------------------------------------

random() ->
    random:seed(erlang:now()),
    HW = random_layer(?HIDDEN_COUNT, ?INPUT_COUNT),
    OW = random_layer(?OUTPUT_COUNT, ?HIDDEN_COUNT),
    #nn{hidden_weights=HW,
        output_weights=OW}.

crossover(Brain1, _) ->
    Brain1. % no fair!

mutate(Brain) ->
    Brain. % derp

react(Brain, Percept) ->
    {pid, Pid} = lists:keyfind(pid, 1, Percept),
    {energy, Energy} = lists:keyfind(energy, 1, Percept),
    {pos, {X, Y}=Pos} = lists:keyfind(pos, 1, Percept),
    {creatures, Creatures} = lists:keyfind(creatures, 1, Percept),
    {CX, CY} = vector_to_nearest_creature(Pos, Creatures),
    [N, S, W, E] = activate_network([Energy,
                                     X, Y,
                                     CX, CY,
                                     length(Creatures)],
                                    Brain),
    if
        N >= 1 -> artifice_creature:move(Pid, north);
        S >= 1 -> artifice_creature:move(Pid, south);
        W >= 1 -> artifice_creature:move(Pid, west);
        E >= 1 -> artifice_creature:move(Pid, east);
        true   -> ok
    end.

%%% Internal -------------------------------------------------------------------

activate_network(Inputs, #nn{hidden_weights=HW, output_weights=OW}) ->
    HOut = activate_layer(Inputs, HW),
    activate_layer(HOut, OW).

activate_layer(Inputs, Weights) ->
    [activate_neuron(Inputs, W) || W <- Weights].

activate_neuron(Inputs, Weights) ->
    actually_activate_neuron(Inputs, Weights, 0.0).

actually_activate_neuron([I|Is], [W|Ws], Sum) ->
    actually_activate_neuron(Is, Ws, W*I + Sum);
actually_activate_neuron([], [], Sum) ->
    Sum.

random_layer(NumNeurons, NumInputs) ->
    [random_neuron(NumInputs) || _ <- lists:seq(1, NumNeurons)].

random_neuron(NumWeights) ->
    [random_weight() || _ <- lists:seq(1, NumWeights)].

random_weight() ->
    (random:uniform()-0.5) * 10.0. % TODO twiddle for glory

pack_floats(Floats) ->
    actually_pack_floats(Floats, <<>>).

actually_pack_floats([F|Fs], Acc) ->
    actually_pack_floats(Fs, <<Acc/binary, F:?FLOAT_BITS/float>>);
actually_pack_floats([], Acc) ->
    Acc.

unpack_floats(N, Buf) ->
    actually_unpack_floats(N, Buf, []).

actually_unpack_floats(0, Buf, Acc) ->
    {lists:reverse(Acc), Buf};
actually_unpack_floats(N, <<F:?FLOAT_BITS/float, Rest/binary>>, Acc) ->
    actually_unpack_floats(N-1, Rest, [F|Acc]).

vector_to_nearest_creature({X1, Y1}=MyPos, [C|Cs]) ->
    {X2, Y2} =
        lists:foldl(
          fun(#creature{pos=ItsPos}, LeaderPos) ->
                  ItsDist    = artifice_util:squared_distance(MyPos, ItsPos),
                  LeaderDist = artifice_util:squared_distance(MyPos, LeaderPos),
                  case ItsDist < LeaderDist of
                      true  -> ItsPos;
                      false -> LeaderPos
                  end
          end,
          C#creature.pos,
          Cs),
    {X1-X2, Y1-Y2};
vector_to_nearest_creature(_MyPos, []) ->
    {0, 0}. % TODO placeholder vector