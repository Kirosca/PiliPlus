import 'package:PiliPlus/bili_feed/core/bili_filter_engine.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BiliFilterEngine 2.2 Syntax Unit Tests', () {
    test('Tokenize and Parse | Branches', () {
      final query = BiliFilterEngine.parseSearchQuery('黑神话 | 艾尔登法环');
      expect(query.hasRules, isTrue);
      expect(query.branches.length, 2);
      expect(query.exclusions.isEmpty, isTrue);
      expect(query.branches[0].first.val, '黑神话');
      expect(query.branches[1].first.val, '艾尔登法环');
    });

    test('cleanKeyword extracts positive terms across branches', () {
      final clean = BiliFilterEngine.cleanKeyword('黑神话 | 艾尔登法环 -#手游');
      expect(clean, '黑神话 艾尔登法环');
    });

    test('三维排除 (NOT): 标题、标签、作者一票否决', () {
      final query = BiliFilterEngine.parseSearchQuery('猫 -解说 -#手游 -@营销号');
      expect(query.exclusions.length, 3);
      expect(query.exclusions[0].target, FilterTarget.title);
      expect(query.exclusions[0].val, '解说');
      expect(query.exclusions[1].target, FilterTarget.tag);
      expect(query.exclusions[1].val, '手游');
      expect(query.exclusions[2].target, FilterTarget.author);
      expect(query.exclusions[2].val, '营销号');
    });

    test('精确匹配 (Quotes): 标签精确全字匹配与UP主精确全名匹配', () {
      final query = BiliFilterEngine.parseSearchQuery('#"游戏" @"官方"');
      expect(query.branches.length, 1);
      final branch = query.branches.first;
      expect(branch.length, 2);
      expect(branch[0].isExact, isTrue);
      expect(branch[0].target, FilterTarget.tag);
      expect(branch[0].val, '游戏');
      expect(branch[1].isExact, isTrue);
      expect(branch[1].target, FilterTarget.author);
      expect(branch[1].val, '官方');
    });

    test('带空格精确短语: "deepseek v3"', () {
      final query = BiliFilterEngine.parseSearchQuery('"deepseek v3"');
      expect(query.branches.length, 1);
      final token = query.branches.first.first;
      expect(token.target, FilterTarget.title);
      expect(token.isExact, isTrue);
      expect(token.val, 'deepseek v3');
    });

    test('全角符号与简繁归一化兼容', () {
      final query = BiliFilterEngine.parseSearchQuery('貓｜狗 －＃手遊');
      expect(query.branches.length, 2);
      expect(query.branches[0].first.val, '猫');
      expect(query.branches[1].first.val, '狗');
      expect(query.exclusions.length, 1);
      expect(query.exclusions.first.target, FilterTarget.tag);
      expect(query.exclusions.first.val, '手游');
    });

    test('filterSearchVideos filtering logic end-to-end', () {
      final video1 = SearchVideoItemModel(
        title: '黑神话悟空真好玩',
        tag: '单机,动作',
        bvid: 'BV1',
        owner: SearchOwner(name: '玩家A'),
      );
      final video2 = SearchVideoItemModel(
        title: '艾尔登法环全收集',
        tag: '魂系,RPG',
        bvid: 'BV2',
        owner: SearchOwner(name: '玩家B'),
      );
      final video3 = SearchVideoItemModel(
        title: '原神抽卡日常',
        tag: '手游,抽卡',
        bvid: 'BV3',
        owner: SearchOwner(name: '玩家C'),
      );
      final video4 = SearchVideoItemModel(
        title: '黑神话手游版虚假宣传',
        tag: '手游,测评',
        bvid: 'BV4',
        owner: SearchOwner(name: '玩家D'),
      );

      final candidates = [video1, video2, video3, video4];

      // 规则: 黑神话 或 艾尔登法环，同时排除标签包含手游
      final filtered = BiliFilterEngine.filterSearchVideos(
        candidates,
        keyword: '黑神话 | 艾尔登法环 -#手游',
      );

      expect(filtered.length, 2);
      expect(filtered.map((e) => e.bvid).toList(), ['BV1', 'BV2']);
    });
  });
}
