import 'package:flutter/material.dart';

import 'empty_state_icon.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: ValueKey('loading'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Colors.blueAccent,
              strokeWidth: 1.5,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Đang tải camera...',
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Vui lòng đợi trong giây lát',
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class EmptyView extends StatefulWidget {
  final VoidCallback? onAddCamera;

  const EmptyView({super.key, this.onAddCamera});

  @override
  State<EmptyView> createState() => _EmptyViewState();
}

class _EmptyViewState extends State<EmptyView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        key: const ValueKey('empty'),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blueAccent.withValues(
                              alpha: _fadeAnimation.value * 0.3,
                            ),
                            width: 1,
                          ),
                        ),
                        child: const EmptyStateIcon(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Chưa có camera nào',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bắt đầu bằng cách thêm camera đầu tiên của bạn để giám sát và bảo vệ ngôi nhà',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              // const SizedBox(height: 32),
              // AddCameraButton(
              //   onPressed: widget.onAddCamera,
              //   label: 'Thêm camera đầu tiên',
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoSearchResultsView extends StatelessWidget {
  final String searchQuery;
  final VoidCallback onClearSearch;

  const NoSearchResultsView({
    super.key,
    required this.searchQuery,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('no_results'),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1 * 255),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off,
                size: 48,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Không tìm thấy camera',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Không có camera nào khớp với "$searchQuery"',
              style: const TextStyle(color: Colors.black54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: onClearSearch,
              icon: const Icon(Icons.clear),
              label: const Text('Xóa tìm kiếm'),
              style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
            ),
          ],
        ),
      ),
    );
  }
}
