import sys
import json
import numpy as np
import tensorflow as tf
from tensorflow.keras.preprocessing import image


# =========================
# CONFIGURATION
# =========================

MODEL_PATH = "models/arecanut_model.keras"
CLASS_NAMES_PATH = "models/class_names.json"

IMG_SIZE = (224, 224)


# =========================
# CHECK IMAGE ARGUMENT
# =========================

if len(sys.argv) < 2:
    print("Usage:")
    print('python src\\predict.py "path\\to\\image.jpg"')
    sys.exit(1)

IMAGE_PATH = sys.argv[1]


# =========================
# LOAD MODEL
# =========================

print("Loading model...")

model = tf.keras.models.load_model(MODEL_PATH)

with open(CLASS_NAMES_PATH, "r", encoding="utf-8") as f:
    class_names = json.load(f)


# =========================
# LOAD IMAGE
# =========================

img = image.load_img(
    IMAGE_PATH,
    target_size=IMG_SIZE
)

img_array = image.img_to_array(img)

img_array = np.expand_dims(
    img_array,
    axis=0
)


# =========================
# PREDICTION
# =========================

predictions = model.predict(
    img_array,
    verbose=0
)

predicted_index = np.argmax(predictions[0])

predicted_class = class_names[predicted_index]

confidence = predictions[0][predicted_index] * 100


# =========================
# RESULTS
# =========================

print("\n================================")
print("ARECANUT DISEASE PREDICTION")
print("================================")

print(f"Image      : {IMAGE_PATH}")
print(f"Disease    : {predicted_class}")
print(f"Confidence : {confidence:.2f}%")

print("\nAll predictions:")

results = []

for i, probability in enumerate(predictions[0]):
    results.append(
        (class_names[i], probability * 100)
    )

results.sort(
    key=lambda x: x[1],
    reverse=True
)

for name, probability in results:
    print(f"{name:<25} {probability:.2f}%")

print("================================")