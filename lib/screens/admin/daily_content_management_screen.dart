import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/services/daily_content_service.dart';
import 'package:kohntri_os_hq/widgets/loading_overlay.dart';
import 'package:kohntri_os_hq/utils/connectivity_helper.dart';
import 'package:kohntri_os_hq/services/pending_operation_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class DailyContentManagementScreen extends StatefulWidget {
  final ContentType contentType;
  const DailyContentManagementScreen({super.key, required this.contentType});

  @override
  State<DailyContentManagementScreen> createState() =>
      _DailyContentManagementScreenState();
}

class _DailyContentManagementScreenState
    extends State<DailyContentManagementScreen> {
  final DailyContentService _service = DailyContentService();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  Set<String> _pendingIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _items = await _service.getAll(widget.contentType);
      final tableName = _service.tableNameForType(widget.contentType);
      _pendingIds = await PendingOperationService().getPendingIdsForTable(
        tableName,
      );
    } catch (e) {
      print(e);
    }
    setState(() => _isLoading = false);
  }

  void _addItem() => _showDialog();
  void _editItem(Map<String, dynamic> item) => _showDialog(item: item);

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    if (id.startsWith('pending_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete pending item. Wait for sync.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final online = await ConnectivityHelper.isOnline();
    if (online) {
      await _service.delete(widget.contentType, id);
    } else {
      await PendingOperationService().enqueue(
        _service.tableNameForType(widget.contentType),
        'delete',
        {'id': id},
      );
    }
    _loadData();
  }

  Future<void> _showDialog({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final isProverb = widget.contentType == ContentType.proverb;
    final isFunFact = widget.contentType == ContentType.funFact;
    final isChallenge = widget.contentType == ContentType.challenge;

    final textController = TextEditingController(
      text: (item?['text'] ?? item?['question'] ?? '').toString(),
    );
    final meaningController = TextEditingController(
      text: (item?['meaning'] ?? '').toString(),
    );
    final sourceController = TextEditingController(
      text: (item?['source'] ?? '').toString(),
    );
    final categoryController = TextEditingController(
      text: (item?['category'] ?? '').toString(),
    );
    final optionsController = TextEditingController(
      text: (item?['options'] as List?)?.join('\n') ?? '',
    );
    final correctAnswerController = TextEditingController(
      text: ((item?['correct_answer_index'] ?? 0)).toString(),
    );
    final pointsController = TextEditingController(
      text: ((item?['points'] ?? 10)).toString(),
    );
    final explanationController = TextEditingController(
      text: (item?['explanation'] ?? '').toString(),
    );

    File? _selectedImage;
    String? _existingImageUrl = item?['image_url'] as String?;
    final picker = ImagePicker();

    Future<void> _pickImage() async {
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        _selectedImage = File(picked.path);
        _existingImageUrl = null;
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('${isEdit ? 'Edit' : 'Add'} ${_contentTypeLabel()}'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Text field – label depends on type
                  TextFormField(
                    controller: textController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: isProverb
                          ? 'Proverb'
                          : isFunFact
                              ? 'Fact'
                              : 'Question',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Proverb fields
                  if (isProverb) ...[
                    TextFormField(
                      controller: meaningController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Meaning',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: sourceController,
                      decoration: const InputDecoration(
                        labelText: 'Source',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // FunFact fields
                  if (isFunFact) ...[
                    TextFormField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Challenge fields
                  if (isChallenge) ...[
                    TextFormField(
                      controller: optionsController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Options (one per line)',
                        hintText: 'Option A\nOption B\nOption C\nOption D',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: correctAnswerController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Correct answer index (0-based)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: pointsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Points',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: explanationController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Explanation',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Image picker
                  Row(
                    children: [
                      Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(_selectedImage!),
                                  fit: BoxFit.cover,
                                )
                              : _existingImageUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_existingImageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        child: _selectedImage == null && _existingImageUrl == null
                            ? const Icon(Icons.image, size: 32, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library),
                          label: Text(
                            _selectedImage != null
                                ? 'Change Image'
                                : 'Pick Image',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (isEdit)
                    Row(
                      children: [
                        const Text('Position: ',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        Text('${item!['position'] ?? 0}'),
                      ],
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final online = await ConnectivityHelper.isOnline();

                  Map<String, dynamic> data = {};
                  // For proverb/funFact, use 'text'. For challenge, use 'question'
                  if (isChallenge) {
                    data['question'] = textController.text.trim();
                  } else {
                    data['text'] = textController.text.trim();
                  }

                  int position;
                  if (isEdit) {
                    position = item!['position'] as int? ?? 0;
                  } else {
                    if (_items.isEmpty) {
                      position = 1;
                    } else {
                      final maxPos = _items
                          .map((e) => e['position'] as int? ?? 0)
                          .reduce((a, b) => a > b ? a : b);
                      position = maxPos + 1;
                    }
                  }
                  data['position'] = position;

                  if (isProverb) {
                    data['meaning'] = meaningController.text.trim();
                    data['source'] = sourceController.text.trim();
                  } else if (isFunFact) {
                    data['category'] = categoryController.text.trim();
                  } else if (isChallenge) {
                    data['options'] = optionsController.text
                        .split('\n')
                        .where((s) => s.trim().isNotEmpty)
                        .toList();
                    data['correct_answer_index'] =
                        int.tryParse(correctAnswerController.text) ?? 0;
                    data['points'] = int.tryParse(pointsController.text) ?? 10;
                    data['explanation'] = explanationController.text.trim();
                  }

                  if (online) {
                    String? uploadedUrl;
                    if (_selectedImage != null) {
                      try {
                        final bucket = 'daily_content_images';
                        final fileName =
                            'content_${DateTime.now().millisecondsSinceEpoch}_${path.basename(_selectedImage!.path)}';
                        final bytes = await _selectedImage!.readAsBytes();
                        await Supabase.instance.client.storage
                            .from(bucket)
                            .uploadBinary(fileName, bytes);
                        uploadedUrl = Supabase.instance.client.storage
                            .from(bucket)
                            .getPublicUrl(fileName);
                      } catch (e) {
                        print('Image upload failed: $e');
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Image upload failed.')),
                        );
                        return;
                      }
                    }

                    if (uploadedUrl != null) {
                      data['image_url'] = uploadedUrl;
                    } else if (_existingImageUrl != null) {
                      data['image_url'] = _existingImageUrl;
                    }

                    if (isEdit) {
                      await _service.update(
                        widget.contentType,
                        item!['id'] as String,
                        data,
                      );
                    } else {
                      await _service.create(widget.contentType, data);
                    }
                    Navigator.pop(ctx, true);
                  } else {
                    String? localImagePath;
                    if (_selectedImage != null) {
                      final dir = await getApplicationDocumentsDirectory();
                      final fileName =
                          'content_${DateTime.now().millisecondsSinceEpoch}_${path.basename(_selectedImage!.path)}';
                      final dest = File(path.join(dir.path, fileName));
                      await _selectedImage!.copy(dest.path);
                      localImagePath = dest.path;
                    }

                    final media = localImagePath != null
                        ? {'image': localImagePath}
                        : null;
                    await PendingOperationService().enqueue(
                      _service.tableNameForType(widget.contentType),
                      isEdit ? 'update' : 'insert',
                      data,
                      media: media,
                    );

                    final tempId =
                        'pending_${DateTime.now().millisecondsSinceEpoch}';
                    final tempItem = {
                      'id': tempId,
                      ...data,
                      'image_url': localImagePath,
                    };
                    if (mounted) {
                      setState(() {
                        _items.insert(0, tempItem);
                        _pendingIds.add(tempId);
                      });
                    }

                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Added offline – will sync when online.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    Navigator.pop(ctx, true);
                  }
                } catch (e) {
                  print(e);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && await ConnectivityHelper.isOnline()) {
      _loadData();
    }
  }

  String _contentTypeLabel() {
    switch (widget.contentType) {
      case ContentType.proverb:
        return 'Proverb';
      case ContentType.funFact:
        return 'Fun Fact';
      case ContentType.challenge:
        return 'Challenge';
    }
  }

  Color _getAccentColor() {
    switch (widget.contentType) {
      case ContentType.proverb:
        return Colors.green.shade700;
      case ContentType.funFact:
        return Colors.purple.shade600;
      case ContentType.challenge:
        return Colors.orange.shade700;
    }
  }

  IconData _getIcon() {
    switch (widget.contentType) {
      case ContentType.proverb:
        return Icons.format_quote;
      case ContentType.funFact:
        return Icons.lightbulb;
      case ContentType.challenge:
        return Icons.local_fire_department;
    }
  }

  // ---------------------- BUILD ----------------------
  @override
  Widget build(BuildContext context) {
    final accent = _getAccentColor();

    return Scaffold(
      appBar: AppBar(
        title: Text(_contentTypeLabel()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const LoadingOverlay()
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getIcon(), size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No ${_contentTypeLabel().toLowerCase()}s yet.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add your first one.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          color: accent.withOpacity(0.1),
                          child: Row(
                            children: [
                              Icon(_getIcon(), color: accent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _contentTypeLabel(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: accent,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_items.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Column headers
                        _buildHeaderRow(),
                        // Data rows
                        ..._items.asMap().entries.map((entry) {
                          return _buildDataRow(entry.key, entry.value);
                        }),
                      ],
                    ),
                  ),
                ),
    );
  }

  List<String> _getHeaders() {
    switch (widget.contentType) {
      case ContentType.proverb:
        return ['#', 'Proverb', 'Meaning', 'Source', 'Pos', 'Actions'];
      case ContentType.funFact:
        return ['#', 'Fact', 'Category', 'Pos', 'Actions'];
      case ContentType.challenge:
        return ['#', 'Question', 'Options', 'Correct', 'Pts', 'Pos', 'Actions'];
    }
  }

  List<int> _getFlexValues() {
    switch (widget.contentType) {
      case ContentType.proverb:
        return [1, 5, 4, 3, 1, 2];
      case ContentType.funFact:
        return [1, 5, 3, 1, 2];
      case ContentType.challenge:
        return [1, 5, 4, 1, 1, 1, 2];
    }
  }

  Widget _buildHeaderRow() {
    final headers = _getHeaders();
    final flex = _getFlexValues();
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: List.generate(headers.length, (i) {
          return Expanded(
            flex: flex[i],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                headers[i],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDataRow(int index, Map<String, dynamic> item) {
    final id = item['id'] as String;
    final isPending = id.startsWith('pending_');
    final flex = _getFlexValues();

    final List<Widget> cells = [];

    // #
    cells.add(Text('${index + 1}', style: const TextStyle(fontSize: 12)));

    // Text / Question
    final text = (item['text'] ?? item['question'] ?? '').toString();
    cells.add(Row(
      children: [
        Expanded(
          child: Text(
            text.isEmpty ? '—' : text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontStyle: isPending ? FontStyle.italic : FontStyle.normal,
              color: isPending ? Colors.grey : null,
            ),
          ),
        ),
        if (isPending) ...[
          const SizedBox(width: 4),
          const Icon(Icons.sync, size: 14, color: Colors.orange),
        ],
      ],
    ));

    // Type-specific columns
    if (widget.contentType == ContentType.proverb) {
      cells.add(Text(
        (item['meaning'] ?? '—').toString(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ));
      cells.add(Text(
        (item['source'] ?? '—').toString(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ));
    } else if (widget.contentType == ContentType.funFact) {
      cells.add(Text(
        (item['category'] ?? '—').toString(),
        style: const TextStyle(fontSize: 12),
      ));
    } else if (widget.contentType == ContentType.challenge) {
      final options = (item['options'] as List?)?.join(', ') ?? '—';
      cells.add(Text(
        options,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ));
      cells.add(Text(
        '${item['correct_answer_index'] ?? 0}',
        style: const TextStyle(fontSize: 12),
      ));
      cells.add(Text(
        '${item['points'] ?? 0}',
        style: const TextStyle(fontSize: 12),
      ));
    }

    // Position
    cells.add(Text(
      '${item['position'] ?? 0}',
      style: const TextStyle(fontSize: 12),
    ));

    // Actions
    cells.add(Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.edit,
            color: isPending ? Colors.grey : Colors.blue,
            size: 18,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: isPending ? null : () => _editItem(item),
          tooltip: 'Edit',
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(
            Icons.delete,
            color: isPending ? Colors.grey : Colors.red,
            size: 18,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: isPending ? null : () => _deleteItem(item),
          tooltip: 'Delete',
        ),
      ],
    ));

    return Container(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: List.generate(cells.length, (i) {
          return Expanded(
            flex: flex[i],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: cells[i],
            ),
          );
        }),
      ),
    );
  }
}