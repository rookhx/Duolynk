import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_radii.dart';

class DuoShimmerBlock extends StatefulWidget {
  const DuoShimmerBlock({super.key, this.width, required this.height});

  final double? width;
  final double height;

  @override
  State<DuoShimmerBlock> createState() => _DuoShimmerBlockState();
}

class _DuoShimmerBlockState extends State<DuoShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            gradient: LinearGradient(
              begin: Alignment(-1 + (_controller.value * 2), 0),
              end: Alignment(1 + (_controller.value * 2), 0),
              colors: const [
                AppColors.cardSurface,
                Color(0x22FFFFFF),
                AppColors.cardSurface,
              ],
            ),
          ),
        );
      },
    );
  }
}
