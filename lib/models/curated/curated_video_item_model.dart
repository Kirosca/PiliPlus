import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/models/search/result.dart';

class CuratedOwner extends BaseOwner {
  CuratedOwner({int? mid, String? name}) {
    this.mid = mid;
    this.name = name;
  }

  Map<String, dynamic> toJson() => {
        'mid': mid,
        'name': name,
      };

  factory CuratedOwner.fromJson(Map<String, dynamic> json) => CuratedOwner(
        mid: json['mid'] as int?,
        name: json['name'] as String?,
      );
}

class CuratedStat extends BaseStat {
  CuratedStat({int? view, int? danmu, int? like}) {
    this.view = view;
    this.danmu = danmu;
    this.like = like;
  }

  Map<String, dynamic> toJson() => {
        'view': view,
        'danmu': danmu,
        'like': like,
      };

  factory CuratedStat.fromJson(Map<String, dynamic> json) => CuratedStat(
        view: json['view'] as int?,
        danmu: json['danmu'] as int?,
        like: json['like'] as int?,
      );
}

class CuratedVideoItemModel extends BaseRcmdVideoItemModel {
  String? fromKeyword;

  CuratedVideoItemModel({
    required String title,
    String? bvid,
    int? aid,
    int? cid,
    String? cover,
    int duration = -1,
    int? pubdate,
    BaseOwner? owner,
    BaseStat? stat,
    String? goto = 'av',
    String? uri,
    String? rcmdReason,
    this.fromKeyword,
  }) {
    this.title = title;
    this.bvid = bvid;
    this.aid = aid;
    this.cid = cid;
    this.cover = cover;
    this.duration = duration;
    this.pubdate = pubdate;
    this.owner = owner ?? CuratedOwner();
    this.stat = stat ?? CuratedStat();
    this.goto = goto ?? 'av';
    this.uri = uri;
    this.rcmdReason = rcmdReason;
  }

  factory CuratedVideoItemModel.fromSearchItem(
    SearchVideoItemModel item, [
    String? keyword,
  ]) {
    return CuratedVideoItemModel(
      title: item.title,
      bvid: item.bvid,
      aid: item.aid,
      cid: item.cid,
      cover: item.cover,
      duration: item.duration,
      pubdate: item.pubdate,
      owner: CuratedOwner(mid: item.owner.mid, name: item.owner.name),
      stat: CuratedStat(
        view: item.stat.view,
        danmu: item.stat.danmu,
        like: item.stat.like,
      ),
      goto: 'av',
      uri: item.arcurl,
      fromKeyword: keyword,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'bvid': bvid,
        'aid': aid,
        'cid': cid,
        'cover': cover,
        'duration': duration,
        'pubdate': pubdate,
        'owner': (owner is CuratedOwner)
            ? (owner as CuratedOwner).toJson()
            : {'mid': owner.mid, 'name': owner.name},
        'stat': (stat is CuratedStat)
            ? (stat as CuratedStat).toJson()
            : {'view': stat.view, 'danmu': stat.danmu, 'like': stat.like},
        'goto': goto,
        'uri': uri,
        'rcmdReason': rcmdReason,
        'fromKeyword': fromKeyword,
      };

  factory CuratedVideoItemModel.fromJson(Map<String, dynamic> json) =>
      CuratedVideoItemModel(
        title: json['title'] as String? ?? '',
        bvid: json['bvid'] as String?,
        aid: json['aid'] as int?,
        cid: json['cid'] as int?,
        cover: json['cover'] as String?,
        duration: json['duration'] as int? ?? -1,
        pubdate: json['pubdate'] as int?,
        owner: json['owner'] != null
            ? CuratedOwner.fromJson(Map<String, dynamic>.from(json['owner']))
            : null,
        stat: json['stat'] != null
            ? CuratedStat.fromJson(Map<String, dynamic>.from(json['stat']))
            : null,
        goto: json['goto'] as String? ?? 'av',
        uri: json['uri'] as String?,
        rcmdReason: json['rcmdReason'] as String?,
        fromKeyword: json['fromKeyword'] as String?,
      );
}
