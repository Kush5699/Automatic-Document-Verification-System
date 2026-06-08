"""
YOLOv8 + EasyOCR FastAPI Backend for Driver License Field Extraction

Pipeline:
  1. Receive image from Flutter app
  2. YOLOv8 detects field regions (Name, DOB, Address, State)
  3. Crop each detected region
  4. EasyOCR reads text from each clean crop
  5. Return structured JSON

Runs 100% locally — no data leaves your machine.
"""

import io
import os
import sys
import time
import logging

import cv2
import numpy as np
import easyocr
import torch
from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from PIL import Image
from ultralytics import YOLO

# ──────────────────────────────────────────────
#  Setup
# ──────────────────────────────────────────────

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="ID Scanner Backend",
    description="YOLOv8 + EasyOCR local extraction API",
    version="1.0.0",
)

# Allow Flutter app connections from any origin
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ──────────────────────────────────────────────
#  Model Loading
# ──────────────────────────────────────────────

MODEL_PATH = os.path.join(os.path.dirname(__file__), "best.pt")

# Check if trained model exists
if not os.path.exists(MODEL_PATH):
    logger.warning(f"⚠️  Trained model not found at {MODEL_PATH}")
    logger.warning("   You need to either:")
    logger.warning("   1. Place 'best.pt' in the backend/ directory")
    logger.warning("   2. Or run training first (see train.py)")
    logger.warning("")
    logger.warning("   Starting with pretrained YOLOv8n as fallback...")
    logger.warning("   This won't detect DL fields — only general objects.")
    MODEL_PATH = "yolov8n.pt"  # Fallback to pretrained

model = YOLO(MODEL_PATH)
reader = easyocr.Reader(['en'], gpu=torch.cuda.is_available())

# Get class names from model
CLASS_NAMES = model.names  # e.g., {0: 'Name', 1: 'DOB', 2: 'Address', 3: 'State'}
logger.info(f"✅ Model loaded. Classes: {CLASS_NAMES}")
logger.info(f"   GPU: {'CUDA' if torch.cuda.is_available() else 'CPU'}")

# ──────────────────────────────────────────────
#  Field mapping — maps YOLO class names to output keys
# ──────────────────────────────────────────────

FIELD_MAP = {
    # Normalize various class name formats to standard keys
    'name': 'name',
    'Name': 'name',
    'NAME': 'name',
    'first_name': 'name',
    'last_name': 'name',
    'dob': 'dob',
    'DOB': 'dob',
    'date_of_birth': 'dob',
    'Date of Birth': 'dob',
    'address': 'address',
    'Address': 'address',
    'ADDRESS': 'address',
    'addr': 'address',
    'state': 'state',
    'State': 'state',
    'STATE': 'state',
    # Additional common field names from different trained models
    'DL_number': 'id_number',
    'dl_number': 'id_number',
    'license_number': 'id_number',
    'expiry': 'expiry_date',
    'exp': 'expiry_date',
    'sex': 'gender',
    'gender': 'gender',
}


def normalize_field(class_name: str) -> str:
    """Map YOLO class name to a standard field key."""
    return FIELD_MAP.get(class_name, class_name.lower())


# ──────────────────────────────────────────────
#  Core Extraction Pipeline
# ──────────────────────────────────────────────

def extract_fields(image_np: np.ndarray) -> dict:
    """
    Run YOLOv8 detection + EasyOCR on an image.
    Returns dict of field_name → extracted_text.
    """
    start = time.time()

    # Step 1: YOLOv8 detection
    results = model(image_np, conf=0.25, verbose=False)
    detections = results[0]

    fields = {}
    raw_detections = []

    if detections.boxes is not None and len(detections.boxes) > 0:
        for box in detections.boxes:
            # Get bounding box coordinates
            x1, y1, x2, y2 = box.xyxy[0].cpu().numpy().astype(int)
            conf = float(box.conf[0])
            cls_id = int(box.cls[0])
            cls_name = CLASS_NAMES.get(cls_id, f"class_{cls_id}")
            field_key = normalize_field(cls_name)

            # Add padding for better OCR (10% each side)
            h, w = image_np.shape[:2]
            pad_x = int((x2 - x1) * 0.05)
            pad_y = int((y2 - y1) * 0.1)
            x1 = max(0, x1 - pad_x)
            y1 = max(0, y1 - pad_y)
            x2 = min(w, x2 + pad_x)
            y2 = min(h, y2 + pad_y)

            # Step 2: Crop the detected region
            crop = image_np[y1:y2, x1:x2]

            if crop.size == 0:
                continue

            # Step 3: EasyOCR on the cropped region
            ocr_results = reader.readtext(crop, detail=0, paragraph=True)
            text = ' '.join(ocr_results).strip()

            raw_detections.append({
                'field': field_key,
                'class_name': cls_name,
                'confidence': round(conf, 3),
                'bbox': [int(x1), int(y1), int(x2), int(y2)],
                'text': text,
            })

            # Keep highest confidence detection per field
            if field_key not in fields or conf > fields[field_key]['conf']:
                fields[field_key] = {'text': text, 'conf': conf}

    elapsed = round((time.time() - start) * 1000)

    # Build final result
    result = {
        'name': fields.get('name', {}).get('text'),
        'dob': fields.get('dob', {}).get('text'),
        'address': fields.get('address', {}).get('text'),
        'state': fields.get('state', {}).get('text'),
        'id_number': fields.get('id_number', {}).get('text'),
        'expiry_date': fields.get('expiry_date', {}).get('text'),
        'gender': fields.get('gender', {}).get('text'),
        'processing_time_ms': elapsed,
        'detections_count': len(raw_detections),
        'raw_detections': raw_detections,
    }

    return result


# ──────────────────────────────────────────────
#  API Endpoints
# ──────────────────────────────────────────────

@app.get("/")
async def root():
    return {
        "service": "ID Scanner Backend",
        "model": MODEL_PATH,
        "classes": CLASS_NAMES,
        "gpu": torch.cuda.is_available(),
        "status": "ready",
    }


@app.get("/health")
async def health():
    return {"status": "ok", "model_loaded": True}


@app.post("/extract")
async def extract(file: UploadFile = File(...)):
    """
    Extract fields from a driver license image.

    Returns JSON with: name, dob, address, state, processing_time_ms
    """
    try:
        # Read image
        contents = await file.read()
        image = Image.open(io.BytesIO(contents)).convert("RGB")
        image_np = np.array(image)

        # Convert RGB to BGR for OpenCV/YOLO
        image_bgr = cv2.cvtColor(image_np, cv2.COLOR_RGB2BGR)

        # Run extraction pipeline
        result = extract_fields(image_bgr)

        logger.info(
            f"✅ Extracted {result['detections_count']} fields "
            f"in {result['processing_time_ms']}ms"
        )

        return JSONResponse(content=result)

    except Exception as e:
        logger.error(f"❌ Error: {e}")
        return JSONResponse(
            status_code=500,
            content={"error": str(e)},
        )


# ──────────────────────────────────────────────
#  Run
# ──────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", 8000))
    logger.info(f"🚀 Starting ID Scanner Backend on port {port}")
    logger.info(f"   Model: {MODEL_PATH}")
    logger.info(f"   Classes: {CLASS_NAMES}")

    uvicorn.run(app, host="0.0.0.0", port=port)
