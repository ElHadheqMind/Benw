# Welwi — Resilient AI Notes & Calendar

Welwi is an innovative, high-resilience AI assistant built for the **Gemma 4 Good Hackathon**. It provides 100% availability through an offline-first architecture, utilizing **LiteRT-LM** (Gemma 4) for on-device processing.

## 🌵 Cactus Track Potential
Welwi is designed as a "Lit-Edge" assistant. It intelligently handles tasks locally when offline (via LiteRT) and is prepared for future hybrid routing to cloud-based Gemini APIs when connectivity is available, embodying the core of the Cactus track.

## ✨ Key Features
- **Offline Intelligence:** Full note and calendar management powered by Gemma 4 on-device.
- **Voice-First Interaction:** Multimodal audio processing for natural, resilient input.
- **Premium Aesthetics:** A Emerald & Bronze design system inspired by the *Welwitschia* plant.
- **Global Resilience:** Built to provide assistance in all environments, regardless of connectivity.

## 🚀 Getting Started
This project requires the **Gemma 4 LiteRT** model.
1. Place the `gemma-4-E2B-it.litertlm` model in `assets/models/`.
2. Run `flutter pub get`.
3. Launch on a supported Android device (LiteRT target).

## 🛠 Tech Stack
- **Framework:** Flutter
- **ML Engine:** LiteRT-LM (Gemma 4)
- **Modality:** Text, Audio, Image (OCR)
- **State Management:** Provider
