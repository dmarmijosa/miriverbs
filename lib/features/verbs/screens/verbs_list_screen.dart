import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/data/syllabus_data.dart';
import '../../../core/widgets/tactile_button.dart';
import '../../../core/widgets/feedback_toast.dart';
import 'practice_screen.dart';

class VerbsListScreen extends StatefulWidget {
  final String title;
  final String levelCode;

  const VerbsListScreen({
    super.key,
    required this.title,
    required this.levelCode,
  });

  @override
  State<VerbsListScreen> createState() => _VerbsListScreenState();
}

class _VerbsListScreenState extends State<VerbsListScreen> {
  List<VerbModel> _dbVerbs = [];
  List<VerbModel> _filteredVerbs = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVerbsFromDatabase();
  }

  Future<void> _fetchVerbsFromDatabase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('verbs')
          .select()
          .eq('difficulty', widget.levelCode.toLowerCase());

      if ((response as List).isEmpty) {
        _loadLocalFallback(
          warningTitle: 'Base de datos vacía',
          warningMessage: 'Usando verbos locales del silabo offline.',
        );
        return;
      }

      final loadedVerbs = (response as List).map<VerbModel>((json) => VerbModel(
        infinitive: json['infinitive'] ?? '',
        spanish: json['spanish'] ?? '',
        pastSimple: json['past_simple'] ?? '',
        pastParticiple: json['past_participle'] ?? '',
        gerund: json['gerund'] ?? '',
        exampleEn: json['example_en'] ?? '',
        exampleEs: json['example_es'] ?? '',
        difficulty: json['difficulty'] ?? '',
      )).toList();

      setState(() {
        _dbVerbs = loadedVerbs;
        _isLoading = false;
        _filterVerbs();
      });
    } catch (e) {
      debugPrint('Error fetching verbs from Supabase: $e');
      _loadLocalFallback(
        warningTitle: 'Modo Offline',
        warningMessage: 'No se pudo conectar al servidor. Cargando verbos locales.',
      );
    }
  }

  void _loadLocalFallback({required String warningTitle, required String warningMessage}) {
    final difficulty = widget.levelCode.toLowerCase();
    final localList = SyllabusData.verbs.where((v) => v.difficulty == difficulty).toList();

    setState(() {
      _dbVerbs = localList;
      _isLoading = false;
      _filterVerbs();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FeedbackToast.showWarning(
          context,
          title: warningTitle,
          message: warningMessage,
        );
      }
    });
  }

  void _filterVerbs() {
    final baseList = _dbVerbs;

    if (_searchQuery.isEmpty) {
      _filteredVerbs = baseList;
    } else {
      _filteredVerbs = baseList
          .where((v) =>
              v.infinitive.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              v.spanish.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: AppTheme.headlineMd.copyWith(fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.onBackground),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // ── Search field ───────────────────────────────────────────────
              TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                    _filterVerbs();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar verbo...',
                  hintStyle: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                  filled: true,
                  fillColor: AppTheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    borderSide: const BorderSide(color: AppTheme.surfaceContainer, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    borderSide: const BorderSide(color: AppTheme.surfaceContainer, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Practice Button ────────────────────────────────────────────
              TactileButton(
                text: '🎯 Practicar estos verbos',
                backgroundColor: AppTheme.secondary,
                darkColor: AppTheme.secondaryDark,
                textColor: AppTheme.onBackground,
                onTap: _isLoading || _filteredVerbs.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PracticeScreen(
                              verbs: _filteredVerbs,
                              levelName: widget.title,
                            ),
                          ),
                        );
                      },
              ),
              const SizedBox(height: 20),

              // ── Verbs List / Loading / Empty State ─────────────────────────
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppTheme.primary),
                            SizedBox(height: 16),
                            Text(
                              'Cargando verbos desde la base de datos...',
                              style: TextStyle(color: AppTheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : _filteredVerbs.isEmpty
                        ? Center(
                            child: Text(
                              'No se encontraron verbos.',
                              style: AppTheme.bodyLg.copyWith(color: AppTheme.onSurfaceVariant),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _filteredVerbs.length,
                            itemBuilder: (context, index) {
                              final verb = _filteredVerbs[index];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                                  onTap: () => _showVerbDetails(verb),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    verb.infinitive,
                                                    style: AppTheme.headlineMd.copyWith(
                                                      fontSize: 18,
                                                      color: AppTheme.primary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.surfaceContainer,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        verb.spanish,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: AppTheme.labelMd.copyWith(
                                                          fontSize: 11,
                                                          color: AppTheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  _tenseChip('Pasado', verb.pastSimple),
                                                  const SizedBox(width: 12),
                                                  _tenseChip('Participio', verb.pastParticiple),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.info_outline_rounded,
                                          color: AppTheme.outline,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tenseChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.labelMd.copyWith(fontSize: 10, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6)),
        ),
        Text(
          value,
          style: AppTheme.labelLg.copyWith(fontSize: 13, color: AppTheme.onBackground),
        ),
      ],
    );
  }

  void _showVerbDetails(VerbModel verb) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXLarge)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              verb.infinitive,
              textAlign: TextAlign.center,
              style: AppTheme.displayLg.copyWith(fontSize: 32, color: AppTheme.primary),
            ),
            Text(
              'Significado: ${verb.spanish}',
              textAlign: TextAlign.center,
              style: AppTheme.bodyLg.copyWith(color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _detailTenseCol('Pasado Simple', verb.pastSimple),
                _detailTenseCol('Participio Pasado', verb.pastParticiple),
                _detailTenseCol('Gerundio (-ing)', verb.gerund),
              ],
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(color: AppTheme.surfaceContainer),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ejemplo de uso:',
                    style: AppTheme.labelLg.copyWith(color: AppTheme.primary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    verb.exampleEn,
                    style: AppTheme.bodyMd.copyWith(fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
                  ),
                  Text(
                    verb.exampleEs,
                    style: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TactileButton(
              text: 'Entendido',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailTenseCol(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTheme.labelMd.copyWith(fontSize: 11, color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.headlineMd.copyWith(fontSize: 16, color: AppTheme.onBackground),
        ),
      ],
    );
  }
}
