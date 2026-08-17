import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/affiliate_link.dart';
import '../../../providers/providers.dart';
import '../../widgets/app_error_view.dart';
import '../../../l10n/app_localizations.dart';

const _categories = [
  'tech',
  'finance',
  'lifestyle',
  'health',
  'education',
  'travel',
  'food',
  'fashion',
  'sports',
  'other',
];

const _statuses = ['active', 'paused', 'expired'];

class AffiliationFormSheet extends ConsumerStatefulWidget {
  const AffiliationFormSheet({super.key, this.affiliation});

  final AffiliateLink? affiliation;

  @override
  ConsumerState<AffiliationFormSheet> createState() =>
      _AffiliationFormSheetState();
}

class _AffiliationFormSheetState extends ConsumerState<AffiliationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _slugCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _contactUrlCtrl;
  late final TextEditingController _loginUrlCtrl;
  late final TextEditingController _commissionCtrl;
  late final TextEditingController _keywordsCtrl;
  late final TextEditingController _notesCtrl;
  late String _category;
  late String _status;
  DateTime? _expiresAt;
  bool _saving = false;

  bool get _isEditing => widget.affiliation != null;

  @override
  void initState() {
    super.initState();
    final a = widget.affiliation;
    _nameCtrl = TextEditingController(text: a?.name ?? '');
    _urlCtrl = TextEditingController(text: a?.url ?? '');
    _slugCtrl = TextEditingController(text: a?.slug ?? '');
    _descriptionCtrl = TextEditingController(text: a?.description ?? '');
    _contactUrlCtrl = TextEditingController(text: a?.contactUrl ?? '');
    _loginUrlCtrl = TextEditingController(text: a?.loginUrl ?? '');
    _commissionCtrl = TextEditingController(text: a?.commission ?? '');
    _keywordsCtrl =
        TextEditingController(text: a?.keywords.join(', ') ?? '');
    _notesCtrl = TextEditingController(text: a?.notes ?? '');
    _category = a?.category ?? '';
    _status = a?.status ?? 'active';
    _expiresAt = a?.expiresAt;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _slugCtrl.dispose();
    _descriptionCtrl.dispose();
    _contactUrlCtrl.dispose();
    _loginUrlCtrl.dispose();
    _commissionCtrl.dispose();
    _keywordsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isEditing ? context.tr('Edit Affiliate Link') : context.tr('New Affiliate Link'),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Name *'),
                  hintText: context.tr('Amazon Associates'),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? context.tr('Required') : null,
              ),
              const SizedBox(height: 12),

              // URL
              TextFormField(
                controller: _urlCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('URL *'),
                  hintText: context.tr('https://affiliate.example.com/ref=123'),
                ),
                keyboardType: TextInputType.url,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? context.tr('Required') : null,
              ),
              const SizedBox(height: 12),

              // Slug
              TextFormField(
                controller: _slugCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Short link slug'),
                  hintText: context.tr('my-affiliate-offer'),
                  helperText: context.tr('Optional: /r/your-slug'),
                ),
                textCapitalization: TextCapitalization.none,
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descriptionCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Description'),
                  hintText: context.tr('Brief description of the program...'),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // Category + Commission
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category.isEmpty ? null : _category,
                      decoration: InputDecoration(labelText: context.tr('Category')),
                      items: _categories
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                  c[0].toUpperCase() + c.substring(1))))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v ?? ''),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _commissionCtrl,
                      decoration: InputDecoration(
                        labelText: context.tr('Commission'),
                        hintText: context.tr('5% or 10/sale'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Contact URL + Login URL
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _contactUrlCtrl,
                      decoration: InputDecoration(
                        labelText: context.tr('Contact URL'),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _loginUrlCtrl,
                      decoration: InputDecoration(
                        labelText: context.tr('Login URL'),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Keywords
              TextFormField(
                controller: _keywordsCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Keywords (comma-separated)'),
                  hintText: context.tr('hosting, wordpress, website'),
                  helperText: context.tr('AI uses these to match content topics'),
                ),
              ),
              const SizedBox(height: 12),

              // Status + Expires
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: InputDecoration(labelText: context.tr('Status')),
                      items: _statuses
                          .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                  s[0].toUpperCase() + s.substring(1))))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _status = v ?? 'active'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration:
                            InputDecoration(labelText: context.tr('Expires')),
                        child: Text(
                          _expiresAt != null
                              ? '${_expiresAt!.year}-${_expiresAt!.month.toString().padLeft(2, '0')}-${_expiresAt!.day.toString().padLeft(2, '0')}'
                              : context.tr('No date'),
                          style: TextStyle(
                            color: _expiresAt != null
                                ? null
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Notes
              TextFormField(
                controller: _notesCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Notes for AI'),
                  hintText: context.tr('When and how to use this link...'),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.pop(context, false),
                      child: Text(context.tr('Cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isEditing ? context.tr('Update') : context.tr('Create')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _expiresAt = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final keywords = _keywordsCtrl.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'url': _urlCtrl.text.trim(),
      if (_slugCtrl.text.trim().isNotEmpty)
        'slug': _slugCtrl.text.trim(),
      if (_descriptionCtrl.text.trim().isNotEmpty)
        'description': _descriptionCtrl.text.trim(),
      if (_category.isNotEmpty) 'category': _category,
      if (_commissionCtrl.text.trim().isNotEmpty)
        'commission': _commissionCtrl.text.trim(),
      if (_contactUrlCtrl.text.trim().isNotEmpty)
        'contactUrl': _contactUrlCtrl.text.trim(),
      if (_loginUrlCtrl.text.trim().isNotEmpty)
        'loginUrl': _loginUrlCtrl.text.trim(),
      if (keywords.isNotEmpty) 'keywords': keywords,
      'status': _status,
      if (_notesCtrl.text.trim().isNotEmpty)
        'notes': _notesCtrl.text.trim(),
      if (_expiresAt != null)
        'expiresAt': _expiresAt!.toIso8601String(),
    };

    try {
      final api = ref.read(apiServiceProvider);
      if (_isEditing) {
        await api.updateAffiliation(widget.affiliation!.id!, data);
      } else {
        await api.createAffiliation(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error, stackTrace) {
      if (mounted) {
        showDiagnosticSnackBar(
          context,
          ref,
          message: context.tr('Failed to save: {error}', {'error': '$error'}),
          scope: 'affiliations.save',
          error: error,
          stackTrace: stackTrace,
          contextData: {
            'isEditing': _isEditing,
            'name': _nameCtrl.text.trim(),
          },
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
