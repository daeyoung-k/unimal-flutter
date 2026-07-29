/// 서버 미구현 기간 UI 확인용 목 응답.
///
/// **이 문자열은 실제 파서(`decodeMapFeedResponse`)를 그대로 탄다.** 목이 파서를
/// 우회하면 목으로 본 화면과 실서버 화면이 달라질 수 있다.
///
/// 활성 조건: `.env.local` 의 `MAP_FEED_MOCK=true`. 릴리즈는 `.env.prod` 를 쓰고
/// 그 파일에는 키가 없으므로 자동으로 비활성이다.
///
/// 서버가 붙으면: `.env.local` 에서 키를 지우고 이 파일과
/// `board_api_service.getMapFeed` 의 분기 3줄을 삭제한다.
///
/// 데이터 구성 의도:
/// - `LATEST` 5건 — 사진 글 4 + **사진 없는 텍스트 글 1**(`thumbnail_url` null 렌더 확인)
/// - `HOT` 3건 — `has_more: false` (헤더에 `>` 안 뜨는지 확인)
/// - `NEARBY` 4건 — `has_more: true`
/// - 제목 빈 글 1건 포함 (본문 폴백 확인)
const String kMapFeedMockJson = '''
{
  "code": 200,
  "message": "Success",
  "data": {
    "dong": "역삼동",
    "sections": [
      {
        "type": "LATEST",
        "title": "방금 올라온 소식",
        "has_more": true,
        "items": [
          {
            "board_id": "mock-l1",
            "thumbnail_url": "https://cdn.unimal.co.kr/images/c2NhbGVkX0lNR18yMDI2MDQwN18xNjMxMzAuanBn-693be74f7721479bb08a055c67888b5c.jpeg",
            "title": "역삼동 골목 고양이",
            "content": "퇴근길에 만난 삼색이. 사람을 안 피하네요.",
            "street_name": "서울 강남구 역삼로 123",
            "dong": "역삼동",
            "latitude": 37.5006,
            "longitude": 127.0366,
            "nickname": "대영",
            "profile_image": null,
            "like_count": 12,
            "reply_count": 3,
            "created_at": "2026-07-29T14:33:00"
          },
          {
            "board_id": "mock-l2",
            "thumbnail_url": "https://cdn.unimal.co.kr/images/c2NhbGVkXzIwMjYwNjMwXzIzMTMzMi5qcGc=-d48c4a41ed1f46fc96b4bc26d1acdc72.jpeg",
            "title": "",
            "content": "제목 없는 글입니다. 카드에서 본문이 제목 자리에 와야 합니다.",
            "street_name": "서울 강남구 테헤란로 44",
            "dong": "역삼동",
            "latitude": 37.5012,
            "longitude": 127.0372,
            "nickname": "지수",
            "profile_image": null,
            "like_count": 4,
            "reply_count": 0,
            "created_at": "2026-07-29T13:10:00"
          },
          {
            "board_id": "mock-l3",
            "thumbnail_url": null,
            "title": "사진 없는 글",
            "content": "썸네일이 없을 때 카드가 어떻게 보이는지 확인용입니다.",
            "street_name": "서울 강남구 봉은사로 12",
            "dong": "역삼동",
            "latitude": 37.5031,
            "longitude": 127.0341,
            "nickname": "민호",
            "profile_image": null,
            "like_count": 1,
            "reply_count": 1,
            "created_at": "2026-07-29T11:05:00"
          },
          {
            "board_id": "mock-l4",
            "thumbnail_url": "https://cdn.unimal.co.kr/images/aW1hZ2VfcGlja2VyX0U1MDg3MDJCLTIyOUUtNDQ1Qi04MEY2LUQ0RUE0RUM3NjcwNy0zODQ4LTAwMDAwMUVBODE3RDIzRDkuanBn-625234aa73ac4ee2a6b4a7478eb9d258.jpeg",
            "title": "점심 맛집 발견",
            "content": "줄 서서 먹을 만합니다.",
            "street_name": "서울 강남구 역삼로 87",
            "dong": "역삼동",
            "latitude": 37.4998,
            "longitude": 127.0388,
            "nickname": "현우",
            "profile_image": null,
            "like_count": 22,
            "reply_count": 7,
            "created_at": "2026-07-29T09:40:00"
          },
          {
            "board_id": "mock-l5",
            "thumbnail_url": "https://cdn.unimal.co.kr/images/MzE3YzIzMmQtMTIzMC00YjM2LTliZjAtZjAzMDA1YWZmOTI5NzY2MTc1MjY0MzIxNjA3MjMyNS5qcGc=-3c507125752c481fbc021a245ecd7853.jpeg",
            "title": "한강 야경",
            "content": "오늘 바람이 좋았어요.",
            "street_name": "서울 강남구 압구정로 1",
            "dong": "역삼동",
            "latitude": 37.5104,
            "longitude": 127.0301,
            "nickname": "서연",
            "profile_image": null,
            "like_count": 31,
            "reply_count": 5,
            "created_at": "2026-07-28T21:15:00"
          }
        ]
      },
      {
        "type": "HOT",
        "title": "지금 인기 있는 스토리",
        "has_more": false,
        "items": [
          {
            "board_id": "mock-h1",
            "thumbnail_url": "https://cdn.unimal.co.kr/images/aW1hZ2VfcGlja2VyX0EyRUQ4NDFDLTdCNzYtNEIyMi04NUNGLUFBNTA5RUYzMkJDMS05NTYwLTAwMDAwNTAwOUI1QzNGMUYuanBn-3e1c70eee0234c238bd9f5726bee62df.jpeg",
            "title": "동네 벽화 완성",
            "content": "주말에 다 같이 칠했습니다.",
            "street_name": "서울 강남구 언주로 30",
            "dong": "역삼동",
            "latitude": 37.4971,
            "longitude": 127.0333,
            "nickname": "가영",
            "profile_image": null,
            "like_count": 88,
            "reply_count": 24,
            "created_at": "2026-07-27T18:00:00"
          },
          {
            "board_id": "mock-h2",
            "thumbnail_url": "https://cdn.unimal.co.kr/images/aW1hZ2VfcGlja2VyXzJBRUQwRTc4LThGREUtNEIyQy1CQjkzLUQxREEyRURFQzgwNS05NTYwLTAwMDAwNTAwQTEyMDc1M0MuanBn-1d97278c7f724f4b9fb0d1929020b4f3.jpeg",
            "title": "길 잃은 강아지 찾았어요",
            "content": "주인분 찾습니다.",
            "street_name": "서울 강남구 도곡로 5",
            "dong": "역삼동",
            "latitude": 37.4955,
            "longitude": 127.0359,
            "nickname": "준영",
            "profile_image": null,
            "like_count": 54,
            "reply_count": 19,
            "created_at": "2026-07-27T12:30:00"
          },
          {
            "board_id": "mock-h3",
            "thumbnail_url": "https://cdn.unimal.co.kr/images/aW1hZ2VfcGlja2VyXzEyNEU5REUyLTlENkYtNDM3Mi04MUUwLTY2OThFQzBFNDc3NS05ODE4LTAwMDAwNTJBQUU5N0FEQjQuanBn-0308bd60cf444e099cb48f1dbd665916.jpeg",
            "title": "플리마켓 후기",
            "content": "생각보다 사람이 많았습니다.",
            "street_name": "서울 강남구 선릉로 100",
            "dong": "역삼동",
            "latitude": 37.5044,
            "longitude": 127.0489,
            "nickname": "하늘",
            "profile_image": null,
            "like_count": 40,
            "reply_count": 11,
            "created_at": "2026-07-26T16:20:00"
          }
        ]
      },
      {
        "type": "NEARBY",
        "title": "역삼동 이웃들의 스토리",
        "has_more": true,
        "items": [
          {
            "board_id": "mock-n1",
            "thumbnail_url": "https://cdn.unimal.co.kr/images/aW1hZ2VfcGlja2VyXzU0QzZGMTE5LTgxMjMtNDQxNy05RDM3LTI0MDg2REM4Q0QxNS05ODE4LTAwMDAwNTJBQUVEQkNBRTAuanBn-f1116ab83eef470ebe0084ca47d8054d.jpeg",
            "title": "새로 생긴 카페",
            "content": "조용해서 작업하기 좋아요.",
            "street_name": "서울 강남구 역삼로 200",
            "dong": "역삼동",
            "latitude": 37.5021,
            "longitude": 127.0412,
            "nickname": "다온",
            "profile_image": null,
            "like_count": 9,
            "reply_count": 2,
            "created_at": "2026-07-25T10:00:00"
          },
          {
            "board_id": "mock-n2",
            "thumbnail_url": "https://cdn.unimal.co.kr/images/aW1hZ2VfcGlja2VyX0U2MzMxNDBBLURBMjItNDdENi04RTdCLTA0QTJENTQzNjNCOC0xMDM3Ny0wMDAwMDU0RTJGQ0E5ODNDLmpwZw==-834210a55e5f4d479dd91894b98565a6.jpeg",
            "title": "공원 산책로 정비 끝",
            "content": "이제 걷기 편합니다.",
            "street_name": "서울 강남구 논현로 77",
            "dong": "역삼동",
            "latitude": 37.4989,
            "longitude": 127.0299,
            "nickname": "은지",
            "profile_image": null,
            "like_count": 6,
            "reply_count": 0,
            "created_at": "2026-07-24T08:45:00"
          },
          {
            "board_id": "mock-n3",
            "thumbnail_url": "https://cdn.unimal.co.kr/images/aW1hZ2VfcGlja2VyXzkyMjhDNjM3LUEzODctNDkyNS05NUEyLTZDNDVFOTM3RDdFMi0xMDM3Ny0wMDAwMDU0RTMwNUFGMUQ1LmpwZw==-b608c9c98233494fa46e49c280e36a0b.jpeg",
            "title": "중고 책장 나눔",
            "content": "가져가실 분 댓글 주세요.",
            "street_name": "서울 강남구 역삼로 55",
            "dong": "역삼동",
            "latitude": 37.5002,
            "longitude": 127.0350,
            "nickname": "태현",
            "profile_image": null,
            "like_count": 3,
            "reply_count": 8,
            "created_at": "2026-07-23T19:30:00"
          },
          {
            "board_id": "mock-n4",
            "thumbnail_url": "https://cdn.unimal.co.kr/images/aW1hZ2VfcGlja2VyXzFCNTg2QzFELUIzMTQtNDY0QS04RDg3LURGNkE5RjA5ODQzNC0xMDM3Ny0wMDAwMDU0RTMwMTIxREM5LmpwZw==-ee3d3d698f2e4a39a19f3f6d34bc6fbb.jpeg",
            "title": "골목 벼룩시장",
            "content": "토요일마다 열립니다.",
            "street_name": "서울 강남구 테헤란로 200",
            "dong": "역삼동",
            "latitude": 37.5038,
            "longitude": 127.0441,
            "nickname": "소라",
            "profile_image": null,
            "like_count": 15,
            "reply_count": 4,
            "created_at": "2026-07-22T14:00:00"
          }
        ]
      }
    ]
  }
}
''';
