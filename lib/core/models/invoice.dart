class Invoice {
  final String id;
  final String userId;
  final String invoiceNumber;
  final String status;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final String currency;
  final DateTime issuedDate;
  final DateTime? dueDate;
  final DateTime? paidDate;
  final String? paymentMethod;
  final String? transactionId;
  final List<InvoiceItem> items;
  final InvoiceBillingAddress billingAddress;
  final String? notes;
  final Map<String, dynamic>? metadata;

  const Invoice({
    required this.id,
    required this.userId,
    required this.invoiceNumber,
    required this.status,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.currency,
    required this.issuedDate,
    this.dueDate,
    this.paidDate,
    this.paymentMethod,
    this.transactionId,
    required this.items,
    required this.billingAddress,
    this.notes,
    this.metadata,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'VND',
      issuedDate: DateTime.parse(
        json['issued_date'] ?? DateTime.now().toIso8601String(),
      ),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : null,
      paidDate: json['paid_date'] != null
          ? DateTime.parse(json['paid_date'])
          : null,
      paymentMethod: json['payment_method']?.toString(),
      transactionId: json['transaction_id']?.toString(),
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (item) => InvoiceItem.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      billingAddress: InvoiceBillingAddress.fromJson(
        json['billing_address'] ?? {},
      ),
      notes: json['notes']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'invoice_number': invoiceNumber,
    'status': status,
    'subtotal': subtotal,
    'tax_amount': taxAmount,
    'discount_amount': discountAmount,
    'total_amount': totalAmount,
    'currency': currency,
    'issued_date': issuedDate.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'paid_date': paidDate?.toIso8601String(),
    'payment_method': paymentMethod,
    'transaction_id': transactionId,
    'items': items.map((item) => item.toJson()).toList(),
    'billing_address': billingAddress.toJson(),
    'notes': notes,
    'metadata': metadata,
  };

  Invoice copyWith({
    String? id,
    String? userId,
    String? invoiceNumber,
    String? status,
    double? subtotal,
    double? taxAmount,
    double? discountAmount,
    double? totalAmount,
    String? currency,
    DateTime? issuedDate,
    DateTime? dueDate,
    DateTime? paidDate,
    String? paymentMethod,
    String? transactionId,
    List<InvoiceItem>? items,
    InvoiceBillingAddress? billingAddress,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return Invoice(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      issuedDate: issuedDate ?? this.issuedDate,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionId: transactionId ?? this.transactionId,
      items: items ?? this.items,
      billingAddress: billingAddress ?? this.billingAddress,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isPaid => status == 'paid';
  bool get isOverdue =>
      dueDate != null && DateTime.now().isAfter(dueDate!) && !isPaid;
  bool get isPending => status == 'pending';
}

class InvoiceItem {
  final String id;
  final String description;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? productCode;
  final Map<String, dynamic>? metadata;
  final double? unitAmountSnapshot;
  final double? taxRate;
  final Map<String, dynamic>? discounts;
  final double? exchangeRate;
  final String? planCode;
  final String? planVersion;

  const InvoiceItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.productCode,
    this.metadata,
    this.unitAmountSnapshot,
    this.taxRate,
    this.discounts,
    this.exchangeRate,
    this.planCode,
    this.planVersion,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      productCode: json['product_code']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      unitAmountSnapshot: (json['unit_amount_snapshot'] as num?)?.toDouble(),
      taxRate: (json['tax_rate'] as num?)?.toDouble(),
      discounts: json['discounts'] as Map<String, dynamic>?,
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble(),
      planCode: json['plan_code']?.toString(),
      planVersion: json['plan_version']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'quantity': quantity,
    'unit_price': unitPrice,
    'total_price': totalPrice,
    'product_code': productCode,
    'metadata': metadata,
    'unit_amount_snapshot': unitAmountSnapshot,
    'tax_rate': taxRate,
    'discounts': discounts,
    'exchange_rate': exchangeRate,
    'plan_code': planCode,
    'plan_version': planVersion,
  };

  InvoiceItem copyWith({
    String? id,
    String? description,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    String? productCode,
    Map<String, dynamic>? metadata,
    double? unitAmountSnapshot,
    double? taxRate,
    Map<String, dynamic>? discounts,
    double? exchangeRate,
    String? planCode,
    String? planVersion,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      productCode: productCode ?? this.productCode,
      metadata: metadata ?? this.metadata,
      unitAmountSnapshot: unitAmountSnapshot ?? this.unitAmountSnapshot,
      taxRate: taxRate ?? this.taxRate,
      discounts: discounts ?? this.discounts,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      planCode: planCode ?? this.planCode,
      planVersion: planVersion ?? this.planVersion,
    );
  }
}

class InvoiceBillingAddress {
  final String name;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  const InvoiceBillingAddress({
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
  });

  factory InvoiceBillingAddress.fromJson(Map<String, dynamic> json) {
    return InvoiceBillingAddress(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      postalCode: json['postal_code']?.toString() ?? '',
      country: json['country']?.toString() ?? 'Vietnam',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'city': city,
    'state': state,
    'postal_code': postalCode,
    'country': country,
  };

  InvoiceBillingAddress copyWith({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? postalCode,
    String? country,
  }) {
    return InvoiceBillingAddress(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
    );
  }
}
