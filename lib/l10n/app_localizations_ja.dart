// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'concapt';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get delete => '削除';

  @override
  String get rename => '名前を変更';

  @override
  String get create => '作成';

  @override
  String get continueAction => '続ける';

  @override
  String get listSeparator => '、';

  @override
  String stageLabel(int stage) {
    return 'ステージ$stage';
  }

  @override
  String get slotLeft => '左';

  @override
  String get slotMiddle => '中央';

  @override
  String get slotRight => '右';

  @override
  String get fieldBonus => 'ボーナス';

  @override
  String get fieldTotal => '合計';

  @override
  String get statusAddsUp => '一致';

  @override
  String get statusMissing => '未入力あり';

  @override
  String statusOffBy(String diff) {
    return '$diff ずれ';
  }

  @override
  String get saveAnywayTitle => 'このまま保存しますか？';

  @override
  String saveAnywayMessage(String stages) {
    return '$stagesの合計が一致しません。';
  }

  @override
  String get saveAnywayAction => '保存する';

  @override
  String runSaved(int seq, String totals) {
    return '$seq回目を保存しました\n$totals';
  }

  @override
  String runDuplicate(int seq) {
    return '$seq回目と同じため、スキップしました';
  }

  @override
  String get noResultScreen => 'リザルト画面が見つかりません';

  @override
  String get incompleteScreen => '3ステージ分を読み取れませんでした。もう一度お試しください';

  @override
  String get readFailed => '画面を読み取れませんでした。もう一度お試しください';

  @override
  String get captureStopped => 'キャプチャが停止しました。アプリから再開してください。';

  @override
  String get checkHighlightedStage => 'ハイライトされたステージを確認してください';

  @override
  String get noSessionSelected => 'セッションが選択されていません。アプリからキャプチャを開始してください。';

  @override
  String get sessionsEmpty => 'まだセッションがありません。リハーサルするチームごとに作成してください。';

  @override
  String get newSession => '新規セッション';

  @override
  String get newSessionHint => '例: コンテスト第3週・チームA';

  @override
  String get renameSession => 'セッション名を変更';

  @override
  String deleteSessionTitle(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String deleteSessionMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count回分の記録も削除されます。',
    );
    return '$_temp0';
  }

  @override
  String runCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count回',
    );
    return '$_temp0';
  }

  @override
  String sessionSubtitle(String runs, String last) {
    return '$runs · 最終 $last';
  }

  @override
  String get allowBubbleTitle => 'バブルの表示を許可';

  @override
  String get allowBubbleMessage =>
      'ゲームの上にキャプチャ用のバブルを表示するため、「他のアプリの上に重ねて表示」の許可が必要です。';

  @override
  String get openSettings => '設定を開く';

  @override
  String get shareScreenTitle => '画面の共有';

  @override
  String get shareScreenMessage =>
      '次の画面で「画面全体」を選んでください。アプリ単位の共有を求められた場合は、ゲームを選んでください。';

  @override
  String get captureDeclined => '画面キャプチャが許可されませんでした。';

  @override
  String get overlayNotification => 'キャプチャ用バブルを表示中';

  @override
  String get exportCsv => 'CSVを書き出す';

  @override
  String get startCapturing => 'キャプチャ開始';

  @override
  String get stopCapturing => 'キャプチャ停止';

  @override
  String runsHeading(int count) {
    return '記録（$count回）';
  }

  @override
  String runTitle(int seq) {
    return '$seq回目';
  }

  @override
  String get edited => '修正済み';

  @override
  String deleteRunTitle(int seq) {
    return '$seq回目を削除しますか？';
  }

  @override
  String get deleteRunMessage => 'この回のスコアは統計から外れます。';

  @override
  String get statN => 'n';

  @override
  String get statMean => '平均';

  @override
  String get statMedian => '中央値';

  @override
  String get statMin => '最小';

  @override
  String get statMax => '最大';

  @override
  String get statP25 => 'P25';

  @override
  String get statP75 => 'P75';

  @override
  String slotColumnSemantics(String stage, String slot, String mean, String n) {
    return '$stage $slot, 平均 $mean, n $n';
  }

  @override
  String seriesTitle(int stage, String slot) {
    return 'ステージ$stage・$slot';
  }

  @override
  String get noRunsYet => 'まだ記録がありません';

  @override
  String legendMean(String value) {
    return '平均 $value';
  }

  @override
  String legendMedian(String value) {
    return '中央値 $value';
  }
}
