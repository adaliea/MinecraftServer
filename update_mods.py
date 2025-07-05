import json
import yaml
import requests
import os

# --- Configuration ---
MODS_FILE = 'mods.json'
LOCK_FILE = 'version-info.lock'
COMPOSE_FILE = 'docker-compose.yml'

def get_mod_versions(slug_or_id, mc_version, loader):
    """Fetches version information for a mod from the Modrinth API."""
    api_url = f"https://api.modrinth.com/v2/project/{slug_or_id}/version"
    headers = {'User-Agent': 'ModpackUpdaterScript/1.2'}
    params = {
        'loaders': json.dumps([loader]),
        'game_versions': json.dumps([mc_version])
    }
    
    try:
        response = requests.get(api_url, params=params, headers=headers)
        response.raise_for_status()
        versions = response.json()
        
        if versions:
            print(f"  [API] Found specific version for '{slug_or_id}' on {mc_version}.")
            return versions[0]

        print(f"  [API] No version found for {mc_version}. Fetching latest available.")
        del params['game_versions']
        response = requests.get(api_url, params=params, headers=headers)
        response.raise_for_status()
        versions = response.json()
        
        if versions:
            return versions[0]
            
    except requests.exceptions.RequestException as e:
        print(f"  [API] Error fetching data for {slug_or_id}: {e}")
        
    return None

# --- 1. Load configuration from Docker Compose file ---
try:
    with open(COMPOSE_FILE, 'r') as f:
        compose_data = yaml.safe_load(f)
    env_vars = compose_data['services']['mc']['environment']
    mc_version = env_vars['VERSION']
    loader = env_vars['TYPE'].lower()
    print(f"✅ Loaded config from '{COMPOSE_FILE}': MC Version={mc_version}, Loader={loader}")
except (FileNotFoundError, KeyError) as e:
    print(f"❌ Error: Could not read '{COMPOSE_FILE}' or find required keys (VERSION, TYPE). Error: {e}")
    exit()

# --- 2. Load and validate the lock file ---
locked_mods = {}
if os.path.exists(LOCK_FILE):
    with open(LOCK_FILE, 'r') as f:
        lock_data = json.load(f)
    if lock_data.get('_meta', {}).get('minecraft_version') == mc_version:
        print(f"✅ Lock file is valid for Minecraft {mc_version}.")
        locked_mods = lock_data.get('mods', {})
    else:
        print(f"⚠️ MC Version mismatch! Lock file is for '{lock_data.get('_meta', {}).get('minecraft_version')}', but config is '{mc_version}'. Forcing API refresh.")
else:
    print(f"ℹ️ No '{LOCK_FILE}' found. Will fetch all mod info from API.")

# --- 3. Load source mods and resolve versions ---
try:
    with open(MODS_FILE, 'r') as f:
        source_mods = json.load(f)
except FileNotFoundError:
    print(f"❌ Error: '{MODS_FILE}' not found. Please create it first.")
    exit()

resolved_mods = []
needs_lock_update = False

for mod in source_mods:
    slug = mod['url'].split('/mod/')[1]
    name = mod['name']
    
    if slug not in locked_mods:
        print(f"[API] Checking for '{name}' ({slug})...")
        needs_lock_update = True
        latest_version = get_mod_versions(slug, mc_version, loader)
        
        if latest_version:
            locked_mods[slug] = {
                "id": latest_version['id'],
                "version_number": latest_version['version_number']
            }
        else:
            print(f"⚠️ Could not resolve a version for '{name}'. Skipping.")
            continue
    else:
        print(f"[CACHE] Using locked version for '{name}' ({slug}).")
            
    resolved_mods.append({
        "slug": slug,
        "name": name,
        "version_id": locked_mods[slug]['id']
    })

# --- 4. Save updated lock file if needed ---
if needs_lock_update:
    new_lock_data = {
        "_meta": {
            "minecraft_version": mc_version
        },
        "mods": locked_mods
    }
    with open(LOCK_FILE, 'w') as f:
        json.dump(new_lock_data, f, indent=4)
    print(f"✅ Lock file '{LOCK_FILE}' has been updated.")

# --- 5. Update the Docker Compose file ---
formatted_lines = []
for i, p in enumerate(resolved_mods):
    formatted_lines.append(f"{p['slug']}:{p['version_id']}")

compose_data['services']['mc']['environment']['MODRINTH_PROJECTS'] = "\n".join(formatted_lines)

with open(COMPOSE_FILE, 'w') as f:
    yaml.dump(compose_data, f, default_flow_style=False, sort_keys=False, indent=2)

print(f"🚀 Docker Compose file '{COMPOSE_FILE}' has been successfully updated!")