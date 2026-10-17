import 'package:flutter/material.dart';

import '../../core/theme/open_vts_colors.dart';

/// Neutral image presentation that preserves the source alpha channel.
/// An opaque saturation blend fills transparent PNG pixels; a matrix does not.
/// Map imagery and vehicle icons use their original, unfiltered images.
class OpenVtsMonochromeImage extends StatelessWidget {
  const OpenVtsMonochromeImage({required this.child, super.key});

  final Image child;

  @override
  Widget build(BuildContext context) => ColorFiltered(
        colorFilter: OpenVtsColors.monochromeFilter,
        child: child,
      );
}
