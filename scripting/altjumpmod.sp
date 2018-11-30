/*
		This plugin uses the code from [TF2] pumpkins from linux_lover, and the pyro plugin from Leonardo
		All other code was written by me for this plugin.
		
	Projectile Reference
	----------------------------------------
	1 - Bullet
	2 - Rocket
	3 - Pipebomb
	4 - Stickybomb (Stickybomb Launcher)
	5 - Syringe
	6 - Flare
	8 - Huntsman Arrow
	11 - Crusader's Crossbow Bolt
	12 - Cow Mangler Particle
	13 - Righteous Bison Particle
	14 - Stickybomb (Sticky Jumper)
	17 - Loose Cannon
	18 - Rescue Ranger Claw
	19 - Festive Huntsman Arrow
	22 - Festive Jarate
	23 - Festive Crusader's Crossbow Bolt
	24 - Self Aware Beuty Mark
	25 - Mutated Milk
	26 - Grappling Hook
	---------------------------------------
*/
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#define REQUIRE_EXTENSIONS
#include <tf2attributes>
#undef REQUIRE_EXTENSIONS

#define VERSION "1.0"
#define MAX_PUMPKIN_LIMIT 3

// Will create a lot of console spam if on a large server.
#define DEBUG

float 
	g_fPos[3];
int
	g_iPumpkins[MAXPLAYERS+1][MAX_PUMPKIN_LIMIT],
	g_iCurrent[MAXPLAYERS+1] = 0,
	g_iLastSpawned[MAXPLAYERS+1];
Handle
	g_hEnabled,
	g_hAutoRemove,
	g_hTimersMax[MAXPLAYERS+1][MAX_PUMPKIN_LIMIT],
	g_hHeavyRestrictCount,
	g_hSpyRestrictCount,
	g_hSniperRestrictCount,
	g_hMedicRestrictCount,
	g_hMedicPower,
	g_hSpyPower,
	g_hSniperPower,
	g_hSniperReload,
	g_hScoutPower,
	g_hScoutRestrictCount,
	g_hScoutDJ;
bool
	g_bTimerExists[MAXPLAYERS+1][MAX_PUMPKIN_LIMIT];

public Plugin myinfo = 
{
	name = "AltJumpMod",
	author = "rush",
	description = "AltJumpMod - Add multiple ways for classes to 'jump'.",
	version = VERSION,
	url = "https://github.com/n0cpra/AltJumpMod"
}
public void OnPluginStart()
{
	// Classes exluded from this plugin soldier, engineer, pyro and demo. They have ways to jump.
	// Those class can either jump with their own weapons, or already have good plugins to aid/do it for them
	CreateConVar("sm_ajm_version", VERSION, "AltJumpMod Version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_REPLICATED);
	g_hEnabled = CreateConVar("sm_ajm_enable", "1", "Turns this plugin on, or off.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	// Heavy - Om nom nom nom!
	g_hAutoRemove = CreateConVar("sm_ajm_autoremove", "1", "Auto remove pumpkins on/off.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hHeavyRestrictCount = CreateConVar("sm_ajm_heavy_count", "1", "Limits the amount of heavys that can use this at once.", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	// Medic
	g_hMedicRestrictCount = CreateConVar("sm_ajm_medic_count", "1", "Limits the amount of medics that can use this at once.", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	g_hMedicPower = CreateConVar("sm_ajm_medic_power", "1.50", "Limits the amount of power the rockets give the medic.", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.50, true, 10.0);
	// Spy
	g_hSpyPower = CreateConVar("sm_ajm_spy_power", "8.0", "Limits the amount of power the rockets give the spy.", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.50, true, 10.0);
	g_hSpyRestrictCount = CreateConVar("sm_ajm_spy_count", "1", "Limits the amount of spies that can use this at once.", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	// Scout
	g_hScoutRestrictCount = CreateConVar("sm_ajm_scout_count", "1", "Limits the amount of scouts that can use this at once.", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	g_hScoutPower = CreateConVar("sm_ajm_scout_power", "8.0", "Sets / Limits how many jumps the scout can make.", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.50, true, 10.0);
	g_hScoutDJ = CreateConVar("sm_ajm_scout_dj", "0", "Allows the scout to double jump or not. (0 no double jump / 1 double jump)", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	// Sniper
	g_hSniperPower = CreateConVar("sm_ajm_sniper_power", "8.0", "Limits the amount of power the rockets give the sniper.", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.50, true, 10.0);
	g_hSniperRestrictCount = CreateConVar("sm_ajm_sniper_count", "1", "Limits the amount of snipers that can use this at once.", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	g_hSniperReload = CreateConVar("sm_ajm_sniper_reload", "0.6", "Sets the snipers reload time on the sniper rifle", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.2, true, 1.5);
	// Heavy commands
	RegConsoleCmd("+pumpkin", cmdPumpkin, "Spawns a NON-SOLID pumpkin");
	RegConsoleCmd("-pumpkin", cmdToggle, "DO NOT USE - This is automatically fired.", FCVAR_HIDDEN|FCVAR_DONTRECORD);

	// ConVar hooks
	HookConVarChange(g_hEnabled, cvarEnable);
	// Heavy stuff
	HookConVarChange(g_hAutoRemove, cvarAutoRemove);
	HookConVarChange(g_hHeavyRestrictCount, cvarHeavyRestrict);
	// Medic stuff
	HookConVarChange(g_hMedicRestrictCount, cvarMedicRestrict);
	HookConVarChange(g_hMedicPower, cvarMedicPower);
	// Spy stuff
	HookConVarChange(g_hSpyRestrictCount, cvarSpyRestrict);
	HookConVarChange(g_hSpyPower, cvarSpyPower);
	// Sniper stuff
	HookConVarChange(g_hSniperRestrictCount, cvarSniperRestrict);
	HookConVarChange(g_hSniperPower, cvarSniperPower);
	HookConVarChange(g_hSniperReload, cvarSniperReload);
	// Scout stuff
	HookConVarChange(g_hScoutPower, cvarScoutPower);
	HookConVarChange(g_hScoutRestrictCount, cvarScoutRestrict);
	HookConVarChange(g_hScoutDJ, cvarScoutDJ);
	// Event hooks
	HookEvent("player_spawn", eventPlayerSpawn);
	
	// Command listeners
	AddCommandListener(OnChangeClass, "joinclass");
}
int GetClientPumpkins(int client)
{
	if (g_iCurrent[client] == 0)
		return 0;
	else
		return g_iCurrent[client]-1;
}
public Action cmdToggle(int client, int args)
{
	if (GetConVarBool(g_hEnabled) && GetConVarBool(g_hAutoRemove) && g_iCurrent[client]-1 < 3)
	{
		if (TF2_GetPlayerClass(client) != TFClass_Heavy)
		{
			return Plugin_Handled;
		}
		if (!g_bTimerExists[client][GetClientPumpkins(client)])
		{
#if defined DEBUG
			PrintToServer("DEBUG: Entity %i has been marked for auto removal.", g_iLastSpawned[client]);
#endif
			g_hTimersMax[client][GetClientPumpkins(client)] = CreateTimer(30.0, timerAutoRemove, g_iLastSpawned[client], TIMER_FLAG_NO_MAPCHANGE);
			g_bTimerExists[client][GetClientPumpkins(client)] = true;
			g_iLastSpawned[client] = 0;
		}
	}
	return Plugin_Handled;
}
public Action cmdPumpkin(int client, int args)
{
	if (!GetConVarBool(g_hEnabled))
	{
		return Plugin_Handled;
	}
	if (TF2_GetPlayerClass(client) != TFClass_Heavy)
	{
		return Plugin_Handled;
	}
	if (g_iCurrent[client] >= MAX_PUMPKIN_LIMIT) { return Plugin_Handled; }
	if(!SetTeleportEndPoint(client))
	{
		PrintToChat(client, "[SM] Could not find spawn point.");
		return Plugin_Handled;
	}
	if(GetEntityCount() >= GetMaxEntities()-32)
	{
		PrintToChat(client, "[SM] Entity limit is reached. Can't spawn anymore pumpkins. Change maps.");
		return Plugin_Handled;
	}

	g_iPumpkins[client][g_iCurrent[client]] = CreateEntityByName("tf_pumpkin_bomb");
#if defined DEBUG
	PrintToServer("DEBUG: Spawned a pumpkin for %N with an entity id of %i and has %i pumpkins", client, g_iPumpkins[client][g_iCurrent[client]], g_iCurrent[client]+1);
#endif
	if(IsValidEntity(g_iPumpkins[client][g_iCurrent[client]]))
	{
		char tName[MAX_NAME_LENGTH];
		Format(tName, sizeof tName, "AJMPumpkin%i", client);
		DispatchKeyValue(g_iPumpkins[client][g_iCurrent[client]], "targetname", tName);
		DispatchSpawn(g_iPumpkins[client][g_iCurrent[client]]);
		SetEntProp(g_iPumpkins[client][g_iCurrent[client]], Prop_Data, "m_CollisionGroup", 17)
		SDKHook(g_iPumpkins[client][g_iCurrent[client]], SDKHook_OnTakeDamage, OnTakeDamage);
		g_iLastSpawned[client] = g_iPumpkins[client][g_iCurrent[client]];

		g_fPos[2] -= 10.0;
		TeleportEntity(g_iPumpkins[client][g_iCurrent[client]], g_fPos, NULL_VECTOR, NULL_VECTOR);
		g_iCurrent[client]++;
	}
	return Plugin_Handled;
}
public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	char pName[MAX_NAME_LENGTH], pName2[MAX_NAME_LENGTH];
	GetEntPropString(victim, Prop_Data, "m_iName", pName, sizeof pName);
	Format(pName2, sizeof pName2, "AJMPumpkin%i", attacker);

	if (strcmp(pName, pName2) == 0)
	{
#if defined DEBUG
		PrintToServer("DEBUG: Allowing damage on %s %N spawned that.", pName, attacker);
#endif
		return Plugin_Continue;
	} else {
#if defined DEBUG
		PrintToServer("DEBUG: Blocking damage on %s %N did not spawn that.", pName, attacker);
#endif
		damage = 0.0;
		return Plugin_Changed;
	}
}
public void OnEntityDestroyed(int entity)
{
	char pumpkin[MAX_NAME_LENGTH];
	GetEntityClassname(entity, pumpkin, sizeof pumpkin);

	if (strcmp(pumpkin, "tf_pumpkin_bomb", true) == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				for (int x = 0; x < 3; x++)
				{
					if (g_iPumpkins[i][x] == entity)
					{
#if defined DEBUG
						PrintToServer("DEBUG: Destroyed a pumpkin for %N with an entity id of %i and has %i pumpkins", i, entity, g_iCurrent[i]);
						PrintToServer("DEBUG: Killed timer for pumpkin %i", g_iPumpkins[i][x]);
#endif
						if (g_hTimersMax[i][x] != INVALID_HANDLE) { KillTimer(g_hTimersMax[i][x]); g_hTimersMax[i][x] = INVALID_HANDLE; }
						g_bTimerExists[i][x] = false;
						g_iPumpkins[i][x] = 0;
						g_iCurrent[i]--;
					}
				}
			}
		}
	}
}
Action timerAutoRemove(Handle timer, any data)
{
	int entity = data;
	char pumpkin[MAX_NAME_LENGTH];
	if (!IsValidEntity(entity))
	{
#if defined DEBUG
		PrintToServer("DEBUG: Timer returned %i isn't a valid entity...", entity);
#endif
		return; 
	}
	GetEntityClassname(entity, pumpkin, sizeof pumpkin);

	if (strcmp(pumpkin, "tf_pumpkin_bomb", true) == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				for (int x = 0; x < 3; x++)
				{
					if (g_iPumpkins[i][x] == entity)
					{
#if defined DEBUG
						PrintToServer("DEBUG: Auto removing pumpkin %i from %N it's been spawned way too long.", entity, i);
#endif
						if (IsValidEntity(entity)) { AcceptEntityInput(entity, "Kill"); }
						g_bTimerExists[i][x] = false;
						if (g_hTimersMax[i][x] != INVALID_HANDLE) { g_hTimersMax[i][x] = INVALID_HANDLE; }
					}
				}
			}
		}
	}
}
Action OnChangeClass(int client, const char[] command, int argc)
{
	char arg1[MAX_NAME_LENGTH]; GetCmdArg(1, arg1, sizeof arg1);
	if (!GetConVarBool(g_hEnabled)) { return Plugin_Handled; }
	
	// Limit heavyweapons
	if (strcmp("joinclass", command, false) == 0 && strcmp("heavyweapons", arg1[0], false) == 0)
	{
#if defined DEBUG
		PrintToServer("DEBUG: Client issued a %s command with %s as an arg.", command, arg1[0]);
#endif
		if (GetPlayersByClass(TFClass_Heavy) >= GetConVarInt(g_hHeavyRestrictCount))
		{
#if defined DEBUG
			PrintToServer("DEBUG: Blocking client %i (%N) from joining as a %s.", client, client, arg1[0]);
#endif
			if (GetConVarInt(g_hHeavyRestrictCount) > 0)
			{
				PrintToChat(client, "[SM] There are already too many people playing as a Heavy.");
			} else {
				PrintToChat(client, "[SM] Heavy has been disabled.");
			}
			return Plugin_Stop;
		}
	}
	// Limit medics
	if (strcmp("joinclass", command, false) == 0 && strcmp("medic", arg1[0], false) == 0)
	{
		if (GetPlayersByClass(TFClass_Medic) >= GetConVarInt(g_hMedicRestrictCount))
		{
#if defined DEBUG
			PrintToServer("DEBUG: Blocking client %i (%N) from joining as a %s.", client, client, arg1[0]);
#endif
			if (GetConVarInt(g_hMedicRestrictCount) > 0)
			{
				PrintToChat(client, "[SM] There are already too many people playing as a Medic.");
			} else {
				PrintToChat(client, "[SM] Medic has been disabled.");
			}
			return Plugin_Stop;
		}
	}
	// Limit spies
	if (strcmp("joinclass", command, false) == 0 && strcmp("spy", arg1[0], false) == 0)
	{
		if (GetPlayersByClass(TFClass_Spy) >= GetConVarInt(g_hSpyRestrictCount))
		{
#if defined DEBUG
			PrintToServer("DEBUG: Blocking client %i (%N) from joining as a %s.", client, client, arg1[0]);
#endif
			if (GetConVarInt(g_hSpyRestrictCount) > 0)
			{
				PrintToChat(client, "[SM] There are already too many people playing as a Spy.");
			} else {
				PrintToChat(client, "[SM] Spy has been disabled.");
			}
			return Plugin_Stop;
		}
	}
	// Limit snipers
	if (strcmp("joinclass", command, false) == 0 && strcmp("sniper", arg1[0], false) == 0)
	{
		if (GetPlayersByClass(TFClass_Sniper) >= GetConVarInt(g_hSniperRestrictCount))
		{
#if defined DEBUG
			PrintToServer("DEBUG: Blocking client %i (%N) from joining as a %s.", client, client, arg1[0]);
#endif
			if (GetConVarInt(g_hSniperRestrictCount) > 0)
			{
				PrintToChat(client, "[SM] There are already too many people playing as a Sniper.");
			} else {
				PrintToChat(client, "[SM] Sniper has been disabled.");
			}
			return Plugin_Stop;
		}
	}
	// Limit scouts
	if (strcmp("joinclass", command, false) == 0 && strcmp("scout", arg1[0], false) == 0)
	{
		if (GetPlayersByClass(TFClass_Scout) >= GetConVarInt(g_hScoutRestrictCount))
		{
#if defined DEBUG
			PrintToServer("DEBUG: Blocking client %i (%N) from joining as a %s.", client, client, arg1[0]);
#endif
			if (GetConVarInt(g_hScoutRestrictCount) > 0)
			{
				PrintToChat(client, "[SM] There are already too many people playing as a Scout.");
			} else {
				PrintToChat(client, "[SM] Scout has been disabled.");
			}
			return Plugin_Stop;
		}
	}
	return Plugin_Continue;
}
Action eventPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	ChangePlayerWeapon(client, TF2_GetPlayerClass(client));
}
int GetPlayersByClass(TFClassType class)
{
	int count = 0;
	for (int i=1;i<=MaxClients;i++)
	{
		if (IsValidClient(i) && TF2_GetPlayerClass(i) == class)
		{
			count++;
#if defined DEBUG
			PrintToServer("DEBUG: We have found %i (%N) players currently playing as class a %s", count, i, GetClassname(class));
#endif
		}
	}
	return count;
}
void ChangePlayerWeapon(int client, TFClassType class)
{
	if (!IsValidClient(client)) { return; }
	{
		int wep_idx = GetPlayerWeaponSlot(client, 0);
		// Medic
		if (class == TFClass_Medic && wep_idx != -1)
		{
#if defined DEBUG
			PrintToServer("DEBUG: Allowing client %i (%N) to use rockets on weapon id %i.", client, client, wep_idx);
			PrintToServer("DEBUG: Setting %i (%N) rocket damage push to %-.2f", client, client, GetConVarFloat(g_hMedicPower));
#endif
			if (!TF2Attrib_SetByDefIndex(wep_idx, 280, 2.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
			if (!TF2Attrib_SetByDefIndex(wep_idx, 135, 0.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
			if (!TF2Attrib_SetByDefIndex(wep_idx, 2, 100.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
			if (!TF2Attrib_SetByDefIndex(wep_idx, 58, GetConVarFloat(g_hMedicPower))) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
			if (!TF2Attrib_ClearCache(wep_idx)) { LogError("Failed to clear cache."); }
		}
		// Spy
		if (class == TFClass_Spy && wep_idx != -1)
		{
#if defined DEBUG
			PrintToServer("DEBUG: Allowing client %i (%N) to use rockets on weapon id %i.", client, client, wep_idx);
			PrintToServer("DEBUG: Setting %i (%N) rocket damage push to %-.2f", client, client, GetConVarFloat(g_hSpyPower));
#endif
			// Centerfire: 289
			if (!TF2Attrib_SetByDefIndex(wep_idx, 280, 2.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }	
			if (!TF2Attrib_SetByDefIndex(wep_idx, 289, 1.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }	
			if (!TF2Attrib_SetByDefIndex(wep_idx, 135, 0.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
			if (!TF2Attrib_SetByDefIndex(wep_idx, 2, 100.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
			if (!TF2Attrib_SetByDefIndex(wep_idx, 58, GetConVarFloat(g_hSpyPower))) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
			if (!TF2Attrib_ClearCache(wep_idx)) { LogError("Failed to clear cache."); }
		}
		// Sniper
		if (class == TFClass_Sniper && wep_idx != -1)
		{
#if defined DEBUG
			PrintToServer("DEBUG: Allowing client %i (%N) to use rockets on weapon id %i.", client, client, wep_idx);
			PrintToServer("DEBUG: Setting %i (%N) rocket damage push to %-.2f", client, client, GetConVarFloat(g_hSniperPower));
#endif
			if (!TF2Attrib_SetByDefIndex(wep_idx, 280, 2.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }	
			if (!TF2Attrib_SetByDefIndex(wep_idx, 289, 1.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }	
			if (!TF2Attrib_SetByDefIndex(wep_idx, 135, 0.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
			if (!TF2Attrib_SetByDefIndex(wep_idx, 2, 150.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
			if (!TF2Attrib_SetByDefIndex(wep_idx, 58, GetConVarFloat(g_hSniperPower))) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
			if (!TF2Attrib_SetByDefIndex(wep_idx, 318, GetConVarFloat(g_hSniperReload))) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }	
			if (!TF2Attrib_ClearCache(wep_idx)) { LogError("Failed to clear cache."); }
		}
		// Scout
		if (class == TFClass_Scout && wep_idx != -1)
		{
#if defined DEBUG
			PrintToServer("DEBUG: Allowing client %i (%N) to use rockets on weapon id %i.", client, client, wep_idx);
			PrintToServer("DEBUG: Setting %i (%N) rocket damage push to %-.2f", client, client, GetConVarFloat(g_hScoutPower));
#endif
			if (!TF2Attrib_SetByDefIndex(wep_idx, 280, 2.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }	
			if (!TF2Attrib_SetByDefIndex(wep_idx, 289, 1.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }	
			if (!TF2Attrib_SetByDefIndex(wep_idx, 135, 0.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
			if (!TF2Attrib_SetByDefIndex(wep_idx, 2, 150.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
			if (!TF2Attrib_SetByDefIndex(wep_idx, 58, GetConVarFloat(g_hScoutPower))) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
			if (GetConVarBool(g_hScoutDJ) && GetConVarBool(g_hScoutDJ))
			{
#if defined DEBUG
				PrintToServer("DEBUG: Turned on double jump.");
#endif
				TF2Attrib_RemoveByDefIndex(wep_idx, 49);
			}
			else
			{
#if defined DEBUG
				PrintToServer("DEBUG: Turned off double jump.");
#endif
				TF2Attrib_SetByDefIndex(wep_idx, 49, 1.0);
			}
			if (!TF2Attrib_ClearCache(wep_idx)) { LogError("Failed to clear cache."); }
		}
	}
}
void ReloadPlayerWeapons()
{
	bool remove = false;
	if (!GetConVarBool(g_hEnabled))
	{
		remove = true;
	}
	for (int i=1;i<=MaxClients;i++)
	{
		if (IsValidClient(i))
		{
			ChangePlayerWeapon(i, TF2_GetPlayerClass(i));
			if (remove)
			{
				TF2_RemoveAllWeapons(i);
				TF2_RegeneratePlayer(i);
			}
		}
	}
}
char GetClassname(TFClassType class)
{
	char myreturn[32];
	switch(class)
	{
		case 1:	{ Format(myreturn, sizeof(myreturn), "Scout"); }
		case 2: { Format(myreturn, sizeof(myreturn), "Sniper"); }
		case 3: { Format(myreturn, sizeof(myreturn), "Soldier"); }
		case 4: { Format(myreturn, sizeof(myreturn), "Demoman"); }
		case 5: { Format(myreturn, sizeof(myreturn), "Medic"); }
		case 6: { Format(myreturn, sizeof(myreturn), "Heavy"); }
		case 7: { Format(myreturn, sizeof(myreturn), "Pyro"); }
		case 8: { Format(myreturn, sizeof(myreturn), "Spy"); }
		case 9: { Format(myreturn, sizeof(myreturn), "Engineer"); }
		// Should never get here.
		default: { Format(myreturn, sizeof(myreturn), "Unknown"); }
	}
	return myreturn;
}
bool IsValidClient(int client)
{
    if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
        return false;
    
    return true;
}
bool SetTeleportEndPoint(int client)
{
	float 
		vAngles[3],
		vOrigin[3],
		vBuffer[3],
		vStart[3],
		Distance;
	GetClientEyePosition(client,vOrigin);
	GetClientEyeAngles(client, vAngles);
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	if(TR_DidHit(trace))
	{   	 
   	 	TR_GetEndPosition(vStart, trace);
		GetVectorDistance(vOrigin, vStart, false);
		Distance = -35.0;
   	 	GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
		g_fPos[0] = vStart[0] + (vBuffer[0]*Distance);
		g_fPos[1] = vStart[1] + (vBuffer[1]*Distance);
		g_fPos[2] = vStart[2] + (vBuffer[2]*Distance);
	}
	else
	{
		delete trace;
		return false;
	}
	delete trace;
	return true;
}
public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > GetMaxClients() || !entity;
}
void cvarEnable(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue) == 0)
	{
		SetConVarBool(g_hEnabled, false);
		PrintToChatAll("[SM] AltJumpMod has been disabled.");
	}
	else
	{
		SetConVarBool(g_hEnabled, true);
		PrintToChatAll("[SM] AltJumpMod has been enabled.");
	}
}
void cvarAutoRemove(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue) == 0)
	{
		SetConVarBool(g_hEnabled, false);
		ReloadPlayerWeapons();
	}
	else
	{
		SetConVarBool(g_hEnabled, true);
		ReloadPlayerWeapons();
	}
}
void cvarScoutPower(Handle convar, const char[] oldValue, const char[] newValue)
{
	SetConVarFloat(g_hScoutPower, StringToFloat(newValue));
	ReloadPlayerWeapons();
}
void cvarMedicPower(Handle convar, const char[] oldValue, const char[] newValue)
{
	SetConVarFloat(g_hMedicPower, StringToFloat(newValue));
	ReloadPlayerWeapons();
}
void cvarSpyPower(Handle convar, const char[] oldValue, const char[] newValue)
{
	SetConVarFloat(g_hSpyPower, StringToFloat(newValue));
	ReloadPlayerWeapons();
}
void cvarSniperPower(Handle convar, const char[] oldValue, const char[] newValue)
{
	SetConVarFloat(g_hSniperPower, StringToFloat(newValue));
	ReloadPlayerWeapons();
}
void cvarSniperReload(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue) == 0)
	{
		SetConVarBool(g_hSniperReload, false);
		ReloadPlayerWeapons();
	}
	else
	{
		SetConVarInt(g_hSniperReload, StringToInt(newValue));
		ReloadPlayerWeapons();
	}
}
void cvarHeavyRestrict(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue) == 0)
		SetConVarBool(g_hHeavyRestrictCount, false);
	else
		SetConVarInt(g_hHeavyRestrictCount, StringToInt(newValue));
}
void cvarSpyRestrict(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue) == 0)
		SetConVarBool(g_hSpyRestrictCount, false);
	else
		SetConVarInt(g_hSpyRestrictCount, StringToInt(newValue));
}
void cvarScoutRestrict(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue) == 0)
		SetConVarBool(g_hScoutRestrictCount, false);
	else
		SetConVarInt(g_hScoutRestrictCount, StringToInt(newValue));
}
void cvarScoutDJ(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue) == 0)
	{
		SetConVarBool(g_hScoutDJ, false);
		ReloadPlayerWeapons();
	}
	else
	{
		SetConVarInt(g_hScoutDJ, StringToInt(newValue));
		ReloadPlayerWeapons();
	}
}
void cvarSniperRestrict(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue) == 0)
		SetConVarBool(g_hSniperRestrictCount, false);
	else
		SetConVarInt(g_hSniperRestrictCount, StringToInt(newValue));
}
void cvarMedicRestrict(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue) == 0)
		SetConVarBool(g_hMedicRestrictCount, false);
	else
	{
		SetConVarInt(g_hMedicRestrictCount, StringToInt(newValue));
	}
}