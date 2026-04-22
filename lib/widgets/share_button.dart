import 'package:flutter/material.dart';

class ShareButton extends StatelessWidget {
  final VoidCallback? onTap;
  const ShareButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: Colors.blue.withAlpha(80),
                blurRadius: 12,
                offset: const Offset(0, 2))
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ios_share_rounded, size: 16, color: Colors.white),
            SizedBox(width: 6),
            Text('Share',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class ExportSheet extends StatelessWidget {
  final VoidCallback onSavePng;
  final VoidCallback onSavePdf;
  final VoidCallback onShare;
  const ExportSheet(
      {super.key,
      required this.onSavePng,
      required this.onSavePdf,
      required this.onShare});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Export board',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const Divider(height: 20),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Save as PNG'),
              subtitle: const Text('High-resolution image file'),
              onTap: onSavePng,
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Save as PDF'),
              subtitle: const Text('A4 landscape document'),
              onTap: onSavePdf,
            ),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Share via…'),
              subtitle: const Text('Open system share sheet'),
              onTap: onShare,
            ),
          ],
        ),
      ),
    );
  }
}
