import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/reviews/models/reviews_dtos.dart';
import 'package:next_fi/services/reviews/models/reviews_models.dart';
import 'package:next_fi/services/reviews/reviews_core_service.dart';

class PublicOfferReviewsModal extends StatefulWidget {
  const PublicOfferReviewsModal({
    super.key,
    required this.offerId,
    required this.c,
    required this.averageRating,
    required this.totalCount,
  });

  final String offerId;
  final AppColor c;
  final double? averageRating;
  final int totalCount;

  @override
  State<PublicOfferReviewsModal> createState() => _PublicOfferReviewsModalState();
}

class _PublicOfferReviewsModalState extends State<PublicOfferReviewsModal> {
  static const int _pageSize = 20;
  final _core = ReviewsCoreService.I;
  final _scrollCtrl = ScrollController();

  final List<ReviewModel> _items = <ReviewModel>[];
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingInitial || _loadingMore) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= (pos.maxScrollExtent - 240)) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _error = null;
      _items.clear();
      _page = 1;
      _hasMore = true;
    });
    try {
      final res = await _core.getOfferReviewsPaged(
        offerId: widget.offerId,
        query: const ReviewsListQuery(page: '1', limit: '20'),
      );
      final rows = List<ReviewModel>.from(res.items)
        ..sort((a, b) {
          final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
      if (!mounted) return;
      setState(() {
        _items.addAll(rows);
        _hasMore = res.meta.totalPages > 1;
        _loadingInitial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingInitial = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final next = _page + 1;
    try {
      final res = await _core.getOfferReviewsPaged(
        offerId: widget.offerId,
        query: ReviewsListQuery(page: '$next', limit: '$_pageSize'),
      );
      final rows = List<ReviewModel>.from(res.items)
        ..sort((a, b) {
          final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
      if (!mounted) return;
      setState(() {
        _items.addAll(rows);
        _page = next;
        _hasMore = next < res.meta.totalPages && rows.isNotEmpty;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Text(
                  'Offer Reviews',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${widget.totalCount})',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                const Spacer(),
                if (widget.averageRating != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _InlineRatingStars(c: c, rating: widget.averageRating),
                        const SizedBox(width: 4),
                        Text(
                          widget.averageRating!.toStringAsFixed(1),
                          style: TextStyle(
                            color: c.warning,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: _buildBody(c),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppColor c) {
    if (_loadingInitial) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Failed to load reviews',
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadInitial, child: const Text('Retry')),
          ],
        ),
      );
    }

    final commentItems = _items.where((r) => (r.comment ?? '').trim().isNotEmpty).toList();
    if (commentItems.isEmpty) {
      return Center(
        child: Text(
          _items.isEmpty ? 'No reviews yet' : 'No written comments yet',
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      itemCount: commentItems.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= commentItems.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return Padding(
          padding: EdgeInsets.only(bottom: index == commentItems.length - 1 ? 0 : 8),
          child: _PublicReviewItem(c: widget.c, review: commentItems[index]),
        );
      },
    );
  }
}

class _PublicReviewItem extends StatelessWidget {
  const _PublicReviewItem({required this.c, required this.review});

  final AppColor c;
  final ReviewModel review;

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 30) return '${d.day}/${d.month}/${d.year}';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 14,
                    color: i < review.rating ? c.warning : c.border,
                  ),
                ),
              ),
              const Spacer(),
              if (review.createdAt != null)
                Text(
                  _timeAgo(review.createdAt!),
                  style: TextStyle(color: c.textSecondary, fontSize: 10),
                ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              review.comment!,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineRatingStars extends StatelessWidget {
  const _InlineRatingStars({required this.c, required this.rating});

  final AppColor c;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final filled = (rating ?? 0).round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Padding(
          padding: EdgeInsets.only(right: i < 4 ? 1 : 0),
          child: Icon(
            i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 10,
            color: i < filled ? c.warning : c.border,
          ),
        ),
      ),
    );
  }
}
