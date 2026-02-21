import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

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

  // 정렬 필터 옵션
  final List<String> _sortOptions = [
    '최신순',    
    '좋아요순',
    '댓글순',    
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
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
    setState(() {
      _searchQuery = query;
    });
    widget.onSearchChanged(query);
  }

  void _onSortSelected(String? sort) {
    if (sort != null) {
      setState(() {
        _selectedSort = sort;
      });
      widget.onSortChanged(sort);
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    
    return Column(
      children: [
        Center(
          child: Container(
            width: screenWidth * 0.9,
            height: 35,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  width: 1,
                  color: const Color(0xFFB8BFC8),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              children: [
                SvgPicture.asset('assets/icon/svg/search_gray.svg', width: 20, height: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: _onSearch,
                    onSubmitted: _onSearch,
                    decoration: const InputDecoration(
                      hintText: '검색',
                      hintStyle: TextStyle(
                        color: Color(0xFFB8BFC8),
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w400,
                        height: 1.12,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)                  
                  IconButton(
                    icon: const Icon(Icons.clear, size: 15,  color: Color(0xFFB8BFC8)),
                    onPressed: () {
                      _searchController.clear();
                      _onSearch('');
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: screenWidth * 0.28,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFB8BFC8),
                width: 0.5,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSort,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, size: 15),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF333333),
                ),
                items: _sortOptions.map((String sort) {
                  return DropdownMenuItem<String>(
                    value: sort,
                    child: Text(sort),
                  );
                }).toList(),
                onChanged: _onSortSelected,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
