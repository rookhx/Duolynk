class PaywallPlan {
  const PaywallPlan({
    required this.id,
    required this.productId,
    required this.title,
    required this.description,
    required this.priceLabel,
    required this.billingLabel,
    this.badge,
    this.savingsLabel,
    this.isAnnual = false,
  });

  final String id;
  final String productId;
  final String title;
  final String description;
  final String priceLabel;
  final String billingLabel;
  final String? badge;
  final String? savingsLabel;
  final bool isAnnual;
}
