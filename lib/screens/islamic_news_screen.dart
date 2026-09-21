import 'package:flutter/material.dart';
import 'package:quran_app_2025/services/islamic_news_service.dart';
import 'package:url_launcher/url_launcher.dart';

class IslamicNewsScreen extends StatefulWidget {
  const IslamicNewsScreen({super.key});
  @override
  State<IslamicNewsScreen> createState() => _IslamicNewsScreenState();
}

class _IslamicNewsScreenState extends State<IslamicNewsScreen> {
  late Future<List<IslamicNewsArticle>> _news;
  @override
  void initState() {
    super.initState();
    _news = IslamicNewsService.fetchLatest();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Berita Islam')),
    body: FutureBuilder<List<IslamicNewsArticle>>(
      future: _news,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _NewsError(
            error: snapshot.error,
            onRetry: () =>
                setState(() => _news = IslamicNewsService.fetchLatest()),
          );
        }
        final news = snapshot.data!;
        if (news.isEmpty) {
          return const Center(
            child: Text('Belum ada berita yang ditemukan hari ini.'),
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              setState(() => _news = IslamicNewsService.fetchLatest()),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: news.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final article = news[index];
              return Card(
                child: ListTile(
                  title: Text(
                    article.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      article.description?.isNotEmpty == true
                          ? '${article.source}\n${article.description}'
                          : article.source,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => launchUrl(
                    Uri.parse(article.url),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

class _NewsError extends StatelessWidget {
  const _NewsError({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.newspaper_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Berita belum dapat dimuat',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
