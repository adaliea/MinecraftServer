import json
import yaml

# --- Configuration ---
JSON_FILE = 'mods.json'
DOCKER_COMPOSE_FILE = 'docker-compose.yml'

# --- 1. Process the JSON mod list ---
try:
    with open(JSON_FILE, 'r') as f:
        mods_list = json.load(f)
except FileNotFoundError:
    print(f"Error: '{JSON_FILE}' not found. Please place it in the same directory.")
    exit()

# Format mods as 'slug:version' and create a list
formatted_mods_list = []
for mod in mods_list:
    try:
        slug = mod['url'].split('/mod/')[1]
        version = mod['version']
        formatted_mods_list.append(f"{slug}:{version}")
    except (IndexError, KeyError) as e:
        print(f"Warning: Skipping invalid entry in JSON: {mod}. Error: {e}")

# Join with newlines to create the multi-line string for the YAML file
new_modrinth_projects_value = "\n".join(formatted_mods_list)

# --- 2. Update the Docker Compose file ---
try:
    with open(DOCKER_COMPOSE_FILE, 'r') as f:
        compose_data = yaml.safe_load(f)
except FileNotFoundError:
    print(f"Error: '{DOCKER_COMPOSE_FILE}' not found.")
    exit()

# Navigate to the correct key and update the value
try:
    compose_data['services']['mc']['environment']['MODRINTH_PROJECTS'] = new_modrinth_projects_value
except KeyError as e:
    print(f"Error: Could not find key path in Docker Compose file. Missing key: {e}")
    exit()

# --- 3. Write the changes back to the file ---
with open(DOCKER_COMPOSE_FILE, 'w') as f:
    # Dump the data back, preserving the block style for multi-line strings
    yaml.dump(compose_data, f, default_flow_style=False, sort_keys=False, indent=2)

print(f"✅ Docker Compose file '{DOCKER_COMPOSE_FILE}' has been updated successfully!")