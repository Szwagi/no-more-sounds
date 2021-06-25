#include <sourcemod>
#include <sdktools>
#include <clientprefs>

// ================================================

public Plugin myinfo =
{
	name = "No More Sounds",
	author = "Szwagi",
	version = "v1.0.1",
	url = "https://github.com/Szwagi/no-more-sounds"
};

// ================================================

#define MAP_MUSIC "nms-map-music"
#define GUN_SOUNDS "nms-gun-sounds"
#define FOOTSTEP_SOUNDS "nms-footstep-sounds"
#define MENU_SOUNDS_VOLUME "nms-menu-sounds-volume"

// ================================================

bool g_changedOptions[MAXPLAYERS+1];

bool g_mapMusic[MAXPLAYERS+1];
bool g_gunSounds[MAXPLAYERS+1];
int g_menuSoundsVolume[MAXPLAYERS+1]; // 0 to 10 inclusive
bool g_footstepSounds[MAXPLAYERS+1];

Cookie g_mapMusicCookie;
Cookie g_gunSoundsCookie;
Cookie g_menuSoundsVolumeCookie;
Cookie g_footstepSoundsCookie;

ConVar g_cv_footstepsServerside;
ConVar g_cv_advertise;

// ================================================

public void OnPluginStart()
{
    g_mapMusicCookie = new Cookie(MAP_MUSIC, "", CookieAccess_Private);
    g_gunSoundsCookie = new Cookie(GUN_SOUNDS, "", CookieAccess_Private);
    g_menuSoundsVolumeCookie = new Cookie(MENU_SOUNDS_VOLUME, "", CookieAccess_Private);
    g_footstepSoundsCookie = new Cookie(FOOTSTEP_SOUNDS, "", CookieAccess_Private);

    g_cv_footstepsServerside = FindConVar("mp_footsteps_serverside");
    g_cv_advertise = CreateConVar("sm_nms_advertise", "0", "Advertise No More Sounds in chat (every 5 minutes)");

    CreateTimer(60.0 * 5.0, Timer_Advertise, 0, TIMER_REPEAT);

    AddNormalSoundHook(Hook_NormalSound);
    AddTempEntHook("Shotgun Shot", Hook_ShotgunShot);

    RegConsoleCmd("sm_nms", Command_Options);
    RegConsoleCmd("sm_soundoptions", Command_Options);
    RegConsoleCmd("sm_stopsound", Command_Options);
    RegConsoleCmd("sm_mapmusic", Command_Options);
    RegConsoleCmd("sm_stopmapmusic", Command_Options);
    RegConsoleCmd("sm_stopmusic", Command_Options);
    RegConsoleCmd("sm_music", Command_Options);
}

public void OnClientConnected(int client)
{
    g_changedOptions[client] = false;
    g_mapMusic[client] = true;
    g_gunSounds[client] = true;
    g_footstepSounds[client] = true;
    g_menuSoundsVolume[client] = 10;
}

public void OnClientDisconnect(int client)
{
    // This check is here because we don't want to bloat the cookie db with default values
    if (g_changedOptions[client])
    {
        g_mapMusicCookie.Set(client, g_mapMusic[client] ? "1" : "0");
        g_gunSoundsCookie.Set(client, g_gunSounds[client] ? "1" : "0");
        g_footstepSoundsCookie.Set(client, g_footstepSounds[client] ? "1" : "0");

        char buffer[16];
        IntToString(g_menuSoundsVolume[client], buffer, sizeof(buffer));
        g_menuSoundsVolumeCookie.Set(client, buffer);
    }
}

public void OnClientCookiesCached(int client)
{
    char buffer[16];

    g_mapMusicCookie.Get(client, buffer, sizeof(buffer));
    if (buffer[0] != 0)
    {
        g_mapMusic[client] = buffer[0] != '0';
    }

    g_gunSoundsCookie.Get(client, buffer, sizeof(buffer));
    if (buffer[0] != 0)
    {
        g_gunSounds[client] = buffer[0] != '0';
    }

    g_footstepSoundsCookie.Get(client, buffer, sizeof(buffer));
    if (buffer[0] != 0)
    {
        g_footstepSounds[client] = buffer[0] != '0';
    }

    g_menuSoundsVolumeCookie.Get(client, buffer, sizeof(buffer));
    if (buffer[0] != 0)
    {
        int vol = StringToInt(buffer);
        if (vol < 0 || vol > 10)
            vol = 10;

        g_menuSoundsVolume[client] = vol;
    }
}

public void OnPlayerRunCmdPost(int client)
{
    if (IsValidClient(client) && !g_mapMusic[client])
    {
        SetEntProp(client, Prop_Data, "soundscapeIndex", 0);
    }
}

// ================================================

Action Timer_Advertise(Handle timer, any data)
{
    if (g_cv_advertise.BoolValue)
    {
        PrintToChatAll(" \x10[NMS] \x01The \x03!nms \x01menu lets you configure your sound preferences, for example disable map music.");
    }
    return Plugin_Continue;
}

Action Hook_NormalSound(int clients[MAXPLAYERS], int& numClients, char sample[PLATFORM_MAX_PATH], 
                        int& entity, int& channel, float& volume, int& level, int& pitch, 
                        int& flags, char soundEntry[PLATFORM_MAX_PATH], int& seed)
{
    // Menu sound volume
    if (numClients == 1)
    {
        int client = clients[0];
        if (StrEqual(sample, "buttons/blip1.wav") || StrEqual(sample, "buttons/button10.wav"))
        {
            volume = float(g_menuSoundsVolume[client]) / 10.0;
            volume = Pow(volume, 3.0); // I'm sure there's some scientific explanation to this
            return Plugin_Changed;
        }
    }

    // Footsteps
    if (g_cv_footstepsServerside.BoolValue)
    {
        if (StrContains(sample, "/footsteps/") >= 0)
        {
            int numNewClients = 0;
            for (int i = 0; i < numClients; i++)
            {
                int client = clients[i];
                if (g_footstepSounds[client] || client == entity)
                {
                    clients[numNewClients] = client;
                    numNewClients++;
                }
            }
            numClients = numNewClients;
            return Plugin_Changed;
        }
    }

    return Plugin_Continue;
}

Action Hook_ShotgunShot(const char[] tename, const int[] clients, int numClients, float delay)
{
    int newClients[MAXPLAYERS];
    int numNewClients = 0;
    for (int i = 0; i < numClients; i++) {
        int client = clients[i];
        if (g_gunSounds[client])
        {
            newClients[numNewClients] = client;
            numNewClients++;
        }
    }

    // Nobody wants to hear it, don't send at all
    if (numNewClients == 0)
    {
        return Plugin_Stop;
    }

    // We actually changed something, send our own temp-ent
    if (numNewClients != numClients) {
        float origin[3];
        TE_Start("Shotgun Shot");
        TE_ReadVector("m_vecOrigin", origin);
        TE_WriteVector("m_vecOrigin", origin);
        TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
        TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
        TE_WriteNum("m_weapon", TE_ReadNum("m_weapon"));
        TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
        TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
        TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
        TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
        TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
        TE_Send(newClients, numNewClients, delay);
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

// ================================================

bool IsValidClient(int client)
{
    return client >= 1 && client <= MaxClients && IsClientInGame(client);
}

void DisplayOptionsMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Options);
    menu.SetTitle("No More Sounds (by Szwagi)\n ");

    char mapMusicLine[64];
    char gunSoundLine[64];
    char menuSoundVolumeLine[64];
    char footstepSoundLine[64];

    Format(mapMusicLine, sizeof(mapMusicLine), "Map Music  -  %s", g_mapMusic[client] ? "On" : "Off");
    Format(gunSoundLine, sizeof(gunSoundLine), "Gunshot Sounds  -  %s", g_gunSounds[client] ? "On" : "Off");
    Format(menuSoundVolumeLine, sizeof(menuSoundVolumeLine), "CP/TP Sound Volume  -  %d%%", g_menuSoundsVolume[client] * 10);
    Format(footstepSoundLine, sizeof(footstepSoundLine), "Footstep Sounds  -  %s", g_footstepSounds[client] ? "On" : "Off");

    menu.AddItem(MAP_MUSIC, mapMusicLine);
    menu.AddItem(GUN_SOUNDS, gunSoundLine);
    menu.AddItem(MENU_SOUNDS_VOLUME, menuSoundVolumeLine);
    if (g_cv_footstepsServerside.BoolValue)
    {
        menu.AddItem(FOOTSTEP_SOUNDS, footstepSoundLine);
    }

    menu.Display(client, 0);
}

// ================================================

int MenuHandler_Options(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int client = param1;
        int item = param2;

        char info[64];
        menu.GetItem(item, info, sizeof(info));

        if (StrEqual(info, MAP_MUSIC))
        {
            g_mapMusic[client] = !g_mapMusic[client];
        }
        else if (StrEqual(info, GUN_SOUNDS))
        {
            g_gunSounds[client] = !g_gunSounds[client];
        }
        else if (StrEqual(info, FOOTSTEP_SOUNDS))
        {
            g_footstepSounds[client] = !g_footstepSounds[client];
        }
        else if (StrEqual(info, MENU_SOUNDS_VOLUME))
        {
            g_menuSoundsVolume[client]++;
            if (g_menuSoundsVolume[client] > 10)
                g_menuSoundsVolume[client] = 0;
        }

        g_changedOptions[client] = true;
        DisplayOptionsMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}


Action Command_Options(int client, int argc)
{
    if (!AreClientCookiesCached(client))
    {
        PrintToChat(client, "Your preferences didn't load yet, try again soon.");
        return Plugin_Handled;
    }

    DisplayOptionsMenu(client);
    return Plugin_Handled;
}
