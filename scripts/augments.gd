extends RefCounted

const ELEMENTS = ["무속성", "불", "얼음", "물", "땅", "풀", "바람", "번개", "양자", "허수"]
const CODES = ["N", "F", "I", "W", "E", "G", "A", "L", "Q", "H"]
const DEITIES = ["아르칸", "이그니스", "니베아", "마레아", "테라곤", "베르디아", "아엘로", "볼타르", "녹스", "오르디아"]
const RARITIES = ["일반", "희귀", "영웅", "전설", "쌍신"]
const COLORS = ["#d7dccb", "#9bceef", "#dab8f2", "#ffe299", "#f1b3a0"]
const POWER = [1.0, 1.2, 1.45, 1.0, 1.0]
const WEIGHTS = [65, 25, 10]
const BOOSTED_WEIGHTS = [45, 35, 20]
const THRESHOLDS = [1, 2, 4, 6]
const SLOTS = ["light", "heavy", "skill", "dash"]
const SOURCES = {
	"burn": ["F01", "F02", "F03", "F08"],
	"cold": ["I01", "I02", "I03", "I04", "I11"],
	"water": ["W01", "W02", "W03", "W04"],
	"push": ["W02", "W03"],
	"shield": ["E04", "E09"],
	"crack": ["E02", "E03"],
	"spore": ["G01", "G02", "G06"],
	"seed": ["G03", "G04"],
	"wind": ["A02", "A04"],
	"charge": ["L01", "L02", "L04", "L09", "L12"],
	"void": ["Q01", "Q02", "Q03"],
	"order": ["H01", "H02", "H03"],
}
const SOURCE_NAMES = {
	"burn": "화상 부여 증강", "cold": "냉기 부여 증강", "water": "물결 표식 부여 증강",
	"push": "W02 또는 W03", "shield": "E04 또는 E09", "crack": "균열 부여 증강",
	"spore": "포자 부여 증강", "seed": "씨앗 생성 증강", "wind": "풍압 부여 증강",
	"charge": "전하 부여 증강", "void": "공허 표식 부여 증강", "order": "질서 각인 부여 증강",
}

# Braced numbers are the explicitly scalable values; all other numbers stay fixed.
const NORMAL_ROWS = """
N01|전사의 손|무속성으로 변환, 피해 +{25}%|
N02|처형자의 도끼|무속성으로 변환, 피해 +{40}%, 파열 부여|
N03|관통 전술|무속성으로 변환, 방어력 {20}% 무시|
N04|반격 보법|회피 후 2초 내 다음 직접 공격 피해 +{35}%|
N05|예리한 감각|직접 피해 치명타 확률 +{5}%p|
N06|급소 파괴|치명타 피해 배율 +{25}%p|N05
N07|사냥꾼의 낙인|직접 공격 치명타 발생 시 파열 부여|N05
N08|추격의 칼날|파열 대상 강공격 적중 시 P의 {30}% 추가 피해. 대상별 1초 간격|N02/N07
N09|피의 격려|처치 후 4초간 공격 속도 +{15}%. 중첩 불가|
N10|결투의 규율|반경 5m 내 적이 1명일 때 직접 피해 +{20}%|
N11|불굴의 투지|생명력 35% 이하에서 받는 피해 {15}% 감소|
N12|최후의 일격|생명력 20% 이하 적에게 직접 피해 +{30}%|
F01|불씨의 손|불속성으로 변환, 피해 +{10}%, 화상 1중첩|
F02|용광로 강타|불속성으로 변환, 피해 +{25}%, 화상 2중첩|
F03|화염 분출|불속성으로 변환, 피해 +{20}%, 화상 2중첩|
F04|잿불 보행|출발 지점에 2초간 불길 생성. 1초마다 P의 {20}% 불 피해|
F05|오래 타는 불꽃|화상 지속시간 +{2}초|burn
F06|겹겹의 열기|화상 최대 중첩 +3|burn
F07|폭발점|최대 화상 대상 강공격 적중 시 화상 소모, 중첩당 P의 {25}% 광역 불 피해|F06
F08|불씨 전염|화상 대상 처치 시 주변 적에게 화상 2중첩|burn
F09|재의 갑옷|화상 대상에게 받는 피해 {10}% 감소|burn
F10|열기 회수|화상 대상 처치 시 권능 게이지 +{2}. 방당 최대 20|burn
F11|전소|생명력 30% 이하 적에게 화상 피해 +{40}%|burn
F12|불길의 대가|자신의 화염 지대 안에서 직접 불 피해 +{20}%|F04
I01|서리 손끝|얼음속성으로 변환, 냉기 1중첩|
I02|빙하 파쇄|얼음속성으로 변환, 피해 +{25}%, 냉기 2중첩|
I03|겨울의 창|얼음속성으로 변환, 피해 +{20}%, 냉기 2중첩|
I04|서리 걸음|출발 지점 주변 적에게 냉기 2중첩|
I05|긴 겨울|냉기 지속시간 +{3}초|cold
I06|절대영도|냉기 최대 중첩 도달 시 소모하고 1초 빙결. 대상별 6초 간격|cold
I07|얼음 파편|빙결 대상 강공격 적중 시 주변에 P의 {80}% 얼음 피해|I06
I08|둔화된 시간|냉기 최대 중첩 대상 공격 속도 {15}% 감소|cold
I09|차가운 방벽|냉기 대상에게 받는 피해 {10}% 감소|cold
I10|설원의 집중|1초간 피격되지 않으면 스킬 피해 +{20}%. 피격 시 해제|
I11|겨울의 숨|냉기 대상 처치 시 주변 적에게 냉기 2중첩|cold
I12|얼어붙은 상처|냉기 대상의 받는 회복량 {50}% 감소|cold
W01|파도의 손|물속성으로 변환, 물결 표식 부여|
W02|해일 강타|물속성으로 변환, 피해 +{25}%, 밀치기·물결 표식|
W03|압축 수류|물속성으로 변환, 피해 +{20}%, 밀치기·물결 표식|
W04|파도 타기|이동 경로에 P의 {35}% 물 피해와 물결 표식|
W05|암초 충돌|자신의 밀치기로 벽 충돌 시 P의 {80}% 물 피해. 대상별 1초 간격|push
W06|거친 물살|물결 표식 대상이 자신의 밀치기로 이동하면 P의 {30}% 물 피해. 대상별 1초 간격|push
W07|두 번째 파도|강공격·스킬 밀치기가 {30}% 확률로 1회 추가|push
W08|깊은 수압|밀치기 면역 대상에게 직접 물 피해 +{20}%|W-core
W09|회복의 샘|전투방 종료 시 최대 생명력의 {2}% 회복|
W10|바다의 선물|전투방 기본 재화 보상 +{15}%|
W11|역류|물결 표식 대상에게 받는 피해 {10}% 감소|water
W12|포말 폭발|물결 표식 대상 처치 시 주변에 P의 {50}% 물 피해|water
E01|암석 주먹|땅속성으로 변환, 피해 +{20}%|
E02|지진 강타|땅속성으로 변환, 피해 +{30}%, 균열 부여|
E03|대지 분쇄|땅속성으로 변환, 균열 부여|
E04|바위 걸음|종료 시 P의 {15}% 보호막. 4초 간격|
E05|단단한 외피|보호막 보유 중 받는 피해 {10}% 감소|
E06|반동 갑주|보호막이 피해를 흡수하면 주변에 P의 {40}% 땅 피해. 1초 간격|shield
E07|균열 확장|균열의 방어력 감소가 {18}%로 증가|crack
E08|파쇄 충격|균열 대상 강공격 적중 시 P의 {50}% 땅 피해. 대상별 1초 간격|crack
E09|바위의 숨|전투방 입장 시 최대 생명력의 {10}% 보호막|
E10|흔들리지 않는 발|강공격 준비 중 받는 피해 {20}% 감소, 밀치기 면역|
E11|잔진|스킬 최초 적중 0.8초 후 같은 위치에 P의 {60}% 땅 피해|E-core
E12|광맥 수확|엘리트 최초 처치 시 추가 재화. 방당 1회|
G01|가시 손끝|풀속성으로 변환, 포자 1중첩|
G02|덩굴 강타|풀속성으로 변환, 피해 +{15}%, 포자 2중첩|
G03|씨앗 투척|풀속성으로 변환, 최초 적중 지점에 씨앗 생성|
G04|새싹 걸음|출발 지점에 씨앗 생성. 2초 간격|
G05|깊은 뿌리|포자 지속시간 +{3}초|spore
G06|포자 확산|포자 대상 처치 시 주변 적에게 포자 2중첩|spore
G07|다산의 씨앗|씨앗 유지 한도 +2|seed
G08|가시 열매|씨앗 폭발 피해 +{40}%|seed
G09|생명의 순환|씨앗이 적 3명 이상에게 적중하면 최대 생명력 {1}% 회복. 방당 5회|seed
G10|기생의 덩굴|포자 대상 처치 시 생명력 {1} 회복. 방당 최대 10|spore
G11|뿌리 감옥|최대 포자 대상 강공격 적중 시 1초 속박. 대상별 6초 간격|spore
G12|생장 촉진|전투방 종료 시 무작위 일반 증강 경험치 획득|
A01|바람 칼날|바람속성으로 변환, 공격 속도 +{10}%|
A02|진공 베기|바람속성으로 변환, 범위 +{20}%, 풍압 부여|
A03|회오리 핵|바람속성으로 변환, 최초 적중 시 주변 일반 적 집결|
A04|질풍 보법|거리 +{15}%, 종료 지점 주변 적에게 풍압|
A05|가벼운 발|이동 속도 +{10}%|
A06|연속 회피|회피 최대 충전 횟수 +1|
A07|잔풍|회피 후 2초간 이동 속도 +{20}%|
A08|속도의 무게|추가 이동 속도 10%p당 직접 피해 +{4}%. 최대 +{20}%|A05/A07
A09|역풍 장막|회피로 통과한 적 투사체 제거. 회피당 최대 3개|
A10|칼날 반송|투사체 제거 시 가까운 적에게 P의 {35}% 바람 피해. 회피당 1회|A09
A11|순풍 회수|스킬 적중 시 회피 남은 충전시간 {0.3}초 감소. 1초 간격|
A12|폭풍 집결|풍압 소모 시 주변 일반 적을 약하게 집결. 대상별 2초 간격|wind
L01|전류의 손|번개속성으로 변환, 전하 1중첩|
L02|천둥 강타|번개속성으로 변환, 피해 +{20}%, 전하 2중첩|
L03|낙뢰 지령|번개속성으로 변환, 최초 대상 주변 적 최대 2명에게 P의 {30}% 번개 피해|
L04|섬광 보법|출발 지점 주변 적에게 전하 1중첩|
L05|전도체|전하 폭발이 주변 적 최대 2명에게 피해량의 {50}%로 전이|charge
L06|긴 전선|전하 지속시간 +{3}초, 전이 반경 +{2}m|charge
L07|이중 낙뢰|전하 폭발 시 {25}% 확률로 같은 대상에게 P의 {40}% 번개 피해|charge
L08|감전 신경|전하 보유 대상 공격 속도 {10}% 감소|charge
L09|정전기 갑옷|피격 시 주변 적에게 전하 1중첩. 2초 간격|
L10|과충전|전하 폭발 피해 +{35}%|charge
L11|번개의 분노|권능 사용 후 4초간 직접 번개 피해 +{25}%|L-core
L12|살아 있는 피뢰침|전하 대상 처치 시 가까운 적에게 전하 2중첩|charge
Q01|공허의 손|양자속성으로 변환, 공허 표식|
Q02|붕괴 강타|양자속성으로 변환, 피해 +{25}%, 공허 표식|
Q03|심연 투사|양자속성으로 변환, 피해 +{20}%, 공허 표식|
Q04|잔상 보법|출발 지점에 1초 뒤 폭발하는 잔상 생성. P의 {40}% 양자 피해|
Q05|뒤늦은 상처|표식 대상 강공격 적중 0.8초 뒤 P의 {50}% 양자 피해. 대상별 1초 간격|Q02
Q06|긴 잔향|공허 표식 지속시간 +{4}초|void
Q07|허상의 칼날|기본 공격 5회 적중마다 잔상이 현재 대상에게 P의 {60}% 양자 피해|Q-core
Q08|불확정 회피|회피 후 2초간 회피율 +{10}%p. 중첩 불가|
Q09|심연 흡수|표식 대상 처치 시 P의 {10}% 보호막. 방당 최대 10회|void
Q10|존재 소거|표식 대상의 사망 시 효과 비활성화. 보스·이벤트 효과 제외|void
Q11|잔상 증폭|자신의 잔상 증강 피해 +{35}%|Q04/Q07
Q12|차원의 틈|스킬 사용 후 다음 회피 충전시간 {50}% 감소. 5초 간격|
H01|법칙의 손|허수속성으로 변환, 질서 각인 1중첩|
H02|심판 강타|허수속성으로 변환, 피해 +{20}%, 각인 2중첩|
H03|기하학적 심판|허수속성으로 변환, 각인 2중첩|
H04|결계 보법|종료 지점에 2초간 결계 생성. 내부에서 받는 피해 {10}% 감소|
H05|정밀한 주기|기본 공격 4회 적중마다 다음 강공격 직접 피해 +{40}%. 중첩 불가|
H06|연속 명령|각인 폭발 시 스킬 남은 대기시간 {0.4}초 감소. 1초 간격|order
H07|안정된 법칙|질서 각인 지속시간 +{4}초|order
H08|확정된 결과|각인 폭발 피해 +{40}%|order
H09|질서의 방패|각인 폭발 시 P의 {10}% 보호막. 2초 간격|order
H10|공간 고정|각인 폭발 대상 1초 속박. 대상별 6초 간격|order
H11|반복 공식|스킬 최초 적중 지점에 1초 뒤 P의 {60}% 허수 피해|H-core
H12|완벽한 준비|전투방 첫 스킬 직접 피해 +{50}%|
"""
const LEGEND_ROWS = """
N-L|끝나지 않는 결투|파열 대상에게 강공격 치명타 적중 시 해당 직접 피해의 40%를 추가한다. 추가 피해는 치명타·원소 반응·적중형 증강을 발생시키지 않는다.|N-core+N06+N08
F-L|불사조의 심장|폭발점 발동 지점에 3초간 불사조 불길 생성. 1초마다 P의 60% 불 피해. 불사조 불길은 최대 2개 유지.|F-core+F07+F08
I-L|겨울의 종결|냉기 최대 중첩 대상에게 강공격 적중 시 냉기를 소모하고 P의 200% 얼음 피해. 대상별 5초 간격. 빙결 면역 대상에게도 피해 적용. 같은 공격에서 절대영도보다 먼저 처리.|I-core+I06+I07
W-L|끝없는 해일|자신의 밀치기로 벽 충돌 시 주변에 P의 120% 물 피해. 추가 피해는 새로운 밀치기와 벽 충돌을 발생시키지 않는다.|W-core+W05+W07
E-L|산맥의 심장|보호막이 적의 공격으로 파괴되면 주변에 P의 250% 땅 피해. 10초 간격. 시간 만료·교체·자발적 소모로는 발동하지 않는다.|E-core+E06+E09
G-L|끝없는 개화|씨앗 폭발이 최대 포자 대상에게 적중하면 씨앗 1개 추가 생성. 2초 간격. 추가 생성 씨앗은 다시 씨앗을 생성하지 않는다.|G-core+G07+G08
A-L|천공의 춤|3초 안에 회피 2회 사용 시 3초간 공격 속도 +30%, 직접 바람 피해 +20%. 8초 간격.|A-core+A06+A08
L-L|무한 전도|전하 전이 대상 수 +2. 전이 피해 비율이 50%에서 80%로 증가. 전이 피해는 전하를 쌓거나 다시 전이하지 않는다.|L-core+L05+L07
Q-L|관측되지 않는 자|허상의 칼날이 2회 발생. 두 번째 피해는 첫 번째의 70%. 추가 발생은 새로운 적중형 효과를 발동하지 않는다.|Q-core+Q07+Q11
H-L|영원한 명령|전투 스킬 3회 사용마다 반복 공식이 2회 발생. 추가 반복은 각인과 스킬 사용 횟수를 생성하지 않는다.|H-core+H06+H11
"""
const DUO_ROWS = """
D01|열충격|냉기 대상에게 폭발점 발동 시 폭발 피해 +40%|F07+cold|F/I
D02|압력 보일러|두 상태를 가진 적에게 강공격 적중 시 P의 100% 물 피해. 대상별 3초 간격|burn+water|F/W
D03|용암 갑주|보호막 보유 중 자신의 불길 피해 +40%|F04+shield|F/E
D04|화원|화상 대상에게 씨앗 폭발 피해 +50%|burn+seed|F/G
D05|화염 회오리|스킬 집결 지점의 자신의 불길을 소모하고 P의 180% 불 피해. 4초 간격|F04+A03|F/A
D06|뇌염 폭주|화상 대상 전하 폭발 시 화상 1중첩 소모, P의 50% 불 피해|burn+charge|F/L
D07|유빙 충돌|냉기 대상에게 벽 충돌 피해 +60%|cold+W05|I/W
D08|빙하 성벽|보호막 획득 시 주변에 냉기 2중첩. 3초 간격|cold+shield|I/E
D09|겨울잠|냉기 대상의 포자 지속시간 감소 속도 절반|cold+spore|I/G
D10|눈보라 칼날|풍압 소모 시 주변에 냉기 2중첩. 2초 간격|cold+wind|I/A
D11|극저온 전도|냉기 대상에서 발생한 전하 전이 피해 +40%|cold+L05|I/L
D12|퇴적 방벽|물결 표식 대상 강공격 적중 시 P의 15% 보호막. 3초 간격|water+shield|W/E
D13|풍요의 물길|물결 표식 대상에게 씨앗 적중 시 최대 생명력 1% 회복. 3초 간격, 방당 5회|water+seed|W/G
D14|소용돌이|스킬 집결 후 3초 내 다음 밀치기의 벽 충돌 피해 +50%|push+A03|W/A
D15|전도 해역|물결 표식 대상에서 발생한 전하 전이의 대상 수 +2|water+L05|W/L
D16|뿌리 성채|보호막 보유 중 최대 포자 대상에게 직접 피해 +20%|shield+spore|E/G
D17|사암 폭풍|균열 대상 풍압 소모 시 주변에 P의 80% 땅 피해. 대상별 2초 간격|crack+wind|E/A
D18|대지 회로|전하 폭발 시 P의 10% 보호막. 2초 간격|shield+charge|E/L
D19|꽃가루 태풍|스킬 집결 시 대상과 주변 적에게 포자 1중첩. 시전당 1회|spore+A03|G/A
D20|생체 전류|최대 포자 대상에게 전하 폭발 피해 +35%|spore+charge|G/L
D21|폭풍 추적자|회피 후 첫 직접 공격이 전하 1중첩 추가 부여|A06+charge|A/L
D22|관측된 역설|공허 표식 대상 각인 폭발 0.8초 뒤 P의 100% 양자 피해. 대상별 2초 간격. 추가 피해는 각인·표식을 생성하지 않는다.|void+order|Q/H
"""
const MYTHS = [
	"무기 달인: 기본 공격 3회 적중 후 다음 강공격 확정 치명타. 소모 후 다시 누적.",
	"꺼지지 않는 불: 화상 대상에게 직접 불 피해 적중 시 화상 지속시간 갱신.",
	"영구동토: 냉기 대상에게 직접 얼음 피해 +20%.",
	"바다의 지배자: 물결 표식 대상에게 주는 광역 증강 피해 +25%.",
	"살아 있는 성채: 보호막 보유 중 직접 땅 피해 +20%.",
	"만개: 씨앗 폭발 적중 대상에게 포자 1중첩.",
	"무풍의 경지: 회피 후 1초 내 다음 직접 공격 피해 +30%. 중첩 불가.",
	"뇌운: 전하 폭발 5회마다 가까운 적에게 P의 120% 번개 피해.",
	"두 번째 존재: 강공격 사용 시 잔상이 같은 범위에 P의 80% 양자 피해. 3초 간격.",
	"완성된 공식: 각인 폭발 4회마다 스킬 남은 대기시간 2초 감소.",
]
const POWERS = [
	"전쟁의 시간: 6초간 공격 속도 +30%, 직접 피해 치명타 확률 +20%p.",
	"태양 낙하: 지정 지점에 P의 600% 불 피해. 생존 대상에게 화상 최대 중첩.",
	"백야: 5초간 주변 눈보라. 0.5초마다 P의 35% 얼음 피해와 냉기 1중첩.",
	"대홍수: 전방 넓은 범위에 P의 500% 물 피해와 강한 밀치기.",
	"대지의 요새: 최대 생명력의 30% 보호막, 주변에 P의 300% 땅 피해.",
	"세계수의 정원: 6초간 정원. 1초마다 P의 40% 풀 피해. 내부에서 초당 최대 생명력 1% 회복.",
	"폭풍의 눈: 5초간 따라오는 회오리. 0.5초마다 P의 30% 바람 피해와 약한 집결.",
	"천벌: 4초간 0.4초마다 주변 무작위 적 1명에게 P의 70% 번개 피해.",
	"사건의 지평선: 지정 지점에 공허 구체. 4초 뒤 P의 650% 양자 피해.",
	"절대 법정: 5초간 결계. 1초마다 P의 80% 허수 피해와 질서 각인 1중첩.",
]

static func catalog() -> Array:
	var result: Array = []
	_append_rows(result, NORMAL_ROWS, "normal")
	_append_rows(result, LEGEND_ROWS, "legendary")
	_append_rows(result, DUO_ROWS, "duo")
	return result

static func _append_rows(result: Array, rows: String, kind: String) -> void:
	for line in rows.strip_edges().split("\n"):
		var fields = line.strip_edges().split("|")
		var id: String = fields[0]
		var index: int = CODES.find(id.left(1))
		var elements: Array = []
		if kind == "duo":
			for code in fields[4].split("/"):
				elements.append(ELEMENTS[CODES.find(code)])
		else:
			elements.append(ELEMENTS[index])
		var groups: Array = []
		var labels: Array[String] = []
		for requirement in fields[3].split("+", false):
			if requirement.is_empty():
				continue
			var alternatives: Array = []
			if SOURCES.has(requirement):
				alternatives = SOURCES[requirement].duplicate()
				labels.append(SOURCE_NAMES[requirement])
			elif requirement.ends_with("-core"):
				for n in range(1, 5):
					alternatives.append(requirement.left(1) + "%02d" % n)
				labels.append(ELEMENTS[CODES.find(requirement.left(1))] + " 핵심")
			else:
				for alternative in requirement.split("/"):
					alternatives.append(alternative)
				labels.append(" 또는 ".join(alternatives))
			groups.append(alternatives)
		var number: int = int(id.substr(1)) if kind == "normal" else 0
		var core_slot: String = SLOTS[number - 1] if number >= 1 and number <= 4 else ""
		var item: Dictionary = {
			"id": id, "name": fields[1], "kind": kind, "element": elements[0],
			"elements": elements, "deity": DEITIES[index] if index >= 0 else "",
			"slot": core_slot, "category": "보조" if core_slot.is_empty() else ["기본 공격", "강공격", "전투 스킬", "회피"][number - 1],
			"template": fields[2], "scalable": kind == "normal" and fields[2].contains("{"),
			"prerequisites": groups, "requires": groups, "prerequisite_text": " + ".join(labels) if not labels.is_empty() else "없음",
			"tags": elements.duplicate(), "icon": "focus" if core_slot.is_empty() else ["edge", "edge", "storm", "stride"][number - 1],
			"max_level": 5 if kind == "normal" and fields[2].contains("{") else 1,
		}
		item["description"] = description(item, 0)
		item["requirements"] = groups
		item["requirements_text"] = item.prerequisite_text
		result.append(item)

static func find(data: Array, id: String) -> Dictionary:
	for item in data:
		if item.id == id:
			return item
	return {}

static func slot(item: Dictionary) -> String:
	return item.get("slot", "")

static func scale(rarity: int, level: int = 1) -> float:
	if rarity >= 3:
		return 1.0
	return POWER[clampi(rarity, 0, 2)] * (1.0 + 0.1 * (clampi(level, 1, 5) - 1))

static func description(item: Dictionary, rarity: int, level: int = 1) -> String:
	var text: String = item.get("template", item.get("description", ""))
	var pattern = RegEx.new()
	pattern.compile("\\{([0-9.]+)\\}")
	var matches = pattern.search_all(text)
	matches.reverse()
	for found in matches:
		var value: float = float(found.get_string(1)) * scale(rarity, level)
		var rendered: String = ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")
		text = text.substr(0, found.get_start()) + rendered + text.substr(found.get_end())
	return text

static func counts(data: Array, owned: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for element in ELEMENTS:
		result[element] = 0
	for item in data:
		if item.kind == "normal" and owned.has(item.id):
			result[item.element] += 1
	return result

static func tier(count: int) -> int:
	var result: int = 0
	for threshold in THRESHOLDS:
		if count >= threshold:
			result += 1
	return result

static func _meets(item: Dictionary, enabled: Dictionary) -> bool:
	for group in item.get("prerequisites", []):
		var met: bool = false
		for id in group:
			if enabled.get(id, false):
				met = true
				break
		if not met:
			return false
	return true

static func prerequisite_progress(data: Array, owned: Dictionary, item: Dictionary) -> Dictionary:
	var enabled: Dictionary = active(data, owned)
	var groups: Array = []
	var met_count: int = 0
	for group in item.get("prerequisites", []):
		var alternatives: Array = []
		var met: bool = false
		for id in group:
			var satisfied: bool = enabled.get(id, false)
			var required_item: Dictionary = find(data, id)
			alternatives.append({"id": id, "name": required_item.get("name", id),
				"owned": owned.has(id), "active": satisfied})
			met = met or satisfied
		if met:
			met_count += 1
		groups.append({"met": met, "alternatives": alternatives})
	return {"met": met_count, "total": groups.size(), "complete": met_count == groups.size(),
		"groups": groups, "text": item.get("prerequisite_text", "없음")}

static func active(data: Array, owned: Dictionary) -> Dictionary:
	var enabled: Dictionary = {}
	for id in owned:
		enabled[id] = false
	# Least fixed point prevents mutually dependent spreaders from sustaining themselves.
	var changed: bool = true
	while changed:
		changed = false
		for item in data:
			if owned.has(item.id) and not enabled[item.id] and _meets(item, enabled):
				enabled[item.id] = true
				changed = true
	return enabled

static func registered_pool(data: Array, owned: Dictionary, registered: Array = []) -> Array:
	var pool: Array = []
	for value in registered:
		var element: String = str(value)
		if CODES.has(element):
			element = ELEMENTS[CODES.find(element)]
		if ELEMENTS.has(element) and not pool.has(element):
			pool.append(element)
	for item in data:
		if item.kind == "normal" and owned.has(item.id) and not pool.has(item.element):
			pool.append(item.element)
	return pool

static func can_level(item: Dictionary, levels: Dictionary = {}) -> bool:
	return item.get("kind", "") == "normal" and item.get("scalable", false) and int(levels.get(item.id, 1)) < 5

static func eligible(data: Array, owned: Dictionary, registered: Array = [], levels: Dictionary = {}) -> Array:
	var enabled: Dictionary = active(data, owned)
	var pool: Array = registered_pool(data, owned, registered)
	var result: Array = []
	for item in data:
		if not _meets(item, enabled):
			continue
		if owned.has(item.id):
			if not enabled.get(item.id, false) or not can_level(item, levels):
				continue
		if item.kind == "normal" and pool.size() >= 4 and not pool.has(item.element):
			continue
		result.append(item)
	return result

static func rarity_at(value: float) -> int:
	var total: float = 0.0
	for i in WEIGHTS.size():
		total += WEIGHTS[i]
		if value < total:
			return i
	return 2

static func roll_rarity(rng: RandomNumberGenerator, boosted: bool = false) -> int:
	var value: float = rng.randf() * 100.0
	if not boosted:
		return rarity_at(value)
	var total: float = 0.0
	for i in BOOSTED_WEIGHTS.size():
		total += BOOSTED_WEIGHTS[i]
		if value < total:
			return i
	return 2

# Set pity.reward_element to target a deity reward; otherwise a deity is sampled.
# Set pity.reroll=true for one reroll, or keep pity.reward_id stable across rerolls.
# Acquisitions are inferred from the inventory at the next reward.
static func offer(data: Array, owned: Dictionary, registered: Array, levels: Dictionary, pity: Dictionary, rng: RandomNumberGenerator) -> Array:
	var same_reward: bool = pity.has("reward_id") and pity.has("_last_reward_id") and pity.reward_id == pity._last_reward_id
	var reroll: bool = bool(pity.get("reroll", false)) or same_reward
	pity.erase("reroll")
	if reroll and pity.has("_reward_before"):
		var before: Dictionary = pity._reward_before
		for key in ["sequence", "deities", "waiting"]:
			pity[key] = before[key].duplicate(true) if before[key] is Dictionary else before[key]
	else:
		pity["_reward_before"] = {
			"sequence": int(pity.get("sequence", 0)),
			"deities": pity.get("deities", {}).duplicate(true),
			"waiting": pity.get("waiting", {}).duplicate(true),
		}
	if pity.has("reward_id"):
		pity["_last_reward_id"] = pity.reward_id
	var explicit_element: bool = pity.has("reward_element")
	if reroll and pity.has("last_reward_element"):
		pity["reward_element"] = pity.last_reward_element
	var result: Array = _offer_reward(data, owned, registered, levels, pity, rng)
	if reroll and not explicit_element:
		pity.erase("reward_element")
	return result

static func _offer_reward(data: Array, owned: Dictionary, registered: Array, levels: Dictionary, pity: Dictionary, rng: RandomNumberGenerator) -> Array:
	var candidates: Array = eligible(data, owned, registered, levels)
	var pool: Array = registered_pool(data, owned, registered)
	var reward_element: String = str(pity.get("reward_element", ""))
	if CODES.has(reward_element):
		reward_element = ELEMENTS[CODES.find(reward_element)]
	if not ELEMENTS.has(reward_element) or (pool.size() >= 4 and not pool.has(reward_element)):
		var choices: Array = pool if not pool.is_empty() else ELEMENTS
		reward_element = choices[rng.randi_range(0, choices.size() - 1)]
	pity["last_reward_element"] = reward_element
	var sequence: int = int(pity.get("sequence", 0)) + 1
	pity["sequence"] = sequence
	var faith: Dictionary = counts(data, owned)
	var enabled: Dictionary = active(data, owned)
	var history: Dictionary = pity.get("deities", {})
	var had_history: bool = history.has(reward_element)
	var state: Dictionary = history.get(reward_element, {"misses": 0, "owned": [], "since": sequence})
	var current_ids: Array = []
	for item in data:
		if item.kind == "normal" and item.element == reward_element and owned.has(item.id):
			current_ids.append(item.id)
	var acquired: bool = false
	for id in current_ids:
		if not state.owned.has(id):
			acquired = true
			break
	state["misses"] = 0 if acquired or not had_history else int(state.misses) + 1
	if acquired:
		state["since"] = sequence
	state["owned"] = current_ids
	history[reward_element] = state
	pity["deities"] = history
	var waiting: Dictionary = pity.get("waiting", {})
	var guarantees: Array = []
	for item in data:
		if item.kind == "normal":
			continue
		if owned.has(item.id) or not _meets(item, enabled):
			waiting.erase(item.id)
			continue
		if not item.elements.has(reward_element):
			continue
		var pending: Dictionary = waiting.get(item.id, {"age": 0, "since": sequence})
		pending["age"] = int(pending.age) + 1
		waiting[item.id] = pending
		var threshold: int = 3 if item.kind == "legendary" else 4
		if pending.age >= threshold and candidates.has(item):
			guarantees.append({"since": pending.since, "id": item.id, "items": [item]})
	if int(state.misses) >= 2:
		var fresh: Array = []
		for item in candidates:
			if item.kind == "normal" and item.element == reward_element and not owned.has(item.id):
				fresh.append(item)
		if not fresh.is_empty():
			guarantees.append({"since": state.since, "id": "new", "items": fresh})
	guarantees.sort_custom(func(a, b): return a.since < b.since if a.since != b.since else a.id < b.id)
	var selected: Array = []
	for guarantee in guarantees:
		if selected.size() >= 3:
			break
		var choices: Array = guarantee.items.filter(func(item): return not selected.has(item))
		if not choices.is_empty():
			selected.append(choices[rng.randi_range(0, choices.size() - 1)])
	while selected.size() < 3:
		var remaining: Array = candidates.filter(func(item): return not selected.has(item))
		if remaining.is_empty():
			# An exhausted catalog cannot supply three legal unique items.
			break
		selected.append(_weighted_pick(remaining, owned, faith, reward_element, selected.size(), rng))
	var result: Array = []
	for item in selected:
		var offered: Dictionary = item.duplicate(true)
		offered["upgrade"] = owned.has(item.id)
		offered["rarity"] = int(owned[item.id]) if owned.has(item.id) else (3 if item.kind == "legendary" else (4 if item.kind == "duo" else roll_rarity(rng, bool(pity.get("rarity_boost", false)))))
		offered["level"] = int(levels.get(item.id, 1)) + 1 if offered.upgrade else 1
		offered["reward_element"] = reward_element
		offered["description"] = description(item, offered.rarity, offered.level)
		result.append(offered)
		if waiting.has(item.id):
			waiting[item.id] = {"age": 0, "since": sequence + 1}
	pity["waiting"] = waiting
	return result

static func _weighted_pick(items: Array, owned: Dictionary, faith: Dictionary, reward_element: String, position: int, rng: RandomNumberGenerator) -> Dictionary:
	var weights: Array[float] = []
	var total: float = 0.0
	for item in items:
		var weight: float = 1.0
		if item.elements.has(reward_element):
			weight *= 5.0
		if item.kind != "normal":
			weight *= 0.45
		elif owned.has(item.id):
			weight *= 0.65
		elif faith.get(item.element, 0) == 3:
			weight *= 3.0
		if position == 0 and not slot(item).is_empty():
			weight *= 2.0
		elif position == 1 and (not item.prerequisites.is_empty() or item.kind != "normal"):
			weight *= 2.5
		elif position == 2 and item.kind == "normal" and item.prerequisites.is_empty() and not owned.has(item.id):
			weight *= 2.0
		total += weight
		weights.append(weight)
	var roll: float = rng.randf() * total
	for i in items.size():
		roll -= weights[i]
		if roll <= 0.0:
			return items[i]
	return items.back()

static func preview(data: Array, owned: Dictionary, item: Dictionary, rarity: int = 0, levels: Dictionary = {}) -> Dictionary:
	var next: Dictionary = owned.duplicate()
	var next_levels: Dictionary = levels.duplicate()
	var removed: Array = []
	if not owned.has(item.id) and not slot(item).is_empty():
		for old in data:
			if owned.has(old.id) and slot(old) == slot(item):
				next.erase(old.id)
				next_levels.erase(old.id)
				removed.append(old.id)
	next[item.id] = owned.get(item.id, rarity)
	next_levels[item.id] = int(levels.get(item.id, 1)) + 1 if owned.has(item.id) else 1
	var before: Dictionary = active(data, owned)
	var after: Dictionary = active(data, next)
	var dormant: Array = []
	var awakened: Array = []
	for id in next:
		if before.get(id, false) and not after.get(id, false):
			dormant.append(id)
		elif not before.get(id, false) and after.get(id, false):
			awakened.append(id)
	var old_counts: Dictionary = counts(data, owned)
	var new_counts: Dictionary = counts(data, next)
	var powers_lost: Array = []
	var myths_lost: Array = []
	for element in ELEMENTS:
		if old_counts[element] >= 4 and new_counts[element] < 4:
			powers_lost.append(element)
		if old_counts[element] >= 6 and new_counts[element] < 6:
			myths_lost.append(element)
	return {"owned": next, "levels": next_levels, "removed": removed, "dormant": dormant,
		"awakened": awakened, "active": after, "counts_before": old_counts,
		"counts_after": new_counts, "powers_lost": powers_lost, "myths_lost": myths_lost}

static func synergy_text(element: String) -> String:
	var index: int = ELEMENTS.find(element)
	if index < 0:
		return ""
	return "1: 접촉 / 2: %s 피해 +10%% / 4: 권능 「%s」 / 6: 신화 「%s」" % [element, POWERS[index], MYTHS[index]]
