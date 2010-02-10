%%%-------------------------------------------------------------------
%%% File    : sqlite3.erl
%%% @author Tee Teoh
%%% @copyright 21 Jun 2008 by Tee Teoh 
%%% @version 1.0.0
%%% @doc Library module for sqlite3
%%% @end
%%%-------------------------------------------------------------------
-module(sqlite3).

-behaviour(gen_server).

%% API
-export([open/1, open/2]).
-export([start_link/1, start_link/2]).
-export([stop/0, close/1]).
-export([sql_exec/1, sql_exec/2]).

-export([create_table/2, create_table/3]).
-export([list_tables/0, list_tables/1, table_info/1, table_info/2]).
-export([write/2, write/3]).
-export([update/4, update/5]).
-export([read/4]).
-export([read/2, read/3]).
-export([delete/2, delete/3]).
-export([drop_table/1, drop_table/2]).

-export([create_function/3]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-define('DRIVER_NAME', 'sqlite3_drv').
-record(state, {port, ops = []}).

%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% @spec start_link(Db) -> {ok,Pid} | ignore | {error,Error}
%%      Db = atom()
%% @doc 
%%   Opens a sqlite3 dbase creating one if necessary. The dbase must 
%%   be called Db.db in the current path. start_link/1 can be use 
%%   with stop/0, sql_exec/1, create_table/2, list_tables/0, 
%%   table_info/1, write/2, read/2, delete/2 and drop_table/1. 
%%   There can be only one start_link call per node.
%%
%%   To open multiple dbases on the same node use open/1 or open/2.
%% @end
%%--------------------------------------------------------------------
-type(result() :: {'ok', pid()} | 'ignore' | {'error', any()}).
-spec(start_link/1::(atom()) -> result()).

start_link(Db) ->
    ?MODULE:open(?MODULE, [{db, "./" ++ atom_to_list(Db) ++ ".db"}]).

%%--------------------------------------------------------------------
%% @spec start_link(Db, Options) -> {ok,Pid} | ignore | {error,Error}
%%      Db = atom()
%% @doc 
%%   Opens a sqlite3 dbase creating one if necessary. By default the 
%%   dbase will be called Db.db in the current path. This can be changed 
%%   by passing the option {db, DbFile :: String()}. DbFile must be the 
%%   full path to the sqlite3 db file. start_link/1 can be use with stop/0, 
%%   sql_exec/1, create_table/2, list_tables/0, table_info/1, write/2, 
%%   read/2, delete/2 and drop_table/1. There can be only one start_link 
%%   call per node.
%%
%%   To open multiple dbases on the same node use open/1 or open/2. 
%% @end
%%--------------------------------------------------------------------
-spec(start_link/2::(atom(), [{atom(), any()}]) -> result()).
start_link(Db, Options) ->
    Opts = case proplists:get_value(db, Options) of
	       undefined -> [{db, "./" ++ atom_to_list(Db) ++ ".db"} | Options];
	       _ -> Options
	   end,
    ?MODULE:open(?MODULE, Opts).

%%--------------------------------------------------------------------
%% @spec open(Db :: atom()) -> {ok, Pid::pid()} | ignore | {error, Error}
%% @doc
%%   Opens a sqlite3 dbase creating one if necessary. The dbase must be 
%%   called Db.db in the current path. Can be use to open multiple sqlite3 
%%   dbases per node. Must be use in conjunction with stop/1, sql_exec/2,
%%   create_table/3, list_tables/1, table_info/2, write/3, read/3, delete/3 
%%   and drop_table/2.
%% @end
%%--------------------------------------------------------------------
-spec(open/1::(atom()) -> result()).
open(Db) ->
    ?MODULE:open(Db, [{db, "./" ++ atom_to_list(Db) ++ ".db"}]).

%%--------------------------------------------------------------------
%% @spec open(Db::atom(), Options::[tuple()]) -> {ok, Pid::pid()} | ignore | {error, Error}
%% @doc
%%   Opens a sqlite3 dbase creating one if necessary. By default the dbase 
%%   will be called Db.db in the current path. This can be changed by 
%%   passing the option {db, DbFile :: String()}. DbFile must be the full 
%%   path to the sqlite3 db file. Can be use to open multiple sqlite3 dbases 
%%   per node. Must be use in conjunction with stop/1, sql_exec/2, 
%%   create_table/3, list_tables/1, table_info/2, write/3, read/3, delete/3 
%%   and drop_table/2. 
%% @end
%%--------------------------------------------------------------------
-spec(open/2::(atom(), [{atom(), any()}]) -> result()).
open(Db, Options) ->
    gen_server:start_link({local, Db}, ?MODULE, Options, []).

%%--------------------------------------------------------------------
%% @spec close(Db::atom()) -> ok
%% @doc
%%   Closes the Db sqlite3 dbase. 
%% @end
%%--------------------------------------------------------------------
-spec(close/1::(atom()) -> 'ok').
close(Db) ->
    gen_server:call(Db, close).

%%--------------------------------------------------------------------
%% @spec stop() -> ok
%% @doc
%%   Closes the sqlite3 dbase.
%% @end
%%--------------------------------------------------------------------
-spec(stop/0::() -> 'ok').
stop() ->
    ?MODULE:close(?MODULE).
    
%%--------------------------------------------------------------------
%% @spec sql_exec(Sql::string()) -> term()
%% @doc
%%   Executes the Sql statement directly.
%% @end
%%--------------------------------------------------------------------
-spec(sql_exec/1::(string()) -> any()).
sql_exec(SQL) ->
    ?MODULE:sql_exec(?MODULE, SQL).

%%--------------------------------------------------------------------
%% @spec sql_exec(Db::atom(), Sql::string()) -> term()
%% @doc
%%   Executes the Sql statement directly on the Db dbase. Returns the 
%%   result of the Sql call.
%% @end
%%--------------------------------------------------------------------
-spec(sql_exec/2::(atom(), string()) -> any()).
sql_exec(Db, SQL) ->
    gen_server:call(Db, {sql_exec, SQL}).

%%--------------------------------------------------------------------
%% @spec create_table(Tbl::atom(), TblInfo::[tuple()]) -> term()
%% @doc
%%   Creates the Tbl table using TblInfo as the table structure. The 
%%   table structure is a list of {column name, column type} pairs.
%%   e.g. [{name, text}, {age, integer}]
%%
%%   Returns the result of the create table call.
%% @end
%%--------------------------------------------------------------------
-spec(create_table/2::(atom(), [tuple()]) -> any()).
create_table(Tbl, Options) ->
    ?MODULE:create_table(?MODULE, Tbl, Options).

%%--------------------------------------------------------------------
%% @spec create_table(Db::atom(), Tbl::atom(), TblInfo::[tuple()]) -> term()
%% @doc
%%   Creates the Tbl table in Db using TblInfo as the table structure. 
%%   The table structure is a list of {column name, column type} pairs. 
%%   e.g. [{name, text}, {age, integer}]
%%
%%   Returns the result of the create table call.
%% @end
%%--------------------------------------------------------------------
-spec(create_table/3::(atom(), atom(), [{atom(), any()}]) -> any()).
create_table(Db, Tbl, Options) ->
    gen_server:call(Db, {create_table, Tbl, Options}).

%%--------------------------------------------------------------------
%% @spec list_tables() -> [atom()]
%% @doc
%%   Returns a list of tables.
%% @end
%%--------------------------------------------------------------------
-spec(list_tables/0::() -> [atom()]).
list_tables() ->
    ?MODULE:list_tables(?MODULE).

%%--------------------------------------------------------------------
%% @spec list_tables(Db :: atom()) -> [atom()]
%% @doc
%%   Returns a list of tables for Db.
%% @end
%%--------------------------------------------------------------------
-spec(list_tables/1::(atom()) -> [atom()]).
list_tables(Db) ->
    gen_server:call(Db, list_tables).

%%--------------------------------------------------------------------
%% @spec table_info(Tbl :: atom()) -> [term()]
%% @doc
%%    Returns table schema for Tbl.
%% @end
%%--------------------------------------------------------------------
-spec(table_info/1::(atom()) -> [any()]).
table_info(Tbl) ->
    ?MODULE:table_info(?MODULE, Tbl).

%%--------------------------------------------------------------------
%% @spec table_info(Db::atom(), Tbl::atom()) -> [term()]
%% @doc
%%   Returns table schema for Tbl in Db.
%% @end
%%--------------------------------------------------------------------
-spec(table_info/2::(atom(), atom()) -> [any()]).
table_info(Db, Tbl) ->
    gen_server:call(Db, {table_info, Tbl}).

%%--------------------------------------------------------------------
%% @spec write(Tbl::atom(), Data) -> term()
%%         Data = [{ColName::atom(), ColData::term()}]
%% @doc
%%   Write Data into Tbl table. ColData must be of the same type as 
%%   determined from table_info/2.
%% @end
%%--------------------------------------------------------------------
-spec(write/2::(atom(), [{atom(), any()}]) -> any()).
write(Tbl, Data) ->
    ?MODULE:write(?MODULE, Tbl, Data).

%%--------------------------------------------------------------------
%% @spec write(Db::atom(), Tbl::atom(), Data) -> term()
%%         Data = [{ColName::atom(), ColData::term()}]
%% @doc
%%   Write Data into Tbl table in Db dbase. ColData must be of the 
%%   same type as determined from table_info/3.
%% @end
%%--------------------------------------------------------------------
-spec(write/3::(atom(), atom(), [{atom(), any()}]) -> any()).
write(Db, Tbl, Data) ->
    gen_server:call(Db, {write, Tbl, Data}).

%%--------------------------------------------------------------------
%% @spec update (Tbl::atom (), Key::atom (), Value, Data) -> Result
%%        Value = any ()
%%        Data = [{Column::atom (), Value::string () | integer () | float ()}]
%%        Result = {ok, ID} | Unknown
%%        Unknown = term ()
%% @doc
%%    Updates rows into Tbl table such that the Value matches the 
%%    value in Key with Data. Returns ID of the first updated 
%%    record.
%% @end
%%--------------------------------------------------------------------
update (Tbl, Key, Value, Data) ->
  ?MODULE:update (?MODULE, Tbl, Key, Value, Data).

%%--------------------------------------------------------------------
%% @spec update (Db::atom (), Tbl::atom (), Key::atom (), Value, Data) -> Result
%%        Value = any ()
%%        Data = [{Column::atom (), Value::string () | integer () | float ()}]
%%        Result = {ok, ID} | Unknown
%%        Unknown = term ()
%% @doc
%%    Updates rows into Tbl table in Db dbase such that the Value 
%%    matches the value in Key with Data. Returns ID of the first 
%%    updated record.
%% @end
%%--------------------------------------------------------------------
update (Db, Tbl, Key, Value, Data) ->
  gen_server:call (Db, {update, Tbl, Key, Value, Data}).

%%--------------------------------------------------------------------
%% @spec read(Tbl::atom(), Key) -> [term()]
%%         Key = {ColName::atom(), ColValue::term()}
%% @doc
%%   Reads a row from Tbl table such that the ColValue matches the 
%%   value in ColName. Returns only the first match. ColValue must 
%%   have the same type as determined from table_info/2.
%% @end
%%--------------------------------------------------------------------
-spec(read/2::(atom(), {atom(), any()}) -> any()).
read(Tbl, Key) ->
    ?MODULE:read(?MODULE, Tbl, Key).

%%--------------------------------------------------------------------
%% @spec read(Db::atom(), Tbl::atom(), Key) -> [term()]
%%         Key = {ColName::atom(), ColValue::term()}
%% @doc
%%   Reads a row from Tbl table in Db dbase such that the ColValue 
%%   matches the value in ColName. Returns only the first match. 
%%   ColValue must have the same type as determined from table_info/3.
%% @end
%%--------------------------------------------------------------------
-spec(read/3::(atom(), atom(), {atom(), any()}) -> any()).
read(Db, Tbl, Key) ->
    gen_server:call(Db, {read, Tbl, Key}).

%%--------------------------------------------------------------------
%% @spec read (Db, Tbl, Key, Columns) -> [term ()]
%%        Db = atom ()
%%        Tbl = atom ()
%%        Key = {Column::atom (), Value::term ()}
%%        Columns = [atom ()]
%% @doc
%%    Reads a row from Tbl table in Db dbase such that the Value
%%    matches the value in Column. Returns columns Columns only for
%%    the first match. Value must have the same type as determined
%%    from table_info/3.
%% @end
%%--------------------------------------------------------------------
read (Db, Tbl, Key, Columns) ->
  gen_server:call (Db, {read, Tbl, Key, Columns}).

%%--------------------------------------------------------------------
%% @spec delete(Tbl::atom(), Key) -> term()
%%         Key = {ColName::atom(), ColValue::term()}
%% @doc
%%   Delete a row from Tbl table such that the ColValue 
%%   matches the value in ColName. Removes only the first match. 
%%   ColValue must have the same type as determined from table_info/3.
%% @end
%%--------------------------------------------------------------------
-spec(delete/2::(atom(), {atom(), any()}) -> any()).
delete(Tbl, Key) ->
    ?MODULE:delete(?MODULE, Tbl, Key).

%%--------------------------------------------------------------------
%% @spec delete(Db::atom(), Tbl::atom(), Key) -> term()
%%         Key = {ColName::atom(), ColValue::term()}
%% @doc
%%   Delete a row from Tbl table in Db dbase such that the ColValue 
%%   matches the value in ColName. Removes only the first match. 
%%   ColValue must have the same type as determined from table_info/3.
%% @end
%%--------------------------------------------------------------------
-spec(delete/3::(atom(), atom(), {atom(), any()}) -> any()).
delete(Db, Tbl, Key) ->
    gen_server:call(Db, {delete, Tbl, Key}).

%%--------------------------------------------------------------------
%% @spec drop_table(Tbl::atom()) -> term()
%% @doc
%%   Drop the table Tbl.
%% @end
%%--------------------------------------------------------------------
-spec(drop_table/1::(atom()) -> any()).
drop_table(Tbl) ->
    ?MODULE:drop_table(?MODULE, Tbl).

%%--------------------------------------------------------------------
%% @spec drop_table(Db::atom(), Tbl::atom()) -> term()
%% @doc
%%   Drop the table Tbl from Db dbase.
%% @end
%%--------------------------------------------------------------------
-spec(drop_table/2::(atom(), atom()) -> any()).
drop_table(Db, Tbl) ->
    gen_server:call(Db, {drop_table, Tbl}).


%%--------------------------------------------------------------------
%% @spec create_function(Db::atom(), FunctionName::atom(), Function::function()) -> term()
%% @doc
%%   Creates function under name FunctionName.
%%
%% @end
%%--------------------------------------------------------------------
-spec(create_function/3::(atom(), atom(), function()) -> any()).
create_function(Db, FunctionName, Function) ->
    gen_server:call(Db, {create_function, FunctionName, Function}).


%%====================================================================
%% gen_server callbacks
%%====================================================================

%%--------------------------------------------------------------------
%% @spec init(Args) -> {ok, State} |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% @doc Initiates the server
%% @end
%% @hidden
%%--------------------------------------------------------------------
-type(init_return() :: {'ok', tuple()} | {'ok', tuple(), integer()} | 'ignore' | {'stop', any()}).
-spec(init/1::([any()]) -> init_return()).
init(Options) ->
    Dbase = proplists:get_value(db, Options),
    SearchDir = filename:join([filename:dirname(code:which(?MODULE)), "..", "ebin"]),
    case erl_ddll:load(SearchDir, atom_to_list(?DRIVER_NAME)) of
      ok -> 
        Port = open_port({spawn, string:join ([atom_to_list (?DRIVER_NAME), Dbase], " ")}, [binary]),
        {ok, #state{port = Port, ops = Options}};
      {error, Error} ->
        io:format("Error loading ~p: ~p", [?DRIVER_NAME, erl_ddll:format_error(Error)]),
        {stop, failed}
    end.
		     
%%--------------------------------------------------------------------
%% @spec handle_call(Request, From, State) -> {reply, Reply, State} |
%%                                      {reply, Reply, State, Timeout} |
%%                                      {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, Reply, State} |
%%                                      {stop, Reason, State}
%% @doc Handling call messages
%% @end
%% @hidden
%%--------------------------------------------------------------------
-type(handle_call_return() :: {reply, any(), tuple()} | {reply, any(), tuple(), integer()} |
      {noreply, tuple()} | {noreply, tuple(), integer()} |
      {stop, any(), any(), tuple()} | {stop, any(), tuple()}).
-spec(handle_call/3::(any(), pid(), tuple()) -> handle_call_return()).
handle_call(close, _From, State) ->
    Reply = ok,
    {stop, normal, Reply, State};
handle_call({sql_exec, SQL}, _From, #state{port = Port} = State) ->
    Reply = exec(Port, {sql_exec, SQL}),
    {reply, Reply, State};
handle_call(list_tables, _From, #state{port = Port} = State) ->
    Reply = exec(Port, {sql_exec, "select name from sqlite_master where type='table';"}),
    TableList = proplists:get_value(rows, Reply),
    TableNames = [erlang:list_to_atom (erlang:binary_to_list (Name)) || {Name} <- TableList],
    {reply, TableNames, State};
handle_call({table_info, Tbl}, _From, #state{port = Port} = State) ->
    % make sure we only get table info.
    % SQL Injection warning
    SQL = io_lib:format("select sql from sqlite_master where tbl_name = '~p' and type='table';", [Tbl]),
    Data = exec(Port, {sql_exec, SQL}),
    TableSql = proplists:get_value(rows, Data),
    [{Info}] = TableSql,
    ColumnList = parse_table_info(binary_to_list(Info)),
    {reply, ColumnList, State};
handle_call({create_function, FunctionName, Function}, _From, #state{port = Port} = State) ->
    % make sure we only get table info.
    % SQL Injection warning
    Reply = exec(Port, {create_function, FunctionName, Function}),
    {reply, Reply, State};
handle_call({create_table, Tbl, Options}, _From, #state{port = Port} = State) ->
    SQL = sqlite3_lib:create_table_sql(Tbl, Options),
    Cmd = {sql_exec, SQL},
    Reply = exec(Port, Cmd),
    {reply, Reply, State};
handle_call ({update, Tbl, Key, Value, Data}, _From, #state{port = Port} = State)->
    Reply = exec (Port, {sql_exec, sqlite3_lib:update_sql (Tbl, Key, Value, Data)}),
    {reply, Reply, State};
handle_call({write, Tbl, Data}, _From, #state{port = Port} = State) ->
    % insert into t1 (data,num) values ('This is sample data',3);
    Reply = exec(Port, {sql_exec, sqlite3_lib:write_sql(Tbl, Data)}),
    {reply, Reply, State};
handle_call({read, Tbl, {Key, Value}}, _From, #state{port = Port} = State) ->
    % select * from  Tbl where Key = Value;
    Reply = exec(Port, {sql_exec, sqlite3_lib:read_sql(Tbl, Key, Value)}),
    {reply, Reply, State};
handle_call ({read, Tbl, {Key, Value}, Columns}, _From, #state{port = Port} = State) ->
    Reply = exec (Port, {sql_exec, sqlite3_lib:read_sql (Tbl, Key, Value, Columns)}),
    {reply, Reply, State};
handle_call({delete, Tbl, {Key, Value}}, _From, #state{port = Port} = State) ->
    % delete from Tbl where Key = Value;
    Reply = exec(Port, {sql_exec, sqlite3_lib:delete_sql(Tbl, Key, Value)}),
    {reply, Reply, State};
handle_call({drop_table, Tbl}, _From, #state{port = Port} = State) ->
    Reply = exec(Port, {sql_exec, sqlite3_lib:drop_table(Tbl)}),
    {reply, Reply, State};
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, State}
%% @doc Handling cast messages
%% @end
%% @hidden
%%--------------------------------------------------------------------
-type(handle_cast_return() :: {noreply, tuple()} | {noreply, tuple(), integer()} |
      {stop, any(), tuple()}).
-spec(handle_cast/2::(any(), tuple()) -> handle_cast_return()).
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% @doc Handling all non call/cast messages
%% @end
%% @hidden
%%--------------------------------------------------------------------
-spec(handle_info/2::(any(), tuple()) -> handle_cast_return()).
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @spec terminate(Reason, State) -> void()
%% @doc This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
%% @end
%% @hidden
%%--------------------------------------------------------------------
-spec(terminate/2::(atom(), tuple()) -> atom()).
terminate(normal, #state{port = Port}) ->
    port_command(Port, term_to_binary({close, nop})),
    port_close(Port),
    ok;
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% Func: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @doc Convert process state when code is changed
%% @end
%% @hidden
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------

-define(SQL_EXEC_COMMAND, 2).
-define(SQL_CREATE_FUNCTION, 3).

create_cmd(Dbase) ->
    "sqlite3_port " ++ Dbase.

wait_result(Port) ->
  receive
	  {Port, Reply} ->
      % io:format("Reply: ~p~n", [Reply]),
	    Reply;
  {error, Reason} ->
    io:format("Error: ~p~n", [Reason]),
    {error, Reason};
	_Else ->
    io:format("Else: ~p~n", [_Else]),
	  _Else
  end.

exec(_Port, {create_function, _FunctionName, _Function}) ->
  error_logger:error_report ([{application, sqlite3}, "NOT IMPL YET"]);
  %port_control(Port, ?SQL_CREATE_FUNCTION, list_to_binary(Cmd)),
  %wait_result(Port);


exec(Port, {sql_exec, Cmd}) ->
  port_control(Port, ?SQL_EXEC_COMMAND, list_to_binary(Cmd)),
  wait_result(Port).
 

parse_table_info(Info) ->
    [_, Tail] = string:tokens(Info, "()"),
    Cols = string:tokens(Tail, ","), 
    build_table_info(lists:map(fun(X) ->
				       string:tokens(X, " ") 
			       end, Cols), []).
   
build_table_info([], Acc) -> 
    lists:reverse(Acc);
build_table_info([[ColName, ColType] | Tl], Acc) -> 
    build_table_info(Tl, [{list_to_atom(ColName), sqlite3_lib:col_type(ColType)}| Acc]); 
build_table_info([[ColName, ColType, "PRIMARY", "KEY"] | Tl], Acc) ->
    build_table_info(Tl, [{list_to_atom(ColName), primary_key}| Acc]).
    
