#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define VERSION "1.0"
#define MAX_PUMPKIN_LIMIT 3

#define DEBUG

float 
	g_pos[3];
int
	g_iPumpkins[MAXPLAYERS+1][MAX_PUMPKIN_LIMIT],
	g_iCurrent[MAXPLAYERS+1] = 0,
	g_iLastSpawned[MAXPLAYERS+1],
	g_iTimersMax[MAXPLAYERS+1][MAX_PUMPKIN_LIMIT];
Handle
	g_hEnabled,
	g_hRestrictClass,
	g_hAutoRemove,
	g_hTimersMax[MAXPLAYERS+1][MAX_PUMPKIN_LIMIT];
bool
	g_bTimerExists[MAXPLAYERS+1][MAX_PUMPKIN_LIMIT];

public Plugin:myinfo = 
{
	name = "AltJumpMod",
	author = "rush",
	description = "AltJumpMod - Add multiple ways for classes to 'jump'.",
	version = VERSION,
	url = "https://github.com/n0cpra/AltJumpMod"
}
public OnPluginStart()
{
	CreateConVar("sm_ajm_version", VERSION, "AnyJumpMod Version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_REPLICATED);
	g_hEnabled = CreateConVar("sm_ajm_enable", "1", "Turns this plugin on, or off.", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	g_hAutoRemove = CreateConVar("sm_ajm_autoremove", "1", "Auto remove pumpkins on/off.", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 1.0);

	RegAdminCmd("+pumpkin", cmdPumpkin, ADMFLAG_SLAY);
	RegAdminCmd("-pumpkin", cmdToggle, ADMFLAG_SLAY);
}
public Action cmdToggle(int client, int args)
{
	if (GetConVarBool(g_hEnabled) && GetConVarBool(g_hAutoRemove) && g_iCurrent[client]-1 < 3)
	{
#if defined DEBUG
	PrintToServer("DEBUG: Entity %i has been marked for auto removal.", g_iLastSpawned[client]);
#endif
		if (!g_bTimerExists[client][g_iCurrent[client]-1])
		{
			g_hTimersMax[client][g_iCurrent[client]-1] = CreateTimer(30.0, timerAutoRemove, g_iLastSpawned[client], TIMER_FLAG_NO_MAPCHANGE);
			g_bTimerExists[client][g_iCurrent[client]-1] = true;
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

		g_pos[2] -= 10.0;
		TeleportEntity(g_iPumpkins[client][g_iCurrent[client]], g_pos, NULL_VECTOR, NULL_VECTOR);
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
		PrintToServer("DEBUG: %s - %N did spawn that.", pName, attacker);
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
bool IsValidClient(int client)
{
    if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || IsFakeClient(client))
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
		g_pos[0] = vStart[0] + (vBuffer[0]*Distance);
		g_pos[1] = vStart[1] + (vBuffer[1]*Distance);
		g_pos[2] = vStart[2] + (vBuffer[2]*Distance);
	}
	else
	{
		CloseHandle(trace);
		return false;
	}
	CloseHandle(trace);
	return true;
}
public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > GetMaxClients() || !entity;
}