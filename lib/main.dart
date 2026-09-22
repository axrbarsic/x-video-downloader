import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/domain/post_url.dart';
import 'src/domain/video_resolver.dart';
import 'src/services/photo_library_saver.dart';
import 'src/services/x_web_video_resolver.dart';

void main() {
  runApp(const XVideoDownloaderApp());
}

class XVideoDownloaderApp extends StatelessWidget {
  const XVideoDownloaderApp({super.key, this.resolver, this.saver});

  final VideoResolver? resolver;
  final PhotoLibrarySaver? saver;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'X Video Saver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF111111)),
        useMaterial3: true,
      ),
      home: SaveVideoPage(
        resolver: resolver ?? XWebVideoResolver(),
        saver: saver ?? const PhotoManagerVideoSaver(),
      ),
    );
  }
}

enum SaveStatus { idle, loading, success, error }

class SaveVideoPage extends StatefulWidget {
  const SaveVideoPage({super.key, required this.resolver, required this.saver});

  final VideoResolver resolver;
  final PhotoLibrarySaver saver;

  @override
  State<SaveVideoPage> createState() => _SaveVideoPageState();
}

class _SaveVideoPageState extends State<SaveVideoPage> {
  final _urlController = TextEditingController();
  SaveStatus _status = SaveStatus.idle;
  String? _message;

  bool get _isLoading => _status == SaveStatus.loading;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteUrl() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text?.trim();
    if (!mounted || text == null || text.isEmpty) return;
    _urlController
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
    setState(() {
      _status = SaveStatus.idle;
      _message = null;
    });
  }

  Future<void> _saveVideo() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _status = SaveStatus.loading;
      _message = null;
    });

    try {
      final reference = PostUrlParser.parse(_urlController.text);
      final video = await widget.resolver.resolve(reference);
      await widget.saver.save(video);
      if (!mounted) return;
      setState(() {
        _status = SaveStatus.success;
        _message = 'Видео сохранено в приложение «Фото».';
      });
    } on PostUrlException catch (error) {
      _showError(error.message);
    } on VideoResolverException catch (error) {
      _showError(error.message);
    } on PhotoLibraryException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Не удалось сохранить видео. Попробуйте ещё раз.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _status = SaveStatus.error;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = _message;
    final isError = _status == SaveStatus.error;
    final isSuccess = _status == SaveStatus.success;

    return Scaffold(
      appBar: AppBar(title: const Text('X Video Saver'), centerTitle: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          children: [
            Text(
              'Сохрани видео из поста',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Вставь ссылку на пост X, и приложение сохранит найденный MP4 в медиатеку.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _urlController,
              enabled: !_isLoading,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_isLoading) _saveVideo();
              },
              decoration: InputDecoration(
                labelText: 'Ссылка на пост',
                hintText: 'https://x.com/user/status/123456789',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(
                  tooltip: 'Вставить из буфера обмена',
                  onPressed: _isLoading ? null : _pasteUrl,
                  icon: const Icon(Icons.content_paste),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isLoading ? null : _saveVideo,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(
                _isLoading ? 'Ищу и скачиваю видео...' : 'Сохранить видео',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 20),
              _StatusCard(
                message: message,
                isError: isError,
                isSuccess: isSuccess,
              ),
            ],
            const SizedBox(height: 28),
            Text(
              'Поддерживаются ссылки x.com и twitter.com. Ссылка должна вести на конкретный пост.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.message,
    required this.isError,
    required this.isSuccess,
  });

  final String message;
  final bool isError;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isError
        ? colors.error
        : isSuccess
        ? Colors.green.shade700
        : colors.primary;
    final icon = isError
        ? Icons.error_outline
        : isSuccess
        ? Icons.check_circle_outline
        : Icons.info_outline;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
