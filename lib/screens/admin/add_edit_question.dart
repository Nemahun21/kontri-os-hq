import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:kohntri_os_hq/services/xlsx_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kohntri_os_hq/models/daily_challenge_question.dart';
import 'package:kohntri_os_hq/models/language_question.dart';
import 'package:kohntri_os_hq/models/language_theme.dart';
import 'package:kohntri_os_hq/models/question.dart';
import 'package:kohntri_os_hq/screens/preview_question_screen.dart';
import 'package:kohntri_os_hq/services/csv_content_importer.dart';
import 'package:kohntri_os_hq/services/daily_challenge_service.dart';
import 'package:kohntri_os_hq/services/language_question_service.dart';
import 'package:kohntri_os_hq/services/question_service.dart';
import 'package:kohntri_os_hq/shared/widgets/auto_scroll_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:audioplayers/audioplayers.dart';
import 'package:kohntri_os_hq/services/question_review_queue.dart';

class AddEditQuestionScreen extends StatefulWidget {
  final Question? question;
  final DailyChallengeQuestion? dailyQuestion;
  final LanguageQuestion? languageQuestion;
  final String? initialCategory;
  final bool isDailyChallenge;
  final int? defaultPosition;
  final String? initialLanguageId;
  final String? initialThemeId;
  final String? languageName;
  final String? themeName;

  const AddEditQuestionScreen({
    super.key,
    this.question,
    this.dailyQuestion,
    this.languageQuestion,
    this.initialCategory,
    this.isDailyChallenge = false,
    this.defaultPosition,
    this.initialLanguageId,
    this.initialThemeId,
    this.languageName,
    this.themeName,
  });

  @override
  State<AddEditQuestionScreen> createState() => _AddEditQuestionScreenState();
}

class _AddEditQuestionScreenState extends State<AddEditQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _explanationController = TextEditingController();
  final _scenarioController = TextEditingController();
  final _wrongConsequenceController = TextEditingController();
  final _culturalContextController = TextEditingController();

  List<TextEditingController> _optionControllers = [];
  List<XFile?> _selectedImages = [];
  List<Uint8List?> _selectedImageBytes = [];

  int _correctAnswerIndex = 0;
  String _selectedCategory = '';
  QuestionType _selectedType = QuestionType.multipleChoice;
  int _points = 10;
  bool _isLoading = false;
  List<String?> _sentenceSegments = [];
  List<Map<String, dynamic>> _wordBank = [];
  List<MapEntry<int, String>> _blankMappings = [];
  List<TextEditingController> _matchLeftControllers = [];
  List<TextEditingController> _matchRightControllers = [];
  PlatformFile? _audioFile;
  String? _existingAudioUrl;
  double? _audioDuration;
  double _trimStart = 0.0;
  double _trimEnd = 0.0;
  bool _isLoadingDuration = false;
  AudioPlayer? _previewPlayer;
  bool _isPreviewPlaying = false;
  Timer? _fadeTimer;
  int _position = 1;

  String? _selectedLanguageId;
  String? _selectedThemeId;
  List<Map<String, dynamic>> _languages = [];
  List<LanguageTheme> _themes = [];

  final DailyChallengeService _dailyService = DailyChallengeService();
  final QuestionService _questionService = QuestionService();
  final LanguageQuestionService _langService = LanguageQuestionService();
  final ImagePicker _picker = ImagePicker();

  Map<Difficulty, int> _difficultyCounts = {};
  Difficulty? _selectedDifficulty;
  int? _nextLevel;
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _levelController = TextEditingController();

  bool get _isLanguageMode =>
      _selectedCategory == 'Languages' ||
      widget.languageQuestion != null ||
      widget.initialLanguageId != null ||
      widget.initialThemeId != null ||
      widget.languageName != null ||
      widget.themeName != null;

  // ---- Review queue ----
  List<QueuedQuestion> _queue = [];
  int _queueIndex = -1;
  bool _useFileLevel = false;
  String? _queueNote;
  int _formVersion = 0;
  final ScrollController _scrollController = ScrollController();
  bool get _queueActive => _queueIndex >= 0 && _queueIndex < _queue.length;
  bool get _isGeneralMode => !widget.isDailyChallenge && !_isLanguageMode;

  Map<String, Set<int>> _existingLevels = {
    'easy': <int>{},
    'medium': <int>{},
    'hard': <int>{},
  };

  // Design tokens
  static const _primary = Color(0xFF1A5276);
  static const _surface = Color(0xFFF7F9FC);
  static const _cardRadius = 14.0;

  @override
  void initState() {
    super.initState();

    if (widget.dailyQuestion != null) {
      _loadDailyForEdit();
    } else if (widget.languageQuestion != null) {
      _loadLanguageForEdit();
    } else if (widget.question != null) {
      _loadQuestionForEdit();
      if (widget.initialLanguageId != null || widget.initialThemeId != null) {
        _selectedCategory = 'Languages';
        _selectedLanguageId = widget.initialLanguageId;
        _selectedThemeId = widget.initialThemeId;
        _loadLanguagePositionForEdit();
      } else {
        _loadExistingLevels();
      }
    } else {
      if (widget.initialCategory != null) {
        _selectedCategory = widget.initialCategory!;
      }
      if (widget.initialLanguageId != null || widget.initialThemeId != null) {
        _selectedCategory = 'Languages';
      }
      if (widget.isDailyChallenge && widget.defaultPosition != null) {
        _position = widget.defaultPosition!;
        _positionController.text = _position.toString();
      }
      if (widget.initialThemeId != null) {
        _selectedThemeId = widget.initialThemeId!;
      }
      if (widget.initialLanguageId != null) {
        _selectedLanguageId = widget.initialLanguageId!;
      }
      _updateOptionsForType();
      _initializeNewQuestionData();
    }
  }

  Future<void> _initializeNewQuestionData() async {
    if (_isLanguageMode) {
      if (widget.languageName != null) {
        _selectedLanguageId = await _langService.getLanguageIdByName(
          widget.languageName!,
        );
      }
      await _loadLanguages();
      if (_selectedLanguageId != null) {
        if (widget.themeName != null) {
          _selectedThemeId = await _langService.getThemeIdByNameAndLanguage(
            widget.themeName!,
            _selectedLanguageId!,
          );
        }
        if (_selectedThemeId != null) {
          await _loadThemesForLanguage(_selectedLanguageId!);
          await _updateNextPosition();
        }
      }
      return;
    }
    if (widget.isDailyChallenge) {
      await _updateNextPosition();
      await _loadExistingLevels();
      return;
    }
    await _loadExistingLevels();
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _previewPlayer?.dispose();
    for (var c in _matchLeftControllers) c.dispose();
    for (var c in _matchRightControllers) c.dispose();
    _positionController.dispose();
    _scenarioController.dispose();
    _wrongConsequenceController.dispose();
    _culturalContextController.dispose();
    _levelController.dispose();
    _scrollController.dispose();
    for (var c in _optionControllers) c.dispose();
    _questionController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Review queue
  // ─────────────────────────────────────────────

  Future<void> _startReviewQueue() async {
    if (_isLanguageMode &&
        (_selectedLanguageId == null || _selectedThemeId == null)) {
      _toast('Open this screen from a language theme first.', error: true);
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: true,
    );
    if (result == null || result.files.first.bytes == null) return;

    final file = result.files.first;
    ReviewQueueResult parsed;
    try {
      final isExcel = file.name.toLowerCase().endsWith('.xlsx');
      var bytes = file.bytes!;
      if (isExcel) {
        final sheets = XlsxReader.read(bytes);
        if (sheets.isEmpty) {
          throw const FormatException('The Excel file has no data.');
        }
        var chosen = sheets;
        if (sheets.length > 1) {
          final picked = await _pickSheets(sheets);
          if (picked == null) return;
          chosen = picked;
        }
        bytes = XlsxReader.toCsv(chosen);
      }
      parsed = ReviewQueueParser.parse(bytes);
    } catch (e) {
      if (!mounted) return;
      _toast(
        'Could not read file. Use .xlsx or .csv with template columns. ($e)',
        error: true,
      );
      return;
    }
    if (parsed.items.isEmpty) {
      if (!mounted) return;
      _toast('No questions found in the file.');
      return;
    }

    final settings = await _askQueueSettings(parsed);
    if (settings == null || !mounted) return;
    setState(() {
      _queue = parsed.items;
      _queueIndex = (settings['start'] as int) - 1;
      _useFileLevel = settings['useFileLevel'] as bool;
      _isLoading = true;
    });
    await _loadQueueItem();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<Map<String, dynamic>?> _askQueueSettings(ReviewQueueResult parsed) {
    final startCtrl = TextEditingController(text: '1');
    var useFileLevel = false;
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Start review queue'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${parsed.items.length} questions ready'
                  '${parsed.skipped.isEmpty ? '' : '  ·  ${parsed.skipped.length} rows skipped'}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                if (parsed.skipped.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...parsed.skipped
                      .take(6)
                      .map(
                        (s) => Text(
                          s,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: startCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Start at item',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use Level numbers from file'),
                  subtitle: const Text('Off = next free level in the database'),
                  value: useFileLevel,
                  onChanged: (v) => setLocal(() => useFileLevel = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'start': (int.tryParse(startCtrl.text) ?? 1)
                    .clamp(1, parsed.items.length)
                    .toInt(),
                'useFileLevel': useFileLevel,
              }),
              child: const Text('Start review'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<XlsxSheet>?> _pickSheets(List<XlsxSheet> sheets) {
    return showDialog<List<XlsxSheet>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Which sheet?'),
        children: [
          for (final s in sheets)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, [s]),
              child: Text('${s.name}  ·  ${s.rows.length - 1} rows'),
            ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, sheets),
            child: const Text('All sheets combined'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadQueueItem() async {
    final item = _queue[_queueIndex];

    _audioFile = null;
    _existingAudioUrl = null;
    _audioDuration = null;
    _trimStart = 0.0;
    _trimEnd = 0.0;
    _selectedDifficulty =
        item.difficulty ?? _selectedDifficulty ?? Difficulty.medium;

    if (_isLanguageMode) {
      await _updateNextPosition();
      if (!mounted) return;
      _queueNote = null;
    } else {
      await _loadExistingLevels();
      if (!mounted) return;
      _queueNote = null;
      if (_useFileLevel && item.level != null) {
        final taken = _existingLevels[_selectedDifficulty!.name] ?? <int>{};
        if (taken.contains(item.level)) {
          _queueNote =
              'File level ${item.level} already used in ${_selectedDifficulty!.name}. '
              'Next free ($_nextLevel) selected.';
        } else {
          _nextLevel = item.level;
          _levelController.text = item.level.toString();
        }
      }
    }

    _selectedType = item.type;
    _updateOptionsForType();

    switch (item.type) {
      case QuestionType.multipleChoice:
        for (final c in _optionControllers) c.dispose();
        _optionControllers = item.options
            .map((o) => TextEditingController(text: o))
            .toList();
        _correctAnswerIndex = item.correctIndex;
        break;
      case QuestionType.trueFalse:
        _correctAnswerIndex = item.correctIndex;
        break;
      case QuestionType.textInput:
        _optionControllers[0].text = item.correctText;
        break;
      case QuestionType.fillBlank:
        final parts = item.question.split(RegExp(r'_{3,}'));
        _sentenceSegments = [];
        for (var i = 0; i < parts.length; i++) {
          _sentenceSegments.add(parts[i]);
          if (i < parts.length - 1) _sentenceSegments.add(null);
        }
        _wordBank = [
          for (final w in item.options) {'id': _generateWordId(), 'text': w},
        ];
        String? correctId;
        for (final w in _wordBank) {
          if (ReviewQueueParser.norm(w['text'] as String) ==
              ReviewQueueParser.norm(item.correctText)) {
            correctId = w['id'] as String;
          }
        }
        if (correctId == null && item.correctText.isNotEmpty) {
          correctId = _generateWordId();
          _wordBank.add({'id': correctId, 'text': item.correctText});
        }
        final blanks = _getBlankIndices();
        _blankMappings = [
          if (blanks.isNotEmpty && correctId != null)
            MapEntry(blanks.first, correctId),
        ];
        break;
      default:
        break;
    }

    _questionController.text = item.question;
    _scenarioController.text = item.scenario;
    _explanationController.text = item.explanation;
    _wrongConsequenceController.text = item.wrongConsequence;
    _culturalContextController.text = item.culturalContext;
    _points = item.points;

    setState(() => _formVersion++);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _advanceQueue() async {
    if (_queueIndex + 1 >= _queue.length) {
      final total = _queue.length;
      setState(() {
        _queue = [];
        _queueIndex = -1;
        _queueNote = null;
      });
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Queue complete'),
          content: Text('All $total items reviewed and processed.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
      return;
    }
    setState(() => _queueIndex++);
    await _loadQueueItem();
  }

  Future<void> _previousQueueItem() async {
    if (_queueIndex <= 0) return;
    setState(() {
      _isLoading = true;
      _queueIndex--;
    });
    await _loadQueueItem();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _skipQueueItem() async {
    setState(() => _isLoading = true);
    await _advanceQueue();
    if (mounted) setState(() => _isLoading = false);
  }

  void _stopQueue() {
    final at = _queueIndex + 1;
    setState(() {
      _queue = [];
      _queueIndex = -1;
      _queueNote = null;
    });
    _toast(
      'Queue stopped at item $at. Reload file and start at $at to resume.',
    );
  }

  // ─────────────────────────────────────────────
  // Shared helpers
  // ─────────────────────────────────────────────

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadExistingLevels() async {
    if (_selectedCategory.isEmpty) return;
    final rows = await _questionService.getLevelNumbersByDifficulty(
      _selectedCategory,
    );
    if (!mounted) return;
    setState(() {
      _existingLevels = rows;
      if (widget.question == null && _selectedDifficulty != null) {
        final existing = rows[_selectedDifficulty!.name] ?? <int>{};
        final maxLevel = existing.isEmpty
            ? 0
            : existing.reduce((a, b) => a > b ? a : b);
        _nextLevel = maxLevel + 1;
        _levelController.text = _nextLevel.toString();
      }
    });
  }

  Future<void> _fadeIn() async {
    const steps = 10;
    const stepDuration = Duration(milliseconds: 50);
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(stepDuration);
      if (_previewPlayer != null && mounted) {
        _previewPlayer!.setVolume(i / steps);
      } else {
        break;
      }
    }
  }

  Future<void> _fadeOut() async {
    const steps = 10;
    const stepDuration = Duration(milliseconds: 50);
    for (int i = steps; i >= 0; i--) {
      await Future.delayed(stepDuration);
      if (_previewPlayer != null && mounted) {
        _previewPlayer!.setVolume(i / steps);
      } else {
        break;
      }
    }
    await _previewPlayer?.stop();
    if (mounted) setState(() => _isPreviewPlaying = false);
  }

  void _showPreview() {
    final question = _buildCurrentObject(forPreview: true);
    final questionData = question.toSupabase();
    if (_audioFile != null) {
      questionData['local_audio_path'] = _audioFile!.path;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewQuestionScreen(questionData: questionData),
      ),
    );
  }

  Future<void> _previewAudio() async {
    if (_audioFile == null || _audioDuration == null) return;
    try {
      await _stopPreview();
      _previewPlayer = AudioPlayer();
      _previewPlayer!.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() => _isPreviewPlaying = state == PlayerState.playing);
        }
      });
      Source source = _audioFile!.bytes != null
          ? BytesSource(_audioFile!.bytes!)
          : DeviceFileSource(_audioFile!.path!);
      await _previewPlayer!.setSource(source);
      if (_trimStart > 0) {
        await _previewPlayer!.seek(
          Duration(milliseconds: (_trimStart * 1000).round()),
        );
      }
      await _previewPlayer!.setVolume(0);
      await _previewPlayer!.resume();
      _fadeIn();
      _previewPlayer!.onPositionChanged.listen((pos) {
        if (_trimEnd > 0 && pos.inMilliseconds >= (_trimEnd * 1000).round()) {
          _fadeOut();
        }
      });
    } catch (e) {
      _toast('Could not preview audio: $e', error: true);
    }
  }

  Future<void> _stopPreview() async {
    if (_previewPlayer != null) {
      await _fadeOut();
    } else if (mounted) {
      setState(() => _isPreviewPlaying = false);
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null) {
      setState(() {
        _audioFile = result.files.first;
        _existingAudioUrl = null;
        _audioDuration = null;
        _isLoadingDuration = true;
      });
      try {
        final player = AudioPlayer();
        final source = _audioFile!.bytes != null
            ? BytesSource(_audioFile!.bytes!)
            : DeviceFileSource(_audioFile!.path!);
        await player.setSource(source);
        final duration = await player.getDuration();
        await player.dispose();
        if (duration != null && mounted) {
          setState(() {
            _audioDuration = duration.inMilliseconds / 1000.0;
            _trimStart = 0.0;
            _trimEnd = _audioDuration!;
          });
        }
      } catch (e) {
        if (kDebugMode) print('Error getting audio duration: $e');
      } finally {
        if (mounted) setState(() => _isLoadingDuration = false);
      }
    }
  }

  Future<void> _loadLanguages() async {
    final data = await _langService.getLanguages();
    setState(() => _languages = data);
  }

  Future<void> _loadThemesForLanguage(String languageId) async {
    final themes = await _langService.getThemesForLanguage(languageId);
    setState(() => _themes = themes);
  }

  List<int> _getBlankIndices() => List.generate(
    _sentenceSegments.length,
    (i) => i,
  ).where((i) => _sentenceSegments[i] == null).toList();

  String _generateWordId() =>
      'w${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}';

  void _updateOptionsForType() {
    for (var c in _optionControllers) c.dispose();
    _optionControllers = [];
    for (var c in _matchLeftControllers) c.dispose();
    for (var c in _matchRightControllers) c.dispose();
    _matchLeftControllers = [];
    _matchRightControllers = [];
    _correctAnswerIndex = 0;
    _selectedImages.clear();

    switch (_selectedType) {
      case QuestionType.trueFalse:
        _optionControllers = [
          TextEditingController(text: 'True'),
          TextEditingController(text: 'False'),
        ];
        _selectedImages = [null, null];
        break;
      case QuestionType.multipleChoice:
        _optionControllers = List.generate(4, (_) => TextEditingController());
        _selectedImages = [];
        break;
      case QuestionType.imageChoice:
        _optionControllers = List.generate(
          4,
          (i) => TextEditingController(text: 'Option ${i + 1}'),
        );
        _selectedImages = [null];
        break;
      case QuestionType.dragAndDrop:
        _optionControllers = [TextEditingController()];
        _selectedImages = [null];
        break;
      case QuestionType.textInput:
        _optionControllers = [TextEditingController()];
        _selectedImages = [];
        break;
      case QuestionType.fillBlank:
        _sentenceSegments = ['The ', null, ' is on the ', null, '.'];
        _wordBank = [
          {'id': _generateWordId(), 'text': 'cat'},
          {'id': _generateWordId(), 'text': 'mat'},
          {'id': _generateWordId(), 'text': 'dog'},
        ];
        _blankMappings = [
          MapEntry(1, _wordBank[0]['id']!),
          MapEntry(3, _wordBank[1]['id']!),
        ];
        break;
      case QuestionType.matchPairs:
        _matchLeftControllers = [TextEditingController()];
        _matchRightControllers = [TextEditingController()];
        break;
      case QuestionType.audioGuess:
        _optionControllers = [TextEditingController()];
        _selectedImages = [];
        break;
    }
    _selectedImageBytes = List<Uint8List?>.filled(_selectedImages.length, null);
  }

  dynamic _buildCurrentObject({bool forPreview = false}) {
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    Map<String, dynamic>? typeData;

    if (_selectedType == QuestionType.matchPairs) {
      final pairs = <Map<String, String>>[];
      for (int i = 0; i < _matchLeftControllers.length; i++) {
        final left = _matchLeftControllers[i].text.trim();
        final right = _matchRightControllers[i].text.trim();
        if (left.isNotEmpty && right.isNotEmpty) {
          pairs.add({'left': left, 'right': right});
        }
      }
      if (pairs.isNotEmpty) {
        typeData = {
          'pairs': pairs,
          'correctMatches': List.generate(
            pairs.length,
            (i) => {'leftIndex': i, 'rightIndex': i},
          ),
        };
      }
    } else if (_selectedType == QuestionType.fillBlank) {
      final validBlankIndices = _getBlankIndices().toSet();
      typeData = {
        'sentenceParts': _sentenceSegments,
        'wordBank': _wordBank,
        'correctAnswers': {
          for (final e in _blankMappings)
            if (validBlankIndices.contains(e.key)) e.key.toString(): e.value,
        },
      };
    } else if (_selectedType == QuestionType.audioGuess) {
      if (_existingAudioUrl != null)
        typeData = {'audio_url': _existingAudioUrl};
    }

    if (widget.isDailyChallenge) {
      return DailyChallengeQuestion(
        id: widget.dailyQuestion?.id ?? '',
        dailyChallengeId: DailyChallengeService.activeDailyChallengeId,
        question: _questionController.text.trim(),
        options: options,
        correctAnswerIndex: _correctAnswerIndex,
        questionType: _selectedType.name,
        imageUrl: null,
        audioUrl: typeData?['audio_url'],
        explanation: _explanationController.text.trim(),
        points: _points,
        position: _position,
        trimStart: _trimStart,
        trimEnd: _trimEnd,
      );
    } else if (_isLanguageMode) {
      return LanguageQuestion(
        id: widget.languageQuestion?.id ?? widget.question?.id ?? '',
        languageTypeId: _selectedLanguageId ?? '',
        themeId: _selectedThemeId ?? '',
        question: _questionController.text.trim(),
        options: options,
        correctAnswerIndex: _correctAnswerIndex,
        type: _selectedType.name,
        explanation: _explanationController.text.trim(),
        points: _points,
        position: _position,
        imageUrl: null,
        audioUrl: typeData?['audio_url'],
        trimStart: _trimStart,
        trimEnd: _trimEnd,
        createdAt: null,
        typeData: typeData,
      );
    } else {
      final id = forPreview ? 'preview' : (widget.question?.id ?? '');
      Map<String, String>? imageUrls;
      if (_selectedType == QuestionType.imageChoice ||
          _selectedType == QuestionType.dragAndDrop) {
        imageUrls = widget.question?.imageUrls ?? {};
      }
      return Question(
        id: id,
        question: _questionController.text.trim(),
        options: options,
        correctAnswerIndex: _correctAnswerIndex,
        category: _selectedCategory,
        explanation: _explanationController.text.trim(),
        type: _selectedType,
        imageUrls: imageUrls,
        points: _points,
        difficulty: _selectedDifficulty ?? Difficulty.medium,
        typeData: typeData,
        scenario: _scenarioController.text.trim().isEmpty
            ? null
            : _scenarioController.text.trim(),
        wrongConsequence: _wrongConsequenceController.text.trim().isEmpty
            ? null
            : _wrongConsequenceController.text.trim(),
        culturalContext: _culturalContextController.text.trim().isEmpty
            ? null
            : _culturalContextController.text.trim(),
      );
    }
  }

  // ─────────────────────────────────────────────
  // Save (logic unchanged)
  // ─────────────────────────────────────────────

  Future<void> _saveQuestion() async {
    if (_selectedCategory.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Select a category before saving'),
      backgroundColor: Colors.red,
    ),
  );
  return;
}
    if (!_formKey.currentState!.validate()) return;

    if (_queueActive &&
        (_selectedType == QuestionType.multipleChoice ||
            _selectedType == QuestionType.trueFalse) &&
        (_correctAnswerIndex < 0 ||
            _correctAnswerIndex >= _optionControllers.length)) {
      _toast('Select the correct option first.', error: true);
      return;
    }

    if (_selectedType == QuestionType.matchPairs) {
      final validPairs = <Map<String, String>>[];
      for (int i = 0; i < _matchLeftControllers.length; i++) {
        final left = _matchLeftControllers[i].text.trim();
        final right = _matchRightControllers[i].text.trim();
        if (left.isNotEmpty && right.isNotEmpty) {
          validPairs.add({'left': left, 'right': right});
        }
      }
      if (validPairs.isEmpty) {
        _toast('Add at least one valid pair (left + right).', error: true);
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (widget.isDailyChallenge) {
        final base = _buildCurrentObject() as DailyChallengeQuestion;
        String? audioUrl = base.audioUrl;
        if (_audioFile != null) {
          final userId =
              Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
          final tempId = DateTime.now().millisecondsSinceEpoch.toString();
          audioUrl = await _uploadAudio(
            _audioFile!,
            userId,
            tempId,
            isDaily: true,
          );
          if (audioUrl == null) throw Exception('Audio upload failed');
        }
        final finalQuestion = DailyChallengeQuestion(
          id: base.id,
          dailyChallengeId: base.dailyChallengeId,
          question: base.question,
          options: base.options,
          correctAnswerIndex: base.correctAnswerIndex,
          questionType: base.questionType,
          imageUrl: base.imageUrl,
          audioUrl: audioUrl,
          explanation: base.explanation,
          points: base.points,
          position: base.position,
          trimStart: _trimStart,
          trimEnd: _trimEnd,
        );
        if (widget.dailyQuestion == null) {
          await _dailyService.addQuestion(finalQuestion);
        } else {
          await _dailyService.updateQuestion(finalQuestion);
        }
      } else if (_isLanguageMode) {
        if (_selectedLanguageId == null || _selectedLanguageId!.isEmpty) {
          throw Exception('Language ID is missing.');
        }
        if (_selectedThemeId == null || _selectedThemeId!.isEmpty) {
          throw Exception('Theme ID is missing.');
        }
        final base = _buildCurrentObject() as LanguageQuestion;
        String? imageUrl = widget.languageQuestion?.imageUrl;
        if (_selectedType == QuestionType.imageChoice ||
            _selectedType == QuestionType.dragAndDrop) {
          for (int i = 0; i < _selectedImages.length; i++) {
            final file = _selectedImages[i];
            if (file != null) {
              final userId =
                  Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
              final tempId = DateTime.now().millisecondsSinceEpoch.toString();
              final url = await _uploadImage(
                file,
                userId,
                tempId,
                isLanguage: true,
              );
              if (url == null) throw Exception('Image upload failed');
              imageUrl = url;
              break;
            }
          }
        }
        String? audioUrl = base.audioUrl;
        if (_audioFile != null) {
          final userId =
              Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
          final tempId = DateTime.now().millisecondsSinceEpoch.toString();
          audioUrl = await _uploadAudio(
            _audioFile!,
            userId,
            tempId,
            isLanguage: true,
          );
          if (audioUrl == null) throw Exception('Audio upload failed');
        } else if (_existingAudioUrl != null) {
          audioUrl = _existingAudioUrl;
        }
        final finalQuestion = LanguageQuestion(
          id: base.id,
          languageTypeId: _selectedLanguageId!,
          themeId: _selectedThemeId!,
          question: base.question,
          options: base.options,
          correctAnswerIndex: base.correctAnswerIndex,
          type: base.type,
          explanation: base.explanation,
          points: base.points,
          position: base.position,
          imageUrl: imageUrl,
          audioUrl: audioUrl,
          trimStart: _trimStart,
          trimEnd: _trimEnd,
          typeData: base.typeData,
        );
        final editId = widget.languageQuestion?.id ?? widget.question?.id;
        if (editId == null || editId.isEmpty) {
          await _langService.addQuestion(finalQuestion);
        } else {
          await _langService.updateQuestion(finalQuestion);
        }
      } else {
        final base = _buildCurrentObject() as Question;
        List<String> optionsList;
        if (_selectedType == QuestionType.multipleChoice) {
          optionsList = _optionControllers
              .map((ctrl) => ctrl.text.trim())
              .where((text) => text.isNotEmpty)
              .toList();
          if (optionsList.length < 2) {
            throw Exception('At least two options required');
          }
        } else if (_selectedType == QuestionType.trueFalse) {
          optionsList = ['True', 'False'];
        } else {
          optionsList = base.options;
        }

        Map<String, String>? imageUrls;
        if (_selectedType == QuestionType.imageChoice ||
            _selectedType == QuestionType.dragAndDrop) {
          imageUrls = {};
          if (widget.question?.imageUrls != null) {
            imageUrls.addAll(widget.question!.imageUrls!);
          }
          final userId =
              Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
          final tempId = DateTime.now().millisecondsSinceEpoch.toString();
          for (int i = 0; i < _selectedImages.length; i++) {
            final file = _selectedImages[i];
            if (file != null) {
              final url = await _uploadImage(file, userId, tempId);
              if (url == null) {
                throw Exception('Image upload failed for option ${i + 1}');
              }
              imageUrls[i.toString()] = url;
            }
          }
        }

        Map<String, dynamic>? typeData = base.typeData;
        if (_audioFile != null) {
          final userId =
              Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
          final tempId = DateTime.now().millisecondsSinceEpoch.toString();
          final url = await _uploadAudio(_audioFile!, userId, tempId);
          if (url != null) {
            typeData ??= {};
            typeData['audio_url'] = url;
            typeData['trim_start'] = _trimStart;
            typeData['trim_end'] = _trimEnd;
          } else {
            throw Exception('Audio upload failed');
          }
        } else if (_existingAudioUrl != null && _audioFile == null) {
          typeData ??= {};
          typeData['audio_url'] = _existingAudioUrl;
          typeData['trim_start'] = _trimStart;
          typeData['trim_end'] = _trimEnd;
        }

        final resolvedDifficulty = _selectedDifficulty ?? base.difficulty;
        final resolvedLevel = _nextLevel ?? 1;
        final isNew = widget.question == null;

        if (isNew) {
          final existing = await Supabase.instance.client
              .from('level_questions')
              .select('question_id')
              .eq('category', _selectedCategory)
              .eq('difficulty', resolvedDifficulty.name)
              .eq('level_number', resolvedLevel);
          if (existing.isNotEmpty) {
            if (mounted) {
              setState(() => _isLoading = false);
              _toast(
                'Level $resolvedLevel (${resolvedDifficulty.name}) already has a question.',
                error: true,
              );
            }
            return;
          }
        } else {
          final existing = await Supabase.instance.client
              .from('level_questions')
              .select('question_id')
              .eq('category', _selectedCategory)
              .eq('difficulty', resolvedDifficulty.name)
              .eq('level_number', resolvedLevel)
              .neq('question_id', widget.question!.id);
          if (existing.isNotEmpty) {
            if (mounted) {
              setState(() => _isLoading = false);
              _toast(
                'Level $resolvedLevel (${resolvedDifficulty.name}) already has a different question.',
                error: true,
              );
            }
            return;
          }
        }

        final question = Question(
          id: widget.question?.id ?? '',
          question: base.question,
          options: optionsList,
          correctAnswerIndex: base.correctAnswerIndex,
          category: base.category,
          explanation: base.explanation,
          type: base.type,
          imageUrls: imageUrls,
          points: base.points,
          difficulty: resolvedDifficulty,
          level: resolvedLevel,
          typeData: typeData,
          scenario: base.scenario,
          wrongConsequence: base.wrongConsequence,
          culturalContext: base.culturalContext,
        );

        if (isNew) {
          final ok = await _questionService.addQuestion(question);
          if (!ok) throw Exception('Save failed. Nothing was added.');
        } else {
          await _questionService.updateQuestion(question);
        }
      }

      if (mounted) {
        _toast('Saved!');
        if (_queueActive) {
          await _advanceQueue();
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e, stack) {
      if (kDebugMode) {
        print('❌ Save error: $e');
        print(stack);
      }
      if (mounted) _toast('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _uploadImage(
    XFile image,
    String userId,
    String tempId, {
    bool isDaily = false,
    bool isLanguage = false,
  }) async {
    try {
      String bucket;
      if (isDaily) {
        bucket = 'daily_challenge_images';
      } else if (isLanguage) {
        bucket = 'language_question_images';
      } else {
        bucket = 'question_images';
      }
      String fileExt = '.jpg';
      final name = image.name;
      if (name.isNotEmpty) {
        final ext = path.extension(name);
        if (ext.isNotEmpty) fileExt = ext;
      }
      final fileName =
          '${isDaily ? 'daily' : (isLanguage ? 'lang' : 'question')}_${tempId}_${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final bytes = await image.readAsBytes();
      await Supabase.instance.client.storage
          .from(bucket)
          .uploadBinary(fileName, bytes);
      return Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(fileName);
    } catch (e) {
      if (kDebugMode) print('❌ Upload error: $e');
      return null;
    }
  }

  Future<String?> _uploadAudio(
    PlatformFile audio,
    String userId,
    String tempId, {
    bool isDaily = false,
    bool isLanguage = false,
  }) async {
    try {
      String bucket;
      if (isDaily) {
        bucket = 'daily_challenge_audio';
      } else if (isLanguage) {
        bucket = 'language_question_audio';
      } else {
        bucket = 'question_audio';
      }
      final fileName =
          '${isDaily ? 'daily' : (isLanguage ? 'lang' : 'question')}_${tempId}_${DateTime.now().millisecondsSinceEpoch}_${audio.name}';
      Uint8List bytes;
      if (kIsWeb) {
        if (audio.bytes != null) {
          bytes = audio.bytes!;
        } else {
          throw Exception('No bytes available on web');
        }
      } else {
        bytes = audio.bytes ?? await File(audio.path!).readAsBytes();
      }
      await Supabase.instance.client.storage
          .from(bucket)
          .uploadBinary(fileName, bytes);
      return Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(fileName);
    } catch (e) {
      if (kDebugMode) print('Upload error: $e');
      return null;
    }
  }

  Future<void> _pickImage(int index) async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      while (_selectedImages.length <= index) _selectedImages.add(null);
      while (_selectedImageBytes.length <= index) _selectedImageBytes.add(null);
      _selectedImages[index] = picked;
      _selectedImageBytes[index] = bytes;
    });
  }

  // ─────────────────────────────────────────────
  // Load for edit (logic mostly unchanged)
  // ─────────────────────────────────────────────

  void _loadQuestionForEdit() {
    final q = widget.question!;
    _selectedDifficulty = q.difficulty;
    _nextLevel = q.level ?? 1;
    _levelController.text = _nextLevel.toString();
    _questionController.text = q.question;
    _scenarioController.text = q.scenario ?? '';
    _wrongConsequenceController.text = q.wrongConsequence ?? '';
    _culturalContextController.text = q.culturalContext ?? '';
    _explanationController.text = q.explanation;
    _selectedCategory = q.category;
    _selectedType = q.type;
    _correctAnswerIndex = q.correctAnswerIndex;
    _points = q.points;
    _optionControllers = q.options
        .map((opt) => TextEditingController(text: opt))
        .toList();
    if (q.imageUrls != null) {
      final count = q.imageUrls!.length;
      _optionControllers = List.generate(
        count,
        (i) => TextEditingController(text: q.options[i]),
      );
      _selectedImages = List.generate(count, (_) => null);
      _selectedImageBytes = List<Uint8List?>.filled(count, null);
    }
    if (_optionControllers.isEmpty) _updateOptionsForType();
    if (q.typeData != null) {
      final data = q.typeData!;
      _existingAudioUrl = data['audio_url'] as String?;
      _trimStart = (data['trim_start'] as num?)?.toDouble() ?? 0.0;
      _trimEnd = (data['trim_end'] as num?)?.toDouble() ?? 0.0;
      _sentenceSegments = List<String?>.from(data['sentenceParts'] ?? []);
      _wordBank = List<Map<String, dynamic>>.from(data['wordBank'] ?? []);
      final correct = data['correctAnswers'] as Map<String, dynamic>? ?? {};
      final validBlanks = _getBlankIndices().toSet();
      _blankMappings = <MapEntry<int, String>>[];
      for (final e in correct.entries) {
        final idx = int.tryParse(e.key);
        if (idx == null || !validBlanks.contains(idx)) continue;
        _blankMappings.add(MapEntry(idx, e.value as String));
      }
      if (_selectedType == QuestionType.matchPairs) {
        final pairsList = (data['pairs'] as List?) ?? [];
        if (pairsList.isNotEmpty) {
          for (final c in _matchLeftControllers) c.dispose();
          for (final c in _matchRightControllers) c.dispose();
          _matchLeftControllers = pairsList.map((p) {
            final left = (p as Map)['left']?.toString() ?? '';
            return TextEditingController(text: left);
          }).toList();
          _matchRightControllers = pairsList.map((p) {
            final right = (p as Map)['right']?.toString() ?? '';
            return TextEditingController(text: right);
          }).toList();
        }
      }
    }
  }

  void _loadDailyForEdit() {
    final q = widget.dailyQuestion!;
    _questionController.text = q.question;
    _explanationController.text = q.explanation ?? '';
    _selectedType = QuestionType.fromString(q.questionType);
    _correctAnswerIndex = q.correctAnswerIndex;
    _points = q.points;
    _position = q.position;
    _positionController.text = _position.toString();
    _trimStart = q.trimStart ?? 0.0;
    _trimEnd = q.trimEnd ?? 0.0;
    _existingAudioUrl = q.audioUrl;
    _optionControllers = q.options
        .map((opt) => TextEditingController(text: opt))
        .toList();
    _updateOptionsForType();
  }

  void _loadLanguageForEdit() {
    final q = widget.languageQuestion!;
    _selectedCategory = 'Languages';
    _questionController.text = q.question;
    _explanationController.text = q.explanation ?? '';
    _selectedType = QuestionType.fromString(q.type);
    _correctAnswerIndex = q.correctAnswerIndex;
    _points = q.points;
    _position = q.position;
    _positionController.text = _position.toString();
    _trimStart = q.trimStart ?? 0.0;
    _trimEnd = q.trimEnd ?? 0.0;
    _existingAudioUrl = q.audioUrl;
    _selectedLanguageId = q.languageTypeId;
    _selectedThemeId = q.themeId;
    _optionControllers = q.options
        .map((opt) => TextEditingController(text: opt))
        .toList();
    _loadLanguages();
    _loadThemesForLanguage(q.languageTypeId);
    _updateOptionsForType();
  }

  Future<void> _loadLanguagePositionForEdit() async {
    await _loadLanguages();
    if (_selectedLanguageId != null) {
      await _loadThemesForLanguage(_selectedLanguageId!);
    }
    if (_selectedThemeId == null) return;
    final questions = await _langService.getQuestionsForTheme(
      _selectedThemeId!,
    );
    LanguageQuestion? match;
    for (final item in questions) {
      if (item.id == widget.question!.id) {
        match = item;
        break;
      }
    }
    if (match == null || !mounted) return;
    setState(() {
      _position = match!.position;
      _positionController.text = match!.position.toString();
    });
  }

  Future<void> _updateNextPosition() async {
    if (widget.isDailyChallenge) {
      final next = await _dailyService.getNextPosition();
      setState(() {
        _position = next;
        _positionController.text = _position.toString();
      });
    } else if (_isLanguageMode && _selectedThemeId != null) {
      final max = await _langService.getMaxPositionForTheme(_selectedThemeId!);
      setState(() {
        _position = max + 1;
        _positionController.text = _position.toString();
      });
    }
  }

  Future<void> _openCsvImport() async {
    CsvImportMode mode;
    if (widget.isDailyChallenge) {
      mode = CsvImportMode.daily;
    } else if (_isLanguageMode) {
      mode = CsvImportMode.language;
    } else {
      mode = CsvImportMode.adventure;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CsvQuestionImporter(
          mode: mode,
          category: _selectedCategory,
          difficulty: _selectedDifficulty,
          languageId: _selectedLanguageId,
          themeId: _selectedThemeId,
          startingPosition: _position,
          dailyChallengeId: DailyChallengeService.activeDailyChallengeId,
        ),
      ),
    );
    if (mounted) {
      await _loadExistingLevels();
      await _updateNextPosition();
    }
  }

  // ─────────────────────────────────────────────
  // UI building blocks
  // ─────────────────────────────────────────────

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required List<Widget> children,
    IconData? icon,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: _primary),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildQueueBanner() {
    final item = _queue[_queueIndex];
    final progress = (_queueIndex + 1) / _queue.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade50, Colors.orange.shade50],
        ),
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_queueIndex + 1} / ${_queue.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'File row ${item.sourceRow}',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.amber.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.amber.shade700,
                ),
              ),
            ),
          ),
          if (_queueNote != null || item.warnings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_queueNote != null)
                    Text(
                      _queueNote!,
                      style: TextStyle(
                        color: Colors.deepOrange[800],
                        fontSize: 12,
                      ),
                    ),
                  for (final w in item.warnings)
                    Text(
                      '⚠ $w',
                      style: TextStyle(
                        color: Colors.deepOrange[800],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          // Navigation row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: (_isLoading || _queueIndex <= 0)
                      ? null
                      : _previousQueueItem,
                  icon: const Icon(Icons.chevron_left, size: 20),
                  label: const Text('Previous'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _isLoading ? null : _skipQueueItem,
                  child: const Text('Skip'),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _stopQueue,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Stop'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextChip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AutoScrollText(
        text: _getContextLabel(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  String _getContextLabel() {
    if (widget.isDailyChallenge) return 'Daily Challenge';
    if (_isLanguageMode) {
      String langName = widget.languageName ?? '?';
      if (widget.languageName == null && _selectedLanguageId != null) {
        final found = _languages.cast<Map<String, dynamic>>().firstWhere(
          (l) => l['id'] == _selectedLanguageId,
          orElse: () => {},
        );
        if (found.isNotEmpty) langName = found['name'] as String;
      }
      String themeName = widget.themeName ?? '?';
      if (widget.themeName == null && _selectedThemeId != null) {
        final found = _themes.firstWhere(
          (t) => t.id == _selectedThemeId,
          orElse: () =>
              LanguageTheme(id: '', name: '', languageTypeId: '', position: 0),
        );
        if (found.id.isNotEmpty) themeName = found.name;
      }
      return '$langName  →  $themeName';
    }
    return 'Category: ${widget.initialCategory ?? _selectedCategory}';
  }

  Widget _buildTypeSelector() {
    return DropdownButtonFormField<int>(
      value: _selectedType.index,
      decoration: const InputDecoration(
        labelText: 'Question type',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: List.generate(
        QuestionType.values.length,
        (i) => DropdownMenuItem(
          value: i,
          child: Text(QuestionType.values[i].displayName),
        ),
      ),
      onChanged: (val) {
        if (val == null) return;
        setState(() {
          _selectedType = QuestionType.values[val];
          _updateOptionsForType();
        });
      },
    );
  }

  Widget _buildOptionsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_optionControllers.length, (i) {
        final isCorrect = i == _correctAnswerIndex;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCorrect ? Colors.green : Colors.grey.shade300,
              width: isCorrect ? 2 : 1,
            ),
            color: isCorrect ? Colors.green.shade50 : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _optionControllers[i],
                  decoration: InputDecoration(
                    labelText: 'Option ${String.fromCharCode(65 + i)}',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    suffixIcon: isCorrect
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
              ),
              Radio<int>(
                value: i,
                groupValue: _correctAnswerIndex,
                onChanged: (val) => setState(() => _correctAnswerIndex = val!),
                activeColor: Colors.green,
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget? _buildImagePreview(int index) {
    if (index < _selectedImageBytes.length &&
        _selectedImageBytes[index] != null) {
      return Image.memory(
        _selectedImageBytes[index]!,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
      );
    }
    final existingUrl = widget.question?.imageUrls?[index.toString()];
    if (existingUrl != null && existingUrl.isNotEmpty) {
      return Image.network(
        existingUrl,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 28),
      );
    }
    return null;
  }

  Widget _buildImageChoiceFields() {
    if (_optionControllers.isEmpty) return const SizedBox.shrink();
    while (_selectedImages.length < _optionControllers.length) {
      _selectedImages.add(null);
    }
    while (_selectedImages.length > _optionControllers.length) {
      _selectedImages.removeLast();
    }
    if (_correctAnswerIndex >= _optionControllers.length) {
      _correctAnswerIndex = _optionControllers.length - 1;
    }
    if (_correctAnswerIndex < 0) _correctAnswerIndex = 0;

    return Column(
      children: [
        ...List.generate(_optionControllers.length, (i) {
          final isCorrect = i == _correctAnswerIndex;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCorrect ? Colors.green : Colors.grey.shade300,
                width: isCorrect ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _optionControllers[i],
                        decoration: const InputDecoration(
                          labelText: 'Label (optional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    Radio<int>(
                      value: i,
                      groupValue: _correctAnswerIndex,
                      onChanged: (val) =>
                          setState(() => _correctAnswerIndex = val!),
                      activeColor: Colors.green,
                    ),
                    if (_optionControllers.length > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeImageOption(i),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_buildImagePreview(i) != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildImagePreview(i),
                      ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _pickImage(i),
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(
                        _buildImagePreview(i) == null ? 'Pick' : 'Change',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: _addImageOption,
          icon: const Icon(Icons.add),
          label: const Text('Add option'),
        ),
      ],
    );
  }

  void _addImageOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
      _selectedImages.add(null);
      _selectedImageBytes.add(null);
    });
  }

  void _removeImageOption(int index) {
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
      _selectedImages.removeAt(index);
      if (index < _selectedImageBytes.length) {
        _selectedImageBytes.removeAt(index);
      }
      if (_correctAnswerIndex >= _optionControllers.length) {
        _correctAnswerIndex = _optionControllers.length - 1;
      }
    });
  }

  Widget _buildDragAndDropFields() {
    return Column(
      children: [
        ...List.generate(_optionControllers.length, (i) {
          final isCorrect = i == _correctAnswerIndex;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCorrect ? Colors.green : Colors.grey.shade300,
                width: isCorrect ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Image ${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (_buildImagePreview(i) != null) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildImagePreview(i),
                        ),
                      ],
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(i),
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: Text(
                          _buildImagePreview(i) == null ? 'Pick' : 'Change',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _optionControllers[i],
                        decoration: const InputDecoration(
                          labelText: 'Label (optional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                Radio<int>(
                  value: i,
                  groupValue: _correctAnswerIndex,
                  onChanged: (val) =>
                      setState(() => _correctAnswerIndex = val!),
                  activeColor: Colors.green,
                ),
                if (_optionControllers.length > 1)
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                    onPressed: () {
                      setState(() {
                        _optionControllers[i].dispose();
                        _optionControllers.removeAt(i);
                        _selectedImages.removeAt(i);
                        if (i < _selectedImageBytes.length) {
                          _selectedImageBytes.removeAt(i);
                        }
                        if (_correctAnswerIndex >= _optionControllers.length) {
                          _correctAnswerIndex = _optionControllers.length - 1;
                        }
                      });
                    },
                  ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => setState(() {
            _optionControllers.add(TextEditingController());
            _selectedImages.add(null);
            _selectedImageBytes.add(null);
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add image'),
        ),
      ],
    );
  }

  Widget _buildTextInputFields() {
    return TextFormField(
      controller: _optionControllers[0],
      decoration: const InputDecoration(
        labelText: 'Expected answer',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
    );
  }

  Widget _buildFillBlankFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sentence segments',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...List.generate(_sentenceSegments.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: _sentenceSegments[i] != null
                      ? TextFormField(
                          initialValue: _sentenceSegments[i],
                          decoration: InputDecoration(
                            labelText: 'Segment ${i + 1}',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) =>
                              setState(() => _sentenceSegments[i] = val),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: const Text(
                            'BLANK',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() {
                    final oldMappings = Map<int, String>.fromEntries(
                      _blankMappings,
                    );
                    _sentenceSegments.removeAt(i);
                    final validBlanks = _getBlankIndices().toSet();
                    final rebuilt = <MapEntry<int, String>>[];
                    for (final entry in oldMappings.entries) {
                      if (entry.key == i) continue;
                      final newIndex = entry.key > i
                          ? entry.key - 1
                          : entry.key;
                      if (validBlanks.contains(newIndex)) {
                        rebuilt.add(MapEntry(newIndex, entry.value));
                      }
                    }
                    _blankMappings = rebuilt;
                  }),
                ),
              ],
            ),
          );
        }),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _sentenceSegments.add('')),
              icon: const Icon(Icons.text_fields, size: 18),
              label: const Text('Text'),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _sentenceSegments.add(null)),
              icon: const Icon(Icons.space_bar, size: 18),
              label: const Text('Blank'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Word bank', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...List.generate(_wordBank.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _wordBank[i]['text'] as String? ?? '',
                    decoration: InputDecoration(
                      labelText: 'Word ${i + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) =>
                        setState(() => _wordBank[i]['text'] = val),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    final removedId = _wordBank[i]['id'] as String;
                    setState(() {
                      _wordBank.removeAt(i);
                      _blankMappings.removeWhere((e) => e.value == removedId);
                    });
                  },
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => setState(
            () => _wordBank.add({'id': _generateWordId(), 'text': ''}),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add word'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Blank mappings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ..._getBlankIndices().map((blankIndex) {
          final currentMappedId = _blankMappings
              .firstWhere(
                (e) => e.key == blankIndex,
                orElse: () => MapEntry(blankIndex, ''),
              )
              .value;
          final validValue = _wordBank.any((w) => w['id'] == currentMappedId)
              ? currentMappedId
              : null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    'Blank $blankIndex',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  child: _wordBank.isEmpty
                      ? Text(
                          '(Add words first)',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          value: validValue,
                          isDense: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          hint: const Text('Select word'),
                          items: _wordBank.map((word) {
                            return DropdownMenuItem(
                              value: word['id'] as String? ?? '',
                              child: Text(word['text'] as String? ?? ''),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _blankMappings.removeWhere(
                                (e) => e.key == blankIndex,
                              );
                              if (val != null && val.isNotEmpty) {
                                _blankMappings.add(MapEntry(blankIndex, val));
                              }
                            });
                          },
                        ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMatchPairsFields() {
    return Column(
      children: [
        ...List.generate(_matchLeftControllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _matchLeftControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Left ${i + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _matchRightControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Right ${i + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: _matchLeftControllers.length > 1
                      ? () => setState(() {
                          _matchLeftControllers[i].dispose();
                          _matchRightControllers[i].dispose();
                          _matchLeftControllers.removeAt(i);
                          _matchRightControllers.removeAt(i);
                        })
                      : null,
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => setState(() {
            _matchLeftControllers.add(TextEditingController());
            _matchRightControllers.add(TextEditingController());
          }),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add pair'),
        ),
      ],
    );
  }

  Widget _buildAudioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _audioFile != null
                    ? _audioFile!.name
                    : (_existingAudioUrl != null
                          ? 'Existing audio file'
                          : 'No audio selected'),
                style: TextStyle(
                  color: _audioFile != null || _existingAudioUrl != null
                      ? Colors.black87
                      : Colors.grey[600],
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _pickAudio,
              icon: const Icon(Icons.audiotrack, size: 18),
              label: const Text('Pick'),
            ),
          ],
        ),
        if (_audioFile != null &&
            _audioDuration != null &&
            !_isLoadingDuration) ...[
          const SizedBox(height: 12),
          Text(
            'Trim  ·  Start ${_trimStart.toStringAsFixed(1)}s  →  '
            'End ${_trimEnd.toStringAsFixed(1)}s',
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _trimStart,
                  min: 0,
                  max: _audioDuration!,
                  onChanged: (v) => setState(() => _trimStart = v),
                ),
              ),
              Expanded(
                child: Slider(
                  value: _trimEnd,
                  min: 0,
                  max: _audioDuration!,
                  onChanged: (v) => setState(() => _trimEnd = v),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isPreviewPlaying ? null : _previewAudio,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Preview'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: !_isPreviewPlaying ? null : _stopPreview,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Stop'),
                ),
              ),
            ],
          ),
        ],
        if (_isLoadingDuration)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }

  Widget _buildDifficultySelector() {
    final difficulties = [Difficulty.easy, Difficulty.medium, Difficulty.hard];
    final labels = ['Easy', 'Moderate', 'Hard'];

    return Column(
      children: List.generate(3, (index) {
        final diff = difficulties[index];
        final key = diff.name;
        final existing = _existingLevels[key] ?? <int>{};
        final sorted = existing.toList()..sort();
        final isSelected = _selectedDifficulty == diff;
        final maxLevel = sorted.isEmpty ? 0 : sorted.last;
        final nextFree = maxLevel + 1;
        final freeLevels = _freeLevelsFor(key).take(8).toList();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? _primary : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
            color: isSelected ? _primary.withOpacity(0.06) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Radio<Difficulty>(
                    value: diff,
                    groupValue: _selectedDifficulty,
                    onChanged: (val) {
                      setState(() {
                        _selectedDifficulty = val;
                        if (widget.question == null) {
                          _nextLevel = nextFree;
                          _levelController.text = nextFree.toString();
                        }
                      });
                    },
                    activeColor: _primary,
                  ),
                  Expanded(
                    child: Text(
                      '${labels[index]}  ·  ${existing.length} level${existing.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
              if (sorted.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 40, bottom: 4),
                  child: Text(
                    'Used: ${sorted.join(", ")}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 8, 6),
                  child: TextFormField(
                    controller: _levelController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Level number',
                      helperText: freeLevels.isEmpty
                          ? 'No free levels nearby'
                          : 'Free: ${freeLevels.join(", ")}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) =>
                        _nextLevel = int.tryParse(v) ?? _nextLevel,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  List<int> _freeLevelsFor(String difficultyKey) {
    final existing = _existingLevels[difficultyKey] ?? <int>{};
    final maxLevel = existing.isEmpty
        ? 0
        : existing.reduce((a, b) => a > b ? a : b);
    final limit = maxLevel + 5;
    final result = <int>[];
    for (var i = 1; i <= limit; i++) {
      if (!existing.contains(i)) result.add(i);
    }
    return result;
  }

  Widget _buildStickyQueueBar() {
    if (!_queueActive) return const SizedBox.shrink();
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: (_isLoading || _queueIndex <= 0)
                    ? null
                    : _previousQueueItem,
                child: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _saveQuestion,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text(
                    _queueIndex + 1 < _queue.length
                        ? 'Save & next'
                        : 'Save & finish',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _isLoading ? null : _skipQueueItem,
                child: const Text('Skip'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = widget.isDailyChallenge
        ? 'Daily Question'
        : (_isLanguageMode ? 'Language Question' : 'Question');

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (!_queueActive) ...[
            IconButton(
              icon: const Icon(Icons.playlist_add_check_rounded),
              tooltip: 'Review queue from CSV / Excel',
              onPressed:
                  (_isLoading ||
                      widget.question != null ||
                      widget.languageQuestion != null ||
                      widget.dailyQuestion != null ||
                      widget.isDailyChallenge)
                  ? null
                  : _startReviewQueue,
            ),
            IconButton(
              icon: const Icon(Icons.upload_file_rounded),
              tooltip: 'Import CSV',
              onPressed: _isLoading ? null : _openCsvImport,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'Preview',
            onPressed: _isLoading ? null : _showPreview,
          ),
          if (!_queueActive)
            IconButton(
              icon: const Icon(Icons.save_rounded),
              tooltip: 'Save',
              onPressed: _isLoading ? null : _saveQuestion,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Form(
                      key: _formKey,
                      child: KeyedSubtree(
                        key: ValueKey(_formVersion),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_queueActive) _buildQueueBanner(),
                            _buildContextChip(),
                            const SizedBox(height: 14),

                            // Position
                            if (widget.isDailyChallenge || _isLanguageMode)
                              _sectionCard(
                                title: 'Position',
                                icon: Icons.format_list_numbered_rounded,
                                children: [
                                  TextFormField(
                                    controller: _positionController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: widget.isDailyChallenge
                                          ? 'Position in Daily Challenge'
                                          : 'Position in Theme',
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      helperText: 'Lowest number appears first',
                                    ),
                                    onChanged: (v) =>
                                        _position = int.tryParse(v) ?? 1,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Required';
                                      }
                                      final pos = int.tryParse(v);
                                      if (pos == null)
                                        return 'Must be a number';
                                      if (pos < 1) return 'Must be ≥ 1';
                                      return null;
                                    },
                                  ),
                                ],
                              ),

                            // Difficulty
                            if (!widget.isDailyChallenge && !_isLanguageMode)
                              _sectionCard(
                                title: 'Difficulty & Level',
                                icon: Icons.trending_up_rounded,
                                children: [_buildDifficultySelector()],
                              ),

                            // Type + Question
                            _sectionCard(
                              title: 'Question',
                              icon: Icons.help_outline_rounded,
                              children: [
                                _buildTypeSelector(),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _questionController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Question text',
                                    border: OutlineInputBorder(),
                                    alignLabelWithHint: true,
                                  ),
                                  validator: (v) =>
                                      v?.isEmpty ?? true ? 'Required' : null,
                                ),
                              ],
                            ),

                            // Scenario (general only)
                            if (!widget.isDailyChallenge && !_isLanguageMode)
                              _sectionCard(
                                title: 'Context (optional)',
                                icon: Icons.menu_book_rounded,
                                children: [
                                  TextFormField(
                                    controller: _scenarioController,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      labelText: 'Scenario',
                                      hintText:
                                          'e.g. You are in a taxi. The driver asks…',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      alignLabelWithHint: true,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _wrongConsequenceController,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      labelText: 'Wrong consequence',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      alignLabelWithHint: true,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _culturalContextController,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      labelText: 'Cultural context',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      alignLabelWithHint: true,
                                    ),
                                  ),
                                ],
                              ),

                            // Type-specific answers
                            _sectionCard(
                              title: 'Answer',
                              icon: Icons.check_circle_outline_rounded,
                              children: [
                                if (_selectedType == QuestionType.imageChoice)
                                  _buildImageChoiceFields(),
                                if (_selectedType == QuestionType.dragAndDrop)
                                  _buildDragAndDropFields(),
                                if (_selectedType == QuestionType.textInput ||
                                    _selectedType == QuestionType.audioGuess)
                                  _buildTextInputFields(),
                                if (_selectedType == QuestionType.fillBlank)
                                  _buildFillBlankFields(),
                                if (_selectedType == QuestionType.matchPairs)
                                  _buildMatchPairsFields(),
                                if (_selectedType ==
                                        QuestionType.multipleChoice ||
                                    _selectedType == QuestionType.trueFalse)
                                  _buildOptionsFields(),
                              ],
                            ),

                            // Audio
                            _sectionCard(
                              title: 'Audio (optional)',
                              icon: Icons.graphic_eq_rounded,
                              children: [_buildAudioSection()],
                            ),

                            // Hint + Points
                            _sectionCard(
                              title: 'Details',
                              icon: Icons.info_outline_rounded,
                              children: [
                                TextFormField(
                                  controller: _explanationController,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Hint / Explanation',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    alignLabelWithHint: true,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  initialValue: _points.toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Points',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (v) =>
                                      _points = int.tryParse(v) ?? 10,
                                ),
                              ],
                            ),

                            if (!_queueActive) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: FilledButton.icon(
                                  onPressed: _isLoading ? null : _saveQuestion,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.save_rounded),
                                  label: const Text(
                                    'Save question',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _buildStickyQueueBar(),
              ],
            ),
    );
  }
}
