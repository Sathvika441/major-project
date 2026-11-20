"""Evidence-based arecanut crop-protection guidance for the current model classes.

Chemical recommendations are shown only where an ICAR-CPCRI source provides a
crop-specific product and dose. A model label is a screening result, not a field
diagnosis. Follow the current product label and local KVK/extension advice.
"""

from datetime import datetime, timezone


def care_guidance(class_name: str) -> dict:
    key = " ".join(class_name.strip().lower().replace("_", " ").split())

    no_spray = {
        "pesticide": (
            "No pesticide is recommended for a healthy image. Continue routine "
            "scouting and use crop-protection products only if a pest or disease "
            "is confirmed."
        ),
        "pesticide_status": "No treatment indicated",
    }

    entries = {
        "healthy leaf": {
            "status": "No disease detected in this class",
            "actions": [
                "Continue regular inspection of leaves and the crown.",
                "Maintain drainage and avoid prolonged waterlogging.",
                "If spots or blight develop, obtain a field diagnosis before spraying."
            ],
            **no_spray,
            "urgency": "Routine monitoring",
        },
        "healthy nut": {
            "status": "No disease detected in this class",
            "actions": [
                "Inspect bunches regularly for water-soaked lesions, rot and premature nut fall.",
                "Keep the garden clean and maintain drainage.",
            ],
            **no_spray,
        },
        "healthy trunk": {
            "status": "No disease detected in this class",
            "actions": [
                "Inspect the trunk for fresh wounds, oozing, cracks or decay.",
                "Avoid mechanical injury and water stagnation around the palm.",
            ],
            **no_spray,
        },
        "mahali koleroga": {
            "status": "Suspected Mahali / Koleroga (arecanut fruit rot)",
            "actions": [
                "Confirm water-soaked or brown lesions on nuts and premature nut fall in the field; an image prediction alone is not confirmation.",
                "Remove and destroy affected fallen nuts and diseased bunch material; improve garden drainage.",
                "For arecanut fruit rot, the January 2025 ICAR-CPCRI bulletin reports Mandipropamid 23.8% SC at 1 ml/L water, or 1% Bordeaux mixture, as management options.",
                "ICAR-CPCRI also recommends prophylactic 1% Bordeaux mixture on bunches before the monsoon, repeated after 40–45 days where monsoon conditions continue.",
                "Use only a currently registered product whose label permits the crop and target disease; confirm product choice, spray volume, timing and any harvest interval with the local KVK."
            ],
            "pesticide": (
                "For fruit rot (Mahali/Koleroga): the January 2025 ICAR-CPCRI "
                "bulletin reports Mandipropamid 23.8% SC at 1 ml per litre of "
                "water. Alternatively, it reports 1% Bordeaux mixture on the "
                "bunches. These are field-trial recommendations, not pesticide "
                "label claims. Confirm the diagnosis and legal product use "
                "with your local agriculture officer/KVK before spraying."
            ),
            "pesticide_status": "CPCRI field-trial rate — no pesticide label claim; expert confirmation required",
            "urgency": "Prompt field confirmation, especially during monsoon",
            "sources": [
                "ICAR-CPCRI, Good Agricultural Practices in Arecanut Cultivation (Technical Bulletin 160, January 2025), fruit rot management: https://agritech.tnau.ac.in/horticulture/pdf/Arecanut_ICAR%20CPCRI_2025.pdf",
                "ICAR-CPCRI, Farmers' Corner — Arecanut: https://cpcri.gov.in/page/article/farmers_corner_crop_advice_arecanut",
            ],
        },
        "stem bleeding": {
            "status": "Stem bleeding — check for basal stem rot (Anabe roga)",
            "actions": [
                "Have the bleeding patch and trunk condition examined by a horticulture officer or KVK before treatment.",
                "Improve drainage and prevent injuries to the trunk.",
                "Check for a brown patch near the palm base, brown liquid oozing from the trunk, and a bracket-like fungal growth; these are signs CPCRI describes for Anabe roga.",
                "If field inspection confirms basal stem rot (Anabe roga) — brown patch near the base, brown oozing liquid and/or fungal bracket at the base — CPCRI 2025 reports Hexaconazole 5% root-zone drenching at 2 ml/L, 15–20 L solution per palm. The image label alone cannot confirm this disease."
            ],
            "pesticide": (
                "If an agriculture officer confirms basal stem rot (Anabe roga), "
                "the CPCRI 2025 field-trial rate is Hexaconazole 5% at 2 ml "
                "per litre of water, using 15–20 litres of solution around "
                "each affected palm root zone. Do not use this for stem "
                "bleeding unless Anabe roga is confirmed. CPCRI states this "
                "is a field-trial recommendation without a pesticide label claim."
            ),
            "pesticide_status": "Only if Anabe roga is confirmed — CPCRI field-trial rate, no label claim",
            "sources": [
                "ICAR-CPCRI, Good Agricultural Practices in Arecanut Cultivation (Technical Bulletin 160, January 2025), Anabe roga management: https://agritech.tnau.ac.in/horticulture/pdf/Arecanut_ICAR%20CPCRI_2025.pdf",
            ],
        },
        "bud borer": {
            "status": "Suspected bud borer damage",
            "actions": [
                "Inspect the spindle and growing point for bore holes, frass, wilting or damaged tissue; confirm the insect before treatment.",
                "Mark affected palms and seek prompt assessment from a horticulture officer or KVK.",
                "No crop-specific pesticide and dosage for an arecanut pest named bud borer could be verified in the ICAR-CPCRI sources reviewed; do not substitute a recommendation for spindle bug or another pest."
            ],
            "pesticide": (
                "The insect must be identified first. We do not have a verified "
                "spray quantity for arecanut bud borer. Please ask your local "
                "agriculture officer/KVK before spraying."
            ),
            "pesticide_status": "No verified dose — pest identification required",
        },
        "healthy foot": {
            "status": "No disease detected in this class",
            "actions": [
                "Keep the palm base well drained and avoid root or collar injury.",
                "Observe for softness, rot, discoloration or unusual leaning.",
            ],
            **no_spray,
        },
        "stem cracking": {
            "status": "Suspected stem cracking",
            "actions": [
                "Arrange field inspection to determine whether the crack is due to injury, growth stress or disease.",
                "Avoid further mechanical injury and improve drainage around the palm.",
                "No pesticide dose can be justified from a stem-cracking image label; do not fill or spray the crack with unverified chemicals."
            ],
            "pesticide": (
                "No pesticide quantity is confirmed for stem cracking. The "
                "cause of the crack must be checked first. Please contact your "
                "local agriculture officer/KVK."
            ),
            "pesticide_status": "No verified dose — cause must be diagnosed",
        },
        "yellow leaf disease": {
            "status": "Possible Yellow Leaf Disease (YLD)",
            "actions": [
                "Yellowing can have other causes too. Ask an agriculture officer or KVK to confirm the disease; CPCRI recommends testing suspected palms.",
                "ICAR-CPCRI identifies the plant hopper Proutista moesta as a carrier of the YLD phytoplasma. Check the garden for this insect, but do not assume that spraying will cure infected palms.",
                "The 2025 ICAR-CPCRI bulletin says YLD cannot be controlled by conventional pesticide treatments. It recommends garden management, regular monitoring and removal of palms confirmed positive for YLD."
            ],
            "pesticide": (
                "No pesticide or spray dosage is recommended for curing Yellow Leaf "
                "Disease. It is caused by a phytoplasma, not a fungus. CPCRI confirms "
                "that the plant hopper Proutista moesta spreads the disease, but its "
                "2025 arecanut bulletin does not give an insecticide and dosage for "
                "YLD control. Do not use a guessed dose or spray to cure the palm. "
                "Ask your local agriculture officer/KVK to confirm the disease and "
                "check whether any separate plant-hopper treatment is currently "
                "registered and suitable for arecanut."
            ),
            "pesticide_status": "No verified pesticide dose for Yellow Leaf Disease",
            "sources": [
                "ICAR-CPCRI, Good Agricultural Practices in Arecanut Cultivation, Technical Bulletin 160 (January 2025), Yellow Leaf Disease, pages 59-61: https://agritech.tnau.ac.in/horticulture/pdf/Arecanut_ICAR%20CPCRI_2025.pdf",
                "ICAR-CPCRI, Research Achievements - Crop Protection (YLD phytoplasma and Proutista moesta vector): https://cpcri.gov.in/page/research_achievements_crop_protection/",
                "Kerala Agricultural University, Yellow Leaf Disease page (older vector-control advice; not adopted as a current CPCRI dose): https://www.celkau.in/crops/plantation/arecanut/yellowleaf.php"
            ],
        },
    }

    guidance = entries.get(key, {
        "status": "Unrecognised model label",
        "actions": [
            "Retake a clear image in natural light, showing the affected part and an unaffected comparison.",
            "Seek local horticulture/KVK confirmation before any treatment."
        ],
        "pesticide": "No pesticide or dosage is recommended for an unrecognised model label.",
        "pesticide_status": "No recommendation available",
    })
    return {
        **guidance,
        "class_name": class_name,
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "safety_note": (
            "This result is only a computer check from your photo and may be wrong. "
            "The pesticide rates shown are CPCRI field-trial recommendations, "
            "not pesticide label claims. Do not spray from this result alone. "
            "Ask your local agriculture officer/KVK to confirm the disease and "
            "whether the product is legally registered and permitted for arecanut. "
            "Always follow the current product label and required safety measures."
        ),
    }
