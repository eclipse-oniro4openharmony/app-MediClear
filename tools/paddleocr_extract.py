import argparse
import json
import os
import sys
import time
from pathlib import Path

import requests


JOB_URL = "https://paddleocr.aistudio-app.com/api/v2/ocr/jobs"
DEFAULT_MODEL = "PP-StructureV3"


def submit_job(file_path: str, token: str, model: str) -> str:
    headers = {
        "Authorization": f"bearer {token}",
    }
    optional_payload = {
        "useDocOrientationClassify": False,
        "useDocUnwarping": False,
        "useChartRecognition": False,
    }

    if file_path.startswith("http"):
        headers["Content-Type"] = "application/json"
        payload = {
            "fileUrl": file_path,
            "model": model,
            "optionalPayload": optional_payload,
        }
        response = requests.post(JOB_URL, json=payload, headers=headers, timeout=60)
    else:
        path = Path(file_path)
        if not path.exists():
            raise FileNotFoundError(f"File not found: {path}")

        data = {
            "model": model,
            "optionalPayload": json.dumps(optional_payload),
        }
        with path.open("rb") as file:
            response = requests.post(
                JOB_URL,
                headers=headers,
                data=data,
                files={"file": file},
                timeout=60,
            )

    if response.status_code != 200:
        raise RuntimeError(f"OCR job submit failed: {response.status_code} {response.text}")

    return response.json()["data"]["jobId"]


def poll_result(job_id: str, token: str, interval_seconds: int) -> str:
    headers = {
        "Authorization": f"bearer {token}",
    }

    while True:
        response = requests.get(f"{JOB_URL}/{job_id}", headers=headers, timeout=60)
        if response.status_code != 200:
            raise RuntimeError(f"OCR polling failed: {response.status_code} {response.text}")

        data = response.json()["data"]
        state = data["state"]
        if state == "done":
            return data["resultUrl"]["jsonUrl"]
        if state == "failed":
            raise RuntimeError(f"OCR job failed: {data.get('errorMsg', 'unknown error')}")

        progress = data.get("extractProgress", {})
        total_pages = progress.get("totalPages", "?")
        extracted_pages = progress.get("extractedPages", "?")
        print(f"OCR job {state}, pages {extracted_pages}/{total_pages}")
        time.sleep(interval_seconds)


def download_results(jsonl_url: str, output_dir: Path) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    response = requests.get(jsonl_url, timeout=120)
    response.raise_for_status()

    raw_jsonl_path = output_dir / "ocr_result.jsonl"
    raw_jsonl_path.write_text(response.text, encoding="utf-8")

    markdown_parts: list[str] = []
    page_num = 0
    for line in response.text.strip().splitlines():
        line = line.strip()
        if not line:
            continue

        result = json.loads(line)["result"]
        for parsed_page in result["layoutParsingResults"]:
            markdown_text = parsed_page["markdown"]["text"]
            page_path = output_dir / f"doc_{page_num}.md"
            page_path.write_text(markdown_text, encoding="utf-8")
            markdown_parts.append(f"\n\n<!-- page {page_num} -->\n\n{markdown_text}")

            for image_path, image_url in parsed_page["markdown"]["images"].items():
                target_path = output_dir / image_path
                target_path.parent.mkdir(parents=True, exist_ok=True)
                image_response = requests.get(image_url, timeout=120)
                image_response.raise_for_status()
                target_path.write_bytes(image_response.content)

            for image_name, image_url in parsed_page["outputImages"].items():
                image_response = requests.get(image_url, timeout=120)
                image_response.raise_for_status()
                target_path = output_dir / f"{image_name}_{page_num}.jpg"
                target_path.write_bytes(image_response.content)

            page_num += 1

    combined_path = output_dir / "combined.md"
    combined_path.write_text("".join(markdown_parts).strip() + "\n", encoding="utf-8")
    return combined_path


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract text from medicine images or PDFs using PaddleOCR API.")
    parser.add_argument("file", help="Local file path or public file URL.")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--output-dir", default="output/paddleocr")
    parser.add_argument("--poll-interval", type=int, default=5)
    args = parser.parse_args()

    token = os.getenv("PADDLEOCR_TOKEN")
    if not token:
        print("Missing PADDLEOCR_TOKEN environment variable.", file=sys.stderr)
        sys.exit(2)

    print(f"Processing file: {args.file}")
    job_id = submit_job(args.file, token, args.model)
    print(f"Job submitted: {job_id}")
    jsonl_url = poll_result(job_id, token, args.poll_interval)
    combined_path = download_results(jsonl_url, Path(args.output_dir))
    print(f"OCR markdown saved: {combined_path}")


if __name__ == "__main__":
    main()
