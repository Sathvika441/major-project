import os
import json
import numpy as np
import tensorflow as tf
import matplotlib.pyplot as plt

from tensorflow import keras
from tensorflow.keras import layers
from sklearn.metrics import classification_report, confusion_matrix
import seaborn as sns


# =========================
# CONFIGURATION
# =========================

TRAIN_DIR = "dataset/train"
TEST_DIR = "dataset/test"

IMG_SIZE = (224, 224)
BATCH_SIZE = 32
SEED = 42

MODEL_DIR = "models"
OUTPUT_DIR = "outputs"

os.makedirs(MODEL_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)


# =========================
# LOAD DATASET
# =========================

print("\nLoading training dataset...")

train_ds = tf.keras.utils.image_dataset_from_directory(
    TRAIN_DIR,
    validation_split=0.2,
    subset="training",
    seed=SEED,
    image_size=IMG_SIZE,
    batch_size=BATCH_SIZE
)

val_ds = tf.keras.utils.image_dataset_from_directory(
    TRAIN_DIR,
    validation_split=0.2,
    subset="validation",
    seed=SEED,
    image_size=IMG_SIZE,
    batch_size=BATCH_SIZE
)

test_ds = tf.keras.utils.image_dataset_from_directory(
    TEST_DIR,
    shuffle=False,
    image_size=IMG_SIZE,
    batch_size=BATCH_SIZE
)

class_names = train_ds.class_names
num_classes = len(class_names)

print("\nClasses:")
for i, name in enumerate(class_names):
    print(f"{i}: {name}")

print(f"\nNumber of classes: {num_classes}")


# Save class names
with open(
    os.path.join(MODEL_DIR, "class_names.json"),
    "w",
    encoding="utf-8"
) as f:
    json.dump(class_names, f, indent=4)


# =========================
# PERFORMANCE
# =========================

AUTOTUNE = tf.data.AUTOTUNE

train_ds = train_ds.prefetch(AUTOTUNE)
val_ds = val_ds.prefetch(AUTOTUNE)
test_ds = test_ds.prefetch(AUTOTUNE)


# =========================
# DATA AUGMENTATION
# =========================

data_augmentation = keras.Sequential([
    layers.RandomFlip("horizontal"),
    layers.RandomRotation(0.1),
    layers.RandomZoom(0.1),
    layers.RandomContrast(0.1),
])


# =========================
# MOBILE NET V2
# =========================

base_model = tf.keras.applications.MobileNetV2(
    input_shape=(224, 224, 3),
    include_top=False,
    weights="imagenet"
)

base_model.trainable = False


# =========================
# BUILD MODEL
# =========================

inputs = keras.Input(shape=(224, 224, 3))

x = data_augmentation(inputs)

x = tf.keras.applications.mobilenet_v2.preprocess_input(x)

x = base_model(x, training=False)

x = layers.GlobalAveragePooling2D()(x)

x = layers.Dropout(0.3)(x)

outputs = layers.Dense(
    num_classes,
    activation="softmax"
)(x)

model = keras.Model(inputs, outputs)


# =========================
# COMPILE
# =========================

model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=0.0001),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"]
)

model.summary()


# =========================
# TRAIN
# =========================

print("\nStarting training...\n")

history = model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=15
)


# =========================
# SAVE MODEL
# =========================

model_path = os.path.join(
    MODEL_DIR,
    "arecanut_model.keras"
)

model.save(model_path)

print(f"\nModel saved to: {model_path}")


# =========================
# ACCURACY GRAPH
# =========================

plt.figure(figsize=(10, 5))

plt.plot(
    history.history["accuracy"],
    label="Training Accuracy"
)

plt.plot(
    history.history["val_accuracy"],
    label="Validation Accuracy"
)

plt.title("Training and Validation Accuracy")
plt.xlabel("Epoch")
plt.ylabel("Accuracy")
plt.legend()

plt.savefig(
    os.path.join(
        OUTPUT_DIR,
        "accuracy.png"
    )
)

plt.close()


# =========================
# LOSS GRAPH
# =========================

plt.figure(figsize=(10, 5))

plt.plot(
    history.history["loss"],
    label="Training Loss"
)

plt.plot(
    history.history["val_loss"],
    label="Validation Loss"
)

plt.title("Training and Validation Loss")
plt.xlabel("Epoch")
plt.ylabel("Loss")
plt.legend()

plt.savefig(
    os.path.join(
        OUTPUT_DIR,
        "loss.png"
    )
)

plt.close()


# =========================
# TEST EVALUATION
# =========================

print("\nEvaluating model on test dataset...")

test_loss, test_accuracy = model.evaluate(test_ds)

print(f"\nTest Accuracy: {test_accuracy * 100:.2f}%")
print(f"Test Loss: {test_loss:.4f}")


# =========================
# PREDICTIONS
# =========================

y_true = []
y_pred = []

for images, labels in test_ds:

    predictions = model.predict(
        images,
        verbose=0
    )

    predicted_classes = np.argmax(
        predictions,
        axis=1
    )

    y_true.extend(labels.numpy())
    y_pred.extend(predicted_classes)


# =========================
# CLASSIFICATION REPORT
# =========================

print("\nClassification Report:\n")

report = classification_report(
    y_true,
    y_pred,
    target_names=class_names
)

print(report)

with open(
    os.path.join(
        OUTPUT_DIR,
        "classification_report.txt"
    ),
    "w",
    encoding="utf-8"
) as f:
    f.write(report)


# =========================
# CONFUSION MATRIX
# =========================

cm = confusion_matrix(
    y_true,
    y_pred
)

plt.figure(figsize=(12, 10))

sns.heatmap(
    cm,
    annot=True,
    fmt="d",
    xticklabels=class_names,
    yticklabels=class_names
)

plt.xlabel("Predicted")
plt.ylabel("Actual")
plt.title("Confusion Matrix")

plt.xticks(rotation=45, ha="right")
plt.yticks(rotation=0)

plt.tight_layout()

plt.savefig(
    os.path.join(
        OUTPUT_DIR,
        "confusion_matrix.png"
    )
)

plt.close()


print("\n====================================")
print("TRAINING COMPLETED")
print("====================================")
print(f"Model: {model_path}")
print("Class names: models/class_names.json")
print("Accuracy graph: outputs/accuracy.png")
print("Loss graph: outputs/loss.png")
print("Confusion matrix: outputs/confusion_matrix.png")
print("Classification report: outputs/classification_report.txt")