import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class BoardSearch extends StatefulWidget {
  final Function(bool) onFocusChange;

  const BoardSearch({super.key, required this.onFocusChange});

  @override
  State<BoardSearch> createState() => _BoardSearchState();
}

class _BoardSearchState extends State<BoardSearch> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedLocation = '내 근처';
  String _selectedSort = '최신순';

  // 임시 추천 검색어 목록
  final List<String> _suggestions = [
    '강아지',
    '고양이',
    '반려동물',
    '애완동물',
    '동물병원',
    '산책',
    '사료',
    '간식',
    '미용',
    '훈련'
  ];

  // 지역 필터 옵션
  final List<String> _locationOptions = [
    '내 근처',
    '전체',
    '강남구',
    '서초구',
    '송파구',
    '마포구',
  ];

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
      setState(() {
        _isSearching = _focusNode.hasFocus;
      });
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
    // TODO: 실제 검색 로직 구현
    print("검색어: $query");
  }

  void _onSuggestionSelected(String suggestion) {
    _searchController.text = suggestion;
    _onSearch(suggestion);
    _focusNode.unfocus();
  }

  void _onLocationSelected(String? location) {
    if (location != null) {
      setState(() {
        _selectedLocation = location;
      });
      _applyFilters();
    }
  }

  void _onSortSelected(String? sort) {
    if (sort != null) {
      setState(() {
        _selectedSort = sort;
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    // TODO: 실제 필터 로직 구현
    print("지역: $_selectedLocation, 정렬: $_selectedSort");
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
            width: screenWidth * 0.4,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            margin: EdgeInsets.only(left: screenWidth * 0.05),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFB8BFC8),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLocation,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 15),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF333333),
                      ),
                      items: _locationOptions.map((String location) {
                        return DropdownMenuItem<String>(
                          value: location,
                          child: Text(location),
                        );
                      }).toList(),
                      onChanged: _onLocationSelected,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 10,
                  color: const Color(0xFFB8BFC8),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
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
              ],
            ),
          ),
        ),
        if (_isSearching)
          Container(
            width: screenWidth * 0.9,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '추천 검색어',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
                ..._suggestions.map((suggestion) => ListTile(
                  title: Text(
                    suggestion,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF333333),
                    ),
                  ),
                  onTap: () => _onSuggestionSelected(suggestion),
                )).toList(),
              ],
            ),
          ),
      ],
    );
  }
}
