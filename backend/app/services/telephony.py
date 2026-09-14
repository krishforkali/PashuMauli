"""Demo Telephony Provider & Interactive IVR State Machine for PashuMauli."""
import logging
import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime
from enum import Enum

logger = logging.getLogger("pashumauli.telephony")


class IVRStep(str, Enum):
    WELCOME = "WELCOME"
    LANGUAGE = "LANGUAGE"
    FARMER_ID = "FARMER_ID"
    ANIMAL_ID = "ANIMAL_ID"
    SYMPTOM_1 = "SYMPTOM_1"  # Fever / Lethargy
    SYMPTOM_2 = "SYMPTOM_2"  # Mouth / Foot Blisters
    SYMPTOM_3 = "SYMPTOM_3"  # Milk Yield Drop
    SYMPTOM_4 = "SYMPTOM_4"  # Nasal Discharge / Coughing
    SYMPTOM_5 = "SYMPTOM_5"  # Lameness / Difficulty Standing
    CONFIRMATION = "CONFIRMATION"
    COMPLETED = "COMPLETED"


# 5 Standard Symptom Definitions for IVR Questionnaire
SYMPTOM_QUESTIONS = [
    {
        "step": IVRStep.SYMPTOM_1,
        "key": "fever_lethargy",
        "name": "High Fever or Lethargy",
        "prompt_en": "Question 1: Does the animal have high fever or lethargy? Press 1 for Yes, 2 for No.",
        "prompt_hi": "प्रश्न 1: क्या पशु को तेज़ बुखार या सुस्ती है? हाँ के लिए 1, नहीं के लिए 2 दबाएँ।",
        "prompt_mr": "प्रश्न 1: जनावराला तीव्र ताप किंवा अशक्तपणा आहे का? होय साठी 1, नाही साठी 2 दाबा.",
    },
    {
        "step": IVRStep.SYMPTOM_2,
        "key": "mouth_foot_blisters",
        "name": "Mouth or Foot Blisters/Lesions",
        "prompt_en": "Question 2: Does the animal have blisters or lesions on mouth or hooves? Press 1 for Yes, 2 for No.",
        "prompt_hi": "प्रश्न 2: क्या मुंह या खुरों में छाले या घाव हैं? हाँ के लिए 1, नहीं के लिए 2 दबाएँ।",
        "prompt_mr": "प्रश्न 2: तोंडात किंवा खुरांमध्ये फोड किंवा जखमा आहेत का? होय साठी 1, नाही साठी 2 दाबा.",
    },
    {
        "step": IVRStep.SYMPTOM_3,
        "key": "milk_drop",
        "name": "Sudden Drop in Milk Yield",
        "prompt_en": "Question 3: Is there a sudden reduction in milk yield? Press 1 for Yes, 2 for No.",
        "prompt_hi": "प्रश्न 3: क्या दूध के उत्पादन में अचानक गिरावट आई है? हाँ के लिए 1, नहीं के लिए 2 दबाएँ।",
        "prompt_mr": "प्रश्न 3: दुधाच्या उत्पादनात अचानक घट झाली आहे का? होय साठी 1, नाही साठी 2 दाबा.",
    },
    {
        "step": IVRStep.SYMPTOM_4,
        "key": "respiratory",
        "name": "Nasal Discharge or Coughing",
        "prompt_en": "Question 4: Does the animal have nasal discharge or coughing? Press 1 for Yes, 2 for No.",
        "prompt_hi": "प्रश्न 4: क्या नाक से स्राव या खाँसी है? हाँ के लिए 1, नहीं के लिए 2 दबाएँ।",
        "prompt_mr": "प्रश्न 4: नाकातून द्रव वाहणे किंवा खोकला आहे का? होय साठी 1, नाही साठी 2 दाबा.",
    },
    {
        "step": IVRStep.SYMPTOM_5,
        "key": "lameness",
        "name": "Lameness or Difficulty Standing",
        "prompt_en": "Question 5: Does the animal exhibit lameness or difficulty walking? Press 1 for Yes, 2 for No.",
        "prompt_hi": "प्रश्न 5: क्या पशु लंगड़ा रहा है या चलने में असमर्थ है? हाँ के लिए 1, नहीं के लिए 2 दबाएँ।",
        "prompt_mr": "प्रश्न 5: जनावर लंगडत आहे किंवा चालण्यास त्रास होत आहे का? होय साठी 1, नाही साठी 2 दाबा.",
    },
]


@dataclass
class IVRCallSession:
    """Represents an active interactive IVR call session."""

    call_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    caller_phone: str = "+919999999999"
    current_step: IVRStep = IVRStep.WELCOME
    language: str = "mr"  # Default Marathi
    farmer_name: str = "IVR Farmer"
    farmer_id: uuid.UUID | None = None
    animal_ear_tag: str = "TAG-IVR-100"
    animal_id: uuid.UUID | None = None
    symptoms_answers: dict[str, bool] = field(default_factory=dict)
    collected_symptoms: list[str] = field(default_factory=list)
    latitude: float = 18.5204
    longitude: float = 73.8567
    created_at: datetime = field(default_factory=lambda: datetime.now(UTC))

    def get_prompt_text(self) -> str:
        """Return the current step's prompt text based on session language."""
        lang = self.language if self.language in ("mr", "hi", "en") else "mr"

        if self.current_step == IVRStep.WELCOME:
            return (
                "Welcome to PashuMauli Helpline. "
                "For Marathi press 1, for Hindi press 2, for English press 3."
            )

        if self.current_step == IVRStep.LANGUAGE:
            if lang == "hi":
                return "पशुमाउली हेल्पलाइन में आपका स्वागत है। कृपया अपना किसान फोन या आईडी दर्ज करें और # दबाएं।"
            if lang == "en":
                return "Welcome. Please enter your Farmer Phone/ID followed by hash."
            return "पशुमाउली हेल्पलाईनवर आपले स्वागत आहे. कृपया आपला शेतकरी फोन किंवा आयडी प्रविष्ट करा आणि # दाबा."

        if self.current_step == IVRStep.FARMER_ID:
            if lang == "hi":
                return "कृपया पशु का इयर टैग नंबर दर्ज करें और # दबाएं।"
            if lang == "en":
                return "Please enter the Animal Ear Tag ID followed by hash."
            return "कृपया जनावराचा इअर टॅग क्रमांक प्रविष्ट करा आणि # दाबा."

        if self.current_step == IVRStep.ANIMAL_ID:
            sq = SYMPTOM_QUESTIONS[0]
            return sq[f"prompt_{lang}"]

        if self.current_step in (
            IVRStep.SYMPTOM_1,
            IVRStep.SYMPTOM_2,
            IVRStep.SYMPTOM_3,
            IVRStep.SYMPTOM_4,
        ):
            idx = [
                IVRStep.SYMPTOM_1,
                IVRStep.SYMPTOM_2,
                IVRStep.SYMPTOM_3,
                IVRStep.SYMPTOM_4,
            ].index(self.current_step)
            sq = SYMPTOM_QUESTIONS[idx + 1]
            return sq[f"prompt_{lang}"]

        if self.current_step == IVRStep.SYMPTOM_5:
            sym_count = len(self.collected_symptoms)
            if lang == "hi":
                return f"आपने {sym_count} लक्षण दर्ज किए हैं। स्वास्थ्य मामला दर्ज करने के लिए 1 दबाएँ, रद्द करने के लिए 2 दबाएँ।"
            if lang == "en":
                return f"You reported {sym_count} symptoms. Press 1 to confirm case creation, 2 to cancel."
            return f"आपण {sym_count} लक्षणे नोंदवली आहेत. आरोग्य केस तयार करण्यासाठी 1 दाबा, रद्द करण्यासाठी 2 दाबा."

        if self.current_step == IVRStep.CONFIRMATION:
            if lang == "hi":
                return "धन्यवाद! आपकी पशु स्वास्थ्य केस सफलतापूर्वक दर्ज कर ली गई है।"
            if lang == "en":
                return "Thank you! Your animal health case has been registered successfully."
            return "धन्यवाद! तुमची जनावर आरोग्य केस यशस्वीरित्या नोंदवली गेली आहे."

        return "Call completed."


class DemoTelephonyProvider:
    """In-memory Telephony Provider simulating Gather -> Passthru IVR flows."""

    def __init__(self) -> None:
        self.active_sessions: dict[str, IVRCallSession] = {}

    def start_call(self, caller_phone: str = "+919999999999", language: str = "mr") -> IVRCallSession:
        """Start a new IVR call session."""
        session = IVRCallSession(caller_phone=caller_phone, language=language)
        self.active_sessions[session.call_id] = session
        logger.info(f"IVR Call Started: session_id={session.call_id}, phone={caller_phone}")
        return session

    def get_session(self, call_id: str) -> IVRCallSession | None:
        """Retrieve active call session by ID."""
        return self.active_sessions.get(call_id)

    def process_passthru_digit(self, call_id: str, digits: str) -> tuple[IVRCallSession, bool, str]:
        """Process synchronous Passthru webhook DTMF digit for the active session.

        Returns (session, is_valid, prompt_message).
        """
        session = self.get_session(call_id)
        if not session:
            logger.warning(f"IVR Passthru called with non-existent session_id={call_id}")
            raise ValueError(f"Session {call_id} not found.")

        cleaned_digits = digits.strip().replace("#", "")

        # 1. WELCOME -> LANGUAGE
        if session.current_step == IVRStep.WELCOME:
            if cleaned_digits == "1":
                session.language = "mr"
            elif cleaned_digits == "2":
                session.language = "hi"
            elif cleaned_digits == "3":
                session.language = "en"
            else:
                session.language = "mr"
            session.current_step = IVRStep.LANGUAGE
            return session, True, session.get_prompt_text()

        # 2. LANGUAGE -> FARMER_ID
        if session.current_step == IVRStep.LANGUAGE:
            if cleaned_digits:
                session.farmer_name = f"Farmer-{cleaned_digits[-4:]}"
            session.current_step = IVRStep.FARMER_ID
            return session, True, session.get_prompt_text()

        # 3. FARMER_ID -> ANIMAL_ID
        if session.current_step == IVRStep.FARMER_ID:
            if cleaned_digits:
                session.animal_ear_tag = f"TAG-{cleaned_digits[-6:]}"
            session.current_step = IVRStep.ANIMAL_ID
            return session, True, session.get_prompt_text()

        # 4. SYMPTOM QUESTIONS (SYMPTOM_1 through SYMPTOM_5)
        symptom_steps = [
            IVRStep.ANIMAL_ID,
            IVRStep.SYMPTOM_1,
            IVRStep.SYMPTOM_2,
            IVRStep.SYMPTOM_3,
            IVRStep.SYMPTOM_4,
        ]

        if session.current_step in symptom_steps:
            step_idx = symptom_steps.index(session.current_step)
            sq = SYMPTOM_QUESTIONS[step_idx]

            # 1 = Yes, 2 = No
            is_yes = cleaned_digits == "1"
            session.symptoms_answers[sq["key"]] = is_yes
            if is_yes:
                session.collected_symptoms.append(sq["name"])

            # Advance to next symptom step or to CONFIRMATION
            next_steps = [
                IVRStep.SYMPTOM_1,
                IVRStep.SYMPTOM_2,
                IVRStep.SYMPTOM_3,
                IVRStep.SYMPTOM_4,
                IVRStep.SYMPTOM_5,
            ]
            session.current_step = next_steps[step_idx]
            return session, True, session.get_prompt_text()

        # 5. SYMPTOM_5 -> CONFIRMATION
        if session.current_step == IVRStep.SYMPTOM_5:
            if cleaned_digits == "1":
                session.current_step = IVRStep.CONFIRMATION
                return session, True, session.get_prompt_text()
            else:
                session.current_step = IVRStep.COMPLETED
                return session, False, "Call cancelled by user."

        return session, True, session.get_prompt_text()


# Global Telephony Provider Singleton
telephony_provider = DemoTelephonyProvider()
