# Mobile NOTES

Basically, the game on mobile is unplayable. 

For the Main HUD SCENE These are my notes. 

--------

toolbar buttons waaay to small.

dpad buttns a little too small

portraits too small

Nine "Voice HUD" was not under the map. was in the middle of the screen. I Tried to fix it by anchoring it to the side. 
GOLD control. in wrong place as well. in the middle. I tried to anchor that to the other side of the screen. hopefully thats also fixed. 
Enemy "EnemyInRange" Gauge in wrong spot. its over to far to the left. 

CONCLUSION: EVERYTHING is waay to small on the HUD. it all needs to be bumped up a bit in size. the DPAD is almost the right size, but there needs to be just a bit more space between the buttons if that is possible? 


------


BattleHud. THe main attack / defend/ spell Buttons are not centered. the are off to the left. I think that might be the same issue as the other items, where they are not actually anchored, they are just adjusted some amount of pixels, and when scaling that amount of pixels isnt right anymore. 

THe FIX for ALL of this, is to make sure EVERYTHING is anchored. No more "x pixel from the left. "


NOTE: 

When opening the character sheet the close button no longer works, nor does switching between characters. 

I had to close the game and restart it when I opened the character menu. 


----

# All Notes

BattleHud: when picking a target when multiple targets are there, the BACK BUTTON is white background with white arrow. we need the arrow to be black. lets try this one: ui/icons/menu/chevron_back.png


BattleHud: when picking a target when multiple targets are there, ALL BUTTONS ARE GREY. THe back button is supposed to be grey, but the target buttons are supposed to be green. Swap the folder from ui/kbtns/Grey to ui/kbtns/Green . well add a new button type that uses the green buttons. or make a variant. whatever. but the target buttons should be green. 


Mana stim missing icon. Cyber ration missing icon. Other items are missing icons. we didnt quite get all the items to have icons. Suggest looking at the Loot options. Also the BONE ARMOR type. I dont think we have icons for that either. 


Ghosts are WAAAY to small and far back. Ghosts are also waaay to weak. THey are plenty scary. but theyu are supposed to be a powerful enemy. suggest moving them up closer and increasing size like 30 - 40%. mayhbe move closer a bit and increase by 30% and we might be close.  Ghoost died in 1 hit. only had 30 hp.

