import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../approvals/data/approvals_providers.dart';
import '../../items/data/items_providers.dart';
import '../data/admin_providers.dart';

const _allStatuses =
    'pending,approved,rejected,released,returned,closed,overdue';

String _csvField(Object? value) {
  final s = (value ?? '').toString();
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String _csvRow(List<Object?> fields) => fields.map(_csvField).join(',');

String _csvDoc(List<String> header, Iterable<List<Object?>> rows) {
  final buffer = StringBuffer(_csvRow(header));
  buffer.write('\r\n');
  for (final row in rows) {
    buffer.write(_csvRow(row));
    buffer.write('\r\n');
  }
  return buffer.toString();
}

Future<String> buildBorrowHistoryCsv(WidgetRef ref) async {
  final requests = (await ref
          .read(approvalsRepositoryProvider)
          .fetchQueue(_allStatuses))
      .requests;
  return _csvDoc(
    [
      'Item',
      'Borrower',
      'Borrower type',
      'Status',
      'Quantity',
      'Requested from',
      'Requested to',
      'Created at',
    ],
    [
      for (final r in requests)
        [
          r.itemLabel,
          r.borrowerName,
          r.borrowerType,
          r.status,
          r.quantityRequested,
          r.requestedFrom.toIso8601String(),
          r.requestedTo?.toIso8601String() ?? '',
          r.createdAt.toIso8601String(),
        ],
    ],
  );
}

Future<String> buildItemsCsv(WidgetRef ref) async {
  final items = await ref.read(itemsRepositoryProvider).fetchItems();
  return _csvDoc(
    ['Name', 'Tag', 'Category', 'Department', 'Quantity', 'Flow type', 'Active'],
    [
      for (final i in items)
        [
          i.name,
          i.distinguishingTag ?? '',
          i.category ?? '',
          i.departmentName ?? '',
          i.quantity,
          i.flowType.name,
          i.active,
        ],
    ],
  );
}

Future<String> buildCitizensCsv(WidgetRef ref) async {
  final users = await ref.read(adminRepositoryProvider).fetchAllUsers();
  final citizens = users.where((u) => !u.isStaff);
  return _csvDoc(
    ['Full name', 'Username', 'ID verified', 'Active'],
    [
      for (final c in citizens)
        [c.fullName, c.username ?? '', c.verified == true, c.active],
    ],
  );
}

/// Downloads [csv] as [filename] on web; on native (no straightforward
/// browser download target), copies it to the clipboard instead so it can
/// be pasted into a spreadsheet app.
Future<void> downloadCsv(BuildContext context, String filename, String csv) async {
  if (kIsWeb) {
    final uri = Uri.dataFromString(
      csv,
      mimeType: 'text/csv',
      encoding: utf8,
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }
  await Clipboard.setData(ClipboardData(text: csv));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard — paste into a spreadsheet app.'),
      ),
    );
  }
}
