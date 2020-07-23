# No More Sounds

SourceMod plugin for use alongside KZTimer or GOKZ. 

### Features:
- Mute map music
- Mute gunshot sounds
- Mute other player footsteps (only when `mp_footsteps_serverside` is 1)
- Control volume of checkpoint/teleport sound

### Notes:
- `mp_footsteps_serverside` is being set by KZTimer in `/cfg/sourcemod/kztimer/main.cfg` and by GOKZ in `/cfg/sourcemod/gokz/gokz.cfg`
- You can set `sv_falldamage_scale` to 0 to remove falldamage sound on your server

### Commands:
- `!nms` / `!soundoptions` - opens options menu

### ConVars:
- `sm_nms_advertise` (default 0) - enables advertisement of the plugin in chat

