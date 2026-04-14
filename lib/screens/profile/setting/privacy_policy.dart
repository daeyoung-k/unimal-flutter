import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          '개인정보처리방침',
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
            _SectionTitle('개인정보처리방침'),
            SizedBox(height: 8),
            _Body(
              '유니멀 아틀라스(이하 "회사"라 합니다)는 회사가 제공하는 서비스(이하 "서비스"라 합니다)를 이용하는 이용자의 개인정보를 중요하게 생각하며, 「개인정보 보호법」 등 관련 법령을 준수하고 있습니다. 회사는 이용자의 개인정보를 보호하고 이와 관련한 고충을 신속하고 원활하게 처리할 수 있도록 다음과 같이 개인정보처리방침을 수립·공개합니다.',
            ),
            SizedBox(height: 24),

            _ArticleTitle('제1조(목적)'),
            SizedBox(height: 8),
            _Body(
              '본 개인정보처리방침은 회사가 서비스 이용과 관련하여 수집하는 이용자의 개인정보를 어떠한 용도와 방식으로 처리하고 있으며, 개인정보 보호를 위하여 어떠한 조치를 취하고 있는지 안내하는 것을 목적으로 합니다.',
            ),
            SizedBox(height: 24),

            _ArticleTitle('제2조(개인정보 처리의 원칙)'),
            SizedBox(height: 8),
            _Body(
              '회사는 관련 법령 및 본 방침에 따라 이용자의 개인정보를 적법하고 공정하게 처리하며, 수집 목적의 범위 내에서 개인정보를 처리합니다.',
            ),
            SizedBox(height: 24),

            _ArticleTitle('제6조(본인확인을 위하여 수집하는 개인정보)'),
            SizedBox(height: 8),
            _Body('회사는 본인확인을 위하여 다음과 같은 개인정보를 수집할 수 있습니다.'),
            SizedBox(height: 6),
            _BulletItem('필수항목: 휴대전화번호, 이메일 주소'),
            SizedBox(height: 24),

            _ArticleTitle('제7조(서비스 제공을 위하여 수집하는 개인정보)'),
            SizedBox(height: 8),
            _Body('회사는 서비스 제공을 위하여 다음과 같은 개인정보를 수집할 수 있습니다.'),
            SizedBox(height: 6),
            _BulletItem('필수항목: 이메일 주소, 연락처'),
            SizedBox(height: 24),

            _ArticleTitle('제8조(개인정보 수집 방법)'),
            SizedBox(height: 8),
            _Body('회사는 다음과 같은 방법으로 개인정보를 수집합니다.'),
            SizedBox(height: 6),
            _NumberedItem(1, '이용자가 서비스 또는 홈페이지에서 직접 입력하는 방식'),
            _NumberedItem(2, '애플리케이션 등 회사가 제공하는 서비스 이용 과정에서 이용자가 직접 입력하는 방식'),
            _NumberedItem(3, '이용자가 회원가입 또는 서비스 이용 과정에서 휴대전화 본인확인 절차를 통해 개인정보를 입력하거나 인증기관을 통하여 제공받는 방식'),
            SizedBox(height: 24),

            _ArticleTitle('제9조(개인정보의 이용 목적)'),
            SizedBox(height: 8),
            _Body('회사는 수집한 개인정보를 서비스 제공, 회원관리, 불만처리 등 관련 법령에 따른 목적으로 이용합니다.'),
            SizedBox(height: 24),

            _ArticleTitle('제12조(법령에 따른 개인정보 보유·이용)'),
            SizedBox(height: 8),
            _Body('회사는 관계 법령에 따라 다음과 같이 개인정보를 보유 및 이용합니다.'),
            SizedBox(height: 6),
            _SubTitle('「전자상거래 등에서의 소비자보호에 관한 법률」'),
            _BulletItem('계약 또는 청약철회 등에 관한 기록: 5년'),
            _BulletItem('대금결제 및 재화 등의 공급에 관한 기록: 5년'),
            _BulletItem('소비자의 불만 또는 분쟁처리에 관한 기록: 3년'),
            _BulletItem('표시·광고에 관한 기록: 6개월'),
            SizedBox(height: 6),
            _SubTitle('「통신비밀보호법」'),
            _BulletItem('웹사이트 로그 기록 자료: 3개월'),
            SizedBox(height: 6),
            _SubTitle('「전자금융거래법」'),
            _BulletItem('전자금융거래에 관한 기록: 5년'),
            SizedBox(height: 6),
            _SubTitle('「위치정보의 보호 및 이용 등에 관한 법률」'),
            _BulletItem('개인위치정보에 관한 기록: 6개월'),
            SizedBox(height: 24),

            _ArticleTitle('제13조(개인정보의 파기 원칙)'),
            SizedBox(height: 8),
            _Body(
              '회사는 개인정보 보유기간의 경과, 처리 목적 달성 등 개인정보가 불필요하게 되었을 때에는 지체 없이 해당 개인정보를 파기합니다.',
            ),
            SizedBox(height: 24),

            _ArticleTitle('제14조(개인정보의 파기 절차)'),
            SizedBox(height: 8),
            _Body('이용자가 회원가입 등을 위해 입력한 개인정보는 처리 목적이 달성된 후 관련 법령에 따라 일정 기간 보관 후 파기됩니다.'),
            SizedBox(height: 24),

            _ArticleTitle('제17조(만 14세 미만 아동의 개인정보 처리)'),
            SizedBox(height: 8),
            _NumberedItem(1, '회사는 만 14세 미만 아동에 대한 개인정보 처리가 필요한 경우 법정대리인의 동의를 받는 등 관련 법령에 따른 조치를 이행합니다.'),
            _NumberedItem(2, '이 경우 회사는 법정대리인 확인에 필요한 최소한의 정보를 추가로 수집할 수 있습니다.'),
            SizedBox(height: 24),

            _ArticleTitle('제18조(개인정보의 조회 및 동의 철회)'),
            SizedBox(height: 8),
            _NumberedItem(1, '이용자 및 법정대리인은 언제든지 자신의 개인정보를 조회하거나 수정할 수 있으며, 개인정보 수집·이용에 대한 동의를 철회할 수 있습니다.'),
            _NumberedItem(2, '이용자 및 법정대리인이 개인정보 수집·이용 동의를 철회하고자 하는 경우, 개인정보 보호책임자 또는 담당자에게 서면, 전화 또는 전자우편으로 연락하시면 회사는 지체 없이 필요한 조치를 하겠습니다.'),
            SizedBox(height: 24),

            _ArticleTitle('제19조(개인정보의 정정·삭제)'),
            SizedBox(height: 8),
            _NumberedItem(1, '이용자는 회사에 자신의 개인정보 오류에 대한 정정을 요청할 수 있습니다.'),
            _NumberedItem(2, '이용자 또는 법정대리인의 요청에 따라 해지 또는 삭제된 개인정보는 관련 법령 및 본 방침에서 정한 보유기간에 따라 처리되며, 그 외의 용도로 열람 또는 이용되지 않도록 관리합니다.'),
            SizedBox(height: 24),

            _ArticleTitle('제23조(비밀번호의 보호)'),
            SizedBox(height: 8),
            _Body(
              '이용자의 비밀번호는 일방향 암호화 방식으로 저장 및 관리되며, 개인정보의 확인 및 변경은 비밀번호를 알고 있는 본인에 의해서만 가능합니다.',
            ),
            SizedBox(height: 24),

            _ArticleTitle('제24조(해킹 등에 대비한 대책)'),
            SizedBox(height: 8),
            _NumberedItem(1, '회사는 해킹, 컴퓨터 바이러스 등 정보통신망 침입에 의하여 개인정보가 유출되거나 훼손되는 것을 방지하기 위하여 최선을 다하고 있습니다.'),
            _NumberedItem(2, '회사는 최신 보안프로그램을 설치·운영하여 개인정보나 자료가 유출 또는 손상되지 않도록 방지하고 있습니다.'),
            _NumberedItem(3, '회사는 침입차단시스템 등 보안장치를 이용하여 외부로부터의 무단 접근을 통제하고 있습니다.'),
            SizedBox(height: 24),

            _ArticleTitle('제29조(개인정보 자동 수집 장치의 설치·운영 및 거부)'),
            SizedBox(height: 8),
            _NumberedItem(1, '회사는 이용자에게 보다 편리한 서비스를 제공하기 위하여 쿠키(cookie)를 사용할 수 있습니다.'),
            _NumberedItem(2, '쿠키는 웹사이트를 운영하는 데 이용되는 서버가 이용자의 브라우저에 보내는 소량의 정보로, 이용자의 기기 내 저장공간에 보관될 수 있습니다.'),
            _NumberedItem(3, '이용자는 웹브라우저 설정을 통하여 쿠키 저장을 거부하거나 저장 시마다 확인하도록 설정할 수 있습니다.'),
            _NumberedItem(4, '다만, 쿠키 저장을 거부할 경우 로그인 등 일부 서비스 이용에 어려움이 발생할 수 있습니다.'),
            SizedBox(height: 24),

            _ArticleTitle('제31조(권익침해 구제방법)'),
            SizedBox(height: 8),
            _Body(
              '이용자는 개인정보 침해로 인한 구제를 받기 위하여 관계 법령이 정하는 바에 따라 행정심판을 청구할 수 있습니다.',
            ),
            SizedBox(height: 32),

            Divider(color: Color(0xFFEEEEEE)),
            SizedBox(height: 16),
            _Body('부칙'),
            SizedBox(height: 4),
            _Body('본 개인정보처리방침은 2026년 4월 15일부터 시행합니다.'),
            SizedBox(height: 40),
          ],
        ),
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

class _SubTitle extends StatelessWidget {
  final String text;
  const _SubTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
          fontFamily: 'Pretendard',
        ),
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
