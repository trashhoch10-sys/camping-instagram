import os, json, base64, datetime, random, pathlib
import anthropic
from openai import OpenAI

ROOT = pathlib.Path(__file__).parent
HISTORY = ROOT / "history.json"

CATEGORIES = [
    "Camping-Küche & Rezepte",
    "Gadgets & Gear",
    "Beleuchtung & Stimmung am Platz",
    "Platzsparen & Packtipps",
    "Zelt- & Schlaf-Komfort",
    "Campingplatz-Hacks & DIY",
    "Wildcamping & Natur-Tipps",
    "Ausrüstung pflegen & reparieren",
]

SYSTEM = """Du schreibst Instagram-Posts für einen deutschsprachigen Camping-Account.
Ton: locker, freundlich, praxisnah. Kein Marketing-Blabla.
Antworte NUR mit JSON, ohne Markdown, mit den Feldern:
- title: kurzes Thema (max. 8 Wörter)
- caption: Hook in Zeile 1, dann 3-5 konkrete Tipps (mit Emojis als Aufzählung), dann eine Frage an die Community. Max. 1200 Zeichen. Ohne Hashtags.
- hashtags: Liste mit 10-15 Hashtags (ohne #)
- image_prompt: englischer Prompt für ein realistisches, stimmungsvolles Foto zum Thema. Kein Text, keine Logos, keine Marken im Bild."""

def main():
    history = json.loads(HISTORY.read_text()) if HISTORY.exists() else []
    recent_cats = [h["category"] for h in history[-(len(CATEGORIES) - 1):]]
    category = random.choice([c for c in CATEGORIES if c not in recent_cats] or CATEGORIES)
    recent_titles = [h["title"] for h in history[-40:]]

    client = anthropic.Anthropic()
    msg = client.messages.create(
        model="claude-sonnet-5-5",
        max_tokens=1500,
        system=SYSTEM,
        messages=[{"role": "user", "content": (
            f"Kategorie: {category}\n"
            f"Bereits behandelte Themen (nicht wiederholen): {recent_titles}\n"
            "Erstelle den nächsten Post."
        )}],
    )
    text = msg.content[0].text.strip().removeprefix("```json").removesuffix("```").strip()
    post = json.loads(text)

    tags = " ".join("#" + t.lstrip("#") for t in post["hashtags"])
    caption = f"{post['caption']}\n\n{tags}\n\n🤖 Bild KI-generiert"

    img = OpenAI().images.generate(
        model="gpt-image-1",
        prompt=post["image_prompt"],
        size="1024x1024",
        output_format="jpeg",
    )
    today = datetime.date.today().isoformat()
    rel_path = f"images/{today}.jpg"
    (ROOT / rel_path).write_bytes(base64.b64decode(img.data[0].b64_json))

    (ROOT / "post.json").write_text(json.dumps(
        {"caption": caption, "image_path": rel_path}, ensure_ascii=False, indent=2))
    history.append({"date": today, "category": category, "title": post["title"]})
    HISTORY.write_text(json.dumps(history, ensure_ascii=False, indent=2))
    print("Erstellt:", post["title"])

if __name__ == "__main__":
    main()
