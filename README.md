# EllsmereUI

EllesmereUI 애드온 모음 (WoW Retail 12.0)

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
