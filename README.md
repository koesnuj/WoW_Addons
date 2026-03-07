# EllsmereUI

EllesmereUI에서 개인적으로 불편한거/찐빠난거 업데이트

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
| EllesmereUIUnlockExtras | Vehicle Leave, Queue Status, Loot Frame, Loot Roll, Player Castbar 언락 모드 무버 |
| EllesmereUICastBarExtras | oUF 캐스트바에 Spark, Latency, Smoothing, Channel Ticks, Empowered Pip 스타일링 추가 |

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

EllesmereUI 언락 모드(Unlock Mode)에 블리자드 기본 UI 프레임 4종과 플레이어 캐스트바를 등록하여 자유롭게 위치를 조정할 수 있는 애드온.

| 요소 | 블리자드 프레임 | 설명 |
|------|----------------|------|
| Vehicle Leave Button | `MainMenuBarVehicleLeaveButton` | 탈것 내리기 버튼 |
| Queue Status | `QueueStatusButton` | LFG/PvP 대기열 눈 아이콘 |
| Loot Frame | `LootFrame` | 전리품 획득 창 (`lootUnderMouse` CVar 활성 시 커서 위치 우선) |
| Loot Roll (Need/Greed) | `GroupLootContainer` | 주사위 굴림(Need/Greed/Disenchant) 프레임 |
| Player Castbar | `EllesmereUIUnitFrames_Player.Castbar` | oUF 플레이어 캐스트바 분리/독립 이동 (`EllesmereUIUnitFrames` 필요) |

**특징:**
- EllesmereUI Lite 프로필 시스템 연동 — 프로필 전환 시 위치 자동 적용
- Holder + Reparent + Hook 패턴으로 블리자드 UI 안정적 제어
- 언락 모드에서 탈것 미탑승/대기열 미등록 상태에서도 무버 표시
- SavedVariables: `EllesmereUIUnlockExtrasDB`

### EllesmereUICastBarExtras — 신규 애드온

EllesmereUIUnitFrames의 oUF 캐스트바에 ElvUI 스타일 기능을 추가하는 별도 애드온.
EllesmereUIUnitFrames를 직접 수정하지 않고, oUF 콜백 훅과 서브 위젯만 추가합니다.

| 기능 | 설명 |
|------|------|
| Spark | 캐스트바 진행 위치에 2px 밝은 라인 (oUF 자동 show/hide) |
| SafeZone / Latency | 플레이어 캐스트바에 네트워크 지연 표시 (빨간 오버레이, oUF 자동 위치/크기) |
| Smoothing | `ExponentialEaseOut` 보간으로 부드러운 캐스트바 움직임 |
| Channel Ticks | 정신 채찍, 매혹 등 ~25종 채널링 주문의 틱 간격 표시 |
| Empowered Pip Styling | 역량 시전 단계 구분선을 ElvUI 스타일 flat white line으로 교체 |

**대상 유닛프레임:** Player, Target, Focus
**의존성:** `EllesmereUI`, `EllesmereUIUnitFrames`

---

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-03-08 | EllesmereUIUnlockExtras에 Player Castbar 무버 추가 |
| 2026-03-08 | EllesmereUICastBarExtras 신규 애드온 추가 (Spark, Latency, Smoothing, Channel Ticks, Empowered Pips) |
| 2026-03-07 | EllesmereUIUnlockExtras 신규 애드온 추가 (Vehicle Leave, Queue Status, Loot Frame, Loot Roll) |
| 2026-03-06 | EllesmereUI_PageSwitch 신규 애드온 추가 |
| 2026-03-06 | EllesmereUIActionBars Flyout 버그 수정 |
