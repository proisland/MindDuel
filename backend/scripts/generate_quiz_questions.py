#!/usr/bin/env python3
"""
generate_quiz_questions.py

Generates quiz questions for the MindDuel admin backend using the Claude API.

Usage:
    python3 generate_quiz_questions.py --categories history geography science
    python3 generate_quiz_questions.py --categories-file categories.txt
    python3 generate_quiz_questions.py --categories history --output ./my_output

Requirements:
    pip install anthropic

Output:
    CSV files per category in backend/scripts/questions-csv/
    ID format: {slug}-l{level}-{global_counter}
    Columns: id, level, prompt, correct, distractor1, distractor2, distractor3

Progress is saved in backend/scripts/checkpoints/ so you can safely interrupt and resume.
"""

import anthropic
import argparse
import csv
import json
import math
import os
import re
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent

# ── Configuration ────────────────────────────────────────────────────────────

MODEL           = "claude-haiku-4-5-20251001"
QUESTIONS_TOTAL = 2000          # minimum per category
NUM_LEVELS      = 20            # difficulty levels 1-20
BATCH_SIZE      = 40            # questions per API call
MAX_RETRIES     = 5
RETRY_DELAY_S   = 10            # initial backoff, doubles on each retry
MAX_CONCURRENT  = 2             # parallel API calls (Tier 1 limit: 10k output tokens/min)

LEVEL_DESCRIPTIONS = {
    1:  "veldig enkelt – faktakunnskap de fleste 10-åringer vet",
    2:  "enkelt – allment kjent kunnskap fra grunnskolen",
    3:  "enkelt-middels – kjent for de fleste voksne med litt interesse",
    4:  "middels – krever litt fordypning eller interesse for temaet",
    5:  "middels – typisk folkeopplysningsnivå",
    6:  "middels-vanskelig – krever solid allmenndanning",
    7:  "litt vanskelig – god kunnskap, men ikke ekspertnivå",
    8:  "vanskelig – grundig kunnskap om temaet",
    9:  "vanskelig – detaljert fakta som krever seriøst engasjement",
    10: "vanskelig – typisk quizmester-nivå",
    11: "svært vanskelig – dyp fagkunnskap kreves",
    12: "svært vanskelig – ekspertnivå, uvanlige detaljer",
    13: "ekspert – bare for spesialister eller entusiaster",
    14: "ekspert – obskure fakta kjent for meget dedikerte",
    15: "ekspert-pluss – dypt spesialisert kunnskap",
    16: "mester – informasjon som krever akademisk fordypning",
    17: "mester – sjeldne detaljer selv fagfolk kan miste",
    18: "grandmester – trivia på konkurransenivå",
    19: "grandmester – obskur nisjedetalj for toppdrevne quizere",
    20: "umulig – ekstremt obskur fakta, sjelden kjent av noen",
}

# Subcategory hints inject topic diversity so batches don't repeat the same facts.
# Keys are category slug substrings (case-insensitive prefix match).
SUBCATEGORY_HINTS: dict[str, list[str]] = {
    "history": [
        "oldtiden (Egypt, Hellas, Roma)", "middelalderen", "renessansen og reformasjonen",
        "kolonitiden", "1700-tallet og opplysningstiden", "napoleonskrigene",
        "industrialiseringen på 1800-tallet", "første verdenskrig", "mellomkrigstiden",
        "andre verdenskrig", "den kalde krigen", "dekolonisering i Afrika og Asia",
        "norsk historie", "skandinavisk historie", "amerikansk historie",
        "russisk og sovjetisk historie", "asiatisk historie", "afrikansk historie",
        "latinamerikansk historie", "moderne geopolitikk siden 1990",
    ],
    "geography": [
        "land og hovedsteder i Europa", "land og hovedsteder i Asia",
        "land og hovedsteder i Afrika", "land og hovedsteder i Amerika",
        "hav, elver og innsjøer", "fjell og geologi", "klima og naturkatastrofer",
        "demografi og befolkning", "politiske grenser og konflikter",
        "norsk geografi", "kartlesing og koordinater",
    ],
    "science": [
        "biologi og celler", "genetikk og evolusjon", "menneskekroppen",
        "astronomi og verdensrommet", "kjemi og grunnstoffer", "fysikkens lover",
        "elektrisitet og magnetisme", "klimavitenskap", "matematikk",
        "informatikk og algoritmer", "medisin og sykdommer",
    ],
    "sport": [
        "fotball", "friidlett og olympiske leker", "vintersport",
        "tennis", "basketball", "sykkel", "svømming",
        "norsk idrett", "VM og EM", "idrettsrekorder",
    ],
    "music": [
        "klassisk musikk", "jazz og blues", "rock og pop",
        "hip-hop og rap", "elektronisk musikk", "norsk musikk",
        "musikkinstrumenter", "musikkteorier", "album og låter",
        "artister og band",
    ],
    "film": [
        "Hollywood-klassikere", "Oscar-vinnere", "internasjonale filmer",
        "norsk film", "animasjonsfilmer", "regissører",
        "skuespillere", "filmserier og franchise",
    ],
    "literature": [
        "norsk litteratur", "klassisk verdenslitteratur", "moderne romaner",
        "poesi", "drama og teater", "forfattere og nobelprisvinnere",
        "mytologi og sagn", "barnelitteratur",
    ],
    "technology": [
        "internettets historie", "programmeringsspråk", "maskinvare og CPU",
        "kunstig intelligens", "mobilteknologi", "store teknologiselskaper",
        "cybersikkerhet", "databaser og lagring",
    ],
    "food": [
        "norsk mat", "europeisk kokekunst", "asiatisk mat",
        "amerikanske matretter", "grønnsaker og frukt", "drikke og alkohol",
        "matlagingsteknikker", "kjente kokker",
    ],
}

GENERIC_SUBCATEGORIES = [
    "grunnleggende fakta", "historisk bakgrunn", "kjente personer",
    "rekorder og statistikk", "moderne utvikling", "interessante detaljer",
    "kulturell betydning", "internasjonale aspekter",
]


def get_subcategories(slug: str) -> list[str]:
    for key, hints in SUBCATEGORY_HINTS.items():
        if key in slug.lower():
            return hints
    return GENERIC_SUBCATEGORIES


def build_prompt(category: str, level: int, num_levels: int, batch_num: int, language: str) -> str:
    subs    = get_subcategories(category)
    subtopic = subs[batch_num % len(subs)]
    level_desc = LEVEL_DESCRIPTIONS.get(level, f"vanskelighetsgrad {level} av {num_levels}")

    if language == "no":
        lang_instruction = "Skriv alle spørsmål og svar på norsk (bokmål)."
        example_format   = '{"prompt": "Hva er Norges hovedstad?", "correct": "Oslo", "distractor1": "Bergen", "distractor2": "Trondheim", "distractor3": "Stavanger"}'
    else:
        lang_instruction = "Write all questions and answers in English."
        example_format   = '{"prompt": "What is the capital of Norway?", "correct": "Oslo", "distractor1": "Bergen", "distractor2": "Trondheim", "distractor3": "Stavanger"}'

    return f"""{lang_instruction}

Generate exactly {BATCH_SIZE} unique trivia questions about the category "{category}", focusing on the subtopic: "{subtopic}".

Difficulty level: {level} / {num_levels} — {level_desc}

Rules:
- Every question must be factually correct.
- Each question must have exactly 1 correct answer and 3 plausible but wrong distractors.
- Distractors must be the same type as the correct answer (e.g. all countries, all years, all names).
- No question should duplicate another in this batch.
- Questions must not be trivially easy or obviously guessable from the wording.

Return ONLY a JSON array — no markdown, no explanations. Example element:
{example_format}

JSON array of exactly {BATCH_SIZE} question objects:"""


def call_api_with_retry(client: anthropic.Anthropic, prompt: str) -> list[dict]:
    delay = RETRY_DELAY_S
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            response = client.messages.create(
                model=MODEL,
                max_tokens=5000,
                messages=[{"role": "user", "content": prompt}],
            )
            text = response.content[0].text.strip()

            # Extract JSON array robustly
            start = text.find("[")
            end   = text.rfind("]") + 1
            if start == -1 or end == 0:
                raise ValueError(f"No JSON array found. Response snippet: {text[:300]}")

            parsed = json.loads(text[start:end])
            if not isinstance(parsed, list):
                raise ValueError("Parsed JSON is not a list")
            return parsed

        except anthropic.APIStatusError as e:
            if e.status_code < 500 and e.status_code != 429:
                raise RuntimeError(f"Non-retriable API error ({e.status_code}): {e.message}") from e
            print(f"  [API error attempt {attempt}/{MAX_RETRIES}]: {e}. Retrying in {delay}s…")
            time.sleep(delay)
            delay = min(delay * 2, 120)
        except (anthropic.RateLimitError, anthropic.APIConnectionError) as e:
            print(f"  [API error attempt {attempt}/{MAX_RETRIES}]: {e}. Retrying in {delay}s…")
            time.sleep(delay)
            delay = min(delay * 2, 120)
        except (json.JSONDecodeError, ValueError) as e:
            print(f"  [Parse error attempt {attempt}/{MAX_RETRIES}]: {e}. Retrying…")
            time.sleep(5)
        except Exception as e:
            print(f"  [Unexpected error attempt {attempt}/{MAX_RETRIES}]: {type(e).__name__}: {e}. Retrying in {delay}s…")
            time.sleep(delay)
            delay = min(delay * 2, 120)

    raise RuntimeError(f"Failed after {MAX_RETRIES} attempts")


def validate_question(q: dict, seen_prompts: set[str]) -> bool:
    required = {"prompt", "correct", "distractor1", "distractor2", "distractor3"}
    if not required.issubset(q.keys()):
        return False
    for field in required:
        if not isinstance(q[field], str) or not q[field].strip():
            return False
    # Deduplicate on normalised prompt text
    key = re.sub(r"\s+", " ", q["prompt"].strip().lower())
    if key in seen_prompts:
        return False
    seen_prompts.add(key)
    return True


def load_checkpoint(path: Path) -> list[dict]:
    if path.exists():
        with open(path) as f:
            return json.load(f)
    return []


def save_checkpoint(path: Path, questions: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        json.dump(questions, f, ensure_ascii=False, indent=2)


def write_csv(output_path: Path, category_slug: str, questions: list[dict]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, quoting=csv.QUOTE_ALL)
        writer.writerow(["id", "level", "prompt", "correct", "distractor1", "distractor2", "distractor3"])
        for i, q in enumerate(questions, start=1):
            level = q["_level"]
            row_id = f"{category_slug}-l{level}-{i}"
            writer.writerow([
                row_id,
                level,
                q["prompt"],
                q["correct"],
                q["distractor1"],
                q["distractor2"],
                q["distractor3"],
            ])


def generate_category(
    client: anthropic.Anthropic,
    category: str,
    category_slug: str,
    checkpoint_dir: Path,
    output_dir: Path,
    language: str,
    target: int,
    progress: "ProgressTracker",
    num_levels: int = NUM_LEVELS,
    concurrency: int = MAX_CONCURRENT,
) -> None:
    checkpoint_path = checkpoint_dir / f"{category_slug}-{language}.json"
    output_path     = output_dir / f"{category_slug}-{language}-v1.csv"

    questions: list[dict] = load_checkpoint(checkpoint_path)
    seen_prompts: set[str] = {
        re.sub(r"\s+", " ", q["prompt"].strip().lower()) for q in questions
    }
    lock = threading.Lock()

    print(f"\n{'─' * 60}")
    print(f"Category : {category} ({category_slug})  [{language}]")
    print(f"Target   : {target}  |  Already done: {len(questions)}  |  Workers: {concurrency}")

    if len(questions) >= target:
        print("  Already complete — writing CSV and skipping.")
        print(f"  Overall: {progress.bar()}")
        write_csv(output_path, category_slug, questions[:target])
        return

    # Per-level targets
    base_per_level = target // num_levels
    extra          = target - base_per_level * num_levels
    level_targets: dict[int, int] = {
        lvl: base_per_level + (1 if lvl <= extra else 0)
        for lvl in range(1, num_levels + 1)
    }

    # Count already-done per level
    level_counts: dict[int, int] = {lvl: 0 for lvl in range(1, num_levels + 1)}
    for q in questions:
        lvl = q.get("_level", 1)
        if lvl in level_counts:
            level_counts[lvl] += 1

    # Build task list: (level, batch_num) — add 25 % buffer for deduplication losses
    tasks: list[tuple[int, int]] = []
    for level in range(1, num_levels + 1):
        needed = level_targets[level] - level_counts[level]
        if needed <= 0:
            continue
        n_batches = math.ceil(needed * 1.25 / BATCH_SIZE)
        for b in range(n_batches):
            tasks.append((level, b))

    print(f"  Dispatching {len(tasks)} batches across {concurrency} workers…")
    completed = 0

    def fetch(level: int, batch_num: int) -> tuple[int, list[dict]]:
        prompt = build_prompt(category, level, num_levels, batch_num, language)
        return level, call_api_with_retry(client, prompt)

    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = {executor.submit(fetch, level, batch_num): (level, batch_num)
                   for level, batch_num in tasks}

        for future in as_completed(futures):
            level, batch_num = futures[future]
            try:
                _, raw = future.result()
            except Exception as e:
                print(f"  [Batch l{level}#{batch_num} failed]: {e}")
                continue

            with lock:
                added = 0
                for item in raw:
                    if not isinstance(item, dict):
                        continue
                    item["_level"] = level
                    if validate_question(item, seen_prompts):
                        questions.append(item)
                        added += 1
                completed += 1
                progress.update(added)
                cat_total = len(questions)
                print(
                    f"  [batch {completed}/{len(tasks)}] level {level}, chunk {batch_num + 1}"
                    f" → +{added} | cat: {cat_total}/{target}"
                    f"  |  Overall: {progress.bar()}"
                )
                save_checkpoint(checkpoint_path, questions)

    final = questions[:target]
    print(f"\n  Writing {len(final)} questions → {output_path}")
    write_csv(output_path, category_slug, final)
    print(f"  Done: {category} [{language}]")


class ProgressTracker:
    def __init__(self, total: int, initial: int = 0) -> None:
        self.total   = total
        self.done    = initial
        self._lock   = threading.Lock()

    def update(self, n: int) -> None:
        with self._lock:
            self.done += n

    def bar(self, width: int = 25) -> str:
        pct  = min(self.done / self.total, 1.0) if self.total else 0
        fill = int(width * pct)
        bar  = "█" * fill + "░" * (width - fill)
        return f"[{bar}] {pct * 100:.1f}% ({self.done}/{self.total})"


def slugify(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.strip().lower()).strip("_")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate MindDuel quiz questions via Claude API")
    group  = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--categories", nargs="+", metavar="CATEGORY",
        help='Category names, e.g. --categories history geography science',
    )
    group.add_argument(
        "--categories-file", metavar="FILE",
        help="Path to a text file with one category per line",
    )
    parser.add_argument(
        "--slug-override", nargs="+", metavar="SLUG",
        help="Custom slugs for each category (must match --categories count)",
    )
    parser.add_argument(
        "--output", default=str(SCRIPT_DIR / "questions-csv"), metavar="DIR",
        help="Output directory for CSV files (default: backend/scripts/questions-csv)",
    )
    parser.add_argument(
        "--checkpoints", default=str(SCRIPT_DIR / "checkpoints"), metavar="DIR",
        help="Directory for progress checkpoints (default: backend/scripts/checkpoints)",
    )
    parser.add_argument(
        "--levels", type=int, default=NUM_LEVELS,
        help=f"Number of difficulty levels (default: {NUM_LEVELS})",
    )
    parser.add_argument(
        "--languages", nargs="+", default=["no", "en"], choices=["no", "en"],
        metavar="LANG",
        help="Languages to generate (default: no en). Example: --languages no en",
    )
    parser.add_argument(
        "--concurrency", type=int, default=MAX_CONCURRENT,
        help=f"Parallel API calls per category (default: {MAX_CONCURRENT})",
    )
    parser.add_argument(
        "--target", type=int, default=QUESTIONS_TOTAL,
        help=f"Questions to generate per category (default: {QUESTIONS_TOTAL})",
    )
    args = parser.parse_args()

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("Error: ANTHROPIC_API_KEY environment variable is not set.")
        sys.exit(1)

    if args.categories_file:
        with open(args.categories_file) as f:
            categories = [line.strip() for line in f if line.strip() and not line.startswith("#")]
    else:
        categories = args.categories

    if args.slug_override:
        if len(args.slug_override) != len(categories):
            print("Error: --slug-override must have the same number of items as --categories")
            sys.exit(1)
        slugs = args.slug_override
    else:
        slugs = [slugify(c) for c in categories]

    output_dir     = Path(args.output)
    checkpoint_dir = Path(args.checkpoints)
    client         = anthropic.Anthropic(api_key=api_key)

    num_levels = args.levels
    languages  = list(dict.fromkeys(args.languages))  # deduplicate, preserve order

    # Pre-load checkpoints to compute overall start state
    grand_total   = len(categories) * len(languages) * args.target
    initial_done  = 0
    for slug in slugs:
        for lang in languages:
            cp = checkpoint_dir / f"{slug}-{lang}.json"
            existing = load_checkpoint(cp)
            initial_done += min(len(existing), args.target)

    progress = ProgressTracker(total=grand_total, initial=initial_done)

    print(f"Model:       {MODEL}")
    print(f"Languages:   {', '.join(languages)}")
    print(f"Target:      {args.target} questions per category per language")
    print(f"Levels:      1–{num_levels}")
    print(f"Batch size:  {BATCH_SIZE} questions per API call")
    print(f"Concurrency: {args.concurrency} parallel workers")
    print(f"Output:      {output_dir.resolve()}")
    print(f"Overall:     {progress.bar()}")

    for category, slug in zip(categories, slugs):
        for lang in languages:
            generate_category(
                client=client,
                category=category,
                category_slug=slug,
                checkpoint_dir=checkpoint_dir,
                output_dir=output_dir,
                language=lang,
                target=args.target,
                progress=progress,
                num_levels=num_levels,
                concurrency=args.concurrency,
            )

    print(f"\nAlt ferdig! Overall: {progress.bar()}")



if __name__ == "__main__":
    main()
