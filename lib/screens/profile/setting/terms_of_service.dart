import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '이용약관',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontFamily: 'Pretendard',
          ),
        ),
        centerTitle: true,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('유니멀 아틀라스 이용약관'),
            SizedBox(height: 8),
            _Body(
              '본 약관은 유니멀 아틀라스(이하 "회사"라 합니다)가 제공하는 유니멀 아틀라스 서비스(이하 "서비스"라 합니다) 이용에 관한 조건 및 절차, 회사와 이용자의 권리·의무 및 책임사항을 규정함을 목적으로 합니다.',
            ),
            SizedBox(height: 24),

            _ArticleTitle('제1조(목적)'),
            SizedBox(height: 8),
            _Body(
              '이 약관은 회사가 운영하는 유니멀 아틀라스 모바일 애플리케이션 및 관련 서비스를 이용함에 있어 회사와 이용자 간의 권리, 의무 및 책임사항, 기타 필요한 사항을 규정하는 것을 목적으로 합니다.',
            ),
            SizedBox(height: 24),

            _ArticleTitle('제2조(정의)'),
            SizedBox(height: 8),
            _Body('이 약관에서 사용하는 용어의 정의는 다음과 같습니다.'),
            SizedBox(height: 6),
            _NumberedItem(1, '"서비스"란 회사가 제공하는 유니멀 아틀라스 애플리케이션 및 이와 관련된 모든 서비스를 의미합니다.'),
            _NumberedItem(2, '"이용자"란 본 약관에 동의하고 회사가 제공하는 서비스를 이용하는 회원 및 비회원을 말합니다.'),
            _NumberedItem(3, '"회원"이란 회사와 서비스 이용 계약을 체결하고 아이디(ID)를 부여받은 자를 말합니다.'),
            _NumberedItem(4, '"게시물"이란 회원이 서비스를 이용하면서 게시한 글, 사진, 댓글, 위치 정보 등 일체의 정보를 말합니다.'),
            SizedBox(height: 24),

            _ArticleTitle('제3조(약관의 효력 및 변경)'),
            SizedBox(height: 8),
            _NumberedItem(1, '이 약관은 서비스를 이용하고자 하는 모든 이용자에게 적용됩니다.'),
            _NumberedItem(2, '회사는 관련 법령을 위배하지 않는 범위에서 본 약관을 개정할 수 있습니다.'),
            _NumberedItem(3, '약관이 변경되는 경우 회사는 변경 사항을 시행일 7일 전부터 서비스 내 공지사항을 통해 공지합니다.'),
            _NumberedItem(4, '이용자가 변경된 약관에 동의하지 않을 경우 서비스 이용을 중단하고 탈퇴할 수 있습니다.'),
            SizedBox(height: 24),

            _ArticleTitle('제4조(회원가입)'),
            SizedBox(height: 8),
            _NumberedItem(1, '이용자는 회사가 정한 양식에 따라 회원 정보를 기입한 후 이 약관에 동의함으로써 회원가입을 신청합니다.'),
            _NumberedItem(2, '회사는 다음 각 호에 해당하는 신청에 대해서는 가입을 거절하거나 사후에 이용 계약을 해지할 수 있습니다.'),
            _BulletItem('타인의 명의나 정보를 도용하여 신청한 경우'),
            _BulletItem('허위 정보를 기재하거나 회사가 요구하는 정보를 기재하지 않은 경우'),
            _BulletItem('만 14세 미만인 경우'),
            _BulletItem('이전에 서비스 이용 계약이 해지된 경우'),
            _NumberedItem(3, '회원가입 계약은 회사의 승낙이 이용자에게 도달한 시점에 성립됩니다.'),
            SizedBox(height: 24),

            _ArticleTitle('제5조(소셜 로그인)'),
            SizedBox(height: 8),
            _Body(
              '회사는 카카오, 네이버, 구글 등의 소셜 계정을 통한 간편 로그인 기능을 제공합니다. 소셜 로그인 이용 시 해당 플랫폼의 이용약관 및 개인정보처리방침이 함께 적용될 수 있습니다.',
            ),
            SizedBox(height: 24),

            _ArticleTitle('제6조(회원 정보 관리)'),
            SizedBox(height: 8),
            _NumberedItem(1, '회원은 서비스 내 개인정보 설정을 통해 자신의 정보를 직접 열람하고 수정할 수 있습니다.'),
            _NumberedItem(2, '회원은 자신의 계정 정보를 타인에게 공유하거나 양도해서는 안 됩니다.'),
            _NumberedItem(3, '회원의 부주의로 인한 개인정보 유출에 대해 회사는 책임을 지지 않습니다.'),
            SizedBox(height: 24),

            _ArticleTitle('제7조(서비스의 제공)'),
            SizedBox(height: 8),
            _Body('회사는 다음과 같은 서비스를 제공합니다.'),
            SizedBox(height: 6),
            _BulletItem('위치 기반 커뮤니티 서비스'),
            _BulletItem('게시물 작성, 조회, 댓글 등 게시판 서비스'),
            _BulletItem('회원 프로필 및 정보 관리 서비스'),
            _BulletItem('기타 회사가 추가 개발하거나 제휴를 통해 제공하는 서비스'),
            SizedBox(height: 24),

            _ArticleTitle('제8조(서비스 이용 시간)'),
            SizedBox(height: 8),
            _NumberedItem(1, '서비스는 연중무휴, 1일 24시간 제공함을 원칙으로 합니다.'),
            _NumberedItem(2, '회사는 시스템 정기점검, 보수, 교체 등 운영상 필요한 경우 서비스를 일시적으로 중단할 수 있으며, 이 경우 사전에 공지합니다.'),
            SizedBox(height: 24),

            _ArticleTitle('제9조(위치 기반 서비스)'),
            SizedBox(height: 8),
            _NumberedItem(1, '서비스는 이용자의 위치 정보를 활용한 기능을 제공합니다.'),
            _NumberedItem(2, '위치 정보 수집·이용을 위해서는 이용자의 별도 동의가 필요하며, 동의를 거부하더라도 위치 기반 기능 외 서비스 이용은 가능합니다.'),
            _NumberedItem(3, '위치 정보의 수집·이용에 관한 사항은 별도의 위치정보 이용약관에 따릅니다.'),
            SizedBox(height: 24),

            _ArticleTitle('제10조(게시물의 관리)'),
            SizedBox(height: 8),
            _NumberedItem(1, '회원이 작성한 게시물에 대한 저작권은 해당 회원에게 있습니다.'),
            _NumberedItem(2, '회원은 서비스에 게시물을 등록함으로써 회사가 해당 게시물을 서비스 운영 및 홍보 목적으로 이용할 수 있도록 허락합니다.'),
            _NumberedItem(3, '회사는 다음 각 호에 해당하는 게시물을 사전 통보 없이 삭제하거나 이동할 수 있습니다.'),
            _BulletItem('타인의 개인정보, 명예, 사생활을 침해하는 내용'),
            _BulletItem('음란물 또는 청소년에게 유해한 내용'),
            _BulletItem('불법 정보 또는 사기성 내용'),
            _BulletItem('반복적으로 게시되는 도배성 내용'),
            _BulletItem('관련 법령 또는 본 약관에 위배되는 내용'),
            SizedBox(height: 24),

            _ArticleTitle('제11조(이용자의 의무)'),
            SizedBox(height: 8),
            _Body('이용자는 다음 행위를 해서는 안 됩니다.'),
            SizedBox(height: 6),
            _NumberedItem(1, '타인의 정보 도용 및 허위 정보 등록'),
            _NumberedItem(2, '서비스에 게시된 정보 무단 변경'),
            _NumberedItem(3, '회사가 허용하지 않은 광고, 스팸성 게시물 등록'),
            _NumberedItem(4, '서비스의 정상적인 운영을 방해하는 행위'),
            _NumberedItem(5, '타인의 지적재산권 또는 저작권 침해 행위'),
            _NumberedItem(6, '기타 관련 법령 또는 회사의 정책에 위반되는 행위'),
            SizedBox(height: 24),

            _ArticleTitle('제12조(서비스 이용 제한)'),
            SizedBox(height: 8),
            _Body(
              '회사는 이용자가 본 약관을 위반하거나 서비스의 정상적인 운영을 방해한 경우, 경고·일시정지·영구이용정지 등의 조치를 취할 수 있습니다.',
            ),
            SizedBox(height: 24),

            _ArticleTitle('제13조(회원 탈퇴 및 자격 상실)'),
            SizedBox(height: 8),
            _NumberedItem(1, '회원은 언제든지 서비스 내 탈퇴 기능을 통해 이용 계약 해지를 요청할 수 있습니다.'),
            _NumberedItem(2, '탈퇴 시 회원의 게시물은 삭제되지 않을 수 있으며, 삭제를 원하는 경우 탈퇴 전에 직접 삭제해야 합니다.'),
            _NumberedItem(3, '탈퇴한 회원의 정보는 개인정보처리방침에 따라 처리됩니다.'),
            SizedBox(height: 24),

            _ArticleTitle('제14조(책임의 한계)'),
            SizedBox(height: 8),
            _NumberedItem(1, '회사는 천재지변, 전쟁, 기간통신사업자의 서비스 중단 등 불가항력으로 인한 서비스 장애에 대해 책임을 지지 않습니다.'),
            _NumberedItem(2, '회사는 이용자의 귀책사유로 인한 서비스 이용 장애에 대해 책임을 지지 않습니다.'),
            _NumberedItem(3, '회사는 이용자가 서비스를 통해 얻은 정보나 자료의 신뢰도, 정확성에 대해 보증하지 않습니다.'),
            SizedBox(height: 24),

            _ArticleTitle('제15조(분쟁 해결 및 관할)'),
            SizedBox(height: 8),
            _NumberedItem(1, '서비스와 관련하여 분쟁이 발생한 경우 회사와 이용자는 분쟁을 원만히 해결하기 위하여 성실히 협의합니다.'),
            _NumberedItem(2, '협의가 이루어지지 않을 경우 관련 법령에 따라 관할 법원에 소를 제기할 수 있습니다.'),
            SizedBox(height: 24),

            _ArticleTitle('제16조(이용 문의)'),
            SizedBox(height: 8),
            _Body('서비스 이용과 관련한 문의 및 불만 사항은 아래 이메일로 접수해 주시기 바랍니다. 회사는 접수된 내용을 확인하고 신속하게 처리하겠습니다.'),
            SizedBox(height: 8),
            _ContactBox(),
            SizedBox(height: 32),

            Divider(color: Color(0xFFEEEEEE)),
            SizedBox(height: 16),
            _Body('부칙'),
            SizedBox(height: 4),
            _Body('본 이용약관은 2026년 5월 17일부터 시행합니다.'),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ContactBox extends StatelessWidget {
  const _ContactBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE8FF)),
      ),
      child: const Row(
        children: [
          Icon(Icons.email_outlined, size: 18, color: Color(0xFF4D91FF)),
          SizedBox(width: 10),
          Text(
            'support@unimal.co.kr',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4D91FF),
              fontFamily: 'Pretendard',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
        fontFamily: 'Pretendard',
      ),
    );
  }
}

class _ArticleTitle extends StatelessWidget {
  final String text;
  const _ArticleTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
        fontFamily: 'Pretendard',
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.black54,
        fontFamily: 'Pretendard',
        height: 1.6,
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14, color: Colors.black45, fontFamily: 'Pretendard')),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontFamily: 'Pretendard',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberedItem extends StatelessWidget {
  final int number;
  final String text;
  const _NumberedItem(this.number, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number. ', style: const TextStyle(fontSize: 14, color: Colors.black45, fontFamily: 'Pretendard')),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontFamily: 'Pretendard',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
