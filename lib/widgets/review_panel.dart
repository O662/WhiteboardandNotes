import 'package:flutter/material.dart';

class ReviewPanel extends StatelessWidget {
  final VoidCallback onSpellCheck;
  final VoidCallback onThesaurus;
  final VoidCallback onPagePassword;
  final VoidCallback onDocPassword;

  const ReviewPanel({
    super.key,
    required this.onSpellCheck,
    required this.onThesaurus,
    required this.onPagePassword,
    required this.onDocPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(36),
            blurRadius: 24,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Review',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
          ),
          _ReviewItem(
            icon: Icons.spellcheck_rounded,
            color: const Color(0xFF1E88E5),
            label: 'Spell Check',
            onTap: onSpellCheck,
          ),
          _ReviewItem(
            icon: Icons.menu_book_rounded,
            color: const Color(0xFF7C3AED),
            label: 'Thesaurus',
            onTap: onThesaurus,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Divider(height: 1),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 4),
            child: Text('Security',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45)),
          ),
          _ReviewItem(
            icon: Icons.lock_outline_rounded,
            color: const Color(0xFFFB8C00),
            label: 'Page Password',
            onTap: onPagePassword,
          ),
          _ReviewItem(
            icon: Icons.lock_person_rounded,
            color: const Color(0xFFE53935),
            label: 'Document Password',
            onTap: onDocPassword,
          ),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ReviewItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}
