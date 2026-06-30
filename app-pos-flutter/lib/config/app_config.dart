class AppConfig {
  static const String appName = 'POS Resto';
  static const String version = '1.0.0';

  // Default admin credentials
  static const String defaultUsername = 'admin';
  static const String defaultPin = '1234';

  // Roles
  static const List<String> roles = [
    'admin',
    'manager',
    'svp',
    'cashier',
    'waiter',
    'kitchen',
    'bar',
  ];

  // Payment methods
  static const List<String> paymentMethods = [
    'cash',
    'card',
    'qris',
    'transfer',
  ];

  // Order statuses
  static const List<String> orderStatuses = ['cooking', 'ready', 'served'];

  // Item statuses
  static const List<String> itemStatuses = [
    'pending',
    'cooking',
    'ready',
    'served',
  ];

  // Payment statuses
  static const List<String> paymentStatuses = ['unpaid', 'partial', 'paid'];

  // Table statuses
  static const List<String> tableStatuses = [
    'available',
    'occupied',
    'reserved',
  ];

  // Printer types
  static const List<String> printerTypes = [
    'kitchen',
    'bar',
    'cashier',
    'checker',
    'struk',
  ];

  // Paper sizes
  static const List<String> paperSizes = ['58mm', '80mm'];
}
