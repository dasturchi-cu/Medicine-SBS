import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../../core/state/purchase_controller.dart';
import '../../../../core/services/telegram_service.dart';

Future<void> showPurchaseModal({
  required BuildContext context,
  required String courseName,
  required String description,
  required String price,
  String? courseId,
  String? telegramRecipient,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _PurchaseModalContent(
        courseName: courseName,
        description: description,
        price: price,
        courseId: courseId,
        telegramRecipient: telegramRecipient,
      );
    },
  );
}

class _PurchaseModalContent extends ConsumerStatefulWidget {
  const _PurchaseModalContent({
    required this.courseName,
    required this.description,
    required this.price,
    this.courseId,
    this.telegramRecipient,
  });

  final String courseName;
  final String description;
  final String price;
  final String? courseId;
  final String? telegramRecipient;

  @override
  ConsumerState<_PurchaseModalContent> createState() =>
      _PurchaseModalContentState();
}

class _PurchaseModalContentState extends ConsumerState<_PurchaseModalContent> {
  final TelegramService _telegramService = TelegramService();
  bool _loading = false;

  ({String? courseId, String? sectionId}) _resolvePurchaseTarget(String? rawCourseId) {
    final value = (rawCourseId ?? '').trim();
    if (value.isEmpty) return (courseId: null, sectionId: null);
    const marker = '_base_';
    final markerIndex = value.indexOf(marker);
    if (markerIndex > 0 && markerIndex + marker.length < value.length) {
      final courseId = value.substring(0, markerIndex).trim();
      final sectionId = value.substring(markerIndex + marker.length).trim();
      if (courseId.isNotEmpty && sectionId.isNotEmpty) {
        return (courseId: courseId, sectionId: sectionId);
      }
    }
    return (courseId: value, sectionId: null);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x29000000),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Obuna sotib olish',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              _InfoTile(
                icon: Icons.school_outlined,
                title: 'Kurs',
                value: widget.courseName,
              ),
              const SizedBox(height: 10),
              _InfoTile(
                icon: Icons.info_outline,
                title: 'Qisqa tavsif',
                value: widget.description,
              ),
              const SizedBox(height: 10),
              _InfoTile(
                icon: Icons.payments_outlined,
                title: 'Narx',
                value: widget.price,
                valueColor: const Color(0xFF0E8F61),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF229ED9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _loading
                      ? null
                      : () async {
                          final auth = ref.read(authControllerProvider);
                          if (!auth.isLoggedIn || auth.userId == null) {
                            Navigator.of(context).pop();
                            context.push(AppRoutes.login);
                            return;
                          }

                          try {
                            setState(() => _loading = true);
                            final target = _resolvePurchaseTarget(widget.courseId);
                            final platformPurchase =
                                (target.courseId ?? '').trim().isNotEmpty;
                            if (platformPurchase) {
                              await ref.read(purchasesRepositoryProvider).createPurchase(
                                    userId: auth.userId!,
                                    courseId: target.courseId,
                                    sectionId: target.sectionId,
                                  );
                              if (target.sectionId != null && target.courseId != null) {
                                ref
                                    .read(purchaseControllerProvider.notifier)
                                    .purchaseBase(target.courseId!, target.sectionId!);
                                ref
                                    .read(progressControllerProvider.notifier)
                                    .enroll(target.courseId!);
                              } else if (target.courseId != null) {
                                ref
                                    .read(purchaseControllerProvider.notifier)
                                    .purchaseCourse(target.courseId!);
                                ref
                                    .read(progressControllerProvider.notifier)
                                    .enroll(target.courseId!);
                              }
                            }
                            final opened = await _telegramService.openTelegram(
                              courseName: widget.courseName,
                              userId: auth.userId!,
                              courseId: widget.courseId,
                              userName: auth.name,
                              userPhone: auth.email,
                              telegramRecipient: widget.telegramRecipient,
                            );
                            if (!context.mounted) return;

                            setState(() => _loading = false);
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  opened
                                      ? 'So‘rov yuborildi. Kurs admin tasdiqlagandan keyin ochiladi.'
                                      : 'Telegram havolasini ochib bo‘lmadi',
                                ),
                              ),
                            );
                          } catch (_) {
                            if (!context.mounted) return;
                            setState(() => _loading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Xatolik yuz berdi. Qayta urinib ko‘ring.',
                                ),
                              ),
                            );
                          }
                        },
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.telegram),
                  label: Text(
                    _loading ? 'Ochilmoqda...' : 'Telegram orqali sotib olish',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1E6BB8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
