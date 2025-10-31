import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class PolicyPage extends StatelessWidget {
  final String title;
  final String markdown;
  const PolicyPage({required this.title, required this.markdown});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Markdown(
        data: markdown,
        onTapLink: (_, href, __) {
          if (href != null) launchUrl(Uri.parse(href));
        },
        padding: const EdgeInsets.all(16),
      ),
    );
  }
}
