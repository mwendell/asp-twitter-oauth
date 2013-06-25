asp-twitter-oauth
=================

OAuth example for Classic ASP (Jscript) developers. Requests public feed from Twitter API v1.1.

I had been using Tweet.js on a number of websites to request and display the clients' public Twitter feeds. Once the v1 API was deprecated I created this small piece of code which sits on my own server and handles the authentication and requests for all of my client sites. The code limits the number of Twitter requests by caching the JSON response from Twitter into a local file, and only making a new request for each TwitterID when the cache has expired (currently set to 3 hours, easily changed). It is really designed to returning up to to a dozen tweets or so, to be displayed on a website. I doubt it would be appropriate for returning huge numbers of tweets, or as a replacement for a real Twitter client.

The code uses some date parsing and link expansion functions from Tweet.js. You can find out more about Tweet.js on their website: http://tweet.seaofclouds.com/

To use this code, you'll need to be running Classic ASP. Place the ASP file in a dedicated folder on your server. You'll also need to download the crypto and base64 js files mentioned in the code, and save them locally. Change the code to reflect the location of these files, and wrap the code in ASP server side script tags (<% %>). Finally, be sure that the folder has write permissions so that the FileSystemObject can create the JSON response cache files.

You'll need to create your own Twitter API app here: https://dev.twitter.com/apps. Once you create your app, you'll need the Consumer Key and the Consumer Secret. You'll also need to create an Access Token, and an Access Token secret. All four of these are available on the Details tab (as well as the OAuth Tool tab) for your new app on Twitter.

In addition to the keys and secrets, you'll need to provide your local file path (for the cache files) and a default Twitter ID (the final Twitter ID is sent via querystring).

The code is pretty heavily commented, and the places where you need to insert your own information are denoted in all caps and underscores ("_YOUR_CONSUMER_SECRET_HERE_"), I'm hoping it's pretty obvious, but feel free to hit me with questions.

Using it from your site involves simply running an http request with the appropriate querystring values.

	<%
	var http = Server.CreateObject("MSXML2.ServerXMLHTTP");
	http.open('GET', 'twitter-oauth.asp?count=1&id=16715178&output=none', false);
	http.send();
	Response.Write(http.responseText);
	%>

The code above returns just the text (and relative date) of my single most recent original tweet. Without any querystring values, the code will return the raw JSON for the most recent 5 original tweets (no replies or retweets) from the default user (specified in the code itself).

Accepted querystring options are "count=", "id=", "output=", "replies=", "retweets=", and "force_update=".

* count - The code requests 60 tweets, but that includes replies and retweets. If you're filtering these out, obviously you'll get fewer (not sure why Twitter filters after the requested twets are collected). I don't know what will happen if your count is greater than the tweets returned. 
* id - A valid Twitter ID. I use this page to get the ID... http://gettwitterid.com/
* output - The default is the full, raw JSON, but a few formats are available. "none" is really only useful for a single tweet, since it returns only the tweet body itself (and the relative time surrounded by 'small' tags). For multiple tweets you can use "div" or "li", whichever works with your code.
* replies - When set to true, results include replies
* retweets - When set to true, results include retweets
* force_update - When set to true, code will ignore the cache interval, making a request and generating a new file immediately. Primarily in there for testing.

