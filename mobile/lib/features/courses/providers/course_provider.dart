import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/course_model.dart';

final courseSearchProvider =
    FutureProvider.family<List<CourseSummary>, String>((ref, query) async {
  final q = query.trim();
  if (q.length < 2) return const [];
  final api = ref.read(apiClientProvider);
  try {
    final resp = await api.get(ApiConstants.courseSearch, queryParams: {'q': q});
    final list = resp.data['courses'] as List? ?? [];
    return list
        .map((e) => CourseSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
});

final courseDetailProvider =
    FutureProvider.family<CourseDetail, String>((ref, id) async {
  final api = ref.read(apiClientProvider);
  try {
    final resp = await api.get(ApiConstants.courseById(id));
    return CourseDetail.fromJson(resp.data['course'] as Map<String, dynamic>);
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
});
