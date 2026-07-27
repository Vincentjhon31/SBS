import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Shared semantic buckets so item-availability and borrow-request
/// statuses read as the same "kind of thing" (a pending request and a
/// reserved item are both "waiting", for example) even though the two
/// tables use different status strings.
enum StatusTone { positive, waiting, active, attention, neutral }

(Color bg, Color fg) statusToneColors(StatusTone tone) => switch (tone) {
      StatusTone.positive => (AppConstants.pastelMint, const Color(0xFF0E6B52)),
      StatusTone.waiting => (AppConstants.pastelPeach, const Color(0xFF8A5A00)),
      StatusTone.active => (AppConstants.pastelSky, const Color(0xFF0B4A8F)),
      StatusTone.attention => (AppConstants.pastelCoral, const Color(0xFF9C2B1F)),
      StatusTone.neutral => (AppConstants.pastelLavender, const Color(0xFF5B3B96)),
    };
