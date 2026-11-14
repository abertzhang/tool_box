// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '主题演示';

  @override
  String get profile => '我的';

  @override
  String get tools => '工具';

  @override
  String get login => '登录';

  @override
  String get registerTitle => '注册账号';

  @override
  String get nicknameHint => '昵称（选填）';

  @override
  String get emailHint => '邮箱地址';

  @override
  String get passwordHint => '登录密码';

  @override
  String get confirmPasswordHint => '确认密码';

  @override
  String get registerSubmit => '立即注册';

  @override
  String get googleSignUp => '使用 Google 账号注册';

  @override
  String get appleSignUp => '使用 Apple 账号注册';

  @override
  String get appleSignIn => '使用 Apple 账号登录';

  @override
  String get googleSignIn => '使用 Google 账号登录';

  @override
  String get emailSignIn => '使用邮箱登录';

  @override
  String get haveAccountLogin => '已有账号？去登录';

  @override
  String get errEmailInvalid => '请输入有效的邮箱地址';

  @override
  String get errPasswordShort => '密码至少 6 位';

  @override
  String get errNetworkReset => '网络连接被服务器重置。请切换 Wi-Fi/蜂窝网络、或关闭代理/加速器后重试';

  @override
  String get errPasswordMismatch => '两次输入的密码不一致';

  @override
  String get registerSuccess => '注册成功';

  @override
  String get loginSubtitle => '你的随身工具箱 · 登录解锁全部功能';

  @override
  String get loginSubmit => '立即登录';

  @override
  String get loginSuccess => '登录成功';

  @override
  String get forgotPassword => '忘记密码';

  @override
  String get forgotPasswordDesc => '输入你的邮箱，我们将发送密码重置链接。';

  @override
  String get sendResetLink => '发送重置链接';

  @override
  String get resetPasswordSent => '密码重置链接已发送';

  @override
  String get emailNotRegistered => '该邮箱尚未注册';

  @override
  String get emailCheckFailed => '邮箱校验失败，请稍后重试';

  @override
  String get resetPasswordTitle => '设置新密码';

  @override
  String get resetPasswordDesc => '为你的账号设置一个新密码。';

  @override
  String get newPasswordHint => '新密码';

  @override
  String get resetPasswordSubmit => '更新密码';

  @override
  String get resetPasswordSuccess => '密码已更新，请重新登录。';

  @override
  String get resetLinkInvalid => '该重置链接无效或已过期，请重新申请。';

  @override
  String get registerVerifyEmail => '注册成功，请前往邮箱完成验证';

  @override
  String get verifyEmailTitle => '验证邮箱';

  @override
  String get verifyEmailDesc => '我们已向你的邮箱发送 6 位验证码，请在下方输入以激活账号。';

  @override
  String get verifyCodeHint => '6 位验证码';

  @override
  String get verifyEmailSubmit => '验证';

  @override
  String get verifyEmailResend => '重新发送验证码';

  @override
  String get verifyEmailResent => '验证码已重新发送';

  @override
  String get verifyEmailResendFailed => '验证码发送失败，请稍后重试';

  @override
  String get verifyEmailSuccess => '邮箱验证成功';

  @override
  String get verifyEmailContinue => '继续';

  @override
  String get errCodeInvalid => '验证码无效或已过期';

  @override
  String get errSupabaseNotReady =>
      'Supabase 尚未初始化，请通过 --dart-define 提供 SUPABASE_URL 与 SUPABASE_ANON_KEY';

  @override
  String get compassTitle => '指南针';

  @override
  String get compassSensorUnavailable => '当前设备不支持指南针功能。';

  @override
  String get compassLock => '锁定方位';

  @override
  String get compassUnlock => '解锁方位';

  @override
  String get compassDirN => '北';

  @override
  String get compassDirNE => '东北';

  @override
  String get compassDirE => '东';

  @override
  String get compassDirSE => '东南';

  @override
  String get compassDirS => '南';

  @override
  String get compassDirSW => '西南';

  @override
  String get compassDirW => '西';

  @override
  String get compassDirNW => '西北';

  @override
  String get compassHeading => '方位角';

  @override
  String get compassAltitude => '海拔';

  @override
  String get compassLatitude => '纬度';

  @override
  String get compassLongitude => '经度';

  @override
  String get compassRecordLocation => '记录当前位置';

  @override
  String get compassExport => '导出';

  @override
  String get compassHistory => '历史记录';

  @override
  String get compassViewAll => '查看全部';

  @override
  String get compassCollapse => '收起';

  @override
  String get compassNoRecords => '暂无记录，点击「记录当前位置」保存点位';

  @override
  String get compassRecordDialogTitle => '记录当前位置';

  @override
  String get compassRecordNameHint => '名称（如：营地 A）';

  @override
  String get compassSave => '保存';

  @override
  String get compassCancel => '取消';

  @override
  String get compassRecordSaved => '已保存记录';

  @override
  String get compassSaveFailed => '保存失败，请重试';

  @override
  String get compassLocationDenied => '定位权限未开启，无法获取经纬度';

  @override
  String get compassLocationServiceOff => '系统定位服务未开启，请在设置中开启';

  @override
  String get compassOpenSettings => '打开设置';

  @override
  String get compassExported => '已复制全部记录到剪贴板';

  @override
  String get compassDelete => '删除';

  @override
  String get compassDeleteConfirm => '确定删除该记录？';

  @override
  String get compassLatLng => '经纬度';

  @override
  String get compassDirection => '方向';

  @override
  String get noiseTitle => '噪音检测器';

  @override
  String get noiseCurrent => '当前噪音';

  @override
  String get noiseAverage => '平均噪音';

  @override
  String get noiseMin => '最低噪音';

  @override
  String get noiseMax => '最高噪音';

  @override
  String get noiseRecord => '记录当前噪音';

  @override
  String get noiseExport => '导出';

  @override
  String get noiseHistory => '历史记录';

  @override
  String get noiseViewAll => '查看全部';

  @override
  String get noiseCollapse => '收起';

  @override
  String get noiseNoRecords => '暂无噪音记录';

  @override
  String get noiseNoReading => '暂无读数，请稍候';

  @override
  String get noiseZoneQuiet => '安静';

  @override
  String get noiseZoneModerate => '适中';

  @override
  String get noiseZoneLoud => '嘈杂';

  @override
  String get noiseZoneQuietEnv => '安静环境';

  @override
  String get noiseZoneModerateEnv => '适中环境';

  @override
  String get noiseZoneLoudEnv => '嘈杂环境';

  @override
  String get noiseCatQuiet => '安静';

  @override
  String get noiseCatModerate => '正常';

  @override
  String get noiseCatLoud => '嘈杂';

  @override
  String get noiseEnvType => '环境类型';

  @override
  String get noiseLevel => '噪音值';

  @override
  String get noiseDbUnit => 'dB';

  @override
  String get noiseRecordTitle => '记录当前噪音';

  @override
  String get noiseName => '名称';

  @override
  String get noiseNameHint => '请输入名称（如「营地周边环境」）';

  @override
  String get noiseEnvHint => '环境类型（可选，如「户外林地」）';

  @override
  String get noiseSave => '保存';

  @override
  String get noiseCancel => '取消';

  @override
  String get noiseSaved => '已记录到本地';

  @override
  String get noiseExported => '已导出到剪贴板';

  @override
  String get noiseDelete => '删除';

  @override
  String get noiseDeleteConfirm => '确定删除这条记录吗？';

  @override
  String get noiseMicDenied => '麦克风权限被拒绝，无法测量噪音';

  @override
  String get noiseMicNeedPermission => '需要麦克风权限才能测量噪音';

  @override
  String get noiseMicRetry => '重试并授权';

  @override
  String get noiseMicGrant => '授权并开始测量';

  @override
  String get noiseMicOpenSettings => '去系统设置开启';

  @override
  String get commonOpenSettings => '打开设置';

  @override
  String get noiseToday => '今天';

  @override
  String get noiseYesterday => '昨天';

  @override
  String get levelTitle => '水平仪';

  @override
  String get levelBullseye => '圆型牛眼水平仪';

  @override
  String get levelTubular => '管式水平仪';

  @override
  String get levelCalibrated => '已校准';

  @override
  String get levelUncalibrated => '未校准';

  @override
  String get levelStatusLabel => '当前状态';

  @override
  String get levelStatusLevel => '水平';

  @override
  String get levelStatusNear => '接近水平';

  @override
  String get levelStatusTilt => '倾斜';

  @override
  String get levelVertical => '垂直角度 (Y-Axis)';

  @override
  String get levelHorizontal => '水平角度 (X-Axis)';

  @override
  String get levelLock => '锁定读数';

  @override
  String get levelUnlock => '解锁';

  @override
  String get levelCalibrate => '校准水平仪';

  @override
  String get levelCalibratedToast => '已校准至当前角度';

  @override
  String get levelHistory => '测量记录';

  @override
  String get levelSave => '保存测量';

  @override
  String get levelViewAll => '查看全部';

  @override
  String get levelCollapse => '收起';

  @override
  String get levelNoRecords => '暂无测量记录';

  @override
  String get levelRecordTitle => '保存测量';

  @override
  String get levelName => '名称';

  @override
  String get levelNameHint => '记录名称（可选）';

  @override
  String get levelCancel => '取消';

  @override
  String get levelSaveAction => '保存';

  @override
  String get levelSavedToast => '已保存测量记录';

  @override
  String get levelDelete => '删除';

  @override
  String get levelDeleteConfirm => '确定删除这条测量记录吗？';

  @override
  String get levelDefaultName => '水平仪测量';

  @override
  String get appShareSubject => 'Tool Box —— 户外工具箱';

  @override
  String get appShareBody => '水平仪、直尺、指南针、噪音检测、手电筒……一个 App 全搞定，户外作业与家装测量随身带。';

  @override
  String get appShareFailed => '无法打开分享面板';

  @override
  String get levelDescLevel => '已精准校平';

  @override
  String get levelDescNear => '接近水平';

  @override
  String get levelDescTilt => '存在偏斜';

  @override
  String get rulerTitle => '直尺';

  @override
  String get rulerUnitCm => '厘米';

  @override
  String get rulerUnitInch => '英寸';

  @override
  String get rulerLengthLabel => '长度';

  @override
  String get rulerCm => '厘米';

  @override
  String get rulerInch => '英寸';

  @override
  String get rulerTime => '时间';

  @override
  String get rulerName => '名称';

  @override
  String get rulerNameHint => '给这次测量起个名字（可选）';

  @override
  String get rulerRecordTitle => '保存测量';

  @override
  String get rulerCancel => '取消';

  @override
  String get rulerSaveAction => '保存';

  @override
  String get rulerSavedToast => '已保存测量记录';

  @override
  String get rulerExport => '导出';

  @override
  String get rulerExported => '已导出到剪贴板';

  @override
  String get rulerHistory => '测量记录';

  @override
  String get rulerNoRecords => '暂无测量记录';

  @override
  String get rulerViewAll => '查看全部';

  @override
  String get rulerCollapse => '收起';

  @override
  String get rulerDelete => '删除';

  @override
  String get rulerDeleteConfirm => '确定删除这条测量记录吗？';

  @override
  String get rulerDefaultName => '直尺测量';

  @override
  String get flashlightOn => '已开启';

  @override
  String get flashlightPermissionDenied => '使用手电筒需要相机权限，请在系统设置中开启';

  @override
  String get flashlightUnavailable => '当前设备不支持手电筒';

  @override
  String get tideTitle => '潮汐';

  @override
  String get tideRecordCurrent => '记录当前';

  @override
  String get tideExported => '已导出到剪贴板';

  @override
  String get tideScheduleTitle => '今日潮汐时刻表';

  @override
  String get tideCurrentHeight => '当前潮高';

  @override
  String tideTimeToHigh(Object time) {
    return '距满潮还有 $time';
  }

  @override
  String get tideNextLow => '下一轮低潮';

  @override
  String get tideNextHigh => '下一轮满潮';

  @override
  String get tideHistory => '历史记录';

  @override
  String get tideViewAll => '查看全部';

  @override
  String get tideCollapse => '收起';

  @override
  String get tideLowTide => '低潮';

  @override
  String get tideHighTide => '满潮';

  @override
  String get tideRising => '涨潮中';

  @override
  String get tideNoRecords => '暂无潮汐记录';

  @override
  String get tideSavedToast => '已记录当前潮汐';

  @override
  String get toolWorldClock => '世界时钟';

  @override
  String get toolWorldClockDesc => '世界各地时间一览';

  @override
  String get worldClockTitle => '世界时钟';

  @override
  String get worldClockLocalLabel => '本机时间';

  @override
  String get worldClockLocLabel => '当前定位';

  @override
  String get worldClockLocating => '定位中…';

  @override
  String get worldClockLocFailed => '定位不可用，已显示本机时间';

  @override
  String get worldClockCityBeijing => '北京';

  @override
  String get worldClockCityTokyo => '东京';

  @override
  String get worldClockCitySingapore => '新加坡';

  @override
  String get worldClockCitySydney => '悉尼';

  @override
  String get worldClockCityDubai => '迪拜';

  @override
  String get worldClockCityLondon => '伦敦';

  @override
  String get worldClockCityParis => '巴黎';

  @override
  String get worldClockCityNewYork => '纽约';

  @override
  String get worldClockCityLosAngeles => '洛杉矶';

  @override
  String get worldClockRegion => '国家 / 地区';

  @override
  String get worldClockSelectRegion => '请选择国家 / 地区';

  @override
  String get worldClockSelectCity => '请选择城市';

  @override
  String get worldClockCountryCn => '中国';

  @override
  String get worldClockCountryJp => '日本';

  @override
  String get worldClockCountrySg => '新加坡';

  @override
  String get worldClockCountryAu => '澳大利亚';

  @override
  String get worldClockCountryAe => '阿联酋';

  @override
  String get worldClockCountryGb => '英国';

  @override
  String get worldClockCountryFr => '法国';

  @override
  String get worldClockCountryUs => '美国';

  @override
  String get ucTitle => '单位换算';

  @override
  String get ucFormula => '换算公式：';

  @override
  String get ucCommon => '常用换算';

  @override
  String get forceTitle => '拉力承重换算器';

  @override
  String get memoTitle => '出行备忘录';

  @override
  String get memoAdd => '新建备忘';

  @override
  String get memoEmpty => '还没有备忘，点击右下角 + 新建';

  @override
  String get memoTitleHint => '标题';

  @override
  String get memoFieldTitle => '标题';

  @override
  String get memoTravelTime => '出行时间';

  @override
  String get memoTravelTimeHint => '选择时间';

  @override
  String get memoKeyHint => '键';

  @override
  String get memoValueHint => '值';

  @override
  String get memoAddRow => '增加一行';

  @override
  String get memoSave => '保存';

  @override
  String get memoUntitled => '无标题';

  @override
  String get memoNoContent => '无内容';

  @override
  String get memoDelete => '删除';

  @override
  String get memoDeleteConfirm => '确定删除这条备忘吗？';

  @override
  String get memoCancel => '取消';

  @override
  String get memoEdit => '编辑';

  @override
  String get memoTemplateTitle => '模板列表';

  @override
  String get memoUseTemplate => '使用';

  @override
  String get memoTemplateApplied => '已套用模板';

  @override
  String get memoTemplateHint => '选一个模板，快速新建一条备忘';

  @override
  String get memoNewTemplate => '新建模板';

  @override
  String get memoTemplateEmpty => '还没有模板，点 + 新建';

  @override
  String get memoTemplateDeleteConfirm => '确定删除这个模板吗？';

  @override
  String get memoDaysLeftPrefix => '还剩';

  @override
  String get memoDaysLeftSuffix => '天出发';

  @override
  String get memoTodayDepart => '今天出发';

  @override
  String get memoDeparted => '已出发';

  @override
  String get memoShare => '分享';

  @override
  String get memoCopy => '复制';

  @override
  String get memoCopied => '已复制';

  @override
  String get memoSaveAsTemplate => '存为模板';

  @override
  String get memoTemplateCreated => '已生成模板';

  @override
  String get memoExpand => '展开';

  @override
  String get memoCollapse => '收起';

  @override
  String get memoDeleted => '已删除';

  @override
  String get memoUndo => '撤销';

  @override
  String get statToolsUsed => '使用次数';

  @override
  String get statAppToolUsage => 'App使用总量';

  @override
  String get statFreeRemaining => '免费剩余';

  @override
  String get vipTitle => 'Pro 解锁';

  @override
  String get vipDesc => '一次性买断，无广告。';

  @override
  String get vipOpen => '立即开通';

  @override
  String freeRemainingCount(num count) {
    return '免费 $count 次';
  }

  @override
  String get freeLimitTitle => '免费试用已用完';

  @override
  String get freeLimitBody => '已超过最大免费使用次数（10 次），升级 Pro 解锁全部工具。';

  @override
  String get freeLimitUpgrade => '升级 Pro';

  @override
  String get vipSheetProductName => 'Pro 解锁';

  @override
  String get vipSheetProductDesc => '终身会员';

  @override
  String get vipSheetOneTime => '一次性购买';

  @override
  String get vipSheetConfirm => '使用侧边按钮确认';

  @override
  String get vipDeveloping => '会员开通功能开发中';

  @override
  String get vipPayConfirmTitle => '确认购买';

  @override
  String vipPayConfirmBody(Object price) {
    return '支付 $price 开通终身会员。买断制一次付费，可通过 Apple ID 或 Google 账号恢复。';
  }

  @override
  String get vipPayStoreUnavailable => '应用商店不可用，请稍后再试';

  @override
  String get vipPayProductMissing => '会员商品暂未上架';

  @override
  String get vipPayDebugProductMissing =>
      '调试包无法查询 Play 商品：请通过 Play 内部应用共享或内部测试轨道安装后再购买';

  @override
  String get vipPaySheetOpened => '已拉起支付，支付完成后会员自动生效';

  @override
  String get vipRestore => '恢复购买';

  @override
  String get vipRestoreDone => '恢复完成，此前购买过的会员已自动生效';

  @override
  String get vipRestoreEmpty => '未找到可恢复的购买记录';

  @override
  String get vipRestoreCheckAccount =>
      '未找到可恢复的购买记录。恢复购买只查询当前设备登录的这个 Google Play 账号，请确认使用的是购买时的同一个账号';

  @override
  String get vipRestoreAlready => '你已是 Pro 会员，无需恢复';

  @override
  String get vipBecomeMember => '会员已生效';

  @override
  String get syncMemberTitle => '将会员同步到账号';

  @override
  String get syncMemberBody => '登录后可在所有设备保留会员，重装 App 也能一键恢复。';

  @override
  String get syncMemberApple => '通过 Apple 继续';

  @override
  String get syncMemberGoogle => '通过 Google 继续';

  @override
  String get syncMemberLater => '暂不';

  @override
  String get syncMemberDone => '会员已同步到账号';

  @override
  String get syncMemberFailed => '同步失败，请稍后再试';

  @override
  String get syncMemberAction => '同步会员到账号';

  @override
  String get vipPurchaseAppBarTitle => 'Tool Box Pro 解锁';

  @override
  String get vipPurchaseSubtitle =>
      '一次性解锁全部工具：指南针、水平仪、噪音检测、手电筒和出行备忘录。买断制，无广告，无订阅。';

  @override
  String get statOffline => '离线下载';

  @override
  String get statCert => '我的证书';

  @override
  String get statRecord => '学习记录';

  @override
  String get countFiles => '5 个文件';

  @override
  String get countCert => '3 张';

  @override
  String get countDays => '12 天';

  @override
  String get countFav => '128 个';

  @override
  String get settings => '设置';

  @override
  String get themeColorSetting => '主题';

  @override
  String get themeCoffee => '咖啡色';

  @override
  String get themeBlue => '天空';

  @override
  String get langSetting => '语言设置';

  @override
  String get saveNamePromptSetting => '保存弹框';

  @override
  String get clearCache => '清除缓存';

  @override
  String get calculating => '计算中…';

  @override
  String get notifSetting => '通知设置';

  @override
  String get notifDeveloping => '通知设置功能开发中';

  @override
  String get accountSecurity => '账号安全';

  @override
  String get accountDeveloping => '账号与安全功能开发中';

  @override
  String get aboutGroup => '关于';

  @override
  String get checkUpdate => '检查更新';

  @override
  String get rateUs => '给我们评分';

  @override
  String get rateUsUnavailable => '暂时无法打开评分页面，请稍后再试';

  @override
  String get aboutUs => '关于我们';

  @override
  String get userAgreement => '用户协议';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String privacyLastUpdated(String date) {
    return '最后更新时间：$date';
  }

  @override
  String get privacyIntro =>
      '本隐私政策用于说明我们如何收集、使用、存储和保护你在使用本应用过程中产生的信息。请你在使用前仔细阅读。';

  @override
  String get privacySecCollect => '一、我们收集的信息';

  @override
  String get privacySecCollectBody =>
      '注册账号时，我们会收集你的邮箱地址，以及你自行填写的昵称与头像。使用指南针、噪音检测等工具功能时，应用会在你明确授权后访问相应的设备传感器。我们不会收集与你使用本应用无关的个人信息。';

  @override
  String get privacySecUse => '二、信息的使用';

  @override
  String get privacySecUseBody =>
      '收集的信息仅用于以下目的：创建与维护你的账号、在多设备间同步个人资料与会员权益、改进产品体验，以及在必要时与你取得联系。我们不会将你的信息用于与本应用无关的其他用途。';

  @override
  String get privacySecStore => '三、数据的存储与安全';

  @override
  String get privacySecStoreBody =>
      '账号数据存储在 Supabase 云端数据库中，通过传输加密与访问权限控制加以保护。应用产生的本地缓存（如图片缓存）仅保存在你的设备上，你可以在「设置 - 清除缓存」中随时清理。';

  @override
  String get privacySecShare => '四、信息的共享';

  @override
  String get privacySecShareBody =>
      '我们不会出售或出租你的个人信息。仅在下列情形中共享必要数据：为完成会员购买而必需的支付平台（Apple App Store / Google Play）；法律法规要求，或为保护我们合法权益所必需的情形。';

  @override
  String get privacySecAds => '五、广告';

  @override
  String get privacySecAdsBody =>
      '免费版会在 App 内的部分页面展示由 Google AdMob 提供的横幅广告。AdMob 可能使用设备标识符与广告互动数据来选择和衡量广告，详见 Google 隐私政策。购买 Pro Unlock 后不再加载任何广告。本应用不会申请「应用跟踪透明度」授权，也不会将你的工具使用数据发送给广告网络。';

  @override
  String get privacySecRights => '六、你的权利';

  @override
  String get privacySecRightsBody =>
      '你可以随时：在「编辑资料」中修改昵称与头像；在「设置 - 清除缓存」中删除本地数据；通过注销账号删除云端个人资料。如需导出或删除你的数据，可按下方联系方式与我们联系。';

  @override
  String get privacySecUpdate => '七、政策的更新';

  @override
  String get privacySecUpdateBody =>
      '我们可能不时更新本政策。更新后的版本会发布在本页面，发生重大变更时我们会在应用内另行提示。建议你定期查阅本页面，以了解最新的政策内容。';

  @override
  String get privacySecContact => '八、联系我们';

  @override
  String get privacySecContactBody =>
      '如果你对本隐私政策有任何疑问或建议，请通过 support@aknot.uk 与我们联系，我们会在合理期限内回复。';

  @override
  String get agreementIntro =>
      '本用户协议用于说明你使用本应用的各项条款，以及你与我们之间的权利和义务。请你在使用前仔细阅读。你一旦开始使用本应用，即视为同意并接受本协议的全部内容。';

  @override
  String get agreementSecAccept => '一、协议的接受';

  @override
  String get agreementSecAcceptBody =>
      '本协议是你与我们之间具有约束力的合同。如你不同意其中任何条款，请停止使用本应用。若你为未成年人，请在监护人的陪同下阅读本协议。';

  @override
  String get agreementSecService => '二、服务内容';

  @override
  String get agreementSecServiceBody =>
      '本应用提供便签、指南针、噪音检测、水平仪、尺子、手电筒、潮汐等一系列实用工具功能。随着产品迭代，具体功能可能有所调整，我们会尽力保持使用体验的稳定。';

  @override
  String get agreementSecAccount => '三、账号规则';

  @override
  String get agreementSecAccountBody =>
      '部分功能需要登录后使用。你可以通过 Apple 或 Google 账号登录，也可以以游客身份继续使用。你应妥善保管账号凭据，并对该账号下的行为负责。账号数据存储在 Supabase 云端数据库中，具体处理方式详见我们的隐私政策。';

  @override
  String get agreementSecFree => '四、免费额度与广告';

  @override
  String get agreementSecFreeBody =>
      '免费版提供有限次数的工具使用，并在应用内的部分页面展示由 Google AdMob 提供的横幅广告。你可以通过观看应用内广告获得额外免费次数，额度以免费上限为限。使用次数记录在服务端并与设备标识关联，重新安装应用不会将其清零。';

  @override
  String get agreementSecPurchase => '五、购买与退款';

  @override
  String get agreementSecPurchaseBody =>
      'Pro Unlock 为一次性买断商品，购买后不再展示广告，并解除免费次数限制。所有支付由 Apple App Store 或 Google Play 处理，退款适用相应平台的规则，我们无法直接办理退款。购买权益与你的账号绑定，在其他设备登录同一账号即可恢复。';

  @override
  String get agreementSecConduct => '六、使用规范';

  @override
  String get agreementSecConductBody =>
      '你承诺不将本应用用于任何违法用途，不干扰其正常运行，不对本应用进行反向工程、反编译或尝试获取其源代码，也不以自动化方式批量访问本服务。';

  @override
  String get agreementSecIp => '七、知识产权';

  @override
  String get agreementSecIpBody =>
      '本应用及其代码、设计、图标、文字等内容的知识产权归我们所有，并受相关法律保护。你仅可为个人目的使用本应用；未经我们书面许可，不得复制、修改、传播或将其中任何部分用于商业用途。';

  @override
  String get agreementSecDisclaimer => '八、免责声明';

  @override
  String get agreementSecDisclaimerBody =>
      '指南针、噪音检测、水平仪等工具的读数来自你的设备传感器，仅供参考，不能替代专业测量仪器，不得用于对精度要求关乎人身或财产安全的场景，例如建筑施工、医疗诊断、法律举证等。因依赖上述读数而产生的损失，我们不承担责任。';

  @override
  String get agreementSecUpdate => '九、协议的更新';

  @override
  String get agreementSecUpdateBody =>
      '我们可能不时更新本协议。最新版本始终展示在本页面，发生重大变更时我们会在应用内另行提示。协议更新后你继续使用本应用，即视为接受更新后的协议。';

  @override
  String get agreementSecContact => '十、联系我们';

  @override
  String get agreementSecContactBody =>
      '如果你对本用户协议有任何疑问或建议，请通过 support@aknot.uk 与我们联系，我们会在合理期限内回复。';

  @override
  String get cacheCleared => '缓存已清理';

  @override
  String get langChinese => '简体中文';

  @override
  String get langEnglish => 'English';

  @override
  String get langJapanese => '日语';

  @override
  String get langGerman => '德语';

  @override
  String get langFrench => '法语';

  @override
  String get toggleLightDark => '切换亮色 / 暗色';

  @override
  String get sectionGeneral => '通用工具';

  @override
  String get toolForce => '拉力承重换算器';

  @override
  String get toolForceDesc => '承重力精准换算';

  @override
  String get toolUnitConverter => '单位换算';

  @override
  String get toolUnitConverterDesc => '长度 / 重量 / 力';

  @override
  String get toolTravelMemo => '出行备忘录';

  @override
  String get toolTravelMemoDesc => '为每一次美好出行做好准备';

  @override
  String get toolCompass => '指南针';

  @override
  String get toolCompassDesc => '方向随时掌握';

  @override
  String get toolNoise => '噪音检测器';

  @override
  String get toolNoiseDesc => '环境声音分贝';

  @override
  String get toolLevel => '水平仪';

  @override
  String get toolLevelDesc => '精准水平检测';

  @override
  String get toolRuler => '直尺';

  @override
  String get toolRulerDesc => '屏幕即量尺';

  @override
  String get toolFlashlight => '手电筒';

  @override
  String get toolFlashlightDesc => '照亮前程';

  @override
  String get toolTide => '潮汐';

  @override
  String get toolTideDesc => '潮起潮落随时查';

  @override
  String get ucCatArea => '面积';

  @override
  String get ucCatVolume => '体积';

  @override
  String get ucCatTemp => '温度';

  @override
  String get ucCatSpeed => '速度';

  @override
  String get ucCatWeight => '重量';

  @override
  String get ucCatLength => '长度';

  @override
  String get unitSquareMeter => '平方米 (m²)';

  @override
  String get unitSquareKilometer => '平方千米 (km²)';

  @override
  String get unitHectare => '公顷 (ha)';

  @override
  String get unitMu => '亩';

  @override
  String get unitSquareFoot => '平方英尺 (ft²)';

  @override
  String get unitSquareMile => '平方英里 (mi²)';

  @override
  String get unitSquareYard => '平方码 (yd²)';

  @override
  String get unitAcre => '英亩 (ac)';

  @override
  String get unitSquareInch => '平方英寸 (in²)';

  @override
  String get unitMeterPerSec => '米/秒 (m/s)';

  @override
  String get unitKmPerHour => '千米/时 (km/h)';

  @override
  String get unitMilePerHour => '英里/时 (mph)';

  @override
  String get unitFootPerSec => '英尺/秒 (ft/s)';

  @override
  String get unitKnot => '节 (kn)';

  @override
  String get unitKilogram => '千克 (kg)';

  @override
  String get unitGram => '克 (g)';

  @override
  String get unitMilligram => '毫克 (mg)';

  @override
  String get unitTon => '吨 (t)';

  @override
  String get unitPound => '磅 (lb)';

  @override
  String get unitOunce => '盎司 (oz)';

  @override
  String get unitJin => '斤';

  @override
  String get unitLiang => '两';

  @override
  String get unitLiter => '升 (L)';

  @override
  String get unitMilliliter => '毫升 (mL)';

  @override
  String get unitCubicMeter => '立方米 (m³)';

  @override
  String get unitCubicCentimeter => '立方厘米 (cm³)';

  @override
  String get unitGallon => '加仑(美) (gal)';

  @override
  String get unitQuart => '夸脱(美) (qt)';

  @override
  String get unitPint => '品脱(美) (pt)';

  @override
  String get unitCup => '杯(美) (cup)';

  @override
  String get unitCubicFoot => '立方英尺 (ft³)';

  @override
  String get unitCubicInch => '立方英寸 (in³)';

  @override
  String get unitMeter => '米 (m)';

  @override
  String get unitKilometer => '千米 (km)';

  @override
  String get unitCentimeter => '厘米 (cm)';

  @override
  String get unitMillimeter => '毫米 (mm)';

  @override
  String get unitMile => '英里 (mi)';

  @override
  String get unitFoot => '英尺 (ft)';

  @override
  String get unitInch => '英寸 (in)';

  @override
  String get unitYard => '码 (yd)';

  @override
  String get unitNauticalMile => '海里 (nmi)';

  @override
  String get unitCelsius => '摄氏度 (°C)';

  @override
  String get unitFahrenheit => '华氏度 (°F)';

  @override
  String get unitKelvin => '开尔文 (K)';

  @override
  String get unitNewton => '牛顿 (N)';

  @override
  String get unitKilonewton => '千牛 (kN)';

  @override
  String get unitKilogramForce => '千克力 (kgf)';

  @override
  String get unitPoundForce => '磅力 (lbf)';

  @override
  String get unitTonForce => '吨力 (tf)';

  @override
  String get tideHigh => '满潮';

  @override
  String get tideEbbing => '退潮中';

  @override
  String tideDateFormat(Object month, Object day, Object hour, Object min) {
    return '$month月$day日 $hour:$min';
  }

  @override
  String get darkModeLabel => '深色模式';

  @override
  String devToast(Object title) {
    return '$title（开发中）';
  }

  @override
  String get profileNotLogin => '未登录';

  @override
  String get profileTapLogin => '点击登录 / 注册';

  @override
  String get profileGuest => '用户';

  @override
  String get profileNoEmail => '未绑定邮箱';

  @override
  String get profileMemberVip => 'VIP';

  @override
  String get profileMemberFree => '免费用户';

  @override
  String get profileLoadFailed => '资料加载失败';

  @override
  String get profileRetry => '重试';

  @override
  String get profileSignOut => '退出登录';

  @override
  String get profileSignOutConfirm => '确定退出当前账号？';

  @override
  String get deleteAccount => '注销账号';

  @override
  String get deleteAccountConfirm => '确定要注销账号吗？此操作不可恢复。';

  @override
  String get deleteAccountWarning => '注销后，你的所有本地与云端数据将被永久删除，且无法恢复。';

  @override
  String get deleteAccountDone => '账号已注销';

  @override
  String get deleteAccountFailed => '注销失败，请稍后重试';

  @override
  String get profileEditTitle => '编辑资料';

  @override
  String get profileEditName => '昵称';

  @override
  String get profileEditNameHint => '请输入昵称';

  @override
  String get profileEditNameEmpty => '昵称不能为空';

  @override
  String get profileEditAvatarTitle => '选择头像';

  @override
  String get profileEditCurrent => '当前头像';

  @override
  String get profileEditShuffle => '换一批';

  @override
  String get profileEditSave => '保存';

  @override
  String get profileEditSaved => '资料已更新';

  @override
  String get profileEditFailed => '保存失败';

  @override
  String get profileEditNeedLogin => '请先登录后再编辑资料';

  @override
  String get dialogCancel => '取消';

  @override
  String get dialogConfirm => '确定';

  @override
  String get vipActiveTitle => 'Pro 解锁 · 生效中';

  @override
  String get vipLifetime => '永久会员，不限期';

  @override
  String vipExpireAt(Object date) {
    return '有效期至 $date';
  }

  @override
  String splashSkip(Object seconds) {
    return '跳过 ${seconds}s';
  }

  @override
  String get thirdPartySdk => '第三方 SDK 清单';

  @override
  String adWatchForFreeUses(num count) {
    return '观看一次获得 $count 次免费使用';
  }

  @override
  String adRewardProgress(num remaining, num max) {
    return '免费剩余 $remaining/$max 次';
  }

  @override
  String get adUnavailable => '广告暂不可用，请稍后再试';

  @override
  String adRewardSuccess(num count) {
    return '已获得 $count 次免费使用';
  }

  @override
  String get adNotFinished => '广告未看完，本次未获得奖励';

  @override
  String get adLabel => '广告';

  @override
  String get adPrivacySettings => '广告隐私设置';

  @override
  String get webUnsupported => '当前平台不支持内置浏览器';

  @override
  String get webLoadFailed => '页面加载失败';
}
