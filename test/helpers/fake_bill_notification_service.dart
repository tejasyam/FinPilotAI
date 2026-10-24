import 'package:finpilot_ai/data/models/finance_models.dart';
import 'package:finpilot_ai/features/bills/services/bill_notification_service.dart';

class FakeBillNotificationService implements BillNotificationService {
  FakeBillNotificationService({
    this.permissionGranted = true,
    this.scheduleFailureFor,
  });

  bool permissionGranted;
  String? scheduleFailureFor;
  bool initializationCalled = false;
  int permissionRequests = 0;
  int cancelAllCalls = 0;
  final scheduled = <String>[];
  final cancelled = <String>[];

  @override
  bool supported = true;

  @override
  Future<void> initialize() async {
    initializationCalled = true;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> schedule(BillReminder bill) async {
    if (bill.id == scheduleFailureFor) {
      throw StateError('simulated notification scheduling failure');
    }
    scheduled.add(bill.id);
  }

  @override
  Future<void> cancel(BillReminder bill) async => cancelled.add(bill.id);

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
  }
}
