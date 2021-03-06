-module(oidcc).

-export([add_openid_provider/6]).
-export([add_openid_provider/7]).
-export([add_openid_provider/8]).
-export([find_openid_provider/1]).
-export([get_openid_provider_info/1]).
-export([get_openid_provider_list/0]).
-export([create_redirect_url/1]).
-export([create_redirect_url/2]).
-export([create_redirect_url/3]).
-export([create_redirect_url/4]).
-export([create_redirect_url/5]).
-export([create_redirect_for_session/1]).
-export([retrieve_token/2]).
-export([retrieve_token/3]).
-export([parse_and_validate_token/2]).
-export([parse_and_validate_token/3]).
-export([retrieve_user_info/2]).
-export([retrieve_user_info/3]).
-export([retrieve_fresh_token/2]).
-export([retrieve_fresh_token/3]).
-export([introspect_token/2]).
-export([register_module/1]).


%% @doc
%% add an OpenID Connect Provider to the list of possible Providers
%%
%% this automatically triggers the fetching of the configuration endpoint
%% and after that fetching the keys for verifying the signature of the
%% ID Tokens.
%% @end
-spec add_openid_provider(binary(), binary(), binary(), binary(), binary(),
                          binary()) -> {ok, Id::binary(), Pid::pid()}.
add_openid_provider(Name, Description, ClientId, ClientSecret, ConfigEndpoint,
                    LocalEndpoint) ->
    add_openid_provider(undefined, Name, Description, ClientId, ClientSecret,
                        ConfigEndpoint, LocalEndpoint, undefined).

%% @doc
%% add an OpenID Connect Provider to the list of possible Providers, giving the
%% ID to use
%%
%% this automatically triggers the fetching of the configuration endpoint
%% and after that fetching the keys for verifying the signature of the
%% ID Tokens.
%% @end
-spec add_openid_provider(binary(), binary(), binary(), binary(), binary()
                         , binary(), binary()) ->
                                 {ok, Id::binary(), Pid::pid()}|
                                 {error, id_already_used}.
add_openid_provider(IdIn, Name, Description, ClientId, ClientSecret,
                    ConfigEndpoint, LocalEndpoint) ->
    add_openid_provider(IdIn, Name, Description, ClientId, ClientSecret,
                        ConfigEndpoint, LocalEndpoint, undefined).

-spec add_openid_provider(Id, Name, Description, ClientId, ClientSecret,
                          ConfigEndpoint, LocalEndpoint, Scopes) ->
                                 {ok, Id::binary(), Pid::pid()}|
                                 {error, id_already_used} when
      Id :: binary() | undefined,
      Name :: binary(),
      Description :: binary(),
      ClientId :: binary(),
      ClientSecret :: binary(),
      ConfigEndpoint :: binary(),
      LocalEndpoint :: binary(),
      Scopes :: list() | undefined.
add_openid_provider(IdIn, Name, Description, ClientId, ClientSecret,
                    ConfigEndpoint, LocalEndpoint, Scopes) ->
    Config = #{name => Name,
               description => Description,
               client_id => ClientId,
               client_secrect => ClientSecret,
               config_endpoint => ConfigEndpoint,
               local_endpoint => LocalEndpoint,
               request_scopes => Scopes
              },
    oidcc_openid_provider_mgr:add_openid_provider(IdIn, Config).


-spec find_openid_provider(Issuer::binary()) -> {ok, pid()}
                                                    | {error, not_found}.
find_openid_provider(Issuer) ->
    oidcc_openid_provider_mgr:find_openid_provider(Issuer).

%% @doc
%% get information from a given OpenId Connect Provider
%%
%% the parameter can either be the Pid or it's Id. The result is a map
%% containing all the information gathered by connecting to the configuration
%% endpoint given at the beginning.
%% the map also contains a boolean flag 'ready' which is true, once the
%% configuration has been fetched.
%% @end
-spec get_openid_provider_info(pid() | binary()) -> {ok, map()}.
get_openid_provider_info(Pid) when is_pid(Pid) ->
    oidcc_openid_provider:get_config(Pid);
get_openid_provider_info(OpenIdProviderId) when is_binary(OpenIdProviderId) ->
    case oidcc_openid_provider_mgr:get_openid_provider(OpenIdProviderId) of
        {ok, Pid} ->
            oidcc_openid_provider:get_config(Pid);
        {error, Reason} ->
            {error, Reason}
    end.


%% @doc
%% get a list of all currently configured OpenId Connect Provider
%%
%% it is a list of tuples {Id, Pid}
%% @end
-spec get_openid_provider_list() -> {ok, [{binary(), pid()}]}.
get_openid_provider_list() ->
    oidcc_openid_provider_mgr:get_openid_provider_list().

%% @doc
%% same as create_redirect_url/4 but with all parameters being fetched
%% from the given session, except the provider
%% @end
-spec create_redirect_for_session(pid()) -> {ok, binary()}.
create_redirect_for_session(Session) ->
    {ok, Scopes} = oidcc_session:get_scopes(Session),
    {ok, State} = oidcc_session:get_id(Session),
    {ok, Nonce} = oidcc_session:get_nonce(Session),
    {ok, Pkce} = oidcc_session:get_pkce(Session),
    {ok, OpenIdProviderId} = oidcc_session:get_provider(Session),
    create_redirect_url(OpenIdProviderId, Scopes, State, Nonce, Pkce).

%% @doc
%% same as create_redirect_url/4 but with State and Nonce being undefined and
%% scope being openid
%% @end
-spec create_redirect_url(binary()) ->
                                 {ok, binary()} | {error, provider_not_ready}.
create_redirect_url(OpenIdProviderId) ->
    create_redirect_url(OpenIdProviderId, [<<"openid">>], undefined, undefined,
                        undefined).

%% @doc
%% same as create_redirect_url/4 but with State and Nonce being undefined
%% @end
-spec create_redirect_url(binary(), list()) ->
                                 {ok, binary()} | {error, provider_not_ready}.
create_redirect_url(OpenIdProviderId, Scopes) ->
    create_redirect_url(OpenIdProviderId, Scopes, undefined, undefined,
                        undefined).

%% @doc
%% same as create_redirect_url/4 but with Nonce being undefined
%% @end
-spec create_redirect_url(binary(), list(), binary()) ->
                                 {ok, binary()} | {error, provider_not_ready}.
create_redirect_url(OpenIdProviderId, Scopes, OidcState) ->
    create_redirect_url(OpenIdProviderId, Scopes, OidcState, undefined,
                        undefined).

%% @doc
%% create a redirection for the given OpenId Connect provider
%%
%% this can be used to redirect the useragent of the ressource owner
%% to the OpenId Connect Provider
%% @end
-spec create_redirect_url(binary(), list(), binary(), binary()) ->
                                 {ok, binary()} | {error, provider_not_ready}.
create_redirect_url(OpenIdProviderId, Scopes, OidcState, OidcNonce ) ->
    create_redirect_url(OpenIdProviderId, Scopes, OidcState, OidcNonce,
                        undefined).


%% @doc
%% create a redirection for the given OpenId Connect provider
%%
%% also setting the Pkce Map to perform a code challenge
%% @end
-spec create_redirect_url(ProviderId, Scopes, OidcState, OidcNonce, Pkce) ->
                                 {ok, binary()} |
                                 {error, provider_no_ready} when
      ProviderId :: binary(),
      Scopes :: list(),
      OidcState :: binary() | undefined,
      OidcNonce :: binary() | undefined,
      Pkce :: binary() | undefined.
create_redirect_url(OpenIdProviderId, Scopes, OidcState, OidcNonce, Pkce ) ->
    {ok, Info} = get_openid_provider_info(OpenIdProviderId),
    create_redirect_url_if_ready(Info, Scopes, OidcState, OidcNonce, Pkce).

%% @doc
%% retrieve the token using the authcode received before
%%
%% the authcode was sent to the local endpoint by the OpenId Connect provider,
%% using redirects. the result is textual representation of the token and should
%% be verified using parse_and_validate_token/3
%% @end
-spec retrieve_token(binary(), binary()) -> {ok, binary()}.
retrieve_token(AuthCode, OpenIdProviderId) ->
    retrieve_token(AuthCode, undefined, OpenIdProviderId).

-spec retrieve_token(binary(), map() | undefined, binary()) -> {ok, binary()}.
retrieve_token(AuthCode, Pkce, OpenIdProviderId) ->
    {ok, Info} = get_openid_provider_info(OpenIdProviderId),
    #{local_endpoint := LocalEndpoint} = Info,
    QsBody = [ {<<"grant_type">>, <<"authorization_code">>},
                {<<"code">>, AuthCode},
                {<<"redirect_uri">>, LocalEndpoint}
              ],
    retrieve_a_token(QsBody, Pkce, Info).


%% @doc
%% like parse_and_validate_token/3 yet without checking the nonce
%% @end
-spec parse_and_validate_token(binary(), binary()) ->
                                      {ok, map()} | {error, any()}.
parse_and_validate_token(Token, OpenIdProvider) ->
    parse_and_validate_token(Token, OpenIdProvider, undefined).
%% @doc
%%
%% also validates the token according to the OpenID Connect spec, see
%% source of oidcc_token:validate_id_token/1 for more information
%% @end
-spec parse_and_validate_token(Token, Provider, Nonce) ->
                                      {ok, map()} | {error, any()}
                                          when
      Token :: binary(),
      Provider :: binary(),
      Nonce :: binary() | any | undefined.
parse_and_validate_token(Token, OpenIdProvider, Nonce) ->
    TokenMap = oidcc_token:extract_token_map(Token),
    oidcc_token:validate_token_map(TokenMap, OpenIdProvider, Nonce).

%% @doc
%% retrieve the informations of a user given by its token map
%%
%% this is done by looking up the UserInfoEndpoint from the configuration and
%% then requesting info, using the access token as bearer token
%% @end
-spec retrieve_user_info(map() | binary(), binary()) ->
                                {ok, map()} | {error, any()}.
retrieve_user_info(Token, OpenIdProvider) ->
    Subject = extract_subject(Token),
    retrieve_user_info(Token, OpenIdProvider, Subject).


-spec retrieve_user_info(Token, ProviderOrConfig, Subject)-> {ok, map()} |
                                                             {error, any()} when
      Token :: binary() | map(),
      ProviderOrConfig :: binary() | map(),
      Subject :: binary() | undefined.
retrieve_user_info(Token, #{userinfo_endpoint := Endpoint}, Subject) ->
    AccessToken = extract_access_token(Token),
    Header = [bearer_auth(AccessToken)],
    HttpResult = oidcc_http_util:sync_http(get, Endpoint, Header, undefined),
    return_validated_user_info(HttpResult, Subject);
retrieve_user_info(Token, OpenIdProvider, Subject) ->
    {ok, Config} = get_openid_provider_info(OpenIdProvider),
    retrieve_user_info(Token, Config, Subject).



retrieve_fresh_token(RefreshToken, OpenIdProvider) ->
    retrieve_fresh_token(RefreshToken, [], OpenIdProvider).

retrieve_fresh_token(RefreshToken, Scopes, OpenIdProvider) ->
    {ok, Config} = get_openid_provider_info(OpenIdProvider),
    BodyQs0 = [
              {<<"refresh_token">>, RefreshToken},
              {<<"grant_type">>, <<"refresh_token">>}
             ],
    BodyQs = append_scope(Scopes, BodyQs0),
    retrieve_a_token(BodyQs, Config).


%% @doc
%% introspect the given token at the given provider
%%
%% this is done by looking up the IntrospectionEndpoint from the configuration
%% and then requesting info, using the client credentials as authentication
%% @end
-spec introspect_token(Token, ProviderOrConfig) -> {ok, map()} |
                                                   {error, any()} when
      Token :: binary() | map(),
      ProviderOrConfig :: binary() | map().
introspect_token(Token, #{introspection_endpoint := Endpoint,
                          client_id := ClientId,
                          client_secret := ClientSecret}) ->
    AccessToken = extract_access_token(Token),
    Header = [
              {<<"accept">>, <<"application/json">>},
              {<<"content-type">>, <<"application/x-www-form-urlencoded">>},
              basic_auth(ClientId, ClientSecret)
             ],
    BodyQs = cow_qs:qs([{<<"token">>, AccessToken}]),
    HttpResult = oidcc_http_util:sync_http(post, Endpoint, Header, BodyQs),
    return_json_info(HttpResult);
introspect_token(Token, ProviderId) ->
    {ok, Config} = get_openid_provider_info(ProviderId),
    introspect_token(Token, Config).

register_module(Module) ->
    oidcc_client:register(Module).


retrieve_a_token(QsBodyIn, OpenIdProviderInfo) ->
    retrieve_a_token(QsBodyIn, undefined, OpenIdProviderInfo).

retrieve_a_token(QsBodyIn, Pkce, OpenIdProviderInfo) ->
    #{ client_id := ClientId,
       client_secret := Secret,
       token_endpoint := Endpoint,
       token_endpoint_auth_methods_supported := AuthMethods
     } = OpenIdProviderInfo,
    AuthMethod = select_preferred_auth(AuthMethods),
    Header0 = [ {<<"content-type">>, <<"application/x-www-form-urlencoded">>}],
    {QsBody, Header} = add_authentication_code_verifier(QsBodyIn, Header0,
                                                        AuthMethod, ClientId,
                                                        Secret, Pkce),
    Body = cow_qs:qs(QsBody),
    return_token(oidcc_http_util:sync_http(post, Endpoint, Header, Body)).


extract_subject(#{id := IdToken}) ->
    extract_subject(IdToken);
extract_subject(#{sub := Subject}) ->
    Subject;
extract_subject(_) ->
    undefined.

extract_access_token(#{access := AccessToken}) ->
    #{token := Token} = AccessToken,
    Token;
extract_access_token(#{token := Token}) ->
    Token;
extract_access_token(Token) when is_binary(Token) ->
    Token.



create_redirect_url_if_ready(#{ready := false}, _, _, _, _) ->
    {error, provider_not_ready};
create_redirect_url_if_ready(Info, Scopes, OidcState, OidcNonce, Pkce) ->
    #{ local_endpoint := LocalEndpoint,
       client_id := ClientId,
       authorization_endpoint := AuthEndpoint
     } = Info,
    UrlList = [
               {<<"response_type">>, <<"code">>},
               {<<"client_id">>, ClientId},
               {<<"redirect_uri">>, LocalEndpoint}
              ],
    UrlList1 = append_state(OidcState, UrlList),
    UrlList2 = append_nonce(OidcNonce, UrlList1),
    UrlList3 = append_code_challenge(Pkce, UrlList2),
    UrlList4 = append_scope(Scopes, UrlList3),
    Qs = cow_qs:qs(UrlList4),
    Url = << AuthEndpoint/binary, <<"?">>/binary, Qs/binary>>,
    {ok, Url}.


append_scope(<<>>, QsList) ->
    QsList;
append_scope(Scope, QsList) when is_binary(Scope) ->
    [{<<"scope">>, Scope} | QsList];
append_scope(Scopes, QsList) when is_list(Scopes) ->
    append_scope(scopes_to_bin(Scopes, <<>>), QsList).



append_state(State, UrlList) when is_binary(State) ->
    [{<<"state">>, State} | UrlList];
append_state(_, UrlList)  ->
    UrlList.


append_nonce(Nonce, UrlList) when is_binary(Nonce) ->
    [{<<"nonce">>, Nonce} | UrlList];
append_nonce(_, UrlList) ->
    UrlList.

append_code_challenge(#{challenge := Challenge} = Pkce, UrlList) ->
    NewUrlList = [{<<"code_challenge">>, Challenge} | UrlList],
    append_code_challenge_method(Pkce, NewUrlList);
append_code_challenge(_, UrlList) ->
    UrlList.

append_code_challenge_method(#{method := 'S256'}, UrlList) ->
    [{<<"code_challenge_method">>, <<"S256">>} | UrlList];
append_code_challenge_method(_, UrlList) ->
    [{<<"code_challenge_method">>, <<"plain">>} | UrlList].

select_preferred_auth(AuthMethodsSupported) ->
    Selector = fun(Method, Current) ->
                       case {Method, Current} of
                           {_, basic} -> basic;
                           {<<"client_secret_basic">>, _} -> basic;
                           {<<"client_secret_post">>, _} -> post;
                           {_, Current} -> Current
                       end
               end,
    lists:foldl(Selector, undefined, AuthMethodsSupported).


add_authentication_code_verifier(QsBodyList, Header, basic, ClientId, Secret,
                                 undefined) ->
    NewHeader = [basic_auth(ClientId, Secret)| Header ],
    {QsBodyList, NewHeader};
add_authentication_code_verifier(QsBodyList, Header, post, ClientId,
                                 ClientSecret, undefined) ->
    NewBodyList = [ {<<"client_id">>, ClientId},
                    {<<"client_secret">>, ClientSecret} | QsBodyList ],
    {NewBodyList, Header};
add_authentication_code_verifier(B, H, undefined, CI, CS, undefined) ->
    add_authentication_code_verifier(B, H, basic, CI, CS, undefined);
add_authentication_code_verifier(BodyQs, Header, AuthMethod, CI, CS,
                                 #{verifier:=CV}) ->
    BodyQs1 = [{<<"code_verifier">>, CV} | BodyQs],
    add_authentication_code_verifier(BodyQs1, Header, AuthMethod, CI, CS,
                                     undefined).


return_token( {ok, #{body := Token, status := 200}} ) ->
    {ok, Token};
return_token( {ok, #{body := Body, status := Status}} ) ->
    {error, {http_error, Status, Body}}.


return_validated_user_info(HttpData, undefined) ->
    return_json_info(HttpData);
return_validated_user_info(HttpData, Subject) ->
    case return_json_info(HttpData) of
        {ok, #{ sub := Subject } = Map} -> {ok, Map};
        {ok, _} -> {error, bad_subject};
        Other -> Other
    end.

return_json_info({ok, #{status := 200, body := Data}}) ->
    try jsx:decode(Data, [{labels, attempt_atom}, return_maps])
    of Map -> {ok, Map}
    catch Error -> {error, Error}
    end;
return_json_info({ok, Map}) ->
    {error, {bad_status, Map}}.


basic_auth(User, Secret) ->
    UserEnc = cow_qs:urlencode(User),
    SecretEnc = cow_qs:urlencode(Secret),
    RawAuth = <<UserEnc/binary, <<":">>/binary, SecretEnc/binary>>,
    AuthData = base64:encode(RawAuth),
    BasicAuth = << <<"Basic ">>/binary, AuthData/binary >>,
    {<<"authorization">>, BasicAuth}.

bearer_auth(Token) ->
    {<<"authorization">>, << <<"Bearer ">>/binary, Token/binary >>}.


scopes_to_bin([], Bin) ->
    Bin;
scopes_to_bin([H | T], <<>>) when is_binary(H) ->
    scopes_to_bin(T, H);
scopes_to_bin([H | T], Bin) when is_binary(H) ->
    NewBin = << H/binary, <<" ">>/binary, Bin/binary>>,
    scopes_to_bin(T, NewBin);
scopes_to_bin([H | T], Bin) when is_atom(H) ->
    List = [ atom_to_binary(H, utf8) | T],
    scopes_to_bin(List, Bin);
scopes_to_bin([H | T], Bin) when is_list(H) ->
    List = [ list_to_binary(H) | T],
    scopes_to_bin(List, Bin).

