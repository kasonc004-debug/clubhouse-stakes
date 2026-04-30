class PayoutPlace {
  final int place;
  final double pct;
  const PayoutPlace({required this.place, required this.pct});

  factory PayoutPlace.fromJson(Map<String, dynamic> j) => PayoutPlace(
        place: int.tryParse(j['place']?.toString() ?? '') ?? 0,
        pct:   double.tryParse(j['pct']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toJson() => {'place': place, 'pct': pct};

  PayoutPlace copyWith({int? place, double? pct}) =>
      PayoutPlace(place: place ?? this.place, pct: pct ?? this.pct);
}

class FinancialsModel {
  final String id;
  final String name;
  final double signUpFee;
  final String feePer;
  final double skinsFee;
  final double houseCutPct;
  final List<PayoutPlace> payoutPlaces;
  final String status;
  final int maxPlayers;
  final int playerCount;
  final double totalCollected;
  final int skinsCount;
  final double skinsTotal;
  final double houseCutAmount;
  final double prizePool;

  const FinancialsModel({
    required this.id,
    required this.name,
    required this.signUpFee,
    required this.feePer,
    required this.skinsFee,
    required this.houseCutPct,
    required this.payoutPlaces,
    required this.status,
    required this.maxPlayers,
    required this.playerCount,
    required this.totalCollected,
    required this.skinsCount,
    required this.skinsTotal,
    required this.houseCutAmount,
    required this.prizePool,
  });

  factory FinancialsModel.fromJson(Map<String, dynamic> j) {
    final rawPlaces = j['payout_places'];
    List<PayoutPlace> places = [];
    if (rawPlaces is List) {
      places = rawPlaces
          .whereType<Map<String, dynamic>>()
          .map(PayoutPlace.fromJson)
          .toList();
    }
    double n(dynamic v, [double fallback = 0]) =>
        double.tryParse(v?.toString() ?? '') ?? fallback;
    int ni(dynamic v, [int fallback = 0]) =>
        int.tryParse(v?.toString() ?? '') ?? fallback;

    return FinancialsModel(
      id:             j['id'].toString(),
      name:           j['name'] as String,
      signUpFee:      n(j['sign_up_fee']),
      feePer:         (j['fee_per'] ?? 'player') as String,
      skinsFee:       n(j['skins_fee']),
      houseCutPct:    n(j['house_cut_pct']),
      payoutPlaces:   places,
      status:         j['status'] as String,
      maxPlayers:     ni(j['max_players']),
      playerCount:    ni(j['player_count']),
      totalCollected: n(j['total_collected']),
      skinsCount:     ni(j['skins_count']),
      skinsTotal:     n(j['skins_total']),
      houseCutAmount: n(j['house_cut_amount']),
      prizePool:      n(j['prize_pool']),
    );
  }
}
