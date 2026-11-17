class GradeItemModel {
  final String title;

  final String category;
  final double score;
  final double maxScore;
  final DateTime date;

  const GradeItemModel({
    required this.title,
    required this.category,
    required this.score,
    required this.maxScore,
    required this.date,
  });

  double get percentage => score / maxScore * 100;
}
