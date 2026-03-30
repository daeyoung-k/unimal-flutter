import 'package:flutter/material.dart';

class BoardSearch extends StatefulWidget {
  final Function(bool) onFocusChange;
  final Function(String) onSearchChanged;
  final Function(String) onSortChanged;

  const BoardSearch({
    super.key,
    required this.onFocusChange,
    required this.onSearchChanged,
    required this.onSortChanged,
  });

  @override
  State<BoardSearch> createState() => _BoardSearchState();
}

class _BoardSearchState extends State<BoardSearch> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSort = '최신순';
  bool _isFocused = false;

  final List<String> _sortOptions = ['최신순', '좋아요순', '댓글순'];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
      widget.onFocusChange(_focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() => _searchQuery = query);
    widget.onSearchChanged(query);
  }

  void _onSortSelected(String? sort) {
    if (sort != null) {
      setState(() => _selectedSort = sort);
      widget.onSortChanged(sort);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 검색바
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(16),
            border: _isFocused
                ? Border.all(color: const Color(0xFF7AB3FF).withOpacity(0.5), width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: _isFocused ? const Color(0xFF7AB3FF) : const Color(0xFF9CA3AF),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  onChanged: _onSearch,
                  onSubmitted: _onSearch,
                  decoration: const InputDecoration(
                    hintText: '검색',
                    hintStyle: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Pretendard',
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                  child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF9CA3AF)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // 정렬 버튼 (탭 시 바텀시트)
        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '정렬',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._sortOptions.map((sort) {
                      final isSelected = _selectedSort == sort;
                      return InkWell(
                        onTap: () {
                          _onSortSelected(sort);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEEF6FF) : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Text(
                                sort,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontFamily: 'Pretendard',
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isSelected ? const Color(0xFF7AB3FF) : const Color(0xFF374151),
                                ),
                              ),
                              const Spacer(),
                              if (isSelected)
                                const Icon(Icons.check_rounded, size: 18, color: Color(0xFF7AB3FF)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF7AB3FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedSort,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
