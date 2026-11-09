/// One marked piece of work: a quiz, an exam, an assignment...
class GradeItemModel {
  final String title;

  /// "Quiz", "Mid-term exam", "Assignment"...
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
