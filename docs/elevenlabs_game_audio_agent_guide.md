# ElevenLabs Game Audio Guide

> Agent-oriented guidance for generating voice lines and sound effects for the **Vale Party** game.
>
> Target platform: Anbernic RG35XX Plus  
> Runtime strategy: pre-generated offline audio assets  
> Service: ElevenLabs  
> Last reviewed: July 2026

---

## 1. Purpose

Use ElevenLabs as an **audio asset production tool**, not as a runtime dependency.

Generated voice lines and sound effects should be:

- produced during development;
- reviewed manually;
- stored in the repository;
- bundled with the game;
- played locally without internet access;
- referenced through a stable audio manifest.

Do not place an ElevenLabs API key in the game or on the Anbernic device.

---

## 2. Free-plan constraints

### Text-to-Speech

The ElevenLabs free plan supports Text-to-Speech through the API.

Typical free-plan constraints include:

- approximately 10,000 monthly credits;
- non-commercial usage only;
- attribution requirements for publicly published free-plan output;
- limited access to some voices and features;
- lower concurrency than paid plans.

### Sound Effects

Sound effects can be generated manually in the ElevenLabs web application with free credits.

Do not assume that the Sound Effects API is available on a purely free account. API access may require enabling pay-as-you-go billing or upgrading the account.

### Project implication

Use this split:

```text
Voice lines:
  ElevenLabs TTS API -> local audio files

Sound effects:
  ElevenLabs web app -> manually downloaded local audio files
```

All generated assets must be committed or added to the project's asset pipeline.

---

## 3. Recommended model selection

### `eleven_flash_v2_5`

Use for:

- development placeholders;
- bulk experimentation;
- inexpensive drafts;
- simple lines;
- testing voices and wording.

Advantages:

- lower credit usage;
- fast generation;
- good multilingual support.

Limitations:

- less expressive;
- weaker handling of unusual names, abbreviations and complex formatting;
- not ideal for final emotional character performances.

### `eleven_multilingual_v2`

Use for:

- tutorial narration;
- instructions;
- longer or more stable speech;
- lines that must sound consistent;
- predictable multilingual output.

Advantages:

- stable delivery;
- good long-form quality;
- suitable for Russian, German and English.

### `eleven_v3`

Use for:

- expressive final dialogue;
- emotional character reactions;
- laughter, surprise, whispering or curiosity;
- deliberate emphasis;
- pronunciation control through inline IPA;
- short character lines where performance matters.

Limitations:

- more variable;
- more expensive than Flash;
- may require several attempts;
- punctuation and tags can significantly alter delivery.

### Default decision rule

```text
Is this a temporary or low-value line?
  Yes -> Flash v2.5

Is this stable narration or instruction?
  Yes -> Multilingual v2

Is this emotional character dialogue?
  Yes -> Eleven v3
```

---

## 4. Voice selection

Voice selection usually has more impact than model settings.

Choose a voice that naturally matches:

- target language;
- regional accent;
- character age impression;
- emotional range;
- desired speaking pace;
- narrator or character role.

Do not rely on prompt instructions to create a convincing native accent from an unsuitable voice.

For multilingual content, prefer a voice that performs naturally in the target language.

Recommended project roles:

```text
Narrator:
  warm, calm, clear, slightly slow

Unicorn:
  playful, energetic, curious, expressive

Instruction voice:
  predictable, friendly, neutral

Celebration voice:
  energetic but not loud or overwhelming
```

---

## 5. Writing natural TTS input

Write text as spoken dialogue, not as UI copy.

Poor:

```text
Task complete. Five of five balls collected. Next level unlocked.
```

Better:

```text
You found all five balls! Great job — the next adventure is ready.
```

For a small child:

- keep sentences short;
- use familiar words;
- avoid dense instructions;
- communicate one action per sentence;
- avoid sarcasm;
- keep failure feedback gentle;
- prefer encouragement over correction.

Example:

```text
Not there yet. Let's look near the trees!
```

Avoid:

```text
Incorrect destination. Return to the highlighted region.
```

---

## 6. Fluency and pacing

Punctuation strongly affects delivery.

### Short pause

```text
Wait — did you hear that?
```

### Hesitation

```text
Hmm… maybe Valya is hiding near the balloons.
```

### Dramatic pause

```text
One more ball. Then… we can fly home!
```

### Direct emphasis

```text
Look behind the RED balloon!
```

### Guidelines

- use commas for light pauses;
- use em dashes for deliberate pauses;
- use ellipses sparingly;
- capitalize only important words;
- do not capitalize entire sentences unless shouting is intended;
- split long instructions into multiple clips;
- avoid excessive punctuation;
- test each line in context with game music and effects.

---

## 7. Expressive tags for Eleven v3

Eleven v3 supports audio-style tags.

Examples:

```text
[excited] You found another ball!
```

```text
[curious] Hmm… what is hiding behind that cloud?
```

```text
[whispers] I think Valya is nearby.
```

```text
[laughs] That was a funny landing!
```

Use only one or two compatible directions in a short line.

Avoid overloading prompts:

```text
[excited] [whispers] [sad] [laughs] You found the ball!
```

Tags work best when they fit the natural character of the selected voice.

---

## 8. Emphasis and word stress

For ordinary emphasis, start with punctuation and capitalization.

```text
Not the blue balloon — the RED one!
```

```text
You found VALYA!
```

Do not use capitalization everywhere. It reduces control and can produce shouting.

When exact pronunciation matters, use phonetic control.

---

## 9. Difficult names and pronunciation

### First attempt: natural spelling

```text
Valyusha
```

### Second attempt: readable phonetic spelling

```text
Val-yoo-sha
```

### Eleven v3: inline IPA

```text
We need to find "/vɐˈlʲuʂə/".
```

Inline IPA may improve pronunciation but is not perfectly deterministic.

### Pronunciation dictionaries

For supported models, pronunciation dictionaries can define aliases or phonemes.

Alias example:

```xml
<lexeme>
  <grapheme>Valyusha</grapheme>
  <alias>Val-yoo-sha</alias>
</lexeme>
```

Important:

- matching can be case-sensitive;
- the first matching rule may take precedence;
- model support differs;
- always test the final result;
- store the selected audio file instead of relying on reproducibility.

---

## 10. Language and accent rules

The accent mostly comes from the voice.

Use `languageCode` when supported to help the model interpret short or ambiguous text.

Examples:

```ts
languageCode: "en"
```

```ts
languageCode: "de"
```

```ts
languageCode: "ru"
```

Do not expect `languageCode` alone to correct an unsuitable accent.

For stylized characters, experimental v3 tags may help:

```text
[strong German accent] Welcome aboard!
```

Use accent tags only for intentional characterization, not for normal localization.

---

## 11. Suggested voice settings

Treat these as starting points, not fixed truth.

### Calm narrator

```json
{
  "stability": 0.70,
  "similarityBoost": 0.65,
  "style": 0.05,
  "speed": 0.92,
  "useSpeakerBoost": true
}
```

### Friendly child-oriented narrator

```json
{
  "stability": 0.55,
  "similarityBoost": 0.75,
  "style": 0.20,
  "speed": 0.95,
  "useSpeakerBoost": true
}
```

### Energetic unicorn

```json
{
  "stability": 0.35,
  "similarityBoost": 0.75,
  "style": 0.45,
  "speed": 1.03,
  "useSpeakerBoost": true
}
```

### Parameter interpretation

`stability`

- higher: more consistent, flatter;
- lower: more expressive, less predictable.

`similarityBoost`

- higher: closer to the source voice;
- excessive values may reduce naturalness.

`style`

- higher: stronger character and emotional exaggeration;
- use cautiously.

`speed`

- lower than `1.0`: slower;
- higher than `1.0`: faster.

`useSpeakerBoost`

- generally helps preserve voice identity;
- has little importance for an offline generation workflow.

Change one parameter at a time.

---

## 12. TTS API example

```ts
import { ElevenLabsClient } from "@elevenlabs/elevenlabs-js";
import { mkdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";

const apiKey = process.env.ELEVENLABS_API_KEY;

if (!apiKey) {
  throw new Error("ELEVENLABS_API_KEY is missing");
}

const elevenlabs = new ElevenLabsClient({ apiKey });

type GenerateSpeechOptions = {
  voiceId: string;
  text: string;
  outputPath: string;
  languageCode?: "en" | "de" | "ru";
  modelId?: "eleven_flash_v2_5" | "eleven_multilingual_v2" | "eleven_v3";
  seed?: number;
};

export async function generateSpeech({
  voiceId,
  text,
  outputPath,
  languageCode,
  modelId = "eleven_flash_v2_5",
  seed = 42,
}: GenerateSpeechOptions): Promise<void> {
  const expressive = modelId === "eleven_v3";

  const audio = await elevenlabs.textToSpeech.convert(voiceId, {
    text,
    modelId,
    languageCode,
    outputFormat: "mp3_44100_128",
    seed,
    voiceSettings: {
      stability: expressive ? 0.4 : 0.6,
      similarityBoost: 0.75,
      style: expressive ? 0.35 : 0.1,
      speed: 0.96,
      useSpeakerBoost: true,
    },
  });

  const chunks: Buffer[] = [];

  for await (const chunk of audio) {
    chunks.push(Buffer.from(chunk));
  }

  await mkdir(dirname(outputPath), { recursive: true });
  await writeFile(outputPath, Buffer.concat(chunks));
}
```

Notes:

- seeds improve consistency but do not guarantee identical output;
- exact SDK field names may change between versions;
- verify against the installed ElevenLabs SDK;
- never log or commit the API key;
- do not call the API from the game client.

---

## 13. Splitting long narration

Split long narration into semantic units.

Bad split:

```text
Clip 1: Fly to
Clip 2: Brazil and
Clip 3: find the balloons.
```

Good split:

```text
Clip 1: Let's fly to Brazil!
Clip 2: Look for the glowing balloons.
```

Where supported, `previous_text` and `next_text` can help preserve prosody across chunks.

For reusable game clips, each file should still sound complete on its own.

---

## 14. Sound-effect prompt structure

Use this structure:

```text
source or action
+ material or environment
+ emotional character
+ perspective
+ technical format
```

Example:

```text
A short, bright cartoon pop as a magical candy orb is collected,
followed by a tiny sparkling chime, cheerful children's game,
clean one-shot, dry recording, no voice
```

Useful audio terminology:

- one-shot;
- seamless loop;
- ambience;
- foley;
- impact;
- whoosh;
- sparkle;
- pluck;
- chime;
- drone;
- stem;
- dry recording;
- no music;
- no voice;
- close perspective;
- distant perspective.

---

## 15. Sound-effect prompt library

### Ball collected

```text
Short magical candy collection pop, soft bubbly pluck followed by a
tiny sparkling chime, cheerful children's game, clean one-shot,
approximately 0.7 seconds, no voice, no background music
```

### Unicorn jump

```text
Playful tiny unicorn jump, gentle upward whoosh, soft magical hoof
landing, rounded cartoon sound, child-friendly, clean one-shot
```

### Correct destination

```text
Cheerful two-note success sting with marimba and a small magical
sparkle, warm and rewarding, children's game UI, short one-shot
```

### Wrong destination

```text
Soft descending wooden bloop, friendly and non-punitive, gentle
cartoon game feedback, very short clean one-shot
```

### NPC appears

```text
Tiny magical shimmer and friendly bell reveal, curious rather than
dramatic, children's adventure game, clean one-shot
```

### Balloons appear

```text
Several soft bubbly pops with a bright magical shimmer, playful and
light, children's game reveal sound, short clean one-shot
```

### Level completed

```text
Short joyful children's game celebration, warm marimba melody,
sparkling bells and a soft final flourish, approximately three seconds,
rewarding but not loud, no voice
```

### Menu selection

```text
Tiny soft wooden pluck with a subtle sparkle, friendly game UI click,
clean one-shot, no reverb, no voice
```

### Menu back

```text
Soft rounded downward bloop, gentle children's game UI response,
very short clean one-shot, no voice
```

### Airplane movement loop

```text
Small friendly cartoon propeller plane, soft steady engine buzz,
light airy texture, non-mechanical and child-friendly, seamless loop,
no voice, no melody
```

### Enchanted meadow ambience

```text
Peaceful enchanted meadow ambience, soft breeze, distant small birds,
subtle magical sparkling texture, calm children's fantasy world,
seamless loop, no melody, no voices
```

### Cloud-edge ambience

```text
Soft high-altitude wind through fluffy magical clouds, gentle airy
movement, distant sparkling texture, calm children's fantasy ambience,
seamless loop, no melody, no voices
```

---

## 16. Sound-effect generation best practices

Generate simple components separately when exact timing matters.

Instead of:

```text
A ball pops, sparkles, bounces twice, a child laughs, and a melody plays.
```

Generate:

```text
1. collection pop;
2. sparkle;
3. bounce;
4. optional voice reaction;
5. optional music sting.
```

Then combine them locally.

Advantages:

- better control;
- easier iteration;
- reusable components;
- easier volume balancing;
- more predictable timing;
- fewer wasted credits.

For each effect:

1. generate several alternatives;
2. choose the cleanest one;
3. trim silence;
4. normalize loudness;
5. apply a short fade where needed;
6. convert to the project's preferred format;
7. test through handheld speakers;
8. store the source prompt in the manifest.

---

## 17. Audio-format strategy

For development and archiving:

- keep the original generated file;
- optionally keep a lossless master;
- produce a compressed runtime asset.

For LÖVE and small-device playback, test:

- `.ogg` for compact looping and music;
- `.wav` for very short low-latency effects;
- `.mp3` only if runtime compatibility is already verified.

Suggested layout:

```text
assets/
  audio/
    voice/
      en/
      de/
      ru/
    sfx/
      ui/
      character/
      world/
      rewards/
    ambience/
    music/
```

Example:

```text
assets/audio/voice/en/unicorn_ball_collected_01.ogg
assets/audio/sfx/rewards/ball_collected_01.wav
assets/audio/ambience/clouds_loop_01.ogg
```

---

## 18. Asset manifest

Store generation metadata next to each selected asset.

Example:

```json
{
  "unicorn.ballCollected.01": {
    "file": "assets/audio/voice/en/unicorn_ball_collected_01.ogg",
    "text": "[excited] You found another ball! GREAT job!",
    "language": "en",
    "voiceId": "VOICE_ID",
    "modelId": "eleven_v3",
    "seed": 42,
    "settings": {
      "stability": 0.4,
      "similarityBoost": 0.75,
      "style": 0.35,
      "speed": 0.96,
      "useSpeakerBoost": true
    },
    "status": "approved"
  },
  "sfx.ballCollected.01": {
    "file": "assets/audio/sfx/rewards/ball_collected_01.wav",
    "prompt": "Short magical candy collection pop...",
    "source": "ElevenLabs Sound Effects web app",
    "status": "approved"
  }
}
```

Recommended statuses:

```text
draft
review
approved
rejected
deprecated
```

---

## 19. Naming conventions

Use stable semantic names.

Good:

```text
unicorn_ball_collected_01
narrator_fly_to_brazil_01
ui_menu_select_01
sfx_wrong_destination_01
ambience_clouds_loop_01
```

Avoid:

```text
audio_final2
new_sound
test_good
voice_latest
```

Include variants numerically rather than overwriting files.

---

## 20. Credit-efficient workflow

For every voice line:

1. finalize the wording;
2. test with Flash v2.5;
3. select the voice;
4. tune settings with one variable at a time;
5. generate the final version with the chosen model;
6. compare several candidates;
7. save the approved file;
8. record generation metadata;
9. avoid regenerating unchanged assets;
10. never generate during gameplay.

For sound effects:

1. define a narrow prompt;
2. generate several alternatives in the web app;
3. export the best candidate;
4. trim and normalize locally;
5. save the prompt and source;
6. reuse components across game events.

---

## 21. Agent execution rules

An implementation agent working on audio should follow these rules.

### Before generation

- inspect existing audio assets;
- inspect the manifest;
- avoid duplicate concepts;
- identify language and character;
- identify whether the line is narration, dialogue or UI feedback;
- choose the cheapest appropriate model;
- verify that the API key exists only in local environment variables.

### During generation

- generate drafts with Flash;
- use v3 only where expression adds value;
- keep child-facing wording short;
- produce several alternatives for important lines;
- preserve prompts and settings;
- never expose credentials.

### After generation

- do not automatically approve output;
- place output in the correct directory;
- update the manifest;
- mark new assets as `review`;
- avoid replacing approved assets without explicit instruction;
- verify duration, clipping and silence;
- verify pronunciation;
- verify perceived loudness on small speakers.

---

## 22. Review checklist

### Voice line

- Is every word understandable?
- Is the pronunciation correct?
- Does the line sound complete on its own?
- Is the emotion appropriate?
- Is the speaking speed suitable for a four-year-old?
- Is the line too loud, sharp or startling?
- Does it work with background music?
- Is the language natural?
- Is the filename stable?
- Is the manifest updated?

### Sound effect

- Is the effect immediately recognizable?
- Is it short enough?
- Is there unwanted music or voice?
- Is there excessive reverb?
- Does it sound pleasant through handheld speakers?
- Is it distinct from other UI sounds?
- Is failure feedback gentle?
- Does a loop repeat without an audible seam?
- Is the prompt stored?
- Is the manifest updated?

---

## 23. Safety and child-oriented design

Avoid:

- sudden loud transients;
- harsh alarms;
- scary growls;
- punitive failure sounds;
- long spoken instructions during action;
- excessive repetition;
- voices that sound distressed;
- exaggerated shouting;
- effects with unclear copyrighted musical imitation.

Prefer:

- soft attacks;
- rounded tones;
- short positive feedback;
- gentle error sounds;
- low-complexity instructions;
- predictable recurring audio cues;
- comfortable loudness on the RG35XX Plus speaker.

---

## 24. Licensing and publication

Before publishing or distributing the game:

- verify the current ElevenLabs plan terms;
- verify commercial-use rights for every generated asset;
- verify attribution requirements;
- distinguish assets created under free and paid plans;
- retain generation dates and source metadata;
- do not assume that later upgrading retroactively grants commercial rights to previously generated free-plan assets.

For a private family game, free-plan restrictions may be acceptable. For public or commercial distribution, regenerate or license assets under an appropriate plan where required.

---

## 25. Official references

- Pricing: https://elevenlabs.io/pricing
- Models overview: https://elevenlabs.io/docs/overview/models
- Text-to-Speech overview: https://elevenlabs.io/docs/overview/capabilities/text-to-speech
- Text-to-Speech best practices: https://elevenlabs.io/docs/overview/capabilities/text-to-speech/best-practices
- Text-to-Speech API: https://elevenlabs.io/docs/api-reference/text-to-speech/convert
- Sound Effects overview: https://elevenlabs.io/docs/overview/capabilities/sound-effects
- Sound Effects API: https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert
- Voice settings: https://elevenlabs.io/docs/api-reference/voices/settings/update
- API authentication: https://elevenlabs.io/docs/api-reference/authentication
- Pay-as-you-go: https://elevenlabs.io/docs/overview/administration/pay-as-you-go
- Commercial usage help: https://help.elevenlabs.io/hc/en-us/articles/13313564601361-Can-I-publish-the-content-I-generate-on-the-platform

---

## 26. Default recommendation for Vale Party

```text
Runtime:
  Fully offline audio

Development drafts:
  eleven_flash_v2_5

Final emotional character lines:
  eleven_v3

Tutorial and instruction narration:
  eleven_multilingual_v2

Sound effects:
  ElevenLabs web app, generated manually

Repository:
  Commit approved runtime assets and generation manifest

Security:
  Keep API key only in local development environment

Review:
  Human approval required before an asset becomes production-ready
```
