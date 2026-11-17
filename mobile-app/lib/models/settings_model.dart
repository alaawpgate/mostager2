class SystemSettingsModel {
  final int daysBeforeMonthEnd;
  final int daysBeforeContractEnd;
  final int sendHour;
  final int sendMinute;
  final String sendPeriod;
  final String monthlyMessage;
  final String contractEndMessage;
  final bool whats360Configured;

  SystemSettingsModel({
    required this.daysBeforeMonthEnd,
    required this.daysBeforeContractEnd,
    required this.sendHour,
    required this.sendMinute,
    required this.sendPeriod,
    required this.monthlyMessage,
    required this.contractEndMessage,
    required this.whats360Configured,
  });

  factory SystemSettingsModel.fromJson(Map<String, dynamic> json) {
    return SystemSettingsModel(
      daysBeforeMonthEnd: int.tryParse(json['days_before_month_end']?.toString() ?? '') ?? 5,
      daysBeforeContractEnd: int.tryParse(json['days_before_contract_end']?.toString() ?? '') ?? 30,
      sendHour: int.tryParse(json['send_hour']?.toString() ?? '') ?? 10,
      sendMinute: int.tryParse(json['send_minute']?.toString() ?? '') ?? 0,
      sendPeriod: json['send_period']?.toString() ?? 'AM',
      monthlyMessage: json['monthly_message']?.toString() ?? '',
      contractEndMessage: json['contract_end_message']?.toString() ?? '',
      whats360Configured: json['whats360_configured'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'days_before_month_end': daysBeforeMonthEnd,
      'days_before_contract_end': daysBeforeContractEnd,
      'send_hour': sendHour,
      'send_minute': sendMinute,
      'send_period': sendPeriod,
      'monthly_message': monthlyMessage,
      'contract_end_message': contractEndMessage,
    };
  }
}
