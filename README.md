# 개인적으로 불편한거/찐빠난거 업데이트

Ellesmere UI
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
| Ayije_CDM | 쿨다운 매니저 (Core + Options) |
| Ayije_CDM_Keybind | Ayije_CDM 쿨다운 아이콘에 키바인드 텍스트 오버레이 표시 |
| PhoenixCastBars | 플레이어/타겟/포커스 캐스트바 (secret boolean taint 수정 포함) |
| QuickTrainer | 트레이너 NPC에서 레시피 구매 후 자동으로 다음 배울 수 있는 레시피 선택 (독립 애드온) |

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

### EllesmereUIActionBars — 툴팁/하이라이트 수정

버튼을 SecureHandlerStateTemplate로 리페어런팅하면서 마우스 오버 툴팁과 하이라이트 효과가 동작하지 않던 문제 수정.

**원인:**
- 리페어런팅 시 엔진이 `SetMouseMotionEnabled`을 암묵적으로 해제하여 OnEnter/OnLeave가 발생하지 않음
- 수동 `ht:Show()`/`ht:Hide()` 방식은 엔진의 마우스 트래킹이 즉시 덮어쓰기 때문에 무효화됨

**수정 내용:**
1. 프레임 레벨 `OnUpdate` 폴링으로 히트 테스트 수행 → 마우스 아래 버튼 감지 시 `GameTooltip:SetAction()` 호출
2. `C_Timer.After(0.5)` 지연 후 `SetMouseMotionEnabled(true)` 재활성화
3. `LockHighlight()` / `UnlockHighlight()` 사용 — 엔진 마우스 트래킹 우회

### PhoenixCastBars — 캐스트바 깜빡임 수정

캐스팅 중 바가 간헐적으로 깜빡이는 문제 수정.

**원인:**
- `OnUpdate`에서 매 프레임 `pcall(UnitCastingInfo)` / `pcall(UnitChannelInfo)` 호출 → 과도한 오버헤드
- `UpdateBlizzardCastBars()`가 매 이벤트마다 Blizzard 캐스트바를 반복적으로 숨김 처리 → 프레임 부하

**수정 내용:**
1. `OnUpdate` 내 `pcall` 래퍼 제거 → 직접 호출로 변경
2. `UpdateBlizzardCastBars()`에 `blizzardCastBarsHidden` 플래그 추가 — 1회만 실행

### SocialInfo — 전리품 획득 전문화 선택 추가

특성 트리 모듈에 우클릭 시 전리품 획득 전문화를 변경할 수 있는 기능 추가.

**수정 내용:**
- 특성 아이콘 우클릭 → 드롭다운 메뉴로 전문화 목록 표시 (현재 스펙 기준)
- `C_Loot.SetSelectedLootSpecialization()` API 사용
- `Panel.lua`에 `RegisterForClicks("AnyUp")` 추가하여 우클릭 이벤트 전달

### QuickTrainer — 신규 애드온

트레이너 NPC에서 레시피/기술 구매 후 자동으로 다음 배울 수 있는 항목을 선택해주는 독립 애드온.

**기능:**
- `BuyTrainerService()` 후크 → 배운 레시피 자동 숨김 + 다음 레시피 자동 선택
- Blizzard의 `ClassTrainer_SelectNearestLearnableSkill()` 활용 (기존 함수이나 창 열 때만 호출되는 것을 구매 후에도 호출)
- `/qt on` / `/qt off` — 기능 토글
- `/qt hideused` — 배운 레시피 숨김 토글
- SavedVariables: `QuickTrainerDB`

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
- EllesmereUI Lite DB 구조 사용 — 캐릭터별 위치 저장 (프로필 전환은 EllesmereUI 미지원)
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

### Ayije_CDM_Keybind + EllesmereUIActionBars — 파티프레임 마우스오버 성능 최적화

파티프레임에 마우스를 올리면 `ACTIONBAR_SLOT_CHANGED`가 16개 이상 동시 발화하여 프레임드랍이 발생하던 문제 수정.

**원인:**
- `UPDATE_MOUSEOVER_UNIT` → WoW가 `[@mouseover]` 매크로 재평가 → `ACTIONBAR_SLOT_CHANGED` 전 슬롯 발화 (60FPS 반복)
- `Ayije_CDM_Keybind`: 슬롯 변경마다 `RefreshAllKeybindTexts()` 즉시 실행 → 15바 × 12버튼 = 180번 루프를 프레임 수만큼 반복 (최고 497ms 스파이크)
- `EllesmereUIActionBars`: 슬롯 변경마다 전체 바 루프 2개(`EnableRangeCheckForBar`, `ApplyAlwaysShowButtons`)가 즉시 실행

**수정 내용:**

`Ayije_CDM_Keybind/Init.lua`
- `ACTIONBAR_SLOT_CHANGED` 핸들러에 디바운스 추가 — 연속 발화를 0.15초 후 1회로 통합

`Ayije_CDM_Keybind/KeybindText.lua`
- `BuildKeybindCache()` 도입 — 전체 바를 1회 스캔해서 `{spellID → keybind}` 맵 빌드
- `ApplyKeybindText()`가 프레임마다 180번 루프 대신 O(1) 캐시 조회로 변경
- `RefreshAllKeybindTexts()` 시작 시 캐시 무효화 → 스펙/슬롯 변경 반영

`EllesmereUIActionBars/EllesmereUIActionBars.lua`
- `ACTIONBAR_SLOT_CHANGED` → `EnableRangeCheckForBar` 전체 바 루프 디바운스 (0.15s)
- `ACTIONBAR_SLOT_CHANGED` → `ApplyAlwaysShowButtons` 전체 바 루프 디바운스 (next frame 1회로 통합)
- `_slotToRangeInfo` 역방향 조회 테이블 추가 — `ACTION_RANGE_CHECK_UPDATE` 핸들러의 O(N) 전체 순회를 O(1) 슬롯 직접 접근으로 변경

**결과:**

| 항목 | 수정 전 | 수정 후 |
|------|---------|---------|
| Keybind Text CPU | 497ms (스파이크) | ~21ms |
| ActionBars CPU | ~40ms | ~12ms |
| 전체 합계 | ~580ms | ~110ms |
| 파티프레임 마우스오버 프레임드랍 | 발생 | 해소 |

---

### EllesmereUIActionBars — v4.1.6 업스트림 싱크 + 패치 복원

EllesmereUI 업스트림 v4.1.6 대규모 업데이트 적용 및 커스텀 패치 복원.

**업스트림 주요 변경:**
- 새로운 커스텀 Flyout 시스템 (`EABFlyout`) — Blizzard `SpellFlyout` 대신 taint-free WrapScript 기반 보안 구현
- PetBar 슬롯 인덱스 보존 처리
- Override/Vehicle 바 지원 (`[overridebar]` 가시성 조건 추가)
- `SafeEnableMouseMotionOnly` 헬퍼 함수 추가
- Out-of-range 스킬 색상 표시 기능
- OPie 등 다른 애드온 키바인드 충돌 방지 가드 (`GetBindingAction` 체크)

**커스텀 패치 복원:**
- 업스트림 업데이트로 제거된 툴팁/하이라이트 시스템 복원:
  - `ShowTooltipForButton()` + `AttachTooltipHooks()` (OnUpdate 폴링, LockHighlight/UnlockHighlight)
  - 초기화 시 `AttachTooltipHooks(info.key)` 호출
  - `C_Timer.After(0.5)` 지연 `SetMouseMotionEnabled(true)` 재활성화
- 기존 Flyout 수정 → 업스트림 EABFlyout 시스템이 대체하여 불필요

**참고:** 기존 "Flyout(펫소환 등) 수정" 섹션의 내용(flyoutDirection, bind 버튼 라우팅 등)은 v4.1.6 업스트림의 EABFlyout 시스템으로 대체됨.

### EllesmereUI_FlyoutFix — 삭제

업스트림 v4.1.6의 EABFlyout 시스템 도입으로 별도 FlyoutFix 애드온이 불필요해져 삭제.

**이유:**
- `EllesmereUI_FlyoutFix`의 `hooksecurefunc("SetOverrideBindingClick", ...)` 리다이렉트가 업스트림의 새로운 `EABFlyout` 시스템(WrapScript 기반 보안 flyout 인터셉션)과 충돌
- 업스트림이 flyout을 네이티브로 처리하므로 별도 애드온 불필요
- `.gitignore`에서 FlyoutFix 화이트리스트 항목도 제거

---

## 알려진 이슈 / TODO

### [미해결] EnhanceQoL LootToast ↔ EllesmereUIUnlockExtras 충돌

**증상:**
- 주사위창(Loot Roll)과 알림 토스트(Alert Toasts)가 UnlockExtras에서 설정한 위치에 표시되지 않음
- 언락 모드에서 위치를 변경해도 적용되지 않거나 원래 위치로 돌아감

**원인:**
- `EnhanceQoL/Submodules/LootToast.lua`와 `EllesmereUIUnlockExtras`가 동일한 프레임을 제어하려고 충돌
- 둘 다 `GroupLootContainer_Update`를 `hooksecurefunc`로 후킹
- 둘 다 `GroupLootContainer`와 `AlertFrame`의 위치를 재설정
- EQoL 훅이 UnlockExtras 훅 이후에 실행되어 우리 holder 앵커를 덮어씀

**충돌 지점:**

| 프레임 | UnlockExtras | EnhanceQoL LootToast |
|--------|-------------|---------------------|
| `GroupLootContainer` | holder에 reparent + `GroupLootContainer_Update` 훅 (line 342) | `ignoreFramePositionManager = true` + 위치 재설정 (lines 527-532) |
| `AlertFrame` | alertToastsHolder에 reparent (lines 635-643) | `AlertFrame:UpdateAnchors` 훅으로 위치 재설정 (line 1054) |

**해결 방안:**

#### 방안 A: EQoL LootToast 모듈 비활성화 (가장 간단)
- EnhanceQoL 인게임 설정에서 LootToast 모듈만 끄기
- 장점: 코드 수정 불필요, 즉시 적용
- 단점: EQoL LootToast의 다른 기능(루팅 UI 개선 등)도 함께 비활성화됨

#### 방안 B: UnlockExtras 훅 실행 순서 변경 — 지연 적용 (권장)
- UnlockExtras의 `GroupLootContainer_Update` 훅과 `AlertFrame:UpdateAnchors` 훅에 `C_Timer.After(0)` 딜레이 적용
- EQoL 훅이 먼저 실행된 후 다음 프레임에서 UnlockExtras가 위치를 재설정
- 장점: 양쪽 애드온 모두 활성 유지, EQoL의 다른 기능 사용 가능
- 단점: 1프레임 깜빡임 가능성, EQoL 업데이트 시 재검증 필요

#### 방안 C: EQoL 위치 함수 오버라이드 — 완전 제어
- EQoL의 `GroupLootContainer` / `AlertFrame` 위치 설정 로직을 후킹하여 무효화
- UnlockExtras에서 EQoL 로드 여부를 감지하고, 로드된 경우 EQoL의 위치 훅을 빈 함수로 교체
- 장점: 가장 확실한 해결, 깜빡임 없음
- 단점: EQoL 내부 구현에 의존, EQoL 업데이트 시 깨질 수 있음

### [미해결] UltimateCastbars 한글 폰트 깨짐

**원인:**
- `BarUpdate_Helpers.lua` line 249에서 `SetFont`에 `"Fonts\\FRIZQT__.TTF"` (라틴 전용 폰트) 하드코딩
- KRPatch에서 설정한 한국어 폰트를 덮어씀

**해결 방안:**
- A: `FRIZQT__.TTF`를 한국어 지원 폰트 경로로 변경
- B: KRPatch에서 UCB 폰트도 오버라이드하도록 확장


---

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-03-12 | Ayije_CDM_Keybind + EllesmereUIActionBars 파티프레임 마우스오버 CPU 스파이크 수정 (497ms → 21ms) |
| 2026-03-11 | EllesmereUIActionBars v4.1.6 업스트림 싱크 + 툴팁/하이라이트 패치 복원 |
| 2026-03-11 | EllesmereUI_FlyoutFix 삭제 (업스트림 EABFlyout 대체) |
| 2026-03-11 | EnhanceQoL LootToast ↔ UnlockExtras 충돌 원인 분석 (미해결) |
| 2026-03-09 | QuickTrainer 신규 애드온 추가 |
| 2026-03-09 | EllesmereUIActionBars 툴팁/하이라이트 수정 (리페어런팅 후 OnEnter 미발생 문제) |
| 2026-03-09 | PhoenixCastBars 캐스트바 깜빡임 수정 (pcall 오버헤드 + UpdateBlizzardCastBars 중복 호출) |
| 2026-03-09 | SocialInfo 전리품 획득 전문화 선택 기능 추가 (특성 트리 우클릭) |
| 2026-03-08 | PhoenixCastBars 신규 애드온 추가 (secret boolean taint 수정 포함) |
| 2026-03-08 | EllesmereUIUnlockExtras LFG Ready Popup 위치 미적용 버그 수정 (load-on-demand 프레임 대응) |
| 2026-03-08 | SocialInfo 신규 애드온 추가 |
| 2026-03-08 | Ayije_CDM 애드온 스위트 추가 (Core, Keybind, Options) |
| 2026-03-08 | EllesmereUIUnlockExtras 요소 4종 추가 (LFG Ready Popup, Ready Check, Bonus Roll, Alert Toasts) |
| 2026-03-07 | EllesmereUIUnlockExtras 신규 애드온 추가 (Vehicle Leave, Queue Status, Loot Frame, Loot Roll) |
| 2026-03-06 | EllesmereUI_PageSwitch 신규 애드온 추가 |
| 2026-03-06 | EllesmereUIActionBars Flyout 버그 수정 |
