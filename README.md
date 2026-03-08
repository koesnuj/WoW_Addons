# EllesmereUI

개인적으로 불편한거/찐빠난거 업데이트

## 포함 애드온

| 애드온 | 설명 |
|--------|------|
| EllesmereUI | Core UI 프레임워크, 설정, 로컬라이제이션 |
| EllesmereUI_KRPatch | 한국어 번역 패치 |
| EllesmereUI_PageSwitch | Shift+마우스휠 액션바 페이지 전환 (커스텀 애드온) |
| EllesmereUIActionBars | 커스텀 액션바 |
| EllesmereUIAuraBuffReminders | 오라/버프 알림 |
| EllesmereUICursor | 커서 커스텀 |
| EllesmereUINameplates | 네임플레이트 커스텀 |
| EllesmereUIUnitFrames | 유닛프레임 커스텀 |
| EllesmereUIUnlockExtras | Vehicle Leave, Queue Status, Loot Frame, Loot Roll, LFG Ready Popup, Ready Check, Bonus Roll, Alert Toasts 언락 모드 무버 |
| SocialInfo | 길드원, 친구, 특성, 골드, 내구도 정보를 표시하는 컴팩트 수평 패널 (독립 애드온) |
| Ayije_CDM | 쿨다운 매니저 (Core + Keybind + Options) |

## 수정 사항

### EllesmereUIActionBars — Flyout(펫소환 등) 수정

Flyout 스킬(펫 소환 등)이 클릭/단축키로 정상 동작하지 않던 문제 수정.

**원인:**
- 키바인드가 bind 버튼(0×0 숨겨진 SecureActionButtonTemplate)으로 라우팅되어 SpellFlyout 앵커가 잘못된 위치에 표시됨
- EAB가 버튼에 `flyoutDirection` 속성을 설정하지 않아 Blizzard 폴백 방향 계산이 잘못됨
- bind 버튼(`SecureActionButtonTemplate`)이 flyout 토글을 네이티브로 지원하지 않아 단축키로 flyout이 열리지 않음

**수정 내용:**
1. `LayoutBar()` — 바 방향에 따라 `flyoutDirection` 속성을 각 버튼에 설정 (수직: RIGHT, 수평: 위로 성장 시 UP, 아래로 DOWN)
2. `GetOrCreateBindButton()` — `bind:SetAllPoints(btn)` + `bind:SetPassThroughButtons(...)` 추가 (flyout 앵커 위치 보정, 마우스 클릭은 부모로 통과)
3. `UpdateKeybinds()` — 키바인드를 bind 버튼 대신 부모 액션 버튼(`ActionButton`)으로 직접 라우팅하여 flyout 토글 정상 동작

### EllesmereUI_PageSwitch — 신규 애드온

Shift+마우스휠로 ActionBar1 페이지를 전환하는 별도 애드온.
EllesmereUIActionBars 업데이트 영향을 받지 않도록 독립 구성.

- Bar6 슬롯 범위(offset 144, slots 145-156) 사용
- Shift+휠업: 페이지 2(Bar6) 전환, Shift+휠다운: 페이지 1(기본) 복귀
- 토글 모드: 휠 업/다운 모두 전환↔복귀 동작
- 변신/탈것 상태에서 자동 원복

### EllesmereUIUnlockExtras — 신규 애드온

EllesmereUI 언락 모드(Unlock Mode)에 블리자드 기본 UI 프레임 8종을 등록하여 자유롭게 위치를 조정할 수 있는 애드온.

| 요소 | 블리자드 프레임 | 설명 |
|------|----------------|------|
| Vehicle Leave Button | `MainMenuBarVehicleLeaveButton` | 탈것 내리기 버튼 |
| Queue Status | `QueueStatusButton` | LFG/PvP 대기열 눈 아이콘 |
| Loot Frame | `LootFrame` | 전리품 획득 창 (`lootUnderMouse` CVar 활성 시 커서 위치 우선) |
| Loot Roll (Need/Greed) | `GroupLootContainer` | 주사위 굴림(Need/Greed/Disenchant) 프레임 |
| LFG Ready Popup | `LFGDungeonReadyPopup` | 던전/레이드 입장 준비 팝업 |
| Ready Check | `ReadyCheckFrame` | 준비 확인 프레임 |
| Bonus Roll | `BonusRollFrame` | 보너스 굴림(행운의 동전) 프레임 |
| Alert Toasts | `AlertFrame` | 알림 토스트 (전리품 획득, 업그레이드, 업적 등) |

**특징:**
- EllesmereUI Lite 프로필 시스템 연동 — 프로필 전환 시 위치 자동 적용
- Holder + Reparent + Hook 패턴으로 블리자드 UI 안정적 제어
- 언락 모드에서 탈것 미탑승/대기열 미등록 상태에서도 무버 표시
- SavedVariables: `EllesmereUIUnlockExtrasDB`

### SocialInfo — 신규 애드온

접속 중인 길드원/친구 수, 전문화·특성 트리 이름, 골드, 내구도를 한 줄 수평 패널로 표시하는 독립 애드온.

- `/sinfo` — 패널 토글, `/sinfo lock` `/sinfo unlock` — 위치 잠금/해제
- `/sinfo scale <값>` — 패널 크기 조절, Ctrl+마우스휠로도 조절 가능
- 각 항목 마우스 오버 시 블리자드 기본 위치에 상세 툴팁 표시
- 골드 툴팁: 계정 내 캐릭터별 보유 골드 표시
- 길드/친구 툴팁: 접속 중인 멤버 목록 (직업 색상, 레벨순 정렬)
- SavedVariables: `SocialInfoDB`

---

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-03-08 | EllesmereUIUnlockExtras LFG Ready Popup 위치 미적용 버그 수정 (load-on-demand 프레임 대응) |
| 2026-03-08 | SocialInfo 신규 애드온 추가 |
| 2026-03-08 | Ayije_CDM 애드온 스위트 추가 (Core, Keybind, Options) |
| 2026-03-08 | EllesmereUIUnlockExtras 요소 4종 추가 (LFG Ready Popup, Ready Check, Bonus Roll, Alert Toasts) |
| 2026-03-07 | EllesmereUIUnlockExtras 신규 애드온 추가 (Vehicle Leave, Queue Status, Loot Frame, Loot Roll) |
| 2026-03-06 | EllesmereUI_PageSwitch 신규 애드온 추가 |
| 2026-03-06 | EllesmereUIActionBars Flyout 버그 수정 |
