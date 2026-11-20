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
                "For Malnad Karnataka, ICAR-CPCRI reports fenamidone 10% + mancozeb 50% (w/w) at 0.3% spray concentration (3 g/L), with an adhesive, as a management option.",
                "ICAR-CPCRI also recommends prophylactic 1% Bordeaux mixture on bunches before the monsoon, repeated after 40–45 days where monsoon conditions continue.",
                "Use only a currently registered product whose label permits the crop and target disease; confirm product choice, spray volume, timing and any harvest interval with the local KVK."
            ],
            "pesticide": (
                "For fruit rot (Mahali/Koleroga): CPCRI recommends fenamidone "
                "10% + mancozeb 50% mixture at 3 grams per 1 litre of water, "
                "with a suitable sticker. A preventive option is 1% Bordeaux "
                "mixture on the arecanut bunches. Use only if the product label "
                "allows arecanut. Ask your local agriculture officer/KVK to "
                "confirm the product and spray timing."
            ),
            "pesticide_status": "CPCRI advice available — ask an agriculture officer before spraying",
            "urgency": "Prompt field confirmation, especially during monsoon",
            "sources": [
                "ICAR-CPCRI, arecanut Koleroga management recommendation for Malnad Karnataka: https://cpcri.gov.in/page/staff_profile/1/2",
                "ICAR-CPCRI, Farmers' Corner — Arecanut: https://cpcri.gov.in/page/article/farmers_corner_crop_advice_arecanut",
            ],
        },
        "stem bleeding": {
            "status": "Suspected stem bleeding",
            "actions": [
                "Have the bleeding patch and trunk condition examined by a horticulture officer or KVK before treatment.",
                "Improve drainage and prevent injuries to the trunk.",
                "No arecanut-specific pesticide product and dosage could be verified from the cited ICAR-CPCRI recommendations for this model label; do not apply a guessed dose."
            ],
            "pesticide": (
                "A safe spray and quantity could not be confirmed for this "
                "condition. Please show the affected palm to your local "
                "agriculture officer/KVK before using any pesticide."
            ),
            "pesticide_status": "No verified dose — expert diagnosis required",
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
            "status": "Suspected arecanut Yellow Leaf Disease (YLD)",
            "actions": [
                "Confirm the characteristic yellowing pattern and inspect neighbouring palms; nutrient stress and other disorders can look similar.",
                "ICAR-CPCRI identifies YLD as a phytoplasma disease and reports that it is not amenable to control by conventional plant-protection measures.",
                "Do not recommend an insecticide as a cure for YLD. Seek local expert advice on diagnosis, garden management, drainage and nutrition."
            ],
            "pesticide": (
                "Spraying will not cure Yellow Leaf Disease or make the yellow "
                "leaves green again. Do not spend money on pesticide for this "
                "disease. Ask your local agriculture officer or KVK to check "
                "the palm and advise how to care for the garden."
            ),
            "pesticide_status": "No spray can cure this disease",
            "sources": [
                "ICAR-CPCRI, Yellow Leaf Disease research and management: https://cpcri.gov.in/page/research_achievements_crop_protection/xx",
                "ICAR-CPCRI, Arecanut Ready Reckoner: https://cpcri.gov.in/filemgr/webfs/publication/READYRECKONERENGLISH3.pdf",
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
            "This result is only a computer check from your photo. It may be wrong. "
            "Do not spray based on the photo alone. First show the palm to your "
            "local agriculture officer/KVK. If spraying is advised, follow the "
            "instructions on the pesticide packet and wear the safety gear "
            "mentioned there."
        ),
    }
