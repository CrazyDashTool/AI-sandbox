# AI Sandbox

AI Sandbox is a 3D Godot sandbox game built for the [DEV Gemma 4 Challenge](https://dev.to/devteam/join-the-gemma-4-challenge-3000-prize-pool-for-ten-winners-23in).

The project experiments with an AI-controlled companion inside a small interactive island. The NPC is not only a chatbot: it sees the world through its own camera, receives a compact memory of the current world state, answers the player, chooses an action, and then physically acts in the scene.

The default AI configuration targets `gemma-4-31b-it`, with support for Google, OpenRouter, Ollama, and LM Studio style backends.

## What It Is

AI Sandbox is a first-person physics playground where the player can:

- Walk around a small island with a beach, pier, park, fountain, construction area, camping spot, observation tower, and water.
- Spawn props such as cubes, balls, boards, chairs, benches, trees, rocks, balloons, Gemma tokens, wheels, lamps, barrels, and metal pipes.
- Pick up, throw, rotate, pin, weld, float, and motorize objects.
- Talk to an AI NPC that can observe the scene, remember places, move around, sit, swim, collect objects, use nearby props, and react to player actions.
- Change AI providers, graphics settings, audio settings, weather, time of day, and sandbox/debug options.

The core idea is to make the model part of the simulation. The player can give natural language instructions, and the NPC uses both vision and world context to decide what to do next.

## Challenge Angle

This was made for the Gemma 4 Challenge as an interactive game prototype where the model powers real gameplay behavior.

The AI is used for:

- Multimodal scene understanding through an NPC camera snapshot.
- Structured decision making using JSON responses.
- Natural language conversation with the player.
- High-level action selection for the NPC.
- Remembering places and recent world events.
- Turning player requests into in-world behavior.

The model is not just generating text on a menu screen. It directly affects movement, interaction, navigation, and sandbox play.

## Key Features

### AI NPC

- Vision-driven NPC brain with a camera mounted on the NPC head.
- Structured AI responses containing:
  - visual observation
  - speech
  - selected action
  - emotion
- Supported emotions include neutral, happy, surprised, scared, curious, and annoyed.
- The NPC can walk, flee, look around, wave, jump, sit, swim, collect objects, use nearby objects, and build or pin props.
- Direct command parsing is used for some clear player requests before falling back to the model.

### World Memory

The `WorldContext` autoload keeps track of:

- spawned objects
- player actions
- constructions
- conversation memory
- known places
- weather state
- day phase
- water state
- music/environment state

Known places are saved to `user://world_memory.cfg`, so the NPC can keep learned map locations between sessions.

### Physics Sandbox

The player can create and manipulate sandbox objects with several tools:

- Weld Tool: links two nearby objects together.
- Float Tool: toggles buoyancy on props.
- Motor Tool: turns compatible objects into motorized props.
- Driver Tool: pilots motorized or welded objects.
- Pin action: freezes an object in place.

Props use Godot physics with Jolt Physics enabled. Many objects also have material metadata for impact sounds, buoyancy, interaction behavior, and AI awareness.

### Island Map

The authored world includes several recognizable areas:

- Building zone
- Park
- Beach
- Pier
- Fountain
- Observation tower
- Camping area
- Street lights
- Water around the island
- Second island

The map also has grass, terrain, water shaders, particle effects, benches, trees, and other decoration.

### Water, Weather, And Time

The project includes:

- Swimming and underwater movement.
- Underwater screen effect.
- Splash effects for player, NPC, and props.
- Ambient water and underwater audio.
- Dynamic weather states such as clear, cloudy, mist, and rain.
- Day/night cycle with sun, moon, lights, campfire emission, rain sounds, thunder, and lightning visuals.

### Menus And Settings

The game has:

- Main menu with live world preview.
- First-run AI provider dialog.
- AI settings panel.
- Graphics settings panel.
- Audio settings panel.
- Pause menu.
- Spawn menu.
- Player HUD with chat, crosshair, holding label, and NPC status.
- Developer console.

## How It Works

1. The player types a message to the NPC.
2. `WorldContext` creates a compact summary of the current world.
3. The NPC captures an image from its own camera using a SubViewport.
4. `NPCBrain` builds a prompt with:
   - player message
   - NPC capabilities
   - recent memory
   - known places
   - world summary
   - camera image
5. `AIProvider` sends the request to the selected backend.
6. The backend returns a JSON object with speech, visual observation, emotion, and action.
7. `NPCBrain` applies the response.
8. `NPCMovement` executes the action in the Godot world.
9. The HUD shows the NPC reply and the NPC changes expression or behavior.

This loop makes the AI feel like an agent living inside the island instead of a separate text box.

## AI Providers

The project supports multiple AI backends through `AIProvider.gd`.

| Provider | Default model | Default endpoint |
| --- | --- | --- |
| Google | `gemma-4-31b-it` | `https://generativelanguage.googleapis.com/v1beta` |
| OpenRouter | `google/gemma-4-31b-it:free` | `https://openrouter.ai/api/v1/chat/completions` |
| Ollama | `gemma3:12b` | `http://localhost:11434/api/chat` |
| LM Studio | `local-model` | `http://localhost:1234/v1/chat/completions` |

Cloud providers require an API key. Local providers can run without a key if the local server is already running.

AI settings are saved in `user://brain.cfg`. The game also supports offline mode, which lets the player use the sandbox without AI calls.

## Controls

| Control | Action |
| --- | --- |
| `WASD` | Move |
| Mouse | Look around |
| `Shift` | Sprint |
| `Space` | Jump |
| `Ctrl` | Crouch / swim down |
| `E` | Pick up or place object |
| Left mouse | Spawn, use selected tool, or push |
| Right mouse | Throw held object |
| Mouse wheel | Rotate held object |
| `G` | Pin held or targeted object |
| `F` | Use or interact |
| `Q` | Open spawn menu |
| `T` | Chat with NPC |
| `P` | Toggle NPC camera view |
| `Esc` | Pause menu |
| Backtick | Developer console |

## Example NPC Prompts

Try messages like:

```text
Look at me and describe what you see.
Remember this place as the beach.
Go to the beach.
Follow route beach -> tower -> me.
Collect all Gemma tokens.
Sit on the bench.
Build something and pin it.
Run away from me.
Go swim in the water.
Move the nearest object.
```

The NPC can also understand many direct object and place commands without needing a full model response every time.

## Developer Console

Open the console with the backtick key.

Useful commands:

```text
weather clear
weather rain now
weather lock
weather unlock
lightning
time morning
time noon
time evening
time night
time 18
time lock
time unlock
timescale 2
noclip on
fly on
flyspeed 20
tp 0 5 0
respawn
spawn Cube
status
clear
close
```

## Running The Project

### Requirements

- Godot 4.6 or newer.
- A GPU capable of running the Forward Plus renderer.
- Optional: an API key or a local AI backend if you want AI behavior.

### Steps

1. Clone or download this repository.
2. Open `project.godot` in Godot.
3. Let Godot import the assets and enabled plugins.
4. Run the project.
5. Start from the main menu.
6. Configure an AI provider in the AI settings panel, or choose offline mode.

The configured main scene is:

```text
res://scenes/Main menu/node_3d.tscn
```

The main in-game sandbox scene is:

```text
res://main.tscn
```

## Project Structure

```text
addons/                  Godot plugins used by the project
assets/props/            Spawnable prop assets
autoloads/               Global state and persistent configuration
scenes/                  Main menu, world, player, NPC, props, and UI scenes
scripts/                 Gameplay, AI, UI, weather, physics, and tools
shaders/                 Water, sky, underwater, glass, fire, and material shaders
Sounds/                  Music, ambience, weather, water, and prop impact sounds
Textures/                Texture assets
OtherStuff/              Extra authored map assets and environment props
```

## Important Scripts

| Script | Purpose |
| --- | --- |
| `autoloads/GameState.gd` | Input mapping, settings, audio buses, graphics quality, and AI config persistence. |
| `scripts/WorldContext.gd` | Shared world memory, known places, player actions, environment state, and AI context summaries. |
| `scripts/AIProvider.gd` | Provider abstraction for Google, OpenRouter, Ollama, and LM Studio requests. |
| `scripts/NPCBrain.gd` | Builds prompts, captures NPC vision, parses AI JSON, and chooses NPC behavior. |
| `scripts/NPCMovement.gd` | Navigation, pathing, sitting, swimming, fleeing, collection tasks, and route following. |
| `scripts/NPC.gd` | NPC visual setup, emotions, speech bubble, camera transform, and reactions. |
| `scripts/Player.gd` | First-person movement, chat, object holding, spawning, interaction, and camera modes. |
| `scripts/SpawnMenu.gd` | Spawn categories and tool selection UI. |
| `scripts/ObjectSpawner.gd` | Creates procedural and asset-backed sandbox props. |
| `scripts/SpawnedProp.gd` | Physics object behavior, buoyancy, impact sounds, pinning, and interaction metadata. |
| `scripts/PlayerToolActions.gd` | Weld, float, motor, driver, pin, and prop manipulation tools. |
| `scripts/WeatherCycle.gd` | Dynamic sky, time of day, weather state, rain, moon, lights, and environment updates. |
| `scripts/GameConsole.gd` | Debug console commands for weather, time, movement, spawning, and status. |

## Notes For Judges

The AI integration is designed around an agent loop:

- The NPC sees the world.
- The world gives the model grounded state.
- The model responds in a strict action schema.
- The game turns that response into movement and physics interactions.

This makes the Gemma-powered behavior visible inside the actual gameplay space.

## Current Limitations

- This repository is a Godot project, not a packaged release build.
- AI quality depends on the selected provider, model, endpoint, and latency.
- Offline mode disables AI calls but keeps the sandbox playable.
- API keys are saved under Godot's `user://` path and should not be committed.
- Some assets and plugins may have their own licenses. Check third-party terms before redistributing a packaged build.

## License

See `LICENSE` for the repository license and review third-party asset or plugin licenses where applicable.
