#!/usr/bin/env node
// Offline generator for Vale Party Russian voice assets (see
// docs/elevenlabs_game_audio_agent_guide.md). Reads scripts/voice/lines.ru.json,
// calls the ElevenLabs Text-to-Speech REST API once per line, saves the raw mp3
// master under voice-src/ru/ and a runtime .ogg under assets/voice/ru/, and
// writes a generation manifest. Idempotent: an existing .ogg is skipped unless
// --force is given, so re-runs never waste credits on unchanged lines.
//
// The API key lives only in .env (elevenlabs_key) and is never logged or
// committed. Never call this from the game — assets are pre-generated.
//
// Usage:
//   node scripts/voice/generate.mjs [--dry-run] [--force] [--limit N] [--only <file>] [--draft]
//     --dry-run   list what would be generated, make no API calls
//     --force     regenerate even if the .ogg already exists
//     --limit N   generate at most N files this run (credit-safe smoke test)
//     --only F    generate only the file with this id (e.g. voice.russia)
//     --draft     use the free-tier premade substitute voices (draft_voices in
//                 lines.ru.json) instead of the real library voices, which the
//                 ElevenLabs free plan blocks over the API. Placeholder output.

import { readFile, writeFile, mkdir, stat } from "node:fs/promises";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const execFileP = promisify(execFile);
const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..", "..");

const args = process.argv.slice(2);
const has = (f) => args.includes(f);
const val = (f) => {
	const i = args.indexOf(f);
	return i >= 0 ? args[i + 1] : undefined;
};
const DRY = has("--dry-run");
const FORCE = has("--force");
const LIMIT = val("--limit") ? parseInt(val("--limit"), 10) : Infinity;
const ONLY = val("--only");
const DRAFT = has("--draft");

const MP3_DIR = join(root, "voice-src", "ru");
const OGG_DIR = join(root, "assets", "voice", "ru");
const MANIFEST = join(OGG_DIR, "manifest.json");

// --- env -------------------------------------------------------------------
async function loadKey() {
	const raw = await readFile(join(root, ".env"), "utf8");
	for (const line of raw.split(/\r?\n/)) {
		const m = line.match(/^\s*elevenlabs_key\s*=\s*(.+?)\s*$/i);
		if (m) return m[1].replace(/^["']|["']$/g, "");
	}
	throw new Error("elevenlabs_key not found in .env");
}

// --- build the work list from lines.ru.json --------------------------------
function buildJobs(cfg) {
	const voices = DRAFT ? cfg.draft_voices : cfg.voices;
	if (!voices) throw new Error(DRAFT ? "draft_voices missing in lines.ru.json" : "voices missing");
	const jobs = [];
	const narratorId = voices.narrator;
	for (const n of cfg.narration) {
		jobs.push({ file: n.id, text: n.text, voiceId: narratorId, kind: "narrator", role: "narration" });
	}
	for (const c of cfg.countries) {
		const charId = voices[c.voice];
		if (!charId) throw new Error(`unknown voice '${c.voice}' for country '${c.id}'`);
		// Arrival announcement: spoken by the narrator when flying over the country.
		jobs.push({ file: `voice.${c.id}`, text: c.arrival, voiceId: narratorId, kind: "narrator", role: "arrival", country: c.id });
		// Pickup request + drop-off thanks: spoken by the character's own voice.
		jobs.push({ file: `mission.${c.id}`, text: c.request, voiceId: charId, kind: "character", role: "request", country: c.id, voice: c.voice });
		jobs.push({ file: `thanks.${c.id}`, text: c.thanks, voiceId: charId, kind: "character", role: "thanks", country: c.id, voice: c.voice });
	}
	return jobs;
}

async function exists(p) {
	try {
		await stat(p);
		return true;
	} catch {
		return false;
	}
}

async function tts(key, job, cfg) {
	const settings = job.kind === "character" ? cfg.settings.character : cfg.settings.narrator;
	const url = `https://api.elevenlabs.io/v1/text-to-speech/${job.voiceId}?output_format=mp3_44100_128`;
	const res = await fetch(url, {
		method: "POST",
		headers: { "xi-api-key": key, "Content-Type": "application/json" },
		body: JSON.stringify({ text: job.text, model_id: cfg.model, voice_settings: settings }),
	});
	if (!res.ok) {
		const detail = await res.text().catch(() => "");
		throw new Error(`HTTP ${res.status} for ${job.file}: ${detail.slice(0, 300)}`);
	}
	return Buffer.from(await res.arrayBuffer());
}

// mp3 -> ogg (Vorbis). Homebrew ffmpeg on macOS lacks libvorbis, so use the
// built-in experimental "vorbis" encoder; it only writes valid stereo output,
// hence -ac 2.
async function toOgg(mp3Path, oggPath) {
	await execFileP("ffmpeg", ["-y", "-i", mp3Path, "-c:a", "vorbis", "-strict", "-2", "-ac", "2", oggPath]);
}

async function main() {
	const cfg = JSON.parse(await readFile(join(here, "lines.ru.json"), "utf8"));
	let jobs = buildJobs(cfg);
	if (ONLY) jobs = jobs.filter((j) => j.file === ONLY);

	await mkdir(MP3_DIR, { recursive: true });
	await mkdir(OGG_DIR, { recursive: true });

	const key = DRY ? null : await loadKey();
	const manifest = (await exists(MANIFEST)) ? JSON.parse(await readFile(MANIFEST, "utf8")) : {};

	let done = 0,
		skipped = 0,
		failed = 0;
	for (const job of jobs) {
		const oggPath = join(OGG_DIR, `${job.file}.ogg`);
		const mp3Path = join(MP3_DIR, `${job.file}.mp3`);
		if (!FORCE && (await exists(oggPath))) {
			skipped++;
			continue;
		}
		if (done >= LIMIT) break;
		if (DRY) {
			console.log(`would generate ${job.file}  [${job.kind}/${job.voice ?? "narrator"}]  "${job.text}"`);
			done++;
			continue;
		}
		try {
			const mp3 = await tts(key, job, cfg);
			await writeFile(mp3Path, mp3);
			await toOgg(mp3Path, oggPath);
			manifest[job.file] = {
				file: `assets/voice/ru/${job.file}.ogg`,
				master: `voice-src/ru/${job.file}.mp3`,
				text: job.text,
				language: "ru",
				voiceId: job.voiceId,
				modelId: cfg.model,
				settings: job.kind === "character" ? cfg.settings.character : cfg.settings.narrator,
				role: job.role,
				country: job.country ?? null,
				status: DRAFT ? "draft" : "review",
				draft: DRAFT || undefined,
			};
			await writeFile(MANIFEST, JSON.stringify(manifest, null, 2) + "\n");
			done++;
			console.log(`ok   ${job.file}  (${mp3.length} bytes mp3)`);
		} catch (err) {
			failed++;
			console.error(`FAIL ${job.file}: ${err.message}`);
		}
	}
	console.log(`\ndone=${done} skipped=${skipped} failed=${failed} total=${jobs.length}`);
	if (failed > 0) process.exitCode = 1;
}

main().catch((e) => {
	console.error(e);
	process.exit(1);
});
