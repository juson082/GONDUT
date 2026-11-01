# GONDUT 비공개 테스트 준비

## 업로드 전 확인

- Play Console에서 `app.gondut.memo` 사용 가능 여부를 확인합니다. 첫 업로드 이후 패키지 ID를 바꾸면 기존 앱과 별도 앱이 됩니다.
- 비공개 테스트용 서명 AAB와 업로드 키는 테스트 안내서를 참조합니다. 최초 Play 앱이라면 Play 앱 서명 설정을 확인하고 업로드합니다. 기존 앱이라면 기존 앱에 등록된 업로드 키를 사용해야 합니다.
- `privacy-policy.html` 또는 `privacy-policy-draft.md`의 문의 이메일과 시행일을 확인하고 검토한 후 누구나 로그인 없이 열 수 있는 HTTPS 페이지에 게시합니다. 운영자 J.MEN과 계정 이메일이 반영되어 있습니다. Play Console에 해당 주소를 입력하고 앱 내 개인정보 안내도 게시된 내용과 일치시킵니다.
- `listing-ko.md`의 소개 문구와 임시 스토어 아이콘을 검토합니다. 스토어 요구사항에 맞는 실제 기기 스크린샷과 그래픽을 준비합니다.
- Play Console의 앱 콘텐츠, 데이터 보안, 콘텐츠 등급, 광고, 대상 사용자, 앱 접근 권한, 연락처 등의 항목을 실제 서비스 및 개발자 계정에 맞게 작성합니다. 서드파티 라이브러리까지 확인한 후 제출합니다.
- 음성 인식과 로컬 모델의 동작, 소요 시간과 메모리 사용량은 실기기에서 아직 검증되지 않았습니다. 비공개 테스트에서 시험하고 오인식 및 잘못 분류된 결과를 확인합니다.
- 모델이 번들에 포함돼 다운로드 크기가 큽니다. Play Console에서 기기별 다운로드 크기와 업로드 허용 여부를 확인합니다.

## 참고

- [Google Play 테스트 요건](https://support.google.com/googleplay/android-developer/answer/14151465)
- [앱 크기 제한](https://support.google.com/googleplay/android-developer/answer/9859372)
- [대상 Android API 요건](https://developer.android.com/google/play/requirements/target-sdk)
- [개인정보처리방침과 데이터 보안 정책](https://support.google.com/googleplay/android-developer/answer/18265346)
