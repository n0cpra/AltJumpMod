/*
		This plugin uses the code from [TF2] pumpkins from linux_lover, and conc grenades from CrancK, and the pyro plugin from <name>
		All other code was written by me for this plugin.
*/
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#define REQUIRE_EXTENSIONS
#include <tf2attributes>
#undef REQUIRE_EXTENSIONS

#define VERSION "1.0"
#define MAX_PUMPKIN_LIMIT 3

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
	g_hMedicRestrictCount,
	g_hMedicPower;
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
public OnPluginStart()
{
	// Classes exluded from this plugin soldier, and demo. They have ways to jump. Engineer is here to make it faster.
	CreateConVar("sm_ajm_version", VERSION, "AltJumpMod Version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_REPLICATED);
	g_hEnabled = CreateConVar("sm_ajm_enable", "1", "Turns this plugin on, or off.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	// Heavy - Om nom nom nom!
	g_hAutoRemove = CreateConVar("sm_ajm_autoremove", "1", "Auto remove pumpkins on/off.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hHeavyRestrictCount = CreateConVar("sm_ajm_heavy_count", "1", "Limits the amount of heavys that can use this at once.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	// Medic
	g_hMedicRestrictCount = CreateConVar("sm_ajm_medic_count", "1", "Limits the amount of medics that can use this at once.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hMedicPower = CreateConVar("sm_ajm_medic_power", "2.50", "Limits the amount of power the rockets give the medic.", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 2.50, true, 5.0);
	// Scout
	
	// Sniper
	
	// Spy
	
	// Engineer
	
	// Pyro

	// Heavy commands
	RegConsoleCmd("+pumpkin", cmdPumpkin, "Spawns a pumpkin");
	RegConsoleCmd("-pumpkin", cmdToggle, "This is automatically fired.", FCVAR_HIDDEN|FCVAR_DONTRECORD);

	// ConVar hooks
	HookConVarChange(g_hEnabled, cvarEnable);
	// Heacy stuff
	HookConVarChange(g_hAutoRemove, cvarAutoRemove);
	HookConVarChange(g_hHeavyRestrictCount, cvarHeavyRestrict);
	// Medic stuff
	HookConVarChange(g_hMedicRestrictCount, cvarMedicRestrict);
	HookConVarChange(g_hMedicPower, cvarMedicPower);
	
	// Event hooks
	HookEvent("player_spawn", eventPlayerSpawn);
	
	// Command listeners
	AddCommandListener(OnChangeClass, "joinclass");
	
}
public Action cmdToggle(int client, int args)
{
	if (GetConVarBool(g_hEnabled) && GetConVarBool(g_hAutoRemove) && g_iCurrent[client]-1 < 3)
	{
		if (TF2_GetPlayerClass(client) != TFClass_Heavy)
		{
			return Plugin_Handled;
		}
#if defined DEBUG
		// Sometimes a bug happens when this prints and shows the entity as 0. purely a display bug.
		// Bug fix: remove g_iLastSpawned[client] = 0; from here and put it at the top of cmdPumpkin. UNTESTED
		PrintToServer("DEBUG: Entity %i has been marked for auto removal.", g_iLastSpawned[client]);
#endif
		for (int x=0;x<MAX_PUMPKIN_LIMIT;x++)
		{
			if (!g_bTimerExists[client][x])
			{
				g_hTimersMax[client][x] = CreateTimer(30.0, timerAutoRemove, g_iLastSpawned[client], TIMER_FLAG_NO_MAPCHANGE);
				g_bTimerExists[client][x] = true;
			}
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

	g_iLastSpawned[client] = 0;
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
						PrintToServer("DEBUG: Destroyed a pumpkin for %N with an entity id of %i and has %i pumpkins (%i)", i, entity, g_iCurrent[i], x);
#endif
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
						g_hTimersMax[i][x] = INVALID_HANDLE;
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
				PrintToChat(client, "[SM] There are already too many people playing as a heavy.");
			} else {
				PrintToChat(client, "[SM] Heavy has been disabled.");
			}
			return Plugin_Stop;
		}
	}
	if (strcmp("joinclass", command, false) == 0 && strcmp("medic", arg1[0], false) == 0)
	{
	// Limit medics
		if (GetPlayersByClass(TFClass_Medic) >= GetConVarInt(g_hMedicRestrictCount))
		{
	#if defined DEBUG
			PrintToServer("DEBUG: Blocking client %i (%N) from joining as a %s.", client, client, arg1[0]);
	#endif
			if (GetConVarInt(g_hMedicRestrictCount) > 0)
			{
				PrintToChat(client, "[SM] There are already too many people playing as a medic.");
			} else {
				PrintToChat(client, "[SM] Medic has been disabled.");
			}
			return Plugin_Stop;
		}
	}
	// Limit pyros
	// Limit spies
	// Limit engineers
	// Limit snipers
	// Limit scouts
	return Plugin_Continue;
}
Action eventPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int wep_idx = GetPlayerWeaponSlot(client, 0);
	
	if (!IsValidClient(client)) { return; }

	if (TF2_GetPlayerClass(client) == TFClass_Medic && wep_idx != -1)
	{
#if defined DEBUG
		PrintToServer("DEBUG: Allowing client %i (%N) to use rockets on weapon id %i.", client, client, wep_idx);
		PrintToServer("DEBUG: Setting %i (%N) rocket damage push to %-.2f less", client, client, GetConVarFloat(g_hMedicPower));
#endif
		if (!TF2Attrib_SetByDefIndex(wep_idx, 280, 2.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
		if (!TF2Attrib_SetByDefIndex(wep_idx, 135, 0.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
		if (!TF2Attrib_SetByDefIndex(wep_idx, 2, 100.0)) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
		if (!TF2Attrib_SetByDefIndex(wep_idx, 59, GetConVarFloat(g_hMedicPower))) { PrintToChat(client, "[SM] Failed to apply changes."); LogError("Failed to apply attribute changes to %i on client %i (%N)", wep_idx, client, client); }
		if (!TF2Attrib_ClearCache(wep_idx)) { LogError("Failed to clear cache."); }
	}
}
/* 
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
*/
int GetPlayersByClass(TFClassType class)
{
	int count = 0;
	for (int i=1;i<=MaxClients;i++)
	{
		if (IsValidClient(i) && TF2_GetPlayerClass(i) == class)
		{
			count++;
#if defined DEBUG
			PrintToServer("DEBUG: We have found %i (%N) players currently playing as a heavy", count, i);
#endif
		}
	}
	return count;
}
bool IsValidClient(int client)
{
    if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
        return false;
    
    return true;
}
SetTeleportEndPoint(int client)
{
	float 
		vAngles[3],
		vOrigin[3],
		vBuffer[3],
		vStart[3],
		Distance;
	GetClientEyePosition(client,vOrigin);
	GetClientEyeAngles(client, vAngles);
    //get endpoint for teleport
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
// Convar hooks
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
		SetConVarBool(g_hEnabled, false);
	else
		SetConVarBool(g_hEnabled, true);
}
void cvarMedicPower(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (StringToFloat(newValue) > 0.0 && StringToFloat(newValue) <= 5.0)
	{
		SetConVarFloat(g_hMedicPower, StringToFloat(newValue));
	} 
}
void cvarHeavyRestrict(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue) == 0)
	{
		SetConVarBool(g_hHeavyRestrictCount, false);
	}
	else
	{
		if (StringToInt(newValue) <= 5)
		{
			SetConVarInt(g_hHeavyRestrictCount, StringToInt(newValue));
		} 
	}
}
void cvarMedicRestrict(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue) == 0)
	{
		SetConVarBool(g_hMedicRestrictCount, false);
	}
	else
	{
		if (StringToInt(newValue) <= 5)
		{
			SetConVarInt(g_hMedicRestrictCount, StringToInt(newValue));
		}
	}
}