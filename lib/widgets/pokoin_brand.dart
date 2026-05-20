import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PokoinMark extends StatelessWidget {
  const PokoinMark({super.key, this.size = 42});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/pokoin-topbar.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
      semanticLabel: 'Pokoin logo',
    );
  }
}

class PokoinMarkFrame extends StatelessWidget {
  const PokoinMarkFrame({super.key, this.size = 46});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.11),
      decoration: BoxDecoration(
        color: const Color(0xFF111936),
        borderRadius: BorderRadius.circular(size / 3),
        border: Border.all(color: Colors.white24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: PokoinMark(size: size - (size * 0.22)),
      ),
    );
  }
}

class PokoinAppBarTitle extends StatelessWidget {
  const PokoinAppBarTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.homeOnTap = false,
  });

  final String title;
  final String? subtitle;
  final bool homeOnTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (homeOnTap) {
          context.go('/');
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PokoinMarkFrame(size: 42),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
