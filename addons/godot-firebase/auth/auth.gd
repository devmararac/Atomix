
## @meta-authors TODO
## @meta-version 2.5
## The authentication API for Firebase.
## Documentation TODO.
@tool
class_name FirebaseAuth
extends HTTPRequest

const _API_VERSION : String = "v1"
const _INAPP_PLUGIN : String = "GodotSvc"

signal auth_request(result_code, result_content)
signal signup_succeeded(auth_result)
signal login_succeeded(auth_result)
signal login_failed(code, message)
signal signup_failed(code, message)
signal userdata_received(userdata)
signal token_exchanged(successful)
signal token_refresh_succeeded(auth_result)
signal logged_out()

signal reauthentication_completed(success: bool, result: Dictionary)
signal credential_operation_completed(operation: String, success: bool, result: Dictionary)
signal password_change_completed(success: bool, result: Dictionary)
signal account_verification_completed(success: bool, result: Dictionary)

const RESPONSE_SIGNUP : String = "identitytoolkit#SignupNewUserResponse"
const RESPONSE_SIGNIN : String = "identitytoolkit#VerifyPasswordResponse"
const RESPONSE_ASSERTION : String = "identitytoolkit#VerifyAssertionResponse"
const RESPONSE_USERDATA : String = "identitytoolkit#GetAccountInfoResponse"
const RESPONSE_CUSTOM_TOKEN : String = "identitytoolkit#VerifyCustomTokenResponse"

var _base_url : String = ""
var _refresh_request_base_url = ""
var _signup_request_url : String = "accounts:signUp?key=%s"
var _signin_with_oauth_request_url : String = "accounts:signInWithIdp?key=%s"
var _signin_request_url : String = "accounts:signInWithPassword?key=%s"
var _signin_custom_token_url : String = "accounts:signInWithCustomToken?key=%s"
var _userdata_request_url : String = "accounts:lookup?key=%s"
var _oobcode_request_url : String = "accounts:sendOobCode?key=%s"
var _delete_account_request_url : String = "accounts:delete?key=%s"
var _update_account_request_url : String = "accounts:update?key=%s"

var _refresh_request_url : String = "/v1/token?key=%s"
var _google_auth_request_url : String = "https://accounts.google.com/o/oauth2/v2/auth?"

var _config : Dictionary = {}
var auth : Dictionary = {}
var _needs_refresh : bool = false
var is_busy : bool = false
var has_child : bool = false
var is_oauth_login: bool = false

var tcp_server : TCPServer = TCPServer.new()
var tcp_timer : Timer = Timer.new()
var tcp_timeout : float = 0.5

var _headers : PackedStringArray = [
	"Content-Type: application/json",
	"Accept: application/json",
]

var requesting : int = -1

enum Requests {
	NONE = -1,
	EXCHANGE_TOKEN,
	LOGIN_WITH_OAUTH,
	REAUTHENTICATE,
	VERIFY_CHANGE_EMAIL,
	CHANGE_PASSWORD,
	VERIFY_ACCOUNT_EMAIL
}

var auth_request_type : int = -1

enum Auth_Type {
	NONE = -1,
	LOGIN_EP,
	LOGIN_ANON,
	LOGIN_CT,
	LOGIN_OAUTH,
	SIGNUP_EP
}

var _login_request_body : Dictionary = {
	"email": "",
	"password": "",
	"returnSecureToken": true,
}

var _reauthenticate_request_body: Dictionary = {
	"email": "",
	"password": "",
	"returnSecureToken": true
}

var _oauth_login_request_body : Dictionary = {
	"postBody": "",
	"requestUri": "",
	"returnIdpCredential": false,
	"returnSecureToken": true
}

var _anonymous_login_request_body : Dictionary = {
	"returnSecureToken": true
}

var _refresh_request_body : Dictionary = {
	"grant_type": "refresh_token",
	"refresh_token": "",
}

var _custom_token_body : Dictionary = {
	"token": "",
	"returnSecureToken": true
}

var _password_reset_body : Dictionary = {
	"requestType": "password_reset",
	"email": "",
}

var _change_email_body : Dictionary = {
	"idToken": "",
	"email": "",
	"returnSecureToken": true,
}

var _change_password_body : Dictionary = {
	"idToken": "",
	"password": "",
	"returnSecureToken": true,
}

var _verify_change_email_body: Dictionary = {
	"requestType": "VERIFY_AND_CHANGE_EMAIL",
	"idToken": "",
	"newEmail": ""
}

var _account_verification_body: Dictionary = {
	"requestType": "VERIFY_EMAIL",
	"idToken": ""
}

var _update_profile_body : Dictionary = {
	"idToken": "",
	"displayName": "",
	"photoUrl": "",
	"deleteAttribute": "",
	"returnSecureToken": true
}

var link_account_body : Dictionary = {
	"idToken": "",
	"email": "",
	"password": "",
	"returnSecureToken": true
}

var _local_port : int = 8060
var _local_uri : String = "http://localhost:%s/" % _local_port
var _local_provider : AuthProvider = AuthProvider.new()


func _ready() -> void:
	tcp_timer.wait_time = tcp_timeout
	tcp_timer.timeout.connect(_tcp_stream_timer)

	Utilities.fix_http_request(self)
	if Utilities.is_web():
		_local_uri += "tmp_js_export.html"


func _set_config(config_json : Dictionary) -> void:
	_config = config_json
	_signup_request_url %= _config.apiKey
	_signin_request_url %= _config.apiKey
	_signin_custom_token_url %= _config.apiKey
	_signin_with_oauth_request_url %= _config.apiKey
	_userdata_request_url %= _config.apiKey
	_refresh_request_url %= _config.apiKey
	_oobcode_request_url %= _config.apiKey
	_delete_account_request_url %= _config.apiKey
	_update_account_request_url %= _config.apiKey

	request_completed.connect(_on_FirebaseAuth_request_completed)
	_check_emulating()


func _check_emulating() -> void:
	if not Firebase.emulating:
		_base_url = "https://identitytoolkit.googleapis.com/{version}/".format({version = _API_VERSION})
		_refresh_request_base_url = "https://securetoken.googleapis.com"
	else:
		var port : String = _config.emulators.ports.authentication
		if port == "":
			Firebase._printerr("You are in 'emulated' mode, but the port for Authentication has not been configured.")
		else:
			_base_url = "http://localhost:{port}/identitytoolkit.googleapis.com/{version}/".format({
				version = _API_VERSION,
				port = port
			})
			_refresh_request_base_url = "http://localhost:{port}/securetoken.googleapis.com".format({port = port})


func _is_ready() -> bool:
	if is_busy:
		Firebase._printerr("Firebase Auth is currently busy and cannot process this request")
		return false
	return true


func _clean_url(_url):
	_url = _url.replace(" ", "%20")
	return _url


func is_logged_in() -> bool:
	return auth != null and auth.has("idtoken")


func signup_with_email_and_password(email : String, password : String) -> void:
	if _is_ready():
		is_busy = true
		_login_request_body.email = email
		_login_request_body.password = password
		auth_request_type = Auth_Type.SIGNUP_EP
		var err = request(_base_url + _signup_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_login_request_body))
		_login_request_body.email = ""
		_login_request_body.password = ""
		if err != OK:
			is_busy = false
			Firebase._printerr("Error signing up with password and email: %s" % err)


func login_anonymous() -> void:
	if _is_ready():
		is_busy = true
		auth_request_type = Auth_Type.LOGIN_ANON
		var err = request(_base_url + _signup_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_anonymous_login_request_body))
		if err != OK:
			is_busy = false
			Firebase._printerr("Error logging in as anonymous: %s" % err)


func login_with_email_and_password(email : String, password : String) -> void:
	if _is_ready():
		is_busy = true
		_login_request_body.email = email
		_login_request_body.password = password
		auth_request_type = Auth_Type.LOGIN_EP
		var err = request(_base_url + _signin_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_login_request_body))
		_login_request_body.email = ""
		_login_request_body.password = ""
		if err != OK:
			is_busy = false
			Firebase._printerr("Error logging in with password and email: %s" % err)


func login_with_custom_token(token : String) -> void:
	if _is_ready():
		is_busy = true
		_custom_token_body.token = token
		auth_request_type = Auth_Type.LOGIN_CT
		var err = request(_base_url + _signin_custom_token_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_custom_token_body))
		if err != OK:
			is_busy = false
			Firebase._printerr("Error logging in with custom token: %s" % err)


func get_auth_localhost(provider: AuthProvider = get_GoogleProvider(), port : int = _local_port):
	get_auth_with_redirect(provider)
	await get_tree().create_timer(0.5).timeout
	if has_child == false:
		add_child(tcp_timer)
		has_child = true
		tcp_timer.start()
		tcp_server.listen(port, "*")


func get_auth_with_redirect(provider: AuthProvider) -> void:
	var url_endpoint: String = provider.redirect_uri
	for key in provider.params.keys():
		url_endpoint += key + "=" + provider.params[key] + "&"
	url_endpoint += provider.params.redirect_type + "=" + _local_uri
	url_endpoint = _clean_url(url_endpoint)
	if Utilities.is_web():
		JavaScriptBridge.eval('window.location.replace("' + url_endpoint + '")')
	elif Engine.has_singleton(_INAPP_PLUGIN) and OS.get_name() == "iOS":
		set_local_provider(provider)
		Engine.get_singleton(_INAPP_PLUGIN).popup(url_endpoint)
	else:
		set_local_provider(provider)
		OS.shell_open(url_endpoint)


func login_with_oauth(_token: String, provider: AuthProvider) -> void:
	if _token:
		is_oauth_login = true
		var token : String = _token.uri_decode()
		var is_successful: bool = true
		if provider.should_exchange:
			exchange_token(token, _local_uri, provider.access_token_uri, provider.get_client_id(), provider.get_client_secret())
			is_successful = await self.token_exchanged
			token = auth.accesstoken
		if is_successful and _is_ready():
			is_busy = true
			_oauth_login_request_body.postBody = "access_token=" + token + "&providerId=" + provider.provider_id
			_oauth_login_request_body.requestUri = _local_uri
			requesting = Requests.LOGIN_WITH_OAUTH
			auth_request_type = Auth_Type.LOGIN_OAUTH
			var err = request(_base_url + _signin_with_oauth_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_oauth_login_request_body))
			_oauth_login_request_body.postBody = ""
			_oauth_login_request_body.requestUri = ""
			if err != OK:
				is_busy = false
				Firebase._printerr("Error logging in with oauth: %s" % err)


func exchange_token(code : String, redirect_uri : String, request_url: String, _client_id: String, _client_secret: String) -> void:
	if _is_ready():
		is_busy = true
		var exchange_token_body : Dictionary = {
			code = code,
			redirect_uri = redirect_uri,
			client_id = _client_id,
			client_secret = _client_secret,
			grant_type = "authorization_code",
		}
		requesting = Requests.EXCHANGE_TOKEN
		var err = request(request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(exchange_token_body))
		if err != OK:
			is_busy = false
			Firebase._printerr("Error exchanging tokens: %s" % err)


func get_google_auth_manual(provider: AuthProvider = _local_provider) -> void:
	provider.params.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
	get_auth_with_redirect(provider)


func _tcp_stream_timer() -> void:
	var peer : StreamPeer = tcp_server.take_connection()
	if peer != null:
		var raw_result : String = peer.get_utf8_string(441)
		if raw_result != "" and raw_result.begins_with("GET"):
			tcp_timer.stop()
			remove_child(tcp_timer)
			has_child = false
			var token : String = ""
			for value in raw_result.split(" ")[1].lstrip("/?").split("&"):
				var splitted: PackedStringArray = value.split("=")
				if _local_provider.params.response_type in splitted[0]:
					token = splitted[1]
					break

			if token == "":
				login_failed.emit()
				peer.disconnect_from_host()
				tcp_server.stop()
				return

			var data : PackedByteArray = '<p style="text-align:center">&#128293; You can close this window now. &#128293;</p>'.to_ascii_buffer()
			peer.put_data(("HTTP/1.1 200 OK\n").to_ascii_buffer())
			peer.put_data(("Server: Godot Firebase SDK\n").to_ascii_buffer())
			peer.put_data(("Content-Length: %d\n" % data.size()).to_ascii_buffer())
			peer.put_data("Connection: close\n".to_ascii_buffer())
			peer.put_data(("Content-Type: text/html; charset=UTF-8\n\n").to_ascii_buffer())
			peer.put_data(data)
			login_with_oauth(token, _local_provider)
			await self.login_succeeded
			peer.disconnect_from_host()
			tcp_server.stop()


func logout() -> void:
	auth = {}
	remove_auth()
	logged_out.emit()


func needs_login() -> bool:
	var encrypted_file = FileAccess.open_encrypted_with_pass("user://user.auth", FileAccess.READ, _config.apiKey)
	var err = encrypted_file == null
	return err


func manual_token_refresh(auth_data):
	auth = auth_data
	var refresh_token = null
	auth = get_clean_keys(auth)
	if auth.has("refreshtoken"):
		refresh_token = auth.refreshtoken
	elif auth.has("refresh_token"):
		refresh_token = auth.refresh_token
	_needs_refresh = true
	_refresh_request_body.refresh_token = refresh_token
	var err = request(_refresh_request_base_url + _refresh_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_refresh_request_body))
	if err != OK:
		is_busy = false
		Firebase._printerr("Error manually refreshing token: %s" % err)


# Handles completed Firebase Authentication HTTP requests.
func _on_FirebaseAuth_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	var json = Utilities.get_json_data(body.get_string_from_utf8())

	# Capture the request information before resetting shared state.
	var completed_request_type: int = requesting
	var completed_auth_request_type: int = auth_request_type
	var completed_oauth_login: bool = is_oauth_login

	# Reset BEFORE emitting signals. Awaiting coroutines may start another request.
	is_busy = false
	requesting = Requests.NONE
	auth_request_type = Auth_Type.NONE
	is_oauth_login = false

	print("[Firebase Auth] ===== HTTP RESPONSE RECEIVED =====")
	print("[Firebase Auth] Response code: ", response_code)
	print("[Firebase Auth] Completed request type: ", completed_request_type)
	print("[Firebase Auth] Password change enum: ", Requests.CHANGE_PASSWORD)
	print("[Firebase Auth] Completed request name: ",
		Requests.keys()[completed_request_type + 1]
		if completed_request_type >= -1 and completed_request_type < Requests.size()
		else "INVALID"
	)

	var res

	if response_code == 0:
		res = {
			"error": {
				"code": "Connection error",
				"message": "Error connecting to auth service"
			}
		}
	else:
		if json == null:
			Firebase._printerr("Error while parsing auth body json")
			auth_request.emit(ERR_PARSE_ERROR, "Error while parsing auth body json")
			return
		res = json

	if response_code == HTTPClient.RESPONSE_OK:

		if completed_request_type == Requests.VERIFY_ACCOUNT_EMAIL:
			account_verification_completed.emit(true, res)

		elif completed_request_type == Requests.VERIFY_CHANGE_EMAIL:
			credential_operation_completed.emit("email_change", true, res)

		elif completed_request_type == Requests.CHANGE_PASSWORD:
			print("[Firebase Auth] Firebase password update succeeded.")

			auth = get_clean_keys(res)

			if save_auth(auth):
				print("[Firebase Auth] Updated authentication session saved.")
				password_change_completed.emit(true, auth)
				begin_refresh_countdown()
			else:
				print("[Firebase Auth] Failed to save updated authentication session.")
				password_change_completed.emit(false, {
					"message": "Password changed, but the authentication session could not be saved."
				})

		elif completed_request_type == Requests.REAUTHENTICATE:
			auth = get_clean_keys(res)

			if save_auth(auth):
				print("[Firebase Auth] Reauthentication session saved.")
				reauthentication_completed.emit(true, auth)
				begin_refresh_countdown()
			else:
				reauthentication_completed.emit(false, {
					"message": "Unable to save the refreshed authentication session."
				})

		elif not res.has("kind"):
			auth = get_clean_keys(res)

			match completed_request_type:
				Requests.EXCHANGE_TOKEN:
					token_exchanged.emit(true)

			begin_refresh_countdown()
			auth_request.emit(1, auth)

			if _needs_refresh and not completed_oauth_login:
				_needs_refresh = false
				login_succeeded.emit(auth)

		else:
			match res.kind:
				RESPONSE_SIGNUP:
					auth = get_clean_keys(res)
					signup_succeeded.emit(auth)
					begin_refresh_countdown()

				RESPONSE_SIGNIN, RESPONSE_ASSERTION, RESPONSE_CUSTOM_TOKEN:
					auth = get_clean_keys(res)
					login_succeeded.emit(auth)
					begin_refresh_countdown()

				RESPONSE_USERDATA:
					var userdata = FirebaseUserData.new(res.users[0])
					userdata_received.emit(userdata)

			auth_request.emit(1, auth)

	else:

		if completed_request_type == Requests.VERIFY_ACCOUNT_EMAIL:
			account_verification_completed.emit(false, res.get("error", {}))

		elif completed_request_type == Requests.VERIFY_CHANGE_EMAIL:
			credential_operation_completed.emit(
				"email_change",
				false,
				res.get("error", {})
			)

		elif completed_request_type == Requests.CHANGE_PASSWORD:
			print("[Firebase Auth] Firebase password update failed.")
			print("[Firebase Auth] Error response: ", res)
			password_change_completed.emit(false, res.get("error", {}))

		elif completed_request_type == Requests.REAUTHENTICATE:
			reauthentication_completed.emit(false, res.get("error", {}))

		elif completed_request_type == Requests.EXCHANGE_TOKEN:
			token_exchanged.emit(false)

			var error_data: Dictionary = res.get("error", {})

			login_failed.emit(
				error_data.get("code", response_code),
				error_data.get("message", "Token exchange failed.")
			)

			auth_request.emit(
				error_data.get("code", response_code),
				error_data.get("message", "Token exchange failed.")
			)

		else:
			var sig = signup_failed if completed_auth_request_type == Auth_Type.SIGNUP_EP else login_failed
			var error_data: Dictionary = res.get("error", {})

			sig.emit(
				error_data.get("code", response_code),
				error_data.get("message", "Authentication request failed.")
			)

			auth_request.emit(
				error_data.get("code", response_code),
				error_data.get("message", "Authentication request failed.")
			)


func save_auth(auth : Dictionary) -> bool:
	var encrypted_file = FileAccess.open_encrypted_with_pass("user://user.auth", FileAccess.WRITE, _config.apiKey)
	var err = encrypted_file == null
	if err:
		Firebase._printerr("Error Opening File. Error Code: " + str(FileAccess.get_open_error()))
	else:
		encrypted_file.store_line(JSON.stringify(auth))
	return not err


func adopt_external_auth_result(auth_result: Dictionary) -> bool:
	var required_fields := [
		"localId",
		"idToken",
		"refreshToken",
		"expiresIn"
	]

	for field in required_fields:
		if not auth_result.has(field) or str(auth_result[field]).is_empty():
			push_error("[FirebaseAuth] Missing authentication field: " + field)
			return false

	auth = get_clean_keys(auth_result)

	if not save_auth(auth):
		push_error("[FirebaseAuth] Unable to save the authentication session.")
		auth = {}
		return false

	print("[FirebaseAuth] External authentication session saved.")
	login_succeeded.emit(auth)
	begin_refresh_countdown()
	return true


func load_auth() -> bool:
	var encrypted_file = FileAccess.open_encrypted_with_pass("user://user.auth", FileAccess.READ, _config.apiKey)
	var err = encrypted_file == null
	if err:
		Firebase._printerr("Error Opening Firebase Auth File. Error Code: " + str(FileAccess.get_open_error()))
		auth_request.emit(err, "Error Opening Firebase Auth File.")
	else:
		var json = JSON.new()
		var json_parse_result = json.parse(encrypted_file.get_line())
		if json_parse_result == OK:
			var encrypted_file_data = json.data
			manual_token_refresh(encrypted_file_data)
	return not err


func remove_auth() -> void:
	if FileAccess.file_exists("user://user.auth"):
		DirAccess.remove_absolute("user://user.auth")
	else:
		Firebase._printerr("No encrypted auth file exists")


func check_auth_file() -> bool:
	if FileAccess.file_exists("user://user.auth"):
		return load_auth()
	else:
		Firebase._printerr("Encrypted Firebase Auth file does not exist")
		auth_request.emit(ERR_DOES_NOT_EXIST, "Encrypted Firebase Auth file does not exist")
		return false


func change_user_email(email : String) -> void:
	if _is_ready():
		is_busy = true
		_change_email_body.email = email
		_change_email_body.idToken = auth.idtoken
		var err = request(_base_url + _update_account_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_change_email_body))
		if err != OK:
			is_busy = false
			Firebase._printerr("Error changing user email: %s" % err)


func change_user_password(password: String) -> void:
	print("[Firebase Auth] ===== PASSWORD CHANGE STARTED =====")
	print("[Firebase Auth] Is busy: ", is_busy)
	print("[Firebase Auth] Is logged in: ", is_logged_in())

	if not _is_ready():
		print("[Firebase Auth] ERROR: Auth is busy.")
		password_change_completed.emit(false, {
			"message": "Firebase Auth is currently busy."
		})
		return

	if not is_logged_in():
		print("[Firebase Auth] ERROR: No active session.")
		password_change_completed.emit(false, {
			"message": "No active Firebase session."
		})
		return

	if password.strip_edges().is_empty():
		print("[Firebase Auth] ERROR: Empty password.")
		password_change_completed.emit(false, {
			"message": "New password cannot be empty."
		})
		return

	is_busy = true
	requesting = Requests.CHANGE_PASSWORD

	_change_password_body.password = password
	_change_password_body.idToken = auth.idtoken

	print("[Firebase Auth] Sending password update request...")
	print("[Firebase Auth] Request type: ", requesting)

	var err := request(
		_base_url + _update_account_request_url,
		_headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(_change_password_body)
	)

	_change_password_body.password = ""
	_change_password_body.idToken = ""

	print("[Firebase Auth] HTTPRequest start result: ", err)

	if err != OK:
		is_busy = false
		requesting = Requests.NONE
		print("[Firebase Auth] ERROR: Could not start password request.")
		password_change_completed.emit(false, {
			"message": "Could not start password-change request. Error: %s" % err
		})
		return

	print("[Firebase Auth] Password update request successfully started.")
	print("[Firebase Auth] Requesting after start: ", requesting)


func update_account(idToken : String, displayName : String, photoUrl : String, deleteAttribute : PackedStringArray, returnSecureToken : bool) -> void:
	if _is_ready():
		is_busy = true
		_update_profile_body.idToken = idToken
		_update_profile_body.displayName = displayName
		_update_profile_body.photoUrl = photoUrl
		_update_profile_body.deleteAttribute = deleteAttribute
		_update_profile_body.returnSecureToken = returnSecureToken
		var err = request(_base_url + _update_account_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_update_profile_body))
		if err != OK:
			is_busy = false
			Firebase._printerr("Error updating account: %s" % err)


func link_account(email : String, password : String) -> void:
	if _is_ready():
		is_busy = true
		link_account_body.idToken = auth.idtoken
		link_account_body.email = email
		link_account_body.password = password
		var err = request(_base_url + _update_account_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(link_account_body))
		if err != OK:
			is_busy = false
			Firebase._printerr("Error updating account: %s" % err)


func send_account_verification_email() -> void:
	print("[Firebase Auth] Starting account verification request.")

	if not _is_ready():
		account_verification_completed.emit(false, {
			"message": "Firebase Auth is currently busy."
		})
		return

	if not is_logged_in():
		account_verification_completed.emit(false, {
			"message": "No active Firebase session."
		})
		return

	is_busy = true
	requesting = Requests.VERIFY_ACCOUNT_EMAIL
	_account_verification_body.idToken = auth.idtoken

	var err := request(
		_base_url + _oobcode_request_url,
		_headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(_account_verification_body)
	)

	_account_verification_body.idToken = ""

	if err != OK:
		is_busy = false
		requesting = Requests.NONE
		account_verification_completed.emit(false, {
			"message": "Could not start verification request. Error: %s" % err
		})
		return

	print("[Firebase Auth] Account verification HTTP request started.")


func send_password_reset_email(email : String) -> void:
	if _is_ready():
		is_busy = true
		_password_reset_body.email = email
		var err = request(_base_url + _oobcode_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_password_reset_body))
		if err != OK:
			is_busy = false
			Firebase._printerr("Error sending password reset email: %s" % err)


func get_user_data() -> void:
	if _is_ready():
		is_busy = true
		if not is_logged_in():
			print_debug("Not logged in")
			is_busy = false
			return

		var err = request(_base_url + _userdata_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify({"idToken": auth.idtoken}))
		if err != OK:
			is_busy = false
			Firebase._printerr("Error getting user data: %s" % err)


func reauthenticate_user(email: String, password: String) -> void:
	if not _is_ready():
		reauthentication_completed.emit(false, {
			"message": "Firebase Auth is currently busy."
		})
		return

	is_busy = true
	requesting = Requests.REAUTHENTICATE

	_reauthenticate_request_body.email = email
	_reauthenticate_request_body.password = password

	var err = request(
		_base_url + _signin_request_url,
		_headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(_reauthenticate_request_body)
	)

	_reauthenticate_request_body.email = ""
	_reauthenticate_request_body.password = ""

	if err != OK:
		is_busy = false
		requesting = Requests.NONE
		reauthentication_completed.emit(false, {
			"message": "Unable to send the reauthentication request."
		})


func send_email_change_verification(new_email: String) -> void:
	print("[Firebase Auth] Starting email-change verification request.")

	if not _is_ready():
		print("[Firebase Auth] ERROR: Firebase Auth is not ready.")
		credential_operation_completed.emit(
			"email_change",
			false,
			{"message": "Firebase Auth is not ready."}
		)
		return

	if not is_logged_in():
		print("[Firebase Auth] ERROR: No active Firebase session.")
		credential_operation_completed.emit(
			"email_change",
			false,
			{"message": "You must be logged in."}
		)
		return

	print("[Firebase Auth] Auth is ready.")
	print("[Firebase Auth] Preparing VERIFY_AND_CHANGE_EMAIL request.")

	is_busy = true
	requesting = Requests.VERIFY_CHANGE_EMAIL

	_verify_change_email_body.idToken = auth.idtoken
	_verify_change_email_body.newEmail = new_email

	var err := request(
		_base_url + _oobcode_request_url,
		_headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(_verify_change_email_body)
	)

	print("[Firebase Auth] HTTPRequest result: ", err)

	_verify_change_email_body.idToken = ""
	_verify_change_email_body.newEmail = ""

	if err != OK:
		print("[Firebase Auth] ERROR: Could not start HTTP request.")
		is_busy = false
		requesting = Requests.NONE
		credential_operation_completed.emit(
			"email_change",
			false,
			{
				"message": "Could not start email verification request. Error: %s" % err
			}
		)
		return

	print("[Firebase Auth] Email-change HTTP request started.")


func delete_user_account() -> void:
	if _is_ready():
		is_busy = true
		var err = request(_base_url + _delete_account_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify({"idToken": auth.idtoken}))
		if err != OK:
			is_busy = false
			Firebase._printerr("Error deleting user: %s" % err)
		else:
			remove_auth()


func begin_refresh_countdown() -> void:
	var refresh_token = null
	var expires_in = 1000
	auth = get_clean_keys(auth)

	if auth.has("refreshtoken"):
		refresh_token = auth.refreshtoken
		expires_in = auth.expiresin
	elif auth.has("refresh_token"):
		refresh_token = auth.refresh_token
		expires_in = auth.expires_in

	if auth.has("userid"):
		auth["localid"] = auth.userid

	_needs_refresh = true
	token_refresh_succeeded.emit(auth)
	await get_tree().create_timer(float(expires_in)).timeout

	_refresh_request_body.refresh_token = refresh_token
	var err = request(_refresh_request_base_url + _refresh_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_refresh_request_body))
	if err != OK:
		is_busy = false
		Firebase._printerr("Error refreshing via countdown: %s" % err)


func get_token_from_url(provider: AuthProvider):
	var token_type: String = provider.params.response_type if provider.params.response_type == "code" else "access_token"
	if OS.has_feature("web"):
		var token = JavaScriptBridge.eval("""
			var url_string = window.location.href.replaceAll('?#', '?');
			var url = new URL(url_string);
			url.searchParams.get('""" + token_type + """');
		""")
		JavaScriptBridge.eval("""window.history.pushState({}, null, location.href.split('?')[0]);""")
		return token
	return null


func set_redirect_uri(redirect_uri : String) -> void:
	self._local_uri = redirect_uri


func set_local_provider(provider : AuthProvider) -> void:
	self._local_provider = provider


func get_clean_keys(auth_result : Dictionary) -> Dictionary:
	var cleaned = {}
	for key in auth_result.keys():
		cleaned[key.replace("_", "").to_lower()] = auth_result[key]
	return cleaned


func get_GoogleProvider() -> GoogleProvider:
	return GoogleProvider.new(_config.clientId, _config.clientSecret)


func get_FacebookProvider() -> FacebookProvider:
	return FacebookProvider.new(_config.auth_providers.facebook_id, _config.auth_providers.facebook_secret)


func get_GitHubProvider() -> GitHubProvider:
	return GitHubProvider.new(_config.auth_providers.github_id, _config.auth_providers.github_secret)


func get_TwitterProvider() -> TwitterProvider:
	return TwitterProvider.new(_config.auth_providers.twitter_id, _config.auth_providers.twitter_secret)
