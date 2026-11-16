# **Implementation Plan: Post-Boss Villain Cutscene**

## **Goal & Architectural Rules**

Create a composition-based, signal-driven cutscene that triggers after defeating a boss.

> * **Strict static typing** on all variables and parameters (GDScript 2.0).  
> * **Composition over inheritance**: Implement as a self-contained component node (res://Scripts/Cutscenes/BossVillainCutscene.gd) attached to res://Scenes/world.tscn.  
> * **SignalBus decoupling**: Trigger via res://Core/SignalBus.gd rather than hard-coupling to CombatManager.  
> * **Grid-movement safety**: Ensure the camera's backward tween uses PhysicsRayQueryParameters3D to prevent clipping through dungeon walls.  
> * **Party vitals boundary**: Modify HP cleanly through CatCharacter resource properties so the UI updates correctly.


To use this, I want to be able to add a scene to level, and when they player walks into the scene, an event fires. but NOTHING is visible like they cant see the boss until they walk into the scene. so they have no idea its coming. 

## **Step 1: Add Signals to SignalBus**

Open res://Core/SignalBus.gd and add the lifecycle signals for the cutscene:

signal boss\_cutscene\_requested(cutscene\_id: String, anchor\_position: Vector3)  
signal boss\_cutscene\_finished(cutscene\_id: String)

## **Step 2: Extend Ghost Scare Shader for Sustained Vignette**

The current ghost scare flashes and deletes itself. We need a sustained mode for the dark red vignette.

### **2a. Update res://Shaders/ghost\_scare\_screen.gdshader**

Add a uniform to lock the shader into a sustained vignette mode without the double-vision split:

uniform float vignette\_only : hint\_range(0.0, 1.0) \= 0.0;

In the fragment() function, add logic to mix the sustained vignette:

// Sustained dark-red horror vignette: keeps center readable, crushes edges to dark crimson/black.  
float edge\_mask \= smoothstep(0.18, 0.72, distance(uv, vec2(0.5))) \* intensity;  
vec3 dark\_crimson \= tint.rgb \* 0.28;  
vec3 vignette\_col \= mix(col, dark\_crimson, edge\_mask \* 0.85);  
vignette\_col \*= 1.0 \- edge\_mask \* 0.65;

vec3 base\_fx \= mix(scare, blood, duotone);  
COLOR \= vec4(mix(base\_fx, vignette\_col, vignette\_only), 1.0);

### **2b. Add Sustained Helpers to res://Scripts/Enemies/GhostScareFX.gd**

Add a static constructor for the sustained vignette (layer 102, below LoreScare at 105\) and a fade-out function:

static func start\_red\_vignette(tree: SceneTree, fade\_in\_seconds: float \= 0.8, max\_intensity: float \= 0.92, tint: Color \= Color(0.75, 0.03, 0.03)) \-\> GhostScareFX:  
	if tree \== null or tree.root \== null:  
		return null  
	var fx := GhostScareFX.new()  
	fx.layer \= 102 \# Below LoreScareFX (105) so the cube flash punches through  
	fx.\_material.set\_shader\_parameter(&"tint", tint)  
	fx.\_material.set\_shader\_parameter(&"duotone", 0.0)  
	fx.\_material.set\_shader\_parameter(&"vignette\_only", 1.0)  
	fx.\_material.set\_shader\_parameter(&"split\_amount", 0.006)  
	tree.root.add\_child(fx)  
	fx.\_set\_intensity(0.0)  
	  
	var tween: Tween \= fx.create\_tween()  
	tween.tween\_method(fx.\_set\_intensity, 0.0, clampf(max\_intensity, 0.0, 1.0), maxf(0.05, fade\_in\_seconds)) \\  
			.set\_trans(Tween.TRANS\_SINE).set\_ease(Tween.EASE\_OUT)  
	return fx

func fade\_out\_and\_free(fade\_out\_seconds: float \= 0.5) \-\> void:  
	var current: float \= float(\_material.get\_shader\_parameter(&"intensity"))  
	var tween: Tween \= create\_tween()  
	tween.tween\_method(\_set\_intensity, current, 0.0, maxf(0.05, fade\_out\_seconds))  
	tween.finished.connect(queue\_free)

## **Step 3: Create the Cutscene Component**

Create res://Scripts/Cutscenes/BossVillainCutscene.gd (class\_name BossVillainCutscene extends Node). Attach this to res://Scenes/world.tscn.

### **Exported Properties**

@export var cutscene\_id: String \= "main\_villain\_intro"  
@export var villain\_scene: PackedScene  
@export var villain\_spawn\_distance: float \= 3.6  
@export var lore\_flash\_texture: Texture2D  
@export var scary\_voice\_stream: AudioStream  
@export var max\_retreat\_distance: float \= 1.8  
@export var retreat\_duration: float \= 2.4

### **The Sequence Coroutine (\_run\_cutscene)**

Implement as an async function triggered by SignalBus.boss\_cutscene\_requested:

> 1. **Lock State:** Locate DungeonPlayer (via group &"player"). Lock player movement/input. Call GameState.lock\_encounters(30.0).  
> 2. **Spawn Villain:** Get player's active Camera3D. Compute forward vector (flattened on Y). Instantiate villain\_scene, position it at player.global\_position \+ (forward \* villain\_spawn\_distance). Make it look\_at the player.  
> 3. **Initial Impact:** Emit SignalBus.camera\_shake\_requested.emit(0.9). Call GhostScareFX.play\_blood(get\_tree(), 2, 0.95, 0.07).  
> 4. **Start Vignette:** var vignette\_fx: GhostScareFX \= GhostScareFX.start\_red\_vignette(get\_tree()).  
> 5. **Safe Camera Retreat:** Create a PhysicsRayQueryParameters3D casting backwards from the camera up to max\_retreat\_distance \+ 0.6. Calculate safe\_distance based on the raycast hit (clamp to avoid wall clipping). Tween the Camera3D local position.z backwards to safe\_distance over retreat\_duration. Parallel tween a subtle sine wave on position.y for footstep bobbing.  
> 6. **Lore Scare & Audio:** Halfway through the retreat tween, emit SignalBus.lore\_scare\_requested (pass lore\_flash\_texture). Play scary\_voice\_stream using AudioManager (or a local AudioStreamPlayer routed to SFX).  
> 7. **Fade to Black:** Spawn a CanvasLayer (layer 130\) with a black ColorRect. Tween alpha 0 to 1 over 0.9s.  
> 8. **State Reset (While Black):** queue\_free() the villain instance and call vignette\_fx.fade\_out\_and\_free(). Reset Camera3D local position/rotation to Vector3.ZERO so the player stays perfectly aligned to their grid cell. Loop through GameState.current\_party.slots:

if is\_instance\_valid(GameState.current\_party):  
    for member: CatCharacter in GameState.current\_party.slots:  
        if is\_instance\_valid(member):  
            member.current\_hp \= 1

Trigger a save via GameState.

> 9. **Wake Up:** Tween camera rotation slightly down (-12 degrees X) to simulate waking up on the floor. Tween black ColorRect alpha to 0 and camera rotation back to 0 over 1.6s. Unlock DungeonPlayer, free the black screen layer, and emit SignalBus.boss\_cutscene\_finished.emit(cutscene\_id).



## NOTES:

THis is the BOSS's Model: res://Scenes/Enemies/Malviathan.tscn
It has an activation area setup. and a collision shape so the player cant go through it, but the player shoulnt even get close. the activation area is very large. HOWEVER. the boss model is visible, it would be nice so. in the editor I can see roughly where he is, but in the game, he needs to start out not visible to player.

YOu need to add the "Visual Juice" the same way the res://Scenes/Enemies/BlobCorrupt.tscn has. where he has shaders and effects on him. 


AFTER THE CUT SCENE ENDS. They PLAYER DOES NOT FIGHT THE BOSS. YET. 


Instead, a number of things can happen. 

1. they are forced into a battle with a regular pack of enemies. 
2. they wake up on the ground, with 1% (or 10% or whatever is set) of HP and Mana left. Completely wrecked but alive. 
3. they are teleported to a dungeon level

BEFORE any of those things, we need a dialog from the boss. to appear. This dialog needs to have the boss's avatar in the corner. here is the avatar: 'resources/Lore/cube_avatar.png'
Here is a mockup of what the dialog should look like: /Users/eris/Developer/CotU_assets/cutscene_dialog.png Thats just a rough mockup. use the popup windows we already have, so they ahve the cool black glass style. 

To make the "Boss Cutscene Ending" easy to configure, it should have the "dialog text" to fill out. and then you select 1 of the 3 paths. 

Path 1. accepts up to 4 of the enemies data. Just like Scripts/Enemies/enemy.gd where you can add in whatever enemies. 
Path 2. This option has a On / Off toggle, and a Percentage. Where you can set the amount of HP  & Mana they loose. 
Path 3. Take a scene as input. 

NOTE: set it up where Path 1 and Path 3 are like a Yes / NO. where only 1 of them can be selected. They either fight where they are or go to a different scene. 

HOWEVER, Path 2. can be checked no matter what. so they can be drained and left. drained and put into a fight. or drained and teleported. 



## **Step 4: Wire the Boss Defeat Trigger**

The Boss Model 

Create a New Malviathan boss script (e.g., res://Scripts/Enemies/MalviathanController.gd):

Similar to BlobBossController.gd or BossStatue.gd

> * Add @export var defeat\_cutscene\_id: String \= ""  
> * Listen for SignalBus.combat\_ended. If victory \== true and defeat\_cutscene\_id is set:  
  * Await the BATTLE\_VICTORY popup closing (or check GameState.awaiting\_victory\_screen \== false).  
  * Emit SignalBus.boss\_cutscene\_requested.emit(defeat\_cutscene\_id, global\_position).
  
  
  
Eventually they will fight the boss multiple times, and after each battle, a dialog will appear on screen. or a quick movie. But for right now, the boss is basically "taunting" them