import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/curated_feed/controller.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:get/get.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:material_ui/material_ui.dart';

class CuratedFeedPage extends StatefulWidget {
  const CuratedFeedPage({super.key});

  @override
  State<CuratedFeedPage> createState() => _CuratedFeedPageState();
}

class _CuratedFeedPageState extends State<CuratedFeedPage>
    with AutomaticKeepAliveClientMixin, GridMixin {
  final controller = Get.putOrFind(CuratedFeedController.new);

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (controller.needRefresh) {
      controller.needRefresh = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.onRefresh();
      });
    }
    final colorScheme = ColorScheme.of(context);
    return Container(
      clipBehavior: .hardEdge,
      margin: const .symmetric(horizontal: Style.safeSpace),
      decoration: const BoxDecoration(borderRadius: Style.mdRadius),
      child: refreshIndicator(
        onRefresh: controller.onRefresh,
        child: CustomScrollView(
          controller: controller.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const .only(top: Style.cardSpace, bottom: 100),
              sliver: Obx(
                () => _buildBody(colorScheme, controller.loadingState.value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    ColorScheme colorScheme,
    LoadingState<List<SearchVideoItemModel>?> loadingState,
  ) {
    return switch (loadingState) {
      Loading() => gridSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (context, index) {
                  if (index >= response.length - 2) {
                    controller.onLoadMore();
                  }
                  return VideoCardH(
                    videoItem: response[index],
                    onRemove: () {
                      controller.items.removeAt(index);
                      controller.loadingState.value =
                          Success(List.from(controller.items));
                    },
                  );
                },
                itemCount: response.length,
              )
            : SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 80),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_motion_outlined,
                        size: 48,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '暂无符合规则的选推视频',
                        style: TextStyle(
                          fontSize: 15,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '请前往【设置】->【选推规则管理】添加或调整规则',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      Error(:final errMsg) => SliverToBoxAdapter(
          child: HttpError(
            errMsg: errMsg,
            onReload: controller.onRefresh,
          ),
        ),
    };
  }
}
