// Data models for POS Resto
// Mapped from Go backend internal/db/models.go

// ==================== USER ====================

class User {
  final String id;
  final String username;
  final String passwordHash;
  final String fullName;
  final String role;
  final int isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.fullName,
    required this.role,
    this.isActive = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'password_hash': passwordHash,
        'full_name': fullName,
        'role': role,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory User.fromMap(Map<String, dynamic> map) => User(
        id: map['id'] as String,
        username: map['username'] as String,
        passwordHash: map['password_hash'] as String,
        fullName: map['full_name'] as String,
        role: map['role'] as String,
        isActive: map['is_active'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ==================== CATEGORY ====================

class Category {
  final String id;
  final String name;
  final String? description;
  final String? printerId;
  final String printDestination; // 'kitchen' | 'bar' — tujuan cetak tiket
  final int isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    required this.id,
    required this.name,
    this.description,
    this.printerId,
    this.printDestination = 'kitchen',
    this.isDeleted = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'printer_id': printerId,
        'print_destination': printDestination,
        'is_deleted': isDeleted,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        printerId: map['printer_id'] as String?,
        printDestination:
            (map['print_destination'] as String?) == 'bar' ? 'bar' : 'kitchen',
        isDeleted: map['is_deleted'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ==================== PRODUCT ====================

class Product {
  final String id;
  final String name;
  final String? code;
  final String? description;
  final double price;
  final int stock;
  final String? categoryId;
  final int isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.name,
    this.code,
    this.description,
    required this.price,
    this.stock = 0,
    this.categoryId,
    this.isDeleted = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'code': code,
        'description': description,
        'price': price,
        'stock': stock,
        'category_id': categoryId,
        'is_deleted': isDeleted,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as String,
        name: map['name'] as String,
        code: map['code'] as String?,
        description: map['description'] as String?,
        price: (map['price'] as num).toDouble(),
        stock: map['stock'] as int,
        categoryId: map['category_id'] as String?,
        isDeleted: map['is_deleted'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ==================== PRODUCT NOTE ====================

class ProductNote {
  final int? id;
  final String productId;
  final String note;
  final DateTime createdAt;

  const ProductNote({
    this.id,
    required this.productId,
    required this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory ProductNote.fromMap(Map<String, dynamic> map) => ProductNote(
        id: map['id'] as int?,
        productId: map['product_id'] as String,
        note: map['note'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

// ==================== PRODUCT ADDON ====================

class ProductAddon {
  final int? id;
  final String productId;
  final String name;
  final double price;
  final int isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductAddon({
    this.id,
    required this.productId,
    required this.name,
    this.price = 0,
    this.isActive = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'name': name,
        'price': price,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ProductAddon.fromMap(Map<String, dynamic> map) => ProductAddon(
        id: map['id'] as int?,
        productId: map['product_id'] as String,
        name: map['name'] as String,
        price: (map['price'] as num).toDouble(),
        isActive: map['is_active'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ==================== TABLE (RESTAURANT) ====================

class RestaurantTable {
  final String id;
  final String tableNumber;
  final int capacity;
  final String status; // available, occupied, reserved
  final DateTime createdAt;
  final DateTime updatedAt;

  const RestaurantTable({
    required this.id,
    required this.tableNumber,
    this.capacity = 4,
    this.status = 'available',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'table_number': tableNumber,
        'capacity': capacity,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory RestaurantTable.fromMap(Map<String, dynamic> map) => RestaurantTable(
        id: map['id'] as String,
        tableNumber: map['table_number'] as String,
        capacity: map['capacity'] as int,
        status: map['status'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ==================== ORDER ====================

class Order {
  final String id;
  final String tableNumber;
  final String? customerName;
  final String? customerPhone;
  final String? customerId;
  final int pax;
  final int basketSize;
  final double totalAmount;
  final double paidAmount;
  final String orderStatus; // cooking, ready, served
  final String? createdBy;
  final String paymentStatus; // unpaid, partial, paid
  final String? mergedFrom;
  final int isMerged;
  final DateTime? voidedAt;
  final String? voidedBy;
  final String? voidReason;
  final String? complimentBy;
  final String? complimentReason;
  final DateTime? complimentedAt;
  final String? discountNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.tableNumber,
    this.customerName,
    this.customerPhone,
    this.customerId,
    this.pax = 1,
    this.basketSize = 0,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.orderStatus = 'cooking',
    this.createdBy,
    this.paymentStatus = 'unpaid',
    this.mergedFrom,
    this.isMerged = 0,
    this.voidedAt,
    this.voidedBy,
    this.voidReason,
    this.complimentBy,
    this.complimentReason,
    this.complimentedAt,
    this.discountNote,
    required this.createdAt,
    required this.updatedAt,
  });

  double get remaining => totalAmount - paidAmount;
  bool get isPaid => paymentStatus == 'paid';
  bool get isVoided => voidedAt != null;
  bool get isComplimented => complimentedAt != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'table_number': tableNumber,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_id': customerId,
        'pax': pax,
        'basket_size': basketSize,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'order_status': orderStatus,
        'created_by': createdBy,
        'payment_status': paymentStatus,
        'merged_from': mergedFrom,
        'is_merged': isMerged,
        'voided_at': voidedAt?.toIso8601String(),
        'voided_by': voidedBy,
        'void_reason': voidReason,
        'compliment_by': complimentBy,
        'compliment_reason': complimentReason,
        'complimented_at': complimentedAt?.toIso8601String(),
        'discount_note': discountNote,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Order.fromMap(Map<String, dynamic> map) => Order(
        id: map['id'] as String,
        tableNumber: map['table_number'] as String,
        customerName: map['customer_name'] as String?,
        customerPhone: map['customer_phone'] as String?,
        customerId: map['customer_id'] as String?,
        pax: map['pax'] as int,
        basketSize: map['basket_size'] as int,
        totalAmount: (map['total_amount'] as num).toDouble(),
        paidAmount: (map['paid_amount'] as num).toDouble(),
        orderStatus: map['order_status'] as String,
        createdBy: map['created_by'] as String?,
        paymentStatus: map['payment_status'] as String,
        mergedFrom: map['merged_from'] as String?,
        isMerged: map['is_merged'] as int,
        voidedAt: map['voided_at'] != null
            ? DateTime.parse(map['voided_at'] as String)
            : null,
        voidedBy: map['voided_by'] as String?,
        voidReason: map['void_reason'] as String?,
        complimentBy: map['compliment_by'] as String?,
        complimentReason: map['compliment_reason'] as String?,
        complimentedAt: map['complimented_at'] != null
            ? DateTime.parse(map['complimented_at'] as String)
            : null,
        discountNote: map['discount_note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ==================== ORDER ITEM ====================

class OrderItem {
  final String id;
  final String orderId;
  final String productName;
  final String? categoryId; // kategori asal item (untuk routing cetak per-printer)
  final int qty;
  final double price;
  final String destination; // kitchen, bar
  final String itemStatus; // pending, cooking, ready, served
  final String notes;
  final String addons;
  final String waiterName;
  final int isAdditional;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productName,
    this.categoryId,
    required this.qty,
    required this.price,
    this.destination = 'kitchen',
    this.itemStatus = 'pending',
    this.notes = '',
    this.addons = '',
    this.waiterName = '',
    this.isAdditional = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  double get subtotal => qty * price;

  Map<String, dynamic> toMap() => {
        'id': id,
        'order_id': orderId,
        'product_name': productName,
        'category_id': categoryId,
        'qty': qty,
        'price': price,
        'destination': destination,
        'item_status': itemStatus,
        'notes': notes,
        'addons': addons,
        'waiter_name': waiterName,
        'is_additional': isAdditional,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        id: map['id'] as String,
        orderId: map['order_id'] as String,
        productName: map['product_name'] as String,
        categoryId: map['category_id'] as String?,
        qty: map['qty'] as int,
        price: (map['price'] as num).toDouble(),
        destination: map['destination'] as String? ?? 'kitchen',
        itemStatus: map['item_status'] as String? ?? 'pending',
        notes: map['notes'] as String? ?? '',
        addons: map['addons'] as String? ?? '',
        waiterName: map['waiter_name'] as String? ?? '',
        isAdditional: map['is_additional'] as int? ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ==================== CUSTOMER ====================

class Customer {
  final String id;
  final String name;
  final String phone;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ==================== ADDITIONAL CHARGE (Master) ====================

class AdditionalCharge {
  final int? id;
  final String? outletId;
  final String name;
  final String chargeType; // percentage, fixed
  final double value;
  final int isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdditionalCharge({
    this.id,
    this.outletId,
    required this.name,
    required this.chargeType,
    required this.value,
    this.isActive = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'outlet_id': outletId,
        'name': name,
        'charge_type': chargeType,
        'value': value,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory AdditionalCharge.fromMap(Map<String, dynamic> map) =>
      AdditionalCharge(
        id: map['id'] as int?,
        outletId: map['outlet_id'] as String?,
        name: map['name'] as String,
        chargeType: map['charge_type'] as String,
        value: (map['value'] as num).toDouble(),
        isActive: map['is_active'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ==================== ORDER ADDITIONAL CHARGE ====================

class OrderAdditionalCharge {
  final int? id;
  final String orderId;
  final int? chargeId;
  final String name;
  final String chargeType;
  final double value;
  final double appliedAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderAdditionalCharge({
    this.id,
    required this.orderId,
    this.chargeId,
    required this.name,
    required this.chargeType,
    required this.value,
    required this.appliedAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAuto => chargeId != null;
  bool get isManual => chargeId == null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'order_id': orderId,
        'charge_id': chargeId,
        'name': name,
        'charge_type': chargeType,
        'value': value,
        'applied_amount': appliedAmount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory OrderAdditionalCharge.fromMap(Map<String, dynamic> map) =>
      OrderAdditionalCharge(
        id: map['id'] as int?,
        orderId: map['order_id'] as String,
        chargeId: map['charge_id'] as int?,
        name: map['name'] as String,
        chargeType: map['charge_type'] as String,
        value: (map['value'] as num).toDouble(),
        appliedAmount: (map['applied_amount'] as num).toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ==================== TRANSACTION ====================

class Transaction {
  final String id;
  final String orderId;
  final double totalAmount;
  final String paymentMethod; // cash, card, qris, transfer
  final String status;
  final DateTime transactionDate;
  final String? createdBy;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancelReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transaction({
    required this.id,
    required this.orderId,
    required this.totalAmount,
    required this.paymentMethod,
    required this.status,
    required this.transactionDate,
    this.createdBy,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'order_id': orderId,
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'status': status,
        'transaction_date': transactionDate.toIso8601String(),
        'created_by': createdBy,
        'cancelled_at': cancelledAt?.toIso8601String(),
        'cancelled_by': cancelledBy,
        'cancel_reason': cancelReason,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
        id: map['id'] as String,
        orderId: map['order_id'] as String,
        totalAmount: (map['total_amount'] as num).toDouble(),
        paymentMethod: map['payment_method'] as String,
        status: map['status'] as String,
        transactionDate: DateTime.parse(map['transaction_date'] as String),
        createdBy: map['created_by'] as String?,
        cancelledAt: map['cancelled_at'] != null
            ? DateTime.parse(map['cancelled_at'] as String)
            : null,
        cancelledBy: map['cancelled_by'] as String?,
        cancelReason: map['cancel_reason'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ==================== TRANSACTION ITEM ====================

class TransactionItem {
  final String id;
  final String transactionId;
  final String productId;
  final int quantity;
  final double price;

  const TransactionItem({
    required this.id,
    required this.transactionId,
    required this.productId,
    required this.quantity,
    required this.price,
  });

  double get subtotal => quantity * price;

  Map<String, dynamic> toMap() => {
        'id': id,
        'transaction_id': transactionId,
        'product_id': productId,
        'quantity': quantity,
        'price': price,
      };

  factory TransactionItem.fromMap(Map<String, dynamic> map) => TransactionItem(
        id: map['id'] as String,
        transactionId: map['transaction_id'] as String,
        productId: map['product_id'] as String,
        quantity: map['quantity'] as int,
        price: (map['price'] as num).toDouble(),
      );
}

// ==================== PRINTER ====================

class Printer {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final String printerType; // kitchen, bar, cashier, checker, struk
  final String paperSize; // 58mm, 80mm
  final int? connectionTimeout;
  final int? writeTimeout;
  final int? retryAttempts;
  final int? printDensity;
  final String? printSpeed;
  final String? cutMode;
  final int? enableBeep;
  final int? autoCut;
  final String? charset;
  final int isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Printer({
    required this.id,
    required this.name,
    required this.ipAddress,
    this.port = 9100,
    required this.printerType,
    this.paperSize = '80mm',
    this.connectionTimeout,
    this.writeTimeout,
    this.retryAttempts,
    this.printDensity,
    this.printSpeed,
    this.cutMode,
    this.enableBeep,
    this.autoCut,
    this.charset,
    this.isActive = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActivePrinter => isActive == 1;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'ip_address': ipAddress,
        'port': port,
        'printer_type': printerType,
        'paper_size': paperSize,
        'connection_timeout': connectionTimeout,
        'write_timeout': writeTimeout,
        'retry_attempts': retryAttempts,
        'print_density': printDensity,
        'print_speed': printSpeed,
        'cut_mode': cutMode,
        'enable_beep': enableBeep,
        'auto_cut': autoCut,
        'charset': charset,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Printer.fromMap(Map<String, dynamic> map) => Printer(
        id: map['id'] as String,
        name: map['name'] as String,
        ipAddress: map['ip_address'] as String,
        port: map['port'] as int,
        printerType: map['printer_type'] as String,
        paperSize: map['paper_size'] as String? ?? '80mm',
        connectionTimeout: map['connection_timeout'] as int?,
        writeTimeout: map['write_timeout'] as int?,
        retryAttempts: map['retry_attempts'] as int?,
        printDensity: map['print_density'] as int?,
        printSpeed: map['print_speed'] as String?,
        cutMode: map['cut_mode'] as String?,
        enableBeep: map['enable_beep'] as int?,
        autoCut: map['auto_cut'] as int?,
        charset: map['charset'] as String?,
        isActive: map['is_active'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ==================== PAYMENT ====================

class Payment {
  final String id;
  final String orderId;
  final double amount;
  final String paymentMethod; // cash, card, qris, transfer
  final String? paymentNote;
  final String createdBy;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    this.paymentNote,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'order_id': orderId,
        'amount': amount,
        'payment_method': paymentMethod,
        'payment_note': paymentNote,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
        id: map['id'] as String,
        orderId: map['order_id'] as String,
        amount: (map['amount'] as num).toDouble(),
        paymentMethod: map['payment_method'] as String,
        paymentNote: map['payment_note'] as String?,
        createdBy: map['created_by'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

// ==================== PRINT QUEUE JOB ====================

class PrintQueueJob {
  final String id;
  final String printerId;
  final String data; // JSON PrintJobData
  final String status; // pending, done, failed
  final int retryCount;
  final String? errorMessage;
  final DateTime? lockedAt;
  final String? lockedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PrintQueueJob({
    required this.id,
    required this.printerId,
    required this.data,
    this.status = 'pending',
    this.retryCount = 0,
    this.errorMessage,
    this.lockedAt,
    this.lockedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'printer_id': printerId,
        'data': data,
        'status': status,
        'retry_count': retryCount,
        'error_message': errorMessage,
        'locked_at': lockedAt?.toIso8601String(),
        'locked_by': lockedBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory PrintQueueJob.fromMap(Map<String, dynamic> map) => PrintQueueJob(
        id: map['id'] as String,
        printerId: map['printer_id'] as String,
        data: map['data'] as String,
        status: map['status'] as String? ?? 'pending',
        retryCount: map['retry_count'] as int? ?? 0,
        errorMessage: map['error_message'] as String?,
        lockedAt: map['locked_at'] != null
            ? DateTime.parse(map['locked_at'] as String)
            : null,
        lockedBy: map['locked_by'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ==================== CASHIER SHIFT ====================

class CashierShift {
  final String id;
  final String openedBy;
  final DateTime openedAt;
  final double openingCash;
  final DateTime? closedAt;
  final String? closedBy;
  final double? closingCash;
  final double? closingCard;
  final double? closingQris;
  final double? closingTransfer;
  final double? carryOverCash;
  final String? previousShiftId;
  final String? handoverTo;
  final String status; // open, closed
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CashierShift({
    required this.id,
    required this.openedBy,
    required this.openedAt,
    this.openingCash = 0,
    this.closedAt,
    this.closedBy,
    this.closingCash,
    this.closingCard,
    this.closingQris,
    this.closingTransfer,
    this.carryOverCash,
    this.previousShiftId,
    this.handoverTo,
    this.status = 'open',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => status == 'open';

  Map<String, dynamic> toMap() => {
        'id': id,
        'opened_by': openedBy,
        'opened_at': openedAt.toIso8601String(),
        'opening_cash': openingCash,
        'closed_at': closedAt?.toIso8601String(),
        'closed_by': closedBy,
        'closing_cash': closingCash,
        'closing_card': closingCard,
        'closing_qris': closingQris,
        'closing_transfer': closingTransfer,
        'carry_over_cash': carryOverCash,
        'previous_shift_id': previousShiftId,
        'handover_to': handoverTo,
        'status': status,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CashierShift.fromMap(Map<String, dynamic> map) => CashierShift(
        id: map['id'] as String,
        openedBy: map['opened_by'] as String,
        openedAt: DateTime.parse(map['opened_at'] as String),
        openingCash: (map['opening_cash'] as num).toDouble(),
        closedAt: map['closed_at'] != null
            ? DateTime.parse(map['closed_at'] as String)
            : null,
        closedBy: map['closed_by'] as String?,
        closingCash: map['closing_cash'] != null
            ? (map['closing_cash'] as num).toDouble()
            : null,
        closingCard: map['closing_card'] != null
            ? (map['closing_card'] as num).toDouble()
            : null,
        closingQris: map['closing_qris'] != null
            ? (map['closing_qris'] as num).toDouble()
            : null,
        closingTransfer: map['closing_transfer'] != null
            ? (map['closing_transfer'] as num).toDouble()
            : null,
        carryOverCash: map['carry_over_cash'] != null
            ? (map['carry_over_cash'] as num).toDouble()
            : null,
        previousShiftId: map['previous_shift_id'] as String?,
        handoverTo: map['handover_to'] as String?,
        status: map['status'] as String,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ==================== CASHIER CASH MOVEMENT ====================

class CashMovement {
  final String id;
  final String shiftId;
  final String movementType; // in, out
  final double amount;
  final String counterpartName;
  final String note;
  final DateTime createdAt;

  const CashMovement({
    required this.id,
    required this.shiftId,
    required this.movementType,
    required this.amount,
    required this.counterpartName,
    this.note = '',
    required this.createdAt,
  });

  bool get isCashIn => movementType == 'in';

  Map<String, dynamic> toMap() => {
        'id': id,
        'shift_id': shiftId,
        'movement_type': movementType,
        'amount': amount,
        'counterpart_name': counterpartName,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory CashMovement.fromMap(Map<String, dynamic> map) => CashMovement(
        id: map['id'] as String,
        shiftId: map['shift_id'] as String,
        movementType: map['movement_type'] as String,
        amount: (map['amount'] as num).toDouble(),
        counterpartName: map['counterpart_name'] as String,
        note: map['note'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

// ==================== OUTLET CONFIG ====================

class OutletConfig {
  final int? id;
  final String? outletId;
  final String? outletName;
  final String? outletCode;
  final String? outletAddress;
  final String? outletPhone;
  final String? receiptFooter;
  final String? socialMedia;
  final int targetSpendPerPax;
  final String? cloudApiUrl;
  final String? cloudApiKey;
  final int isActive;
  final int syncEnabled;
  final int syncIntervalMinutes;
  final int dataRetentionDays;
  final DateTime? lastSyncAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OutletConfig({
    this.id,
    this.outletId,
    this.outletName,
    this.outletCode,
    this.outletAddress,
    this.outletPhone,
    this.receiptFooter,
    this.socialMedia,
    this.targetSpendPerPax = 0,
    this.cloudApiUrl,
    this.cloudApiKey,
    this.isActive = 1,
    this.syncEnabled = 0,
    this.syncIntervalMinutes = 5,
    this.dataRetentionDays = 0,
    this.lastSyncAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'outlet_id': outletId,
        'outlet_name': outletName,
        'outlet_code': outletCode,
        'outlet_address': outletAddress,
        'outlet_phone': outletPhone,
        'receipt_footer': receiptFooter,
        'social_media': socialMedia,
        'target_spend_per_pax': targetSpendPerPax,
        'cloud_api_url': cloudApiUrl,
        'cloud_api_key': cloudApiKey,
        'is_active': isActive,
        'sync_enabled': syncEnabled,
        'sync_interval_minutes': syncIntervalMinutes,
        'data_retention_days': dataRetentionDays,
        'last_sync_at': lastSyncAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory OutletConfig.fromMap(Map<String, dynamic> map) => OutletConfig(
        id: map['id'] as int?,
        outletId: map['outlet_id'] as String?,
        outletName: map['outlet_name'] as String?,
        outletCode: map['outlet_code'] as String?,
        outletAddress: map['outlet_address'] as String?,
        outletPhone: map['outlet_phone'] as String?,
        receiptFooter: map['receipt_footer'] as String?,
        socialMedia: map['social_media'] as String?,
        targetSpendPerPax: map['target_spend_per_pax'] as int? ?? 0,
        cloudApiUrl: map['cloud_api_url'] as String?,
        cloudApiKey: map['cloud_api_key'] as String?,
        isActive: map['is_active'] as int? ?? 1,
        syncEnabled: map['sync_enabled'] as int? ?? 0,
        syncIntervalMinutes: map['sync_interval_minutes'] as int? ?? 5,
        dataRetentionDays: map['data_retention_days'] as int? ?? 0,
        lastSyncAt: map['last_sync_at'] != null
            ? DateTime.parse(map['last_sync_at'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
