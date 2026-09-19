import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kohntri_os_hq/models/daily_challenge_question.dart';
import 'package:kohntri_os_hq/models/language_question.dart';
import 'package:kohntri_os_hq/models/language_theme.dart';
import 'package:kohntri_os_hq/models/question.dart';
import 'package:kohntri_os_hq/screens/preview_question_screen.dart';
import 'package:kohntri_os_hq/services/daily_challenge_service.dart';
import 'package:kohntri_os_hq/services/language_question_service.dart';
import 'package:kohntri_os_hq/services/question_service.dart';
import 'package:kohntri_os_hq/shared/widgets/auto_scroll_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:audioplayers/audioplayers.dart';

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
  List<File?> _selectedImages = [];
  int _correctAnswerIndex = 0;
  String _selectedCategory = 'General';
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

  // Language-specific fields
  String? _selectedLanguageId;
  String? _selectedThemeId;
  List<Map<String, dynamic>> _languages = [];
  List<LanguageTheme> _themes = [];

  final DailyChallengeService _dailyService = DailyChallengeService();
  final QuestionService _questionService = QuestionService();
  final LanguageQuestionService _langService = LanguageQuestionService();
  final ImagePicker _picker = ImagePicker();
  int _difficultyIndex = 1;
  Map<Difficulty, int> _difficultyCounts = {};
  Difficulty? _selectedDifficulty;
  int? _nextLevel;
  final TextEditingController _positionController = TextEditingController();

  bool get _isLanguageMode =>
      _selectedCategory == 'Languages' ||
      widget.languageQuestion != null ||
      widget.initialLanguageId != null ||
      widget.initialThemeId != null ||
      widget.languageName != null ||
      widget.themeName != null;

  final List<String> _categories = [
    'History',
    'Food',
    'Sports',
    'Places',
    // 'Languages',
  ];

  @override
  void initState() {
    super.initState();

    // First, load any existing data for edit modes
    if (widget.dailyQuestion != null) {
      _loadDailyForEdit();
    } else if (widget.languageQuestion != null) {
      _loadLanguageForEdit();
    } else if (widget.question != null) {
      _loadQuestionForEdit();
    } else {
      // ---- New question ----
      if (widget.initialCategory != null) {
        _selectedCategory = widget.initialCategory!;
      }

      // ✅ Infer language mode from provided IDs (fix for missing initialCategory)
      if (widget.initialLanguageId != null || widget.initialThemeId != null) {
        _selectedCategory = 'Languages';
      }

      if (widget.isDailyChallenge && widget.defaultPosition != null) {
        _position = widget.defaultPosition!;
        _positionController.text = _position.toString();
      }

      // Store initial IDs, but don't fetch async yet
      if (widget.initialThemeId != null) {
        _selectedThemeId = widget.initialThemeId!;
      }
      if (widget.initialLanguageId != null) {
        _selectedLanguageId = widget.initialLanguageId!;
      }

      print('🔍 Initial category: $_selectedCategory');
      print('🔍 Initial languageId: ${widget.initialLanguageId}');
      print('🔍 Initial themeId: ${widget.initialThemeId}');

      _updateOptionsForType();

      // After setting up basic state, start async loading for dynamic data
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
          await _updateNextPosition(); // position auto-computed for theme
        }
      }
      return;
    }

    // ---------- DAILY CHALLENGE FLOW ----------
    if (widget.isDailyChallenge) {
      await _updateNextPosition();
      await _loadDifficultyCounts();
      return;
    }

    // ---------- ADVENTURE FLOW ----------
    await _loadDifficultyCounts();
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
    super.dispose();
  }

  Future<void> _loadDifficultyCounts() async {
    final counts = await _questionService.getQuestionCountsByDifficulty(
      _selectedCategory,
    );
    setState(() {
      _difficultyCounts = counts;
      // If a difficulty is already selected (e.g., from editing), keep it
      if (_selectedDifficulty != null) {
        final count = _difficultyCounts[_selectedDifficulty] ?? 0;
        _nextLevel = count + 1;
      }
    });
  }

  // Audio helpers
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
    if (mounted) {
      setState(() {
        _isPreviewPlaying = false;
      });
    }
  }

  void _showPreview() {
    final question = _buildCurrentObject(forPreview: true);
    final questionData = question.toSupabase();
    // Add local audio path for preview if a new file is picked
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
          setState(() {
            _isPreviewPlaying = state == PlayerState.playing;
          });
        }
      });
      Source source;
      if (_audioFile!.bytes != null) {
        source = BytesSource(_audioFile!.bytes!);
      } else {
        source = DeviceFileSource(_audioFile!.path!);
      }
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
      print('Preview error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not preview audio: $e')));
    }
  }

  Future<void> _stopPreview() async {
    if (_previewPlayer != null) {
      await _fadeOut();
    } else {
      if (mounted) {
        setState(() {
          _isPreviewPlaying = false;
        });
      }
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
        print('Error getting audio duration: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoadingDuration = false);
        }
      }
    }
  }
  // ----------------------------------------------------------------------

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
    for (var c in _matchLeftControllers) c.dispose(); // 👈
    for (var c in _matchRightControllers) c.dispose();
    _matchLeftControllers = []; // 👈
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
        _optionControllers = List.generate(4, (i) => TextEditingController());
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
      //case QuestionType.mapLocation:
      case QuestionType.audioGuess:
        _optionControllers = [TextEditingController()];
        _selectedImages = [];
        break;
    }
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
        if (left.isNotEmpty && right.isNotEmpty)
          pairs.add({'left': left, 'right': right});
      }
      if (pairs.isNotEmpty)
        typeData = {
          'pairs': pairs,
          'correctMatches': List.generate(
            pairs.length,
            (i) => {'leftIndex': i, 'rightIndex': i},
          ),
        };
    } else if (_selectedType == QuestionType.fillBlank) {
      typeData = {
        'sentenceParts': _sentenceSegments,
        'wordBank': _wordBank,
        'correctAnswers': _blankMappings.fold<Map<String, String>>({}, (
          map,
          e,
        ) {
          map[e.key.toString()] = e.value;
          return map;
        }),
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
        id: widget.languageQuestion?.id ?? '',
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
        // level: _nextLevel,
        typeData: typeData,
        // 👇 ADD THESE THREE LINES:
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

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one valid pair (left + right).'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    print('🔍 Language ID: $_selectedLanguageId');
    print('🔍 Theme ID: $_selectedThemeId');
    setState(() => _isLoading = true);

    try {
      // ============================================================
      // 1. DAILY CHALLENGE
      // ============================================================
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
          //typeData: base.typeData,
        );

        if (widget.dailyQuestion == null) {
          await _dailyService.addQuestion(finalQuestion);
        } else {
          await _dailyService.updateQuestion(finalQuestion);
        }
      }
      // ============================================================
      // 2. LANGUAGE QUESTION
      // ============================================================
      else if (_isLanguageMode) {
        if (_selectedLanguageId == null || _selectedLanguageId!.isEmpty) {
          throw Exception(
            'Language ID is missing. Please select a valid language.',
          );
        }
        if (_selectedThemeId == null || _selectedThemeId!.isEmpty) {
          throw Exception('Theme ID is missing. Please select a valid theme.');
        }

        final base = _buildCurrentObject() as LanguageQuestion;

        // Upload image(s)
        String? imageUrl;
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
              if (url != null) {
                imageUrl = url;
                break;
              }
            }
          }
        }

        // Upload audio
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

        if (widget.languageQuestion == null) {
          await _langService.addQuestion(finalQuestion);
        } else {
          await _langService.updateQuestion(finalQuestion);
        }
      }
      // ============================================================
      // 3. ADVENTURE (existing code)
      // ============================================================
      else {
        final base = _buildCurrentObject() as Question;
        List<String> optionsList;
        if (_selectedType == QuestionType.multipleChoice) {
          optionsList = _optionControllers
              .map((ctrl) => ctrl.text.trim())
              .where((text) => text.isNotEmpty)
              .toList();
          if (optionsList.length < 2) {
            throw Exception(
              'At least two options required for multiple choice',
            );
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
          final userId =
              Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
          final tempId = DateTime.now().millisecondsSinceEpoch.toString();
          for (int i = 0; i < _selectedImages.length; i++) {
            final file = _selectedImages[i];
            if (file != null) {
              final url = await _uploadImage(file, userId, tempId);
              if (url != null) imageUrls[i.toString()] = url;
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
          // Only apply trim values if there is actually audio attached
          typeData ??= {};
          typeData['audio_url'] = _existingAudioUrl;
          typeData['trim_start'] = _trimStart;
          typeData['trim_end'] = _trimEnd;
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
          difficulty: base.difficulty,
          typeData: typeData,
          scenario: base.scenario,
          wrongConsequence: base.wrongConsequence,
          culturalContext: base.culturalContext,
        );

        print('📦 Saving question data: ${question.toSupabase()}');

        if (widget.question == null) {
          await _questionService.addQuestion(question);
        } else {
          await _questionService.updateQuestion(question);
        }
      }

      // ============================================================
      // SUCCESS
      // ============================================================
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e, stack) {
      print('❌ Save error: $e');
      print(stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _uploadImage(
    File image,
    String userId,
    String tempId, {
    bool isDaily = false,
    bool isLanguage = false,
  }) async {
    try {
      String bucket;
      if (isDaily)
        bucket = 'daily_challenge_images';
      else if (isLanguage)
        bucket = 'language_question_images';
      else
        bucket = 'question_images';

      // Safely get file extension
      String fileExt = '.jpg';
      if (image is XFile) {
        fileExt = path.extension(image.path);
      } else if (!kIsWeb && image.path != null && image.path.isNotEmpty) {
        fileExt = path.extension(image.path);
      }

      final fileName =
          '${isDaily ? 'daily' : (isLanguage ? 'lang' : 'question')}_${tempId}_${DateTime.now().millisecondsSinceEpoch}$fileExt';

      Uint8List bytes;
      if (kIsWeb) {
        // On web, read bytes from the XFile directly
        final XFile xFile = image as XFile;
        bytes = await xFile.readAsBytes();
      } else {
        bytes = await image.readAsBytes();
      }
      await Supabase.instance.client.storage
          .from(bucket)
          .upload(fileName, bytes as File);
      return Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(fileName);
    } catch (e) {
      print('Upload error: $e');
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
      if (isDaily)
        bucket = 'daily_challenge_audio';
      else if (isLanguage)
        bucket = 'language_question_audio';
      else
        bucket = 'question_audio';

      final fileName =
          '${isDaily ? 'daily' : (isLanguage ? 'lang' : 'question')}_${tempId}_${DateTime.now().millisecondsSinceEpoch}_${audio.name}';

      Uint8List bytes;
      if (kIsWeb) {
        // On web, PlatformFile.bytes is available; otherwise use readBytes from the file
        if (audio.bytes != null) {
          bytes = audio.bytes!;
        } else {
          // This should not happen on web if picker returns bytes
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
      print('Upload error: $e');
      return null;
    }
  }
  // List<XFile?> _selectedImages = []; // change type

  Future<void> _pickImage(int index) async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImages[index] = picked as File?);
    }
  }

  void _loadQuestionForEdit() {
    final q = widget.question!;
    _selectedDifficulty = q.difficulty;
    _nextLevel = null;
    _questionController.text = q.question;
    _scenarioController.text = q.scenario ?? '';
    _wrongConsequenceController.text = q.wrongConsequence ?? '';
    _culturalContextController.text = q.culturalContext ?? '';
    _explanationController.text = q.explanation;
    _selectedCategory = q.category;
    _selectedType = q.type;
    _correctAnswerIndex = q.correctAnswerIndex;
    _points = q.points;
    _difficultyIndex = q.difficulty.index;

    // ---- Options (for multiple choice / true-false) ----
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
    }

    // ---- Initialize blank type-specific fields ONCE ----
    // (this clears and sets up controllers for the current type)
    if (_optionControllers.isEmpty) {
      _updateOptionsForType();
    }

    // ---- Restore type-specific data (AFTER _updateOptionsForType) ----
    if (q.typeData != null) {
      final data = q.typeData!;
      _existingAudioUrl = data['audio_url'] as String?;
      _trimStart = (data['trim_start'] as num?)?.toDouble() ?? 0.0;
      _trimEnd = (data['trim_end'] as num?)?.toDouble() ?? 0.0;
      _sentenceSegments = List<String?>.from(data['sentenceParts'] ?? []);
      _wordBank = List<Map<String, dynamic>>.from(data['wordBank'] ?? []);
      final correct = data['correctAnswers'] as Map<String, dynamic>? ?? {};
      _blankMappings = correct.entries
          .map((e) => MapEntry(int.parse(e.key), e.value as String))
          .toList();

      // ---- Restore match pairs (LAST, so nothing overwrites it) ----
      if (_selectedType == QuestionType.matchPairs) {
        final pairsList = (data['pairs'] as List?) ?? [];
        if (pairsList.isNotEmpty) {
          // Dispose the placeholder controller created by _updateOptionsForType
          for (final c in _matchLeftControllers) {
            c.dispose();
          }
          for (final c in _matchRightControllers) {
            c.dispose();
          }

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
    _selectedCategory = 'Languages'; // ✅ CRITICAL FIX
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

  // ----------------------------------------------------------------------
  // UI Builder Methods
  Widget _buildDropdown(
    String label,
    List<String> items,
    int value,
    Function(int?) onChanged,
  ) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: List.generate(
        items.length,
        (i) => DropdownMenuItem(value: i, child: Text(items[i])),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildOptionsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Options (select the correct one)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...List.generate(_optionControllers.length, (i) {
          final isCorrect = i == _correctAnswerIndex;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCorrect ? Colors.green : Colors.grey.shade300,
                width: isCorrect ? 2 : 1,
              ),
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
                        vertical: 8,
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
                  onChanged: (val) =>
                      setState(() => _correctAnswerIndex = val!),
                  activeColor: Colors.green,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildImageChoiceFields() {
    // Safety: ensure lists are same length and correctAnswerIndex is valid
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Image Options',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...List.generate(_optionControllers.length, (i) {
          final isCorrect = i == _correctAnswerIndex;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
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
                          labelText: 'Option text (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                          Icons.remove_circle,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeImageOption(i),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_selectedImages[i] != null)
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: FileImage(_selectedImages[i]!),
                            fit: BoxFit.cover,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(i),
                      icon: const Icon(Icons.image),
                      label: Text(
                        _selectedImages[i] == null ? 'Pick Image' : 'Change',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _addImageOption,
          child: const Text('Add Image Option'),
        ),
      ],
    );
  }

  void _addImageOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
      _selectedImages.add(null);
    });
  }

  void _removeImageOption(int index) {
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
      _selectedImages.removeAt(index);
      if (_correctAnswerIndex >= _optionControllers.length) {
        _correctAnswerIndex = _optionControllers.length - 1;
      }
    });
  }

  Widget _buildDragAndDropFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Drag & Drop Images',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...List.generate(_optionControllers.length, (i) {
          final isCorrect = i == _correctAnswerIndex;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
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
                      if (_selectedImages[i] != null)
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: FileImage(_selectedImages[i]!),
                              fit: BoxFit.cover,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(i),
                        icon: const Icon(Icons.image),
                        label: Text(
                          _selectedImages[i] == null ? 'Pick Image' : 'Change',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _optionControllers[i],
                        decoration: const InputDecoration(
                          labelText: 'Label (optional)',
                          border: OutlineInputBorder(),
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
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _optionControllers[i].dispose();
                        _optionControllers.removeAt(i);
                        _selectedImages.removeAt(i);
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
        ElevatedButton(
          onPressed: () => setState(() {
            _optionControllers.add(TextEditingController());
            _selectedImages.add(null);
          }),
          child: const Text('Add Image'),
        ),
      ],
    );
  }

  Widget _buildTextInputFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Correct Answer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _optionControllers[0],
          decoration: const InputDecoration(
            labelText: 'Expected answer',
            border: OutlineInputBorder(),
          ),
          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildFillBlankFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sentence Segments',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ...List.generate(_sentenceSegments.length, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _sentenceSegments[i] != null
                      ? TextFormField(
                          initialValue: _sentenceSegments[i],
                          decoration: InputDecoration(
                            labelText: 'Segment ${i + 1}',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (val) =>
                              setState(() => _sentenceSegments[i] = val),
                        )
                      : const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'BLANK',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      setState(() => _sentenceSegments.removeAt(i)),
                ),
              ],
            ),
          );
        }),
        Row(
          children: [
            ElevatedButton(
              onPressed: () => setState(() => _sentenceSegments.add('')),
              child: const Text('Add Text Segment'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => setState(() => _sentenceSegments.add(null)),
              child: const Text('Add Blank'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Word Bank', style: TextStyle(fontWeight: FontWeight.bold)),
        ...List.generate(_wordBank.length, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _wordBank[i]['text'] as String? ?? '',
                    decoration: InputDecoration(
                      labelText: 'Word ${i + 1}',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (val) =>
                        setState(() => _wordBank[i]['text'] = val),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
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
        ElevatedButton(
          onPressed: () => setState(
            () => _wordBank.add({'id': _generateWordId(), 'text': ''}),
          ),
          child: const Text('Add Word'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Blank Mappings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text('Blank $blankIndex: '),
                const SizedBox(width: 16),
                Expanded(
                  child: _wordBank.isEmpty
                      ? const Text(
                          '(Add words to bank first)',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        )
                      : DropdownButtonFormField<String>(
                          value: validValue,
                          hint: const Text('Select word'),
                          items: _wordBank.map((word) {
                            final id = word['id'] as String?;
                            final text = word['text'] as String? ?? '';
                            return DropdownMenuItem(
                              value: id ?? '',
                              child: Text(text),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _blankMappings.removeWhere(
                                (e) => e.key == blankIndex,
                              );
                              if (val != null && val.isNotEmpty)
                                _blankMappings.add(MapEntry(blankIndex, val));
                            });
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Matching Pairs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...List.generate(_matchLeftControllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _matchLeftControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Left ${i + 1}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _matchRightControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Right ${i + 1}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle),
                  onPressed: _matchLeftControllers.length > 1
                      ? () {
                          setState(() {
                            _matchLeftControllers[i].dispose();
                            _matchRightControllers[i].dispose();
                            _matchLeftControllers.removeAt(i);
                            _matchRightControllers.removeAt(i);
                          });
                        }
                      : null,
                ),
              ],
            ),
          );
        }),
        ElevatedButton(
          onPressed: () => setState(() {
            _matchLeftControllers.add(TextEditingController());
            _matchRightControllers.add(TextEditingController());
          }),
          child: const Text('Add Pair'),
        ),
      ],
    );
  }

  Widget _buildAudioSelectionInfo() {
    if (_audioFile != null) return Text('Selected: ${_audioFile!.name}');
    if (_existingAudioUrl != null) return const Text('Existing audio file');
    return const Text('No audio selected');
  }

  Widget _buildAudioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Audio (optional)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildAudioSelectionInfo()),
                  ElevatedButton.icon(
                    onPressed: _pickAudio,
                    icon: const Icon(Icons.audiotrack),
                    label: const Text('Pick Audio'),
                  ),
                ],
              ),
              if (_audioFile != null &&
                  _audioDuration != null &&
                  !_isLoadingDuration) ...[
                const SizedBox(height: 16),
                const Text(
                  'Trim Audio (seconds)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('Start: ${_trimStart.toStringAsFixed(1)}s'),
                          Slider(
                            value: _trimStart,
                            min: 0,
                            max: _audioDuration!,
                            onChanged: (val) =>
                                setState(() => _trimStart = val),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('End: ${_trimEnd.toStringAsFixed(1)}s'),
                          Slider(
                            value: _trimEnd,
                            min: 0,
                            max: _audioDuration!,
                            onChanged: (val) => setState(() => _trimEnd = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isPreviewPlaying ? null : _previewAudio,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Preview'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: !_isPreviewPlaying ? null : _stopPreview,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                      ),
                    ),
                  ],
                ),
              ],
              if (_isLoadingDuration)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultySelector() {
    final difficulties = [Difficulty.easy, Difficulty.medium, Difficulty.hard];
    final labels = ['Easy', 'Medium', 'Hard'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Difficulty & Level',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...List.generate(3, (index) {
          final diff = difficulties[index];
          final count = _difficultyCounts[diff] ?? 0;
          final level = count + 1;
          final isSelected = _selectedDifficulty == diff;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(8),
              color: isSelected ? Colors.blue.shade50 : null,
            ),
            child: Row(
              children: [
                Radio<Difficulty>(
                  value: diff,
                  groupValue: _selectedDifficulty,
                  onChanged: (val) {
                    setState(() {
                      _selectedDifficulty = val;
                      _nextLevel = (_difficultyCounts[val!] ?? 0) + 1;
                    });
                  },
                ),
                Expanded(child: Text('${labels[index]} – $level')),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _getContextLabel() {
    if (widget.isDailyChallenge) {
      return 'Daily Challenge';
    } else if (_isLanguageMode) {
      // Determine language name
      String langName = '?';
      if (widget.languageName != null) {
        langName = widget.languageName!;
      } else if (_selectedLanguageId != null) {
        final found = _languages.cast<Map<String, dynamic>>().firstWhere(
          (l) => l['id'] == _selectedLanguageId,
          orElse: () => {},
        );
        if (found.isNotEmpty) langName = found['name'] as String;
      }

      // Determine theme name
      String themeName = '?';
      if (widget.themeName != null) {
        themeName = widget.themeName!;
      } else if (_selectedThemeId != null) {
        final found = _themes.firstWhere(
          (t) => t.id == _selectedThemeId,
          orElse: () =>
              LanguageTheme(id: '', name: '', languageTypeId: '', position: 0),
        );
        if (found.id.isNotEmpty) themeName = found.name;
      }
      return 'Language => $langName :) Theme => $themeName';
    } else {
      final category = widget.initialCategory ?? _selectedCategory;
      return 'Quiz Category: $category';
    }
  }

  Future<void> _updateNextPosition() async {
    if (widget.isDailyChallenge) {
      final max = await _dailyService.getMaxPosition();
      setState(() => _position = max + 1);
    } else if (_isLanguageMode && _selectedThemeId != null) {
      final max = await _langService.getMaxPositionForTheme(_selectedThemeId!);
      setState(() {
        _position = max + 1;
        _positionController.text = _position.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isDailyChallenge
              ? 'Daily Question'
              : (_isLanguageMode ? 'Language Question' : 'Question'),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.preview),
            onPressed: _isLoading ? null : _showPreview,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveQuestion,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top context indicator
                    Container(
                      width: 280,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AutoScrollText(
                        text: _getContextLabel(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Position (Daily Challenge or Language)
                    if (widget.isDailyChallenge || _isLanguageMode) ...[
                      TextFormField(
                        controller: _positionController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: widget.isDailyChallenge
                              ? 'Position in Daily Challenge'
                              : 'Position in Theme',
                          border: OutlineInputBorder(),
                          helperText: 'Lowest number appears first',
                        ),
                        onChanged: (v) => _position = int.tryParse(v) ?? 1,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Position is required';
                          }
                          final pos = int.tryParse(v);
                          if (pos == null) return 'Must be a number';
                          if (pos < 1) return 'Position must be at least 1';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Difficulty (general only)
                    if (!widget.isDailyChallenge && !_isLanguageMode) ...[
                      _buildDifficultySelector(),
                      const SizedBox(height: 16),
                    ],

                    // Type dropdown
                    _buildDropdown(
                      'Type',
                      QuestionType.values.map((e) => e.displayName).toList(),
                      _selectedType.index,
                      (val) {
                        setState(() {
                          _selectedType = QuestionType.values[val!];
                          _updateOptionsForType();
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // ---- Scenario fields (general only) ----
                    if (!widget.isDailyChallenge && !_isLanguageMode) ...[
                      TextFormField(
                        controller: _scenarioController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Scenario (optional)',
                          hintText: 'E.g You are in a taxi. The driver asks…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _wrongConsequenceController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Wrong Consequence (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _culturalContextController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Cultural Context (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Question field
                    TextFormField(
                      controller: _questionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Question',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Type-specific fields
                    if (_selectedType == QuestionType.imageChoice)
                      _buildImageChoiceFields(),
                    if (_selectedType == QuestionType.dragAndDrop)
                      _buildDragAndDropFields(),
                    if (_selectedType == QuestionType.textInput)
                      _buildTextInputFields(),
                    if (_selectedType == QuestionType.audioGuess)
                      _buildTextInputFields(),
                    if (_selectedType == QuestionType.fillBlank)
                      _buildFillBlankFields(),
                    if (_selectedType == QuestionType.matchPairs)
                      _buildMatchPairsFields(),
                    if (_selectedType == QuestionType.multipleChoice ||
                        _selectedType == QuestionType.trueFalse)
                      _buildOptionsFields(),
                    const SizedBox(height: 16),

                    // Audio
                    _buildAudioSection(),
                    const SizedBox(height: 16),

                    // Hint/Explanation
                    TextFormField(
                      controller: _explanationController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Hint/Explanation',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Points
                    TextFormField(
                      initialValue: _points.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Points',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _points = int.tryParse(v) ?? 10,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
