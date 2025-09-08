import 'package:flutter/material.dart';

class PumpkinColors {
  // Wine-themed color palette
  static const Color primaryWine = Color(0xFF8B0000);     // Deep Wine Red - main brand color
  static const Color backgroundLinen = Color(0xFFF7F6F4); // Linen - clean background
  static const Color textCharcoal = Color(0xFF2F2F2F);    // Charcoal - primary text
  static const Color accentGold = Color(0xFFD4AF37);      // Antique Gold - accent highlights
  static const Color secondaryWine = Color(0xFFB71C1C);   // Lighter wine for variants
  static const Color mutedWine = Color(0xFF6D0000);       // Darker wine for depth
  
  // Legacy colors (keep for backward compatibility during transition)
  static const Color orange = Color(0xFF8B0000);          // Now maps to primaryWine
  static const Color lightOrange = Color(0xFFB71C1C);     // Now maps to secondaryWine  
  static const Color darkOrange = Color(0xFF6D0000);      // Now maps to mutedWine
  static const Color errorRed = Color(0xFFE53E3E);
  static const Color successGreen = Color(0xFF38A169);
}