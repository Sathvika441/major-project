import 'irrigation_audit.dart';
import 'irrigation_decision_engine.dart';
import 'irrigation_models.dart';
import 'pump_controller.dart';

class IrrigationCoordinator {
  final IrrigationDecisionEngine engine;
  final IrrigationAuditLog audit;
  final SafePumpController? pump;

  const IrrigationCoordinator({
    required this.engine,
    required this.audit,
    this.pump,
  });

  Future<IrrigationDecision> evaluate(
    IrrigationInput input,
    IrrigationMode mode,
  ) async {
    final decision = engine.decide(input: input, mode: mode);
    await audit.record(
      IrrigationAuditRecord(
        id: 'recommendation_' + decision.decisionId,
        type: IrrigationAuditType.recommendation,
        decisionId: decision.decisionId,
        action: 'recommendation',
        status: decision.irrigationRecommended
            ? 'recommended'
            : 'not_recommended',
        reason: decision.reason,
        timestamp: decision.createdAt,
        details: decision.toMap(),
      ),
    );

    if (mode == IrrigationMode.automatic &&
        decision.irrigationRecommended &&
        pump != null) {
      await pump!.start(
        commandId: 'auto_' + decision.decisionId,
        duration: decision.suggestedDuration,
        mode: mode,
        confirmed: true,
        decisionId: decision.decisionId,
        reason: 'Automatic mode: ' + decision.reason,
      );
    }
    return decision;
  }
}
