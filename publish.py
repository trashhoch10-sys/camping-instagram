import os, json, time, pathlib, requests

ROOT = pathlib.Path(__file__).parent
API = "https://graph.facebook.com/v21.0"

def main():
    post = json.loads((ROOT / "post.json").read_text())
    if os.getenv("DRY_RUN") == "1":
        print("DRY RUN – nicht veröffentlicht:\n", post["caption"])
        return

    ig_id = os.environ["IG_USER_ID"]
    token = os.environ["IG_ACCESS_TOKEN"]
    image_url = (f"https://raw.githubusercontent.com/"
                 f"{os.environ['GITHUB_REPOSITORY']}/main/{post['image_path']}")

    r = requests.post(f"{API}/{ig_id}/media", data={
        "image_url": image_url, "caption": post["caption"], "access_token": token})
    r.raise_for_status()
    creation_id = r.json()["id"]

    for _ in range(12):  # bis zu 60 s warten, bis Instagram das Bild verarbeitet hat
        s = requests.get(f"{API}/{creation_id}", params={
            "fields": "status_code", "access_token": token}).json()
        if s.get("status_code") == "FINISHED":
            break
        time.sleep(5)

    r = requests.post(f"{API}/{ig_id}/media_publish", data={
        "creation_id": creation_id, "access_token": token})
    r.raise_for_status()
    print("Veröffentlicht:", r.json())

if __name__ == "__main__":
    main()
