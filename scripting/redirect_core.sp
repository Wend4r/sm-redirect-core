#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <redirect_core>
#include <PTaH>

#pragma newdecls required
#pragma tabsize 4

#define SPPP_COMPILER 0

#if !SPPP_COMPILER
	#define decl static
#endif

ArrayList		g_hRedirectPlayers, g_hDomains, g_hDomainsIP;

// weapon_blocker.sp
// SourcePawn Compiler 1.10 Ex
public Plugin myinfo =
{
	name = "[Redirect] Core",
	author = "Wend4r",
	version = "1.0.0 Alpha",
	url = "Discord: Wend4r#0001 | https://discord.gg/9gGHgBP"
};

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] sError, int iErrorSize)
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		strcopy(sError, iErrorSize, "This plugin works only on CS:GO");

		return APLRes_SilentFailure;
	}

	CreateNative("SetRedirectDomainForIP", Native_SetRedirectDomainForIP);
	CreateNative("GetPlayerRedirectServer", Native_GetPlayerRedirectServer);
	CreateNative("RedirectClientOnServer", Native_RedirectClientOnServer);

	RegPluginLibrary("redirect_api");

	HookEvent("player_disconnect", OnPlayerDisconnect, EventHookMode_Pre); // Hello, insecure SMAC Ultra.

	return APLRes_Success;
}

public void OnPluginStart()
{
	RegAdminCmd("sm_redirect", OnRedirect, ADMFLAG_ROOT, "Forced redirect the target to server");
	RegAdminCmd("sm_get_session", OnGetSesssion, ADMFLAG_ROOT, "Test command for getting a player session");

	g_hRedirectPlayers = new ArrayList(3);
	g_hDomains = new ArrayList(64); // char[256]
	g_hDomainsIP = new ArrayList();

	PTaH(PTaH_ClientConnectPre, Hook, OnClientConnectPre);
	PTaH(PTaH_ClientConnectPost, Hook, OnClientConnectPost);

	AddCommandListener(OnClientRealDisconnect, "disconnect");
}

int Native_SetRedirectDomainForIP(Handle hPlugin, int iArgs)
{
	decl char sDomain[256];

	GetNativeString(1, sDomain, sizeof(sDomain));

	g_hDomains.PushString(sDomain);
	g_hDomainsIP.Push(GetNativeCell(2));
}

int Native_GetPlayerRedirectServer(Handle hPlugin, int iArgs)
{
	int iIndex = g_hRedirectPlayers.FindValue(GetSteamAccountID(GetNativeCell(1)));

	if(iIndex != -1)
	{
		if(GetNativeCellRef(2))
		{
			SetNativeCellRef(2, g_hRedirectPlayers.Get(iIndex, 1));		// iIP
		}

		if(GetNativeCellRef(3))
		{
			SetNativeCellRef(3, g_hRedirectPlayers.Get(iIndex, 2));		// iPort
		}

		return true;
	}

	return false;
}

int Native_RedirectClientOnServer(Handle hPlugin, int iArgs)
{
	ClientRedirect(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));
}

Action OnRedirect(int iClient, int iArgs)
{
	if(iArgs < 2)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_redirect <#userid|name> \"ip:port\"");
	}
	else
	{
		bool bTargetIsMl = false;

		int iTargets = 0,
			iTargetList[MAXPLAYERS + 1];

		char sBuffer[256];

		GetCmdArg(1, sBuffer, sizeof(sBuffer));

		if((iTargets = ProcessTargetString(sBuffer, iClient, iTargetList, sizeof(iTargetList), COMMAND_FILTER_NO_BOTS, sBuffer, sizeof(sBuffer), bTargetIsMl)) < 1)
		{
			ReplyToTargetError(iClient, iTargets);
		}

		GetCmdArg(2, sBuffer, sizeof(sBuffer));

		int iStartPort = FindCharInString(sBuffer, ':'),
			iPort = iStartPort > 0 ? StringToInt(sBuffer[iStartPort + 1]) : 27015;

		char sIPv4[4][4];

		ExplodeString(sBuffer, ".", sIPv4, sizeof(sIPv4), sizeof(sIPv4[]));

		for(int i = 0, iIP = GetIP32FromIPv4(sIPv4); i != iTargets; i++)
		{
			ClientRedirect(iTargetList[i], iIP, iPort);
		}
	}

	return Plugin_Handled;
}

Action OnGetSesssion(int iClient, int iArgs)
{
	QueryClientConVar(iClient, "cl_session", QuerySession, GetClientUserId(iClient));
}

void QuerySession(QueryCookie iCookie, int iClient, ConVarQueryResult iResult, const char[] sCvarName, const char[] sCvarValue, int iUser)
{
	iUser = GetClientOfUserId(iUser);

	if(iUser)
	{
		PrintToChat(iUser, "You session: %s", sCvarValue);
	}
}

Action OnClientRealDisconnect(int iClient, const char[] sCommand, int iArgs)
{
	int iIndex = g_hRedirectPlayers.FindValue(GetSteamAccountID(iClient));

	if(iIndex != -1)
	{
		g_hRedirectPlayers.Erase(iIndex);
	}
}

Action OnPlayerDisconnect(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if(!bDontBroadcast)
	{
		int iUserId = hEvent.GetInt("userid"),
			iClient = GetClientOfUserId(iUserId);

		if(iClient)
		{
			int iIndex = g_hRedirectPlayers.FindValue(GetSteamAccountID(iClient));

			if(iIndex != -1)
			{
				hEvent.BroadcastDisabled = true;

				int iIP = g_hRedirectPlayers.Get(iIndex, 1),
					iPort = g_hRedirectPlayers.Get(iIndex, 2),
					iDomainIndex = g_hDomainsIP.FindValue(iIP);

				decl char sBuffer[256];

				Event hEvent2 = CreateEvent("player_disconnect", true);

				hEvent2.SetInt("userid", iUserId);
				hEvent2.SetInt("redirect_ip", iIP);
				hEvent2.SetInt("redirect_port", iPort);

				if(iDomainIndex != -1)
				{
					g_hDomains.GetString(iDomainIndex, sBuffer, sizeof(sBuffer));
					hEvent2.SetString("redirect_domain", sBuffer);

					FormatEx(sBuffer, sizeof(sBuffer), "Redirecting in %s:%i", sBuffer, iPort);
				}
				else
				{
					FormatEx(sBuffer, sizeof(sBuffer), "Redirecting in %i.%i.%i.%i:%i", iIP >>> 24, iIP >> 16 & 255, iIP >> 8 & 255, iIP & 255, iPort);
				}

				hEvent2.SetString("reason", sBuffer);

				hEvent.GetString("name", sBuffer, sizeof(sBuffer));
				hEvent2.SetString("name", sBuffer);
	
				hEvent.GetString("networkid", sBuffer, sizeof(sBuffer));
				hEvent2.SetString("networkid", sBuffer);

				UnhookEvent(sName, OnPlayerDisconnect, EventHookMode_Pre);

				hEvent2.Fire();

				HookEvent(sName, OnPlayerDisconnect, EventHookMode_Pre);
			}
		}
	}
}

void ClientRedirect(int iClient, int iIP, int iPort)
{
	int iAccountID = GetSteamAccountID(iClient);

	if(iAccountID)
	{
		int iIndex = g_hRedirectPlayers.Push(iAccountID);

		g_hRedirectPlayers.Set(iIndex, iIP, 1);
		g_hRedirectPlayers.Set(iIndex, iPort, 2);

		ClientCommand(iClient, "retry");
	}
}

Action OnClientConnectPre(int iAccountID, const char[] sIP, const char[] sName, char sPassword[128], char sRejectReason[255])
{
	int iIndex = g_hRedirectPlayers.FindValue(iAccountID);

	if(iIndex != -1)
	{
		int iIP = g_hRedirectPlayers.Get(iIndex, 1),
			iPort = g_hRedirectPlayers.Get(iIndex, 2),
			iDomainIndex = g_hDomainsIP.FindValue(iIP);

		if(iDomainIndex != -1)
		{
			decl char sDomain[256];

			g_hDomains.GetString(iDomainIndex, sDomain, sizeof(sDomain));
			FormatEx(sRejectReason, sizeof(sRejectReason), "ConnectRedirectAddress:%s:%i\n", sDomain, iPort);
		}
		else
		{
			FormatEx(sRejectReason, sizeof(sRejectReason), "ConnectRedirectAddress:%i.%i.%i.%i:%i\n", iIP >>> 24, iIP >> 16 & 255, iIP >> 8 & 255, iIP & 255, iPort);
		}

		g_hRedirectPlayers.Erase(iIndex);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

void OnClientConnectPost(int iClient, int iAccountID, const char[] sIp, const char[] sName)
{
	LogMessage("%i, %i, %s, %s", iClient, iAccountID, sIp, sName);
}