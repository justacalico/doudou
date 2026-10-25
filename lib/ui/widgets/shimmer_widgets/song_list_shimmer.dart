import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../design/doudou_colors.dart';

import 'basic_container.dart';

class SongListShimmer extends StatelessWidget {
  const SongListShimmer({super.key, this.itemCount = 10, this.topPadding = 0});
  final int itemCount;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final c = context.doudouColors;
    return Shimmer.fromColors(
      baseColor: c.surfaceElevated,
      highlightColor: c.stateHover,
      child: ListView.builder(
          itemCount: itemCount,
          padding: EdgeInsets.only(top: topPadding, left: 0),
          itemBuilder: (_, index) {
            return _listTile();
          }),
    );
  }

  Widget _listTile() {
    return const ListTile(
      leading: BasicShimmerContainer(Size(50, 50)),
      title: BasicShimmerContainer(Size(90, 20)),
      subtitle: BasicShimmerContainer(Size(40, 15)),
      trailing: BasicShimmerContainer(Size(50, 20)),
    );
  }
}
