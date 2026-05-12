\# TALKER Delta

Grounding the AI in the game engine. A fork of Coelacanthiform's TALKER-Expanded fork.



\### Events

* Generally an attempt to add more events that make more of the game engine visible to the AI
* Characters can now view their own inventories
* Characters can see you use, pick up, store, and drop items. This also makes crafting and disassembly visible. (A special consolidation system is used to prevent spam)
* Characters can see trades happen
* Characters can now see their health and the health of others (optionally, they can see limb injuries on the player)
* Dynamic news events (PDA broadcasts) are now visible to the AI. AI can see general broadcasts (usually blowout-related broadcasts) as well as broadcasts from their own faction
* Option to disable some events for companions only



\### Prompting

* General prompting tweaks to the main system prompt. Generally a slimming down of superfluous explanations and some things that threw the AI off.
* Reworked AI queue system reduces duplicate requests
* Reworked timestamp system makes it easier for AI to track events over time
* Dead characters are now visible to the AI
* Tweaks to the speaker selection AI (the fast AI) prompt to make it more reliable
* Who the player is, is now "hidden" and they appear like a normal character to the AI instead of being revealed as the player.



\### Memory

* Memory size can now be tweaked in the MCM.
* It is much longer by default (900 events vs. 12 in Expanded). This should dramatically improve memory quality for most people. Lower it if token costs are too much or AI gets too slow on old characters. Note the compactification will eventually kick in and replace all 900 with a short summary.



\### AI Notes

At the time of writing, GLM-5.1, Kimi 2.6 and Deepseek v4 are good cheap/free options (of those, I recommend GLM). All frontier proprietary models (Gemini, Claude, GPT) are also good (of those, I recommend Claude). For best results use the most recent model that you can.



With these tweaks I have seen a significant improvement in the quality and immersive-ness of AI responses.



This is a one-off update, further updates from me are not planned. You are free to merge these changes into your own fork under the conditions of the original TALKER EXPANDED license.

Created on GAMMA 0.9.4. May 2026.

Safe to install over Talker Expanded. It still appears as Talker Expanded in the MCM.

