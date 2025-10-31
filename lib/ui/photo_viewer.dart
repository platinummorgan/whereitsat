import 'dart:io';
import 'package:flutter/material.dart';


class PhotoViewer extends StatelessWidget {
  final File imageFile;
  const PhotoViewer({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Image.file(
          imageFile,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
