package com.example.quran_app_2025

import com.ryanheise.audioservice.AudioServiceActivity

// Shares the Flutter engine with the background audio service so murottal
// keeps playing, and media controls work, while the screen is off.
class MainActivity : AudioServiceActivity()
