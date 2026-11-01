import 'package:flutter/widgets.dart';
import 'extra_translations.dart';

/// Korean strings are stable internal keys; user content is never translated.
String tr(BuildContext context, String korean) {
  final code = Localizations.localeOf(context).languageCode;
  if (code == 'ko') return korean;
  final english = _english[korean] ?? korean;
  return additionalTranslation(code, english) ?? english;
}

const _english = <String, String>{
  '노드 모양': 'Node shape',
  '둥근 사각형': 'Rounded rectangle',
  '알약': 'Pill',
  '원': 'Circle',
  '마름모': 'Diamond',
  '모양을 저장하지 못했습니다. 다시 시도해 주세요.': 'Could not save the shape. Please try again.',
  '빈 곳을 두 번 눌러 노드를 추가하세요': 'Double-tap an empty spot to add a node',
  '가지 메뉴': 'Branch menu',
  '원문을 저장했지만 가지에 추가하지 못했습니다.':
      'Saved the transcript, but could not add the branch.',
  '원문을 저장하고 지정한 가지에 추가했습니다.':
      'Saved the transcript and added it to the specified branch.',
  '원문을 저장했습니다. 메모 또는 가지를 확실히 찾지 못해 연결하지 않았습니다.':
      'Saved the transcript. No branch was added because the note or branch could not be uniquely identified.',
  '자동 저장하지 못했습니다. 다시 시도해 주세요.':
      'Could not save automatically. Please try again.',
  '다시 시도': 'Retry',
  '가지를 옮겼습니다.': 'Branch moved.',
  '되돌리기': 'Undo',
  '되돌리지 못했습니다. 다시 시도해 주세요.': 'Could not undo. Please try again.',
  '마지막 획 다시 실행': 'Redo last stroke',
  '내용을 눌러 수정': 'Tap the text to edit',
  '눌러 수정 · 길게 눌러 옮기면 가까운 가지에 연결':
      'Tap to edit · Hold and move to connect to a nearby branch',
  '어느 가지에 연결할까요?': 'Connect to which branch?',
  '연결 변경': 'Change connection',
  '위치를 저장하지 못했습니다. 다시 시도해 주세요.':
      'Could not save the position. Please try again.',
  '키보드 입력': 'Keyboard input',
  '전체 보기': 'Fit tree',
  '손글씨를 읽지 못했습니다. 글씨와 언어를 확인해 주세요.':
      'Could not recognize the handwriting. Check the writing and language.',
  '변환 결과 확인': 'Review recognized text',
  '인식 결과를 확인하고 수정해 주세요. 손글씨 원본은 그대로 보관됩니다.':
      'Review and edit the recognized text. Your original handwriting is preserved.',
  '메모에 추가': 'Add to note',
  '추가하고 AI 그래프 만들기': 'Add and create AI tree',
  '추가할 텍스트가 없습니다.': 'There is no text to add.',
  '변환하지 못했습니다. 손글씨 원본은 보관됩니다.':
      'Recognition failed. Your original handwriting is preserved.',
  '손글씨 인식 중…': 'Recognizing handwriting…',
  '글자로 변환': 'Convert to text',
  '변환한 글을 메모에 추가했습니다.': 'Recognized text added to the note.',
  '언어': 'Language',
  '기기 설정 따르기': 'Use device language',
  '언어를 저장하지 못했습니다.': 'Could not save the language.',
  '설정': 'Settings',
  '앱 테마': 'App theme',
  '마음에 드는 색을 골라 보세요.': 'Choose a color you like.',
  '라벤더': 'Lavender',
  '장미': 'Rose',
  '복숭아': 'Peach',
  '세이지': 'Sage',
  '하늘': 'Sky',
  '샌드': 'Sand',
  '닫기': 'Close',
  '취소': 'Cancel',
  '삭제': 'Delete',
  '저장': 'Save',
  '교체': 'Replace',
  '수정': 'Edit',
  '백업 저장 완료': 'Backup saved',
  '백업 복원': 'Restore backup',
  '현재 메모와 그래프를 백업 내용으로 교체합니다. 먼저 현재 데이터를 백업하세요.':
      'Your notes and trees will be replaced by the backup. Back up current data first.',
  '복원 완료': 'Restore complete',
  '테마를 저장하지 못했습니다. 다시 시도해 주세요.': 'Could not save the theme. Please try again.',
  '음성 메모': 'Voice note',
  '개인정보와 저장': 'Privacy and storage',
  '설정 · 테마': 'Settings · theme',
  '백업 저장': 'Save backup',
  '이전 그래프 기록 보기': 'View previous graphs',
  '새 메모': 'New note',
  '이전 그래프 기록': 'Previous graphs',
  '이전 버전의 메모 간 연결입니다. 읽기 전용으로 보관되며 백업에도 포함됩니다.':
      'Connections from the previous version are read-only and included in backups.',
  '(빈 메모)': '(Empty note)',
  '생각을 한 장씩 모아 보세요': 'Gather your thoughts, one page at a time',
  '새 메모를 눌러 시작해요': 'Tap New note to begin',
  '길게 눌러 더보기': 'Press and hold for options',
  '음성 분석 초안 확인': 'Review voice analysis draft',
  '메모 삭제': 'Delete note',
  '메모와 이 메모의 가지가 삭제됩니다. 이전 그래프에 배치된 메모라면 해당 노드와 연결도 함께 삭제됩니다.':
      'This note and its branches will be deleted, along with any nodes and links in older graphs.',
  '그래프에 놓기': 'Drop onto graph',
  '메모를 아래로 끌어 놓거나 +로 추가 · 노드를 끌어 이동':
      'Drag a note below or tap + to add it · Drag nodes to move them',
  '연결할 대상 노드를 선택하세요': 'Select a node to connect',
  '메모 배치': 'Place note',
  '연결 취소': 'Cancel connection',
  '연결 관리': 'Manage connections',
  '배치할 메모': 'Choose a note',
  '다른 노드에 연결': 'Connect to another node',
  '그래프에서 제거': 'Remove from graph',
  '그래프 초안': 'Tree draft',
  '저장된 초안이 없습니다. 이 메모를 기기에서 분석할 수 있습니다.':
      'No draft saved. You can analyze this note on your device.',
  '분석': 'Analyze',
  '음성 그래프 초안': 'Voice tree draft',
  '후보를 확인하고 수정하세요. 원문 메모는 그대로 보관됩니다.':
      'Review and edit the suggestions. Your original note is preserved.',
  '확인 후 이 메모의 나무에 가지로 추가할 수 있습니다.':
      'After review, you can add them to this note’s tree.',
  '초안 저장': 'Save draft',
  '이 메모의 나무에 추가': 'Add to this note’s tree',
  '배치할 내용이 없습니다.': 'There is nothing to add.',
  '초안을 저장했습니다.': 'Draft saved.',
  '분석할 메모가 없습니다.': 'There is no note to analyze.',
  '기기에서 분석 중입니다. 시간이 걸릴 수 있습니다.': 'Analyzing on device. This may take a while.',
  '초안 후보를 찾지 못했습니다. 원문은 유지됩니다.':
      'No suggestions found. Your original is preserved.',
  '메모나 초안이 변경되어 분석 결과를 저장하지 않았습니다.':
      'The note or draft changed, so the analysis was not saved.',
  '먼저 메모에 내용을 적어 주세요.': 'Write something in your note first.',
  '원문에서 확인할 수 있는 과정 후보를 찾지 못했습니다. 직접 가지를 추가할 수 있습니다.':
      'No process suggestions were found in the source. You can add branches yourself.',
  '확인한 초안을 나무에 추가했습니다. 자유롭게 수정할 수 있습니다.':
      'Added the reviewed draft to your tree. You can edit it freely.',
  'AI 초안을 만들지 못했습니다. 원문과 기존 가지는 보관됩니다. 메모가 길거나 변경되었는지도 확인해 주세요.':
      'Could not create an AI draft. Your original and existing branches are preserved. Check whether the note is too long or has changed.',
  '저장하지 못했습니다. 다시 시도해 주세요.': 'Could not save. Please try again.',
  '내 노트': 'My note',
  '글쓰기': 'Write',
  '나무 그래프': 'Tree',
  '손글씨': 'Handwriting',
  '서식 데이터를 읽을 수 없어 원문을 읽기 전용으로 보여줍니다. 백업을 보관해 주세요.':
      'Formatting could not be read, so the original is read-only. Keep your backup.',
  '생각을 적어 보세요': 'Write your thoughts',
  '간단히': 'Fewer tools',
  '서식 더보기': 'More formatting',
  '어디로 옮길까요?': 'Move to',
  '이 메모의 첫 번째 가지': 'Top level of this note',
  '자기 자신이나 하위 가지로는 옮길 수 없습니다.':
      'Cannot move a branch into itself or its descendants.',
  '가지 삭제': 'Delete branch',
  '이 가지와 그 아래의 가지가 함께 삭제됩니다.':
      'This branch and its descendants will be deleted.',
  '하위 가지로는 옮길 수 없습니다.': 'Cannot move a branch into its descendants.',
  '다른 가지로 이동': 'Move to another branch',
  '펼치기': 'Expand',
  '접기': 'Collapse',
  '+ 가지': '+ Branch',
  '이 메모의 생각 나무': 'This note’s tree',
  '가지를 눌러 수정 · 길게 끌어 옮기기': 'Tap a branch to edit · Press and hold to move',
  '첫 번째 생각을 가지로 추가해 보세요.': 'Add your first thought as a branch.',
  '이 메모': 'This note',
  '첫 번째 가지 추가': 'Add first branch',
  '기기에서 분석 중…': 'Analyzing on device…',
  'AI 과정 초안': 'AI process draft',
  '가지 추가': 'Add branch',
  '가지 수정': 'Edit branch',
  '손글씨를 불러오거나 저장하지 못했습니다. 기존 백업을 확인해 주세요.':
      'Could not load or save handwriting. Check your backup.',
  '손가락이나 펜으로 적어 보세요': 'Write with a finger or stylus',
  '마지막 획 되돌리기': 'Undo last stroke',
  '각 항목을 1~200자로 입력하거나 삭제해 주세요.':
      'Enter 1–200 characters for each item, or delete it.',
  '추가할 항목이 없습니다.': 'There are no items to add.',
  '메모가 바뀌었거나 삭제되어 적용하지 않았습니다. 메모를 확인한 뒤 다시 생성해 주세요.':
      'The note changed or was deleted. Check it and generate the draft again.',
  '초안을 저장하지 못했습니다. 기존 메모와 가지는 그대로입니다.':
      'Could not save the draft. Your note and existing branches are preserved.',
  '과정 초안 확인': 'Review process draft',
  'AI가 찾은 과정을 확인해 주세요': 'Review the process suggested by AI',
  'AI가 종류를 잘못 판단할 수 있습니다. 예측과 실제 결과를 구분해 확인하고, 필요하면 수정하거나 삭제해 주세요. 기존 가지는 그대로 유지됩니다.':
      'AI may classify items incorrectly. Check predictions against actual outcomes and edit or remove items as needed. Existing branches are preserved.',
  '원문 보기': 'View original',
  '과정 종류': 'Process type',
  '초안 항목 삭제': 'Remove draft item',
  '가지 내용': 'Branch text',
  '추가 중…': 'Adding…',
  '확인한 초안을 나무에 추가': 'Add reviewed draft to tree',
  '관찰': 'Observation',
  '근거': 'Evidence',
  '판단': 'Judgment',
  '결정': 'Decision',
  '이유': 'Reason',
  '실행': 'Action',
  '결과': 'Outcome',
  '회고': 'Reflection',
  '후속 계획': 'Next steps',
  '녹음을 시작한 뒤 마치기를 누르세요. 음성은 기기에서 처리됩니다. 한 번에 최대 5분입니다.':
      'Start recording, then tap Stop. Audio is processed on device. Maximum: 5 minutes.',
  '녹음 중 (최대 5분)': 'Recording (maximum 5 minutes)',
  '음성을 기기에서 인식 중입니다. 처음에는 모델 준비에 시간이 걸립니다.':
      'Recognizing speech on device. Preparing the model may take time on first use.',
  '원문을 저장했습니다. 기기에서 내용을 분석 중입니다.': 'Transcript saved. Analyzing on device.',
  '저장된 녹음을 다시 인식 중입니다.': 'Recognizing the saved recording again.',
  '녹음 마치기': 'Stop recording',
  '녹음 시작': 'Start recording',
  '기기에 저장된 녹음': 'Recordings on this device',
  '다시 인식하면 새 메모가 생성됩니다.': 'Recognizing again creates a new note.',
  '녹음 삭제': 'Delete recording',
  '이 녹음 파일을 삭제할까요?': 'Delete this recording?',
  '백업 실패': 'Backup failed',
  '복원 실패': 'Restore failed',
  '분석 실패': 'Analysis failed',
  '연결': 'Connections',
  '원문': 'Original',
  '아래': 'under',
  '녹음 시작 실패': 'Could not start recording',
  '처리 실패': 'Processing failed',
  '녹음 파일은 기기에 보관됩니다.': 'The recording remains on the device.',
  '녹음 파일이 없습니다': 'The recording file is missing',
  '인식된 텍스트가 없습니다. 녹음은 기기에 보관됩니다.':
      'No text was recognized. The recording remains on the device.',
  '원문을 메모로 저장했습니다. 이전 방식의 메모 간 그래프 명령은 새 나무에 자동 적용하지 않습니다.':
      'The transcript was saved. Commands for the old graph are not automatically applied to the new tree.',
  '원문을 메모에 저장했습니다. 생성된 그래프 초안이 없습니다.':
      'The transcript was saved. No tree draft was generated.',
  '원문과 AI 초안을 저장했습니다. 메모를 길게 눌러 초안을 확인하세요.':
      'The transcript and AI draft were saved. Press and hold the note to review the draft.',
  '메모나 초안이 변경되어 새 분석 결과를 저장하지 않았습니다.':
      'The note or draft changed, so the new analysis was not saved.',
  '원문을 저장했지만 AI 분석에 실패했습니다.':
      'The transcript was saved, but AI analysis failed.',
  '메모, 그래프, 음성 전사와 녹음은 기기에 저장됩니다. 음성 인식은 기기에서 처리되며 앱은 계정이나 클라우드 동기화를 제공하지 않습니다.\n\n백업에는 메모와 그래프가 포함되며 녹음 파일은 포함되지 않습니다. 백업 파일은 암호화되지 않습니다.\n\n앱 삭제 시 기기 내부 기록과 녹음이 삭제됩니다. 마이크 권한은 음성 녹음에 사용됩니다.\n\n운영자: J.MEN\n문의: juson082@gmail.com':
      'Notes, graphs, transcripts, and recordings are stored on your device. Speech recognition runs on device. There are no accounts or cloud sync.\n\nBackups include notes and graphs, but not recordings, and are not encrypted.\n\nUninstalling deletes local notes and recordings. Microphone access is used for recording.\n\nOperator: J.MEN\nContact: juson082@gmail.com',
};
