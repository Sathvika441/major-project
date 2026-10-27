"""Disease care guidance mapped to the current ArecaSmart model classes.

The guidance is conservative decision support, not an automatic pesticide/fertilizer
prescription. The model labels alone cannot determine dose; dose depends on crop age,
soil/tissue test, severity, product label and local extension recommendations.
"""

from datetime import datetime, timezone


def care_guidance(class_name: str) -> dict:
    key = " ".join(class_name.strip().lower().replace("_", " ").split())
    entries = {
        "healthy leaf": {
            "status": "No disease detected in this class",
            "actions": [
                "Continue weekly scouting and photograph the same area for comparison.",
                "Keep drainage open and avoid prolonged waterlogging.",
                "Use balanced nutrition based on soil testing and local arecanut recommendations."
            ],
            "fertilizer": "No corrective fertilizer is indicated by this image alone. Follow soil-test-based, crop-age-specific nutrition; do not apply extra nitrogen as a disease treatment.",
            "urgency": "Routine monitoring"
        },
        "healthy nut": {
            "status": "No disease detected in this class",
            "actions": [
                "Inspect nuts and bunches regularly for lesions, rot and unusual drop.",
                "Remove and safely dispose of obviously diseased fallen material where advised locally.",
                "Maintain drainage and avoid injuries during garden operations."
            ],
            "fertilizer": "No disease-specific fertilizer is indicated. Follow soil-test-based, crop-age-specific nutrition."
        },
        "healthy trunk": {
            "status": "No disease detected in this class",
            "actions": [
                "Inspect the stem base and trunk for fresh wounds, oozing or cracks.",
                "Avoid mechanical injury and prevent water from stagnating around the palm.",
                "Record recurring symptoms and seek advice if lesions appear."
            ],
            "fertilizer": "No disease-specific fertilizer is indicated. Follow soil-test-based, crop-age-specific nutrition."
        },
        "mahali koleroga": {
            "status": "Suspected Mahali / Koleroga (fruit rot)",
            "actions": [
                "Inspect nuts, buttons and rachillae for water-soaked/brown lesions and premature nut fall; image predictions are not confirmation.",
                "Improve drainage and reduce persistent wetness around bunches and the garden canopy where practical.",
                "Collect affected fallen nuts and diseased plant material and dispose of them according to local extension advice.",
                "Promptly consult the local horticulture officer/KVK about a locally registered, label-approved disease-management treatment and its timing, especially during wet weather."
            ],
            "fertilizer": "Fertilizer does not cure Koleroga. Do not increase fertilizer or apply a spray solely from this prediction; use soil-test-based nutrition and obtain local plant-pathology advice for crop-protection products.",
            "urgency": "Prompt field confirmation"
        },
        "stem bleeding": {
            "status": "Suspected stem bleeding",
            "actions": [
                "Examine the stem for dark bleeding patches, cracking or tissue decay; photograph the affected area and track spread.",
                "Prevent injury to the trunk and avoid waterlogging near the palm base.",
                "Do not scrape/cut extensively or apply unverified chemicals; seek confirmation from a horticulture officer/KVK.",
                "Ask the local expert to assess the affected palms and recommend a registered treatment based on severity."
            ],
            "fertilizer": "No fertilizer dose can be derived from an image. Nutrition supports overall palm health but will not itself cure stem bleeding; base fertilizer on soil test and crop stage."
        },
        "bud borer": {
            "status": "Suspected bud borer damage",
            "actions": [
                "Inspect the spindle/central unopened leaf and crown for bore holes, frass, wilting or damaged tissue.",
                "Avoid injuring the growing point; mark affected palms and inspect nearby palms.",
                "Get prompt confirmation from a local horticulture officer/KVK because crown damage can be serious.",
                "Use only locally registered control measures and follow the product label, protective equipment and pre-harvest interval."
            ],
            "fertilizer": "Fertilizer does not control borers. Do not apply a chemical or dosage from the image result; ask an extension officer to confirm the pest and recommend label-approved management."
        },
        "healthy foot": {
            "status": "No disease detected in this class",
            "actions": [
                "Keep the palm base well drained and avoid physical damage to roots and collar.",
                "Observe for softness, rot, unusual discoloration or leaning.",
                "Maintain organic matter and nutrition according to soil testing and local recommendations."
            ],
            "fertilizer": "No disease-specific dose is indicated from this image. Use soil-test-based nutrition."
        },
        "stem cracking": {
            "status": "Suspected stem cracking",
            "actions": [
                "Inspect cracks for fresh injury, decay, oozing or widening and record the location and progression.",
                "Avoid further mechanical injury and improve drainage around the palm.",
                "Do not fill or treat cracks with unverified materials; request a field assessment from a horticulture officer/KVK.",
                "If the palm is structurally unstable or the crack is rapidly progressing, keep people clear of the immediate area and obtain expert advice."
            ],
            "fertilizer": "There is not enough evidence to infer a corrective fertilizer dose from stem cracking. Have underlying causes and soil nutrition assessed first."
        },
        "yellow leaf disease": {
            "status": "Suspected yellow leaf disease",
            "actions": [
                "Photograph the whole palm and neighbouring palms, noting which leaves yellow first and how symptoms progress.",
                "Check drainage, soil moisture and other palms for similar symptoms; nutrient deficiencies and other stresses can look similar.",
                "Request field diagnosis from the local horticulture department/KVK before treating; do not infer a nutrient deficiency from yellow colour alone.",
                "Maintain recommended garden care and avoid over-irrigation or unbalanced fertilizer until the cause is confirmed."
            ],
            "fertilizer": "Yellowing alone cannot distinguish disease from nutrient deficiency. Do not prescribe extra nitrogen, magnesium or other nutrients without soil/leaf analysis and local expert advice."
        },
    }
    guidance = entries.get(key, {
        "status": "Unrecognised model label",
        "actions": [
            "Retake a clear image in natural light, showing the affected part and an unaffected comparison.",
            "Seek local horticulture/KVK confirmation before any treatment."
        ],
        "fertilizer": "No fertilizer or pesticide dose is recommended for an unrecognised label."
    })
    return {
        **guidance,
        "class_name": class_name,
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "safety_note": (
            "AI screening only, not a confirmed diagnosis. Exact fertilizer quantity depends on "
            "palm age, soil/leaf analysis, area, product concentration and local recommendations. "
            "Follow the current product label and local agricultural extension advice."
        ),
    }
