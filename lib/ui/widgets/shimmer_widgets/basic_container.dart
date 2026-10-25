import 'package:flutter/material.dart';
import '../../design/doudou_colors.dart';

class BasicShimmerContainer extends StatelessWidget {
  const BasicShimmerContainer(this.size, {super.key, this.radius = 10});
  final Size size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius), color: context.doudouColors.surfaceElevated),
      height: size.height,
      width: size.width,
    );
  }
}
