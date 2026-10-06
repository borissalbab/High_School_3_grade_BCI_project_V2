# High_School_3_grade_BCI_project_V2
extension of Goku BCI + arduino&amp;processing compatibility test(arduino lcd)


NeuroSky TGAM에서 측정한 EEG 데이터를 Processing에서 분석하고,
집중 상태가 감지되었을 때 Arduino로 문자를 전송하여
I2C LCD에 출력하는 BCI 시스템을 구현했다.

## Project Overview

Goku BCI의 보안 & 확장 버전

기존 프로젝트에서 EEG Attention 값을 이용해 시각적인 변화를
제어하는 것에서 더 나아가, 이번 프로젝트에서는

**EEG 데이터 → 신뢰성 판단 → 집중 상태 감지 → Arduino 통신 → LCD 출력**

의 전체 과정을 구현하는 것을 목표로 했다.

사용자가 자신의 이름을 입력하면 LCD에 이름이 표시되고,
EEG 데이터에서 집중 상태가 감지될 때마다 이름의 다음 글자가
LCD에 한 글자씩 출력된다.

모든 글자가 출력되면 LCD에 `MISSION COMPLETE!!`가 표시된다.

---

## System Architecture
```text
       NeuroSky TGAM
            │
            │ EEG Data
            ▼
      Processing
            │
            ├── Attention
            ├── Signal Quality
            └── Beta Power
            │
            ▼
   Reliability Check
            │
            ▼
     Focusing Event
            │
            │ Serial Communication
            ▼
         Arduino
            │
            │ I2C
            ▼
       16x2 LCD
   ```    
---

## Main Features

### 1. EEG Data Acquisition

NeuroSky TGAM으로부터 실시간 EEG 데이터를 수신하고
Processing에서 TGAM 패킷을 분석한다.

다음 데이터를 사용한다.

* Attention
* Signal Quality
* Beta Power

TGAM의 `0xAA 0xAA` 패킷 헤더를 기준으로 데이터를 수신하고,
각 데이터 코드에 따라 필요한 값을 추출한다.

---

### 2. EEG Data Reliability Check

Attention 값만 단순하게 사용하는 것이 아니라
Signal Quality와 Beta Power를 함께 사용하여
현재 Attention 값을 신뢰할 수 있는지 판단하도록 구현했다.

```java

boolean isReliableAttention(int att, int signalQ, int beta) {
  return signalQ <= 50 &&
         att >= 0 &&
         att <= 100 &&
         abs(att - scaleBetaToAttention(beta)) < 40;
}
```

Beta Power는 다음과 같이 0~100 범위의 값으로 변환하여
Attention과 비교한다.

```java

int scaleBetaToAttention(int betaPower) {
  return constrain((int)(betaPower / 600.0), 0, 100);
}
```

이 조건을 통과한 경우에만 해당 데이터를
집중 상태 판단 및 로그 기록에 사용한다.

> 이 프로젝트에서 사용한 신뢰성 판단 방식은
> 실험 과정에서 직접 구성한 휴리스틱 기준이다.

---

### 3. EEG → Focusing Event

단순히 집중 상태인 동안 계속해서 문자를 전송하는 것이 아니라,
집중 상태로 **전환되는 순간**을 감지하도록 구현했다.

```java
if (!wasFocusing && isFocusing && sentLetters < userName.length()) {
    ...
}
```

즉,

```text
Not Focusing
      │
      │ EEG 조건 만족
      ▼
   Focusing
      │
      ▼
문자 1개 전송
```

과 같은 방식으로 동작한다.

이를 통해 집중 상태가 유지되는 동안
같은 문자가 반복적으로 전송되는 것을 방지했다.

---

### 4. Processing → Arduino Serial Communication

Processing에서 Arduino로 다음과 같은 명령을 전송한다.

```text
CLEAR
TITLE:FOCUSING...
LINE2:<name>
CHAR:<character>
TITLE:MISSION
LINE2:COMPLETE!!
```

Arduino는 전달받은 명령을 분석하여 LCD를 제어한다.

---

### 5. Arduino + I2C LCD

Arduino에는 `LiquidCrystal_I2C` 라이브러리를 사용하여
16x2 I2C LCD를 연결했다.

```cpp
LiquidCrystal_I2C lcd(0x27, 16, 2);
```

Arduino는 Processing으로부터 전달받은 명령에 따라

* LCD 초기화
* 제목 출력
* 두 번째 줄 전체 출력
* 문자 하나씩 추가 출력

을 수행한다.

---

### 6. TGAM Packet Error Recovery

EEG 데이터 수신 과정에서 패킷이 손상되거나
비정상적인 Attention 값이 들어오는 경우를 고려하여
패킷 복구 로직을 구현했다.

```java
void forceRecoverFromCorruptedPacket()
```

현재 수신 중인 패킷에서 다시

```text
0xAA 0xAA
```

헤더를 탐색하여 새로운 패킷의 시작점을 찾고,
정상적인 패킷 처리를 다시 시작하도록 구성했다.

---

### 7. EEG Data Logging

신뢰성 조건을 만족한 EEG 데이터는
`attention-log.txt`에 기록한다.

로그에는 다음 정보가 저장된다.

```text
시간 | Attention | Beta Power | Signal Quality
```

예시:

```text
14:32:10 | ATT: 67 | BETA: 40231 | SIG: 12
```

로그는 10개의 데이터가 기록될 때마다
`flush()`하여 파일에 반영하도록 구현했다.

---

## Hardware

* NeuroSky TGAM
* Arduino
* 16x2 I2C LCD
* I2C connection
* Computer

### Serial Communication

| Connection           | Baud Rate |
| -------------------- | --------: |
| TGAM → Processing    |     57600 |
| Processing → Arduino |      9600 |

### LCD

* Display: 16x2
* Interface: I2C
* Address: 0x27

---

## Software

* Processing
* Arduino IDE
* Arduino
* LiquidCrystal_I2C
* Java Serial
* Arduino Wire

---

## Project Flow

1. 사용자 이름 입력
        ↓
2. Processing → Arduino
        ↓
3. LCD에 이름 표시
        ↓
4. 이름 입력 완료
        ↓
5. EEG 데이터 수신
        ↓
6. Attention / Signal Quality / Beta Power 분석
        ↓
7. EEG 데이터 신뢰성 판단
        ↓
8. Focusing 상태 전환 감지
        ↓
9. 이름의 다음 글자 전송
        ↓
10. Arduino → LCD 출력
        ↓
11. 모든 글자 출력
        ↓
12. MISSION COMPLETE!!
    
---

## What I Learned

이 프로젝트를 통해 단순히 EEG 데이터를 받아 사용하는 것보다
**측정된 신호에서 신뢰할 수 있는 정보를 추출하는 과정이
BCI 시스템에서 중요하다는 점**을 경험했다.

특히 EEG 데이터는 항상 일정한 값을 제공하지 않기 때문에
Attention 하나만 사용하는 대신 Signal Quality와 Beta Power를
함께 고려하는 방식을 실험했다.

또한 Processing에서 데이터를 처리하는 것에 그치지 않고
Arduino와 LCD를 연결하여 실제 하드웨어의 동작으로
이어지는 전체 시스템을 구현했다.

이를 통해

* EEG 데이터 수집
* 데이터 파싱
* 신호 신뢰성 판단
* Serial Communication
* Arduino 제어
* I2C 통신
* LCD 출력
* 데이터 로깅
* 오류 패킷 복구

까지 하나의 시스템으로 연결해보았다.

---

## Files

attention-log.txt
    └── 신뢰성 조건을 통과한 EEG 데이터 로그

name_lcd_processing.pde
    └── EEG 데이터 처리 및 Arduino 통신

name_lcd_arduino.ino
    └── Arduino에서 LCD를 제어하는 코드
    
---

## Future Improvements

* EEG 데이터에 대한 보다 안정적인 filtering 방법 적용
* 사용자별 EEG 특성을 반영한 personalized threshold 적용
* Attention 외 다양한 EEG feature 활용
* Serial Port 자동 인식 및 연결 안정성 개선
* EEG 데이터 시각화 및 분석 기능 추가
* 보다 다양한 하드웨어 출력 장치와 연동

ai 맛있네
