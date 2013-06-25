<% @language=jscript %>

<!-- #include file="_YOUR_LOCAL_COPY_OF_hmac-sha1.js"-->
<!-- #include file="_YOUR_LOCAL_COPY_OF_enc-base64-min.js"-->

<%
// for above...
// http://crypto-js.googlecode.com/svn/tags/3.1.2/build/rollups/hmac-sha1.js
// http://crypto-js.googlecode.com/svn/tags/3.1.2/build/components/enc-base64-min.js

// ================================================================
// FUNCTIONS

function pctenc(x) { //simple URL encode, except for the four characters below
  var x = String(x)
  x = Server.URLEncode(x);
	x = x.replace(/%2E/ig,".");
	x = x.replace(/%5F/ig,"_");
	x = x.replace(/%3F/ig,"&");
	x = x.replace(/%2D/ig,"-");
	return x;
}

function parse_date(date_str) { // adapted from tweet.js
	return Date.parse(date_str.replace(/^([a-z]{3})( [a-z]{3} \d\d?)(.*)( \d{4})$/i, '$1,$2$4$3'));
}

function relative_time(time_value) { // adapted from tweet.js
	var parsed_date = parse_date(time_value);
	var relative_to = (arguments.length > 1) ? arguments[1] : new Date();
	var delta = parseInt((relative_to.getTime() - parsed_date) / 1000);
	var pluralize = function (singular, n) {
		return '' + n + ' ' + singular + (n == 1 ? '' : 's');
	};
	if(delta < 60) {
		return 'Posted less than a minute ago.';
	} else if(delta < (60*60)) {
		return 'Posted ' + pluralize("minute", parseInt(delta / 60)) + ' ago on Twitter.';
	} else if(delta < (24*60*60)) {
		return 'Posted ' + pluralize("hour", parseInt(delta / 3600)) + ' ago on Twitter.';
	} else {
		return 'Posted ' + pluralize("day", parseInt(delta / 86400)) + ' ago on Twitter.';
	}
}

function linkURL(x) { // adapted from tweet.js
	var regexp = /((ftp|http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?)/gi;
   var x = x.replace(regexp,"<a href=\"$1\">$1</a>");
	return x;
}

function linkUser(x) { // adapted from tweet.js
	var regexp = /[\@]+([A-Za-z0-9-_]+)/gi;
   var x = x.replace(regexp,"<a href=\"http://twitter.com/$1\">@$1</a>");
	return x;
}

// ================================================================
// INPUT

var hasfile = false;
var expired = true;

var user_id = "_YOUR_TWITTER_ID_"
var qs_id = parseInt(Request.QueryString("id"));
if (!isNaN(qs_id)) { user_id = qs_id };

var count = 5;
var qs_count = parseInt(Request.QueryString("count"));
if (!isNaN(qs_count)) { count = qs_count };

var output = "json";
if (String(Request.QueryString("output")) == "li") { output = "li" };
if (String(Request.QueryString("output")) == "div") { output = "div" };
if (String(Request.QueryString("output")) == "none") { output = "none" };

var replies = false;
if (String(Request.QueryString("replies")) == "true") { replies = true };

var retweets = false;
if (String(Request.QueryString("retweets")) == "true") { retweets = true };

var force_update = false;
if (String(Request.QueryString("force")) == "true") { force_update = true };

// ================================================================
// FILE

var path = "_YOUR_LOCAL_DIRECTORY_PATH_";
var filename = "twitter-" + user_id + ".json";
var now = new Date();

var fso = Server.CreateObject("Scripting.FileSystemObject");

if (fso.FileExists(path + filename)) { // does the cache exist for this id?
	hasfile = true;
	var file = fso.GetFile(path + filename);
	var then = new Date(file.DateLastModified);
	var since = Math.round((now - then)/1000);
	if (((since/60)/60) < 3) { // is the cache file more than X hours old?
		expired = false;
	}
	file = null;
}

// ================================================================
// OAUTH

if ((expired)||(force_update)) {

	// ==== create base URL components
	var base_url = "https://api.twitter.com//1.1/statuses/user_timeline.json";
	var querystring1 = "?count=60"; // COUNT is the MAX number of items the script will generate, adjust accordingly 
	if (!replies) { querystring1 += "&exclude_replies=true" }; // if exclude, replies subtracted from total above
	querystring1 += "&id=" + user_id; 
	if (!retweets) { querystring1 += "&include_rts=false" }; // if !include, retweets subtracted from total above
	var querystring2 = "&skip_user=true&trim_user=true"; // trim_user pares down the JSON output. not sure what skip_user does.

	// ==== key name value pairs (sans signature)
	var oauth_consumer_key = "_YOUR_CONSUMER_KEY_HERE_"; // app's consumer key
	var oauth_nonce = "1e19cf9e6e693b69cd21aa7e5b3004c0"; // random 32 character string
	var oauth_signature_method = "HMAC-SHA1";
	var oauth_timestamp = String(Math.round(+new Date/1000)); // seconds since 1/1/1970
	var oauth_token = _YOUR_PERSONAL_TOKEN_HERE_; // user's access token
	var oauth_version = "1.0"; // gonna have to do this again for 2.0

	// ==== querystring components (sans signature)
	var str_consumer_key = "&oauth_consumer_key=" + oauth_consumer_key;
	var str_nonce = "&oauth_nonce=" + oauth_nonce;
	var str_signature_method = "&oauth_signature_method=" + oauth_signature_method;
	var str_timestamp = "&oauth_timestamp=" + oauth_timestamp;
	var str_token = "&oauth_token=" + oauth_token;
	var str_version = "&oauth_version=" + oauth_version;

	// ==== generate hash encryption key
	var Consumer_Secret = "_YOUR_CONSUMER_SECRET_HERE_"; // app's consumer secret
	var Access_Token_Secret = "_YOUR_ACCESS_TOKEN_SECRET_HERE_"; // user's access token secret
	var hash_key = pctenc(Consumer_Secret) + "&" + pctenc(Access_Token_Secret);

	// ==== build base URL for (message) OAUTH key, keys must be in alphabetical order by name
	var hash_message = base_url + querystring1;
	hash_message += str_consumer_key;
	hash_message += str_nonce;
	hash_message += str_signature_method;
	hash_message += str_timestamp;
	hash_message += str_token;
	hash_message += str_version;
	hash_message += querystring2;

	// ==== add the leading "GET&" and then URLencode it all 
	var hash_message_encoded = "GET&" + pctenc(hash_message); //func above

	// ==== create OUATH SIGNATURE, which is a hash of the URLencoded base URL, using the combined secrets as the key...
	var oauth_signature = CryptoJS.HmacSHA1(hash_message_encoded, hash_key); // for testing, add anything (... + "1" ) to message or hash to GENERATE ERROR 32!
	// ==== ...which is then Base64'd...
	oauth_signature = CryptoJS.enc.Base64.stringify(oauth_signature);
	// ==== ...and then finally URLencoded.
	oauth_signature = pctenc(oauth_signature);

	// ==== create the querystring component for the signature
	var str_signature = "&oauth_signature=" + oauth_signature;

	// ==== build the final request URL
	var final_url = base_url + querystring1 + querystring2
	final_url += str_consumer_key;
	final_url += str_nonce;
	final_url += str_signature;
	final_url += str_signature_method;
	final_url += str_timestamp;
	final_url += str_token;
	final_url += str_version;

	// ==== make the actual twitter GET request
	var http = Server.CreateObject("MSXML2.ServerXMLHTTP");
	http.open('GET', final_url, false);
	try {

		http.send();
		var response = http.responseText;
		var success = true;

		// successful contact and valid response from twitter?
		if (Response.Status != "200 OK") { success = false };

		// do we have tweets... or errors?
		//error_code = 0;
		try { // this will fail if we don't have an error
			var error_data = eval('(' + response + ')');
			var error_code = parseInt(error_data.errors[0].code);
			if (!isNaN(error_code)) { success = false; }
		} catch (err) {
			// success still true
		}

	} catch(err) {
		var success = false;
	}

	if (success) {
		var file = fso.OpenTextFile(path + filename,2,true)
		file.Write(response);
		file.Close();
	}


}

// ================================================================
// OUTPUT

var file = fso.GetFile(path + filename);
var ts = file.OpenAsTextStream(1);
var raw_json = ts.ReadAll();

if (output == "json") { // send the raw JSON
	Response.Write(raw_json)
} else { // output a set of listicles, ready to go
	var tweets = eval('(' + raw_json + ')');
	var c = 0;
	for (i in tweets) {
		var recent = String(tweets[i].text);
		var time = String(tweets[i].created_at);
		time = relative_time(time);
		if (output == "li") { Response.Write("<li>" + linkUser(linkURL(recent)) + "<br/><small>" + time + "</small></li>") };
		if (output == "div") { Response.Write("<div>" + linkUser(linkURL(recent)) + "<br/><small>" + time + "</small></div>") };
		if (output == "none") { Response.Write(linkUser(linkURL(recent)) + "<br/><small>" + time + "</small>") };
		c++
		if (c == count) { break; }
	}
};

%>
