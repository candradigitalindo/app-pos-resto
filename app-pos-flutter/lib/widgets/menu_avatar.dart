import 'package:flutter/material.dart';

/// Avatar placeholder untuk menu yang tidak punya foto: menampilkan huruf
/// pertama nama menu di atas warna yang konsisten dari nama tersebut.
class MenuAvatar extends StatelessWidget {
  final String name;

  /// Ukuran tetap (persegi). Jika null, avatar mengisi penuh ruang induknya.
  final double? size;
  final double radius;

  const MenuAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.radius = 10,
  });

  /// Avatar yang mengisi penuh ruang yang tersedia (untuk kartu besar).
  const MenuAvatar.fill({
    super.key,
    required this.name,
    this.radius = 16,
  }) : size = null;

  // Palet warna lembut; dipilih deterministik dari nama agar konsisten.
  static const _palette = [
    [Color(0xFFD1FAE5), Color(0xFF059669)], // hijau
    [Color(0xFFDBEAFE), Color(0xFF2563EB)], // biru
    [Color(0xFFFEF3C7), Color(0xFFD97706)], // amber
    [Color(0xFFFCE7F3), Color(0xFFDB2777)], // pink
    [Color(0xFFEDE9FE), Color(0xFF7C3AED)], // ungu
    [Color(0xFFFFE4E6), Color(0xFFE11D48)], // merah
    [Color(0xFFCCFBF1), Color(0xFF0D9488)], // teal
    [Color(0xFFFFEDD5), Color(0xFFEA580C)], // oranye
  ];

  /// Inisial dari nama menu: huruf pertama tiap kata (maks 2 kata).
  /// "Nasi Goreng" -> "NG", "Ayam" -> "A".
  String get _initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.characters.first.toUpperCase();
    return (words[0].characters.first + words[1].characters.first)
        .toUpperCase();
  }

  List<Color> get _colors {
    final key = name.trim().isEmpty ? '?' : name.trim();
    final idx = key.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length;
    return _palette[idx];
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    final initials = _initials;
    final factor = initials.length > 1 ? 0.34 : 0.42;

    // Ukuran tetap
    if (size != null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c[0],
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Text(
          initials,
          style: TextStyle(
            color: c[1],
            fontWeight: FontWeight.w800,
            fontSize: size! * factor,
          ),
        ),
      );
    }

    // Mengisi penuh ruang induk; font menyesuaikan sisi terpendek.
    return LayoutBuilder(
      builder: (context, constraints) {
        final dim = constraints.biggest.shortestSide.isFinite
            ? constraints.biggest.shortestSide
            : 64.0;
        return Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c[0],
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Text(
            initials,
            style: TextStyle(
              color: c[1],
              fontWeight: FontWeight.w800,
              fontSize: dim * factor,
            ),
          ),
        );
      },
    );
  }
}
