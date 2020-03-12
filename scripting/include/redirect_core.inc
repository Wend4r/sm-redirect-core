#if defined _redirect_core_included_
  #endinput
#endif
#define _redirect_core_included_

/**
 * Sets the site domain for redirect by IP.
 *
 * @param sDomain           Domain address.
 * @param iIP32             IP32 address.
 *
 * @noreturn
 */
native void SetRedirectDomainForIP(const char[] sDomain, int iIP);

/**
 * Gets the server from the player to which it reconnects.
 * Use in OnClientDisconnect() or CBaseServer::ConnectClient (Pre).
 *
 * @param iClient           Client index.
 * @param iIP32             Where will the IP address be recorded.
 * @param iPort             Where will the port be recorded.
 *
 * @return                  If this is the player reconnecting to another server.
 */
native bool GetPlayerRedirectServer(int iClient, int &iIP = 0, int &iPort = 0);

/**
 * Forced redirects the player to other server.
 *
 * @param iClient           Client index.
 * @param iIP               IP of the server where the player will be redirected.
 * @param iPort             Server port.
 *
 * @noreturn
 */
native void RedirectClientOnServer(int iClient, int iIP, int iPort);

/**
 * Converts IP32 to IPv4.
 *
 * @param iIP32             IP32 address.
 * @param sIPv4             Where will IPv4 be recorded.
 *
 * @noreturn
 */
stock void GetIPv4FromIP32(int iIP, char sIPv4[4][4])
{
	IntToString(iIP >>> 24, sIPv4[0], sizeof(sIPv4[]));
	IntToString(iIP >> 16 & 255, sIPv4[1], sizeof(sIPv4[]));
	IntToString(iIP >> 8 & 255, sIPv4[2], sizeof(sIPv4[]));
	IntToString(iIP & 255, sIPv4[3], sizeof(sIPv4[]));
}

/**
 * Converts IPv4 to IP32.
 *
 * @param sIPv4             IPv4 address.
 *
 * @return                  IP32 address.
 */
stock int GetIP32FromIPv4(const char sIPv4[4][4])
{
	return StringToInt(sIPv4[0]) << 24 | StringToInt(sIPv4[1]) << 16 | StringToInt(sIPv4[2]) << 8 | StringToInt(sIPv4[3]);
}



public SharedPlugin __pl_redirect_core = 
{
	name = "redirect_core",
	file = "redirect_core.smx",

	#if defined REQUIRE_PLUGIN
		required = 1
	#else
		required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_redirect_core_SetNTVOptional()
{
	MarkNativeAsOptional("SetRedirectDomainForIP");
	MarkNativeAsOptional("GetPlayerRedirectServer");
	MarkNativeAsOptional("RedirectClientOnServer");
}
#endif
